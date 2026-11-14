/// Le robot des échecs et l'analyse des parties (ADR 0040). Recherche alpha-bêta classique avec prolongation sur les
/// prises ; évaluation : matériel (pion 1, cavalier et fou 3, tour 5, dame 9 — valeurs d'initiation usuelles) et un
/// petit bonus pour les pièces au centre. Écrit pour l'app (aucun code repris). Les calculs lourds tournent hors du
/// fil de l'interface (`compute`).
library;

import 'dart:math';

import '../l10n/l10n.dart';
import 'game.dart';

const pieceValue = {'P': 100, 'N': 300, 'B': 310, 'R': 500, 'Q': 900, 'K': 0};
const _mate = 100000;

int _center(int s) {
  final f = s % 8, r = s ~/ 8;
  final d = (f - 3.5).abs() + (r - 3.5).abs(); // 1 au centre, 7 dans un coin
  return (7 - d).round() * 4;
}

/// Note de la position pour le camp qui a le trait (en centièmes de pion).
int evaluate(Position p) {
  var score = 0;
  for (var s = 0; s < 64; s++) {
    final x = p.board[s];
    if (x == null) continue;
    final k = x.toUpperCase();
    var v = pieceValue[k]!;
    if (k == 'N' || k == 'B') v += _center(s);
    if (k == 'P') v += (isWhitePiece(x) ? s ~/ 8 - 1 : 6 - s ~/ 8) * 6; // un pion qui avance vaut un peu plus
    score += isWhitePiece(x) ? v : -v;
  }
  return p.whiteToMove ? score : -score;
}

/// Ordre des coups : les prises les plus intéressantes d'abord (grosse pièce prise par une petite).
List<Move> _ordered(Position p, List<Move> moves) {
  int key(Move m) {
    final victim = p.board[m.to];
    final attacker = pieceValue[p.board[m.from]!.toUpperCase()]!;
    return (victim == null ? 0 : 10 * pieceValue[victim.toUpperCase()]! - attacker) + (m.promo == 'q' ? 800 : 0);
  }

  return moves.toList()..sort((a, b) => key(b) - key(a));
}

int _quiesce(Position p, int alpha, int beta, int depth) {
  final stand = evaluate(p);
  if (stand >= beta || depth == 0) return stand;
  if (stand > alpha) alpha = stand;
  for (final m in _ordered(p, p.legalMoves().where(p.isCapture).toList())) {
    final v = -_quiesce(p.play(m), -beta, -alpha, depth - 1);
    if (v >= beta) return v;
    if (v > alpha) alpha = v;
  }
  return alpha;
}

int _search(Position p, int depth, int alpha, int beta, int ply) {
  final moves = p.legalMoves();
  if (moves.isEmpty) return p.inCheck ? -_mate + ply : 0;
  if (p.insufficientMaterial || p.halfmove >= 100) return 0;
  if (depth == 0) return _quiesce(p, alpha, beta, 4);
  var best = -_mate * 2;
  for (final m in _ordered(p, moves)) {
    final v = -_search(p.play(m), depth - 1, -beta, -alpha, ply + 1);
    if (v > best) best = v;
    if (v > alpha) alpha = v;
    if (alpha >= beta) break;
  }
  return best;
}

/// Note de chaque coup légal (pour le camp qui a le trait), à la profondeur [depth].
Map<Move, int> scoreMoves(Position p, int depth) => {
      for (final m in _ordered(p, p.legalMoves())) m: -_search(p.play(m), depth - 1, -_mate * 2, _mate * 2, 1),
    };

/// Niveaux du robot : 1 joue vite et se trompe souvent, 3 calcule trois demi-coups et ne laisse rien en prise.
/// Entrée pour `compute` : (fen, niveau, graine) → coup UCI.
String robotMove((String, int, int) a) {
  final (fen, level, seed) = a;
  final p = Position.fen(fen);
  final r = Random(seed);
  final moves = p.legalMoves();
  if (level <= 1 && r.nextDouble() < 0.35) return moves[r.nextInt(moves.length)].uci;
  final scores = scoreMoves(p, level <= 1 ? 1 : level);
  // Un peu de hasard entre coups presque aussi bons : le robot ne joue pas toujours la même partie.
  final noise = switch (level) { <= 1 => 120, 2 => 40, _ => 10 };
  final best = scores.values.reduce(max);
  final good = [for (final e in scores.entries) if (e.value >= best - noise) e.key];
  return good[r.nextInt(good.length)].uci;
}

/// Un commentaire sur un coup de l'enfant (ADR 0040).
class MoveNote {
  const MoveNote(this.ply, this.kind, this.text, {this.better});
  final int ply;

  /// mat, mat_manque, gaffe, prise_manquee, bien
  final String kind;
  final String text;

  /// Le coup qu'il valait mieux jouer (UCI), s'il y en a un.
  final String? better;

  Map<String, Object?> toJson() => {'ply': ply, 'kind': kind, 'text': text, 'better': better};
  static MoveNote fromJson(Map<String, dynamic> j) =>
      MoveNote(j['ply'] as int, j['kind'] as String, j['text'] as String, better: j['better'] as String?);
}

/// Analyse d'une partie pour le camp [white] : mat manqué, pièce laissée en prise, prise gratuite manquée, et les
/// bons coups (mat, échec gagnant du matériel). Entrée pour `compute` : (fen de départ, coups UCI, camp de l'enfant).
List<Map<String, Object?>> analyseGame((String, List<String>, bool) a) {
  final (fen, uci, white) = a;
  var p = Position.fen(fen);
  final notes = <MoveNote>[];
  for (final (ply, u) in uci.indexed) {
    final m = Move.parse(u);
    if (p.whiteToMove == white) {
      final note = _judge(p, m, ply);
      if (note != null) notes.add(note);
    }
    p = p.play(m);
  }
  return [for (final n in notes) n.toJson()];
}

MoveNote? _judge(Position p, Move m, int ply) {
  final next = p.play(m);
  final san = p.san(m);
  if (next.legalMoves().isEmpty && next.inCheck) return MoveNote(ply, 'mat', tf('{move} : échec et mat, bravo !', {'move': san}));
  // Un mat en un coup existait ?
  for (final o in p.legalMoves()) {
    final q = p.play(o);
    if (q.inCheck && q.legalMoves().isEmpty) {
      return MoveNote(ply, 'mat_manque', tf('Tu pouvais faire échec et mat avec {move} !', {'move': p.san(o)}), better: o.uci);
    }
  }
  final scores = scoreMoves(p, 2);
  final best = scores.entries.reduce((x, y) => y.value > x.value ? y : x);
  final played = scores[m]!;
  final loss = best.value - played;
  if (loss >= 250) {
    // Ce que l'adversaire peut prendre après ce coup.
    final replies = scoreMoves(next, 1);
    // Pat : l'adversaire n'a plus de coup. Sans cela, `reduce` levait « No element » et l'analyse restait sur « J'analyse la
    // partie… » (revue du 2026-11-14 : roi et dame contre roi, l'enfant fait pat).
    if (replies.isEmpty) {
      return MoveNote(ply, 'gaffe', tf('{move} : pat, la partie est nulle. Mieux : {best}.', {'move': san, 'best': p.san(best.key)}), better: best.key.uci);
    }
    final reply = replies.entries.reduce((x, y) => y.value > x.value ? y : x).key;
    final taken = next.board[reply.to];
    if (taken != null && next.isCapture(reply)) {
      final v = {'move': san, 'piece': pieceName(taken), 'square': squareName(reply.to), 'best': p.san(best.key)};
      return MoveNote(
          ply,
          'gaffe',
          taken.toUpperCase() == 'R' || taken.toUpperCase() == 'Q'
              ? tf('Après {move}, {piece} en {square} peut être prise : regarde toujours ce que l\'adversaire attaque. Mieux : {best}.', v)
              : tf('Après {move}, {piece} en {square} peut être pris : regarde toujours ce que l\'adversaire attaque. Mieux : {best}.', v),
          better: best.key.uci);
    }
    if (p.isCapture(best.key) && p.board[best.key.to] != null) {
      final prize = p.board[best.key.to]!;
      return MoveNote(ply, 'prise_manquee', tf('Tu pouvais prendre {piece} en {square} avec {move}.', {'piece': pieceName(prize), 'square': squareName(best.key.to), 'move': p.san(best.key)}),
          better: best.key.uci);
    }
    return MoveNote(ply, 'gaffe', tf('{move} fait perdre du matériel. Mieux : {best}.', {'move': san, 'best': p.san(best.key)}), better: best.key.uci);
  }
  if (next.inCheck && loss <= 30 && p.isCapture(m)) return MoveNote(ply, 'bien', tf('{move} : une prise avec échec, très bien !', {'move': san}));
  return null;
}
