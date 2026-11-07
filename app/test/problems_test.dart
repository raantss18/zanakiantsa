import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/engine.dart';
import 'package:zanakiantsa/core/game.dart';

/// Les problèmes d'échecs (ADR 0040) : chaque position est permise, et les coups donnés comme solutions sont
/// exactement tous les coups qui réussissent selon le thème. Pas de solution oubliée, pas de « fausse » réponse juste.
void main() {
  final topic = Topic(jsonDecode(File('assets/content/echecs.json').readAsStringSync()) as Map<String, dynamic>);
  final problems = topic.skills.where((s) => s.activity == 'probleme').toList();

  /// La pièce en [from] attaque-t-elle la case [to] (marche de la pièce, pièces qui bouchent la ligne comprises) ?
  bool hits(List<String?> b, int from, int to) {
    final piece = b[from]!.toUpperCase();
    final (fr, ff, tr, tf) = (from ~/ 8, from % 8, to ~/ 8, to % 8);
    final (dr, df) = (tr - fr, tf - ff);
    switch (piece) {
      case 'P':
        return dr == (isWhitePiece(b[from]!) ? 1 : -1) && df.abs() == 1;
      case 'N':
        return (dr.abs() == 1 && df.abs() == 2) || (dr.abs() == 2 && df.abs() == 1);
      case 'K':
        return dr.abs() <= 1 && df.abs() <= 1 && (dr != 0 || df != 0);
    }
    final straight = dr == 0 || df == 0, diagonal = dr.abs() == df.abs();
    if ((dr == 0 && df == 0) || !(piece == 'R' && straight || piece == 'B' && diagonal || piece == 'Q' && (straight || diagonal))) return false;
    final (sr, sf) = (dr.sign, df.sign);
    for (var (r, f) = (fr + sr, ff + sf); (r, f) != (tr, tf); (r, f) = (r + sr, f + sf)) {
      if (b[r * 8 + f] != null) return false;
    }
    return true;
  }

  /// Les pièces blanches qui font échec au roi noir.
  Set<int> checkers(Position q) {
    final k = q.kingOf(false)!;
    return {for (var s = 0; s < 64; s++) if (q.board[s] != null && isWhitePiece(q.board[s]!) && hits(q.board, s, k)) s};
  }

  bool mate(Position q) => q.inCheck && q.legalMoves().isEmpty;

  /// Les coups qui réussissent, d'après le moteur, pour un thème.
  Set<String> winning(String theme, Position p) {
    final moves = p.legalMoves();
    switch (theme) {
      case 'roque':
        return {for (final m in moves) if (p.board[m.from] == 'K' && (m.to - m.from).abs() == 2) m.uci};
      case 'promotion':
        return {for (final m in moves) if (m.promo == 'q' && (p.board[m.to] != null || !moves.any((o) => o.promo == 'q' && p.board[o.to] != null))) m.uci};
      case 'en-passant':
        return {for (final m in moves) if (p.board[m.from] == 'P' && m.to == p.ep) m.uci};
      case 'couloir':
        return {for (final m in moves) if (p.play(m).inCheck && p.play(m).legalMoves().isEmpty) m.uci};
      case 'fourchette':
        return {
          for (final m in moves)
            if (p.play(m).inCheck &&
                !p.play(m).attacked(m.to, byWhite: false) &&
                Position(List.of(p.play(m).board), whiteToMove: true)
                    .legalMoves()
                    .any((x) => x.from == m.to && 'rq'.contains(p.play(m).board[x.to] ?? '-')))
              m.uci,
        };
      case 'gratuite':
        final free = {
          for (final m in moves)
            if (p.isCapture(m) && !p.play(m).attacked(m.to, byWhite: false)) m.uci: pieceValue[p.board[m.to]!.toUpperCase()]!,
        };
        if (free.isEmpty) return {};
        final best = free.values.reduce((a, b) => a > b ? a : b);
        return {for (final e in free.entries) if (e.value == best) e.key};
      case 'mat':
        return {for (final m in moves) if (mate(p.play(m))) m.uci};
      case 'double':
        return {for (final m in moves) if (checkers(p.play(m)).length == 2) m.uci};
      case 'decouverte':
        // Échec par une autre pièce que celle qui a bougé, et celle-ci prend une pièce (pas un pion) au passage.
        return {
          for (final m in moves)
            if (p.play(m).inCheck &&
                !checkers(p.play(m)).contains(m.to) &&
                p.board[m.to] != null &&
                !isWhitePiece(p.board[m.to]!) &&
                p.board[m.to] != 'p')
              m.uci,
        };
      case 'clouage':
        // Pas d'échec, la pièce est à l'abri, et une pièce noire (ni roi ni pion) protège seule son roi de cette pièce.
        return {
          for (final m in moves)
            if (!p.play(m).inCheck &&
                !p.play(m).attacked(m.to, byWhite: false) &&
                [
                  for (var x = 0; x < 64; x++)
                    if (p.play(m).board[x] case final c? when !isWhitePiece(c) && c != 'k' && c != 'p') x,
                ].any((x) {
                  final b = List.of(p.play(m).board)..[x] = null;
                  return hits(b, m.to, p.play(m).kingOf(false)!);
                }))
              m.uci,
        };
      case 'deviation':
        // On offre une pièce en faisant échec : toutes les réponses la prennent (pas avec le roi), et chaque prise permet
        // un mat au coup suivant.
        return {
          for (final m in moves)
            if (p.play(m).inCheck &&
                p.play(m).legalMoves().isNotEmpty &&
                p.play(m).legalMoves().every((r) =>
                    r.to == m.to &&
                    p.play(m).board[r.from] != 'k' &&
                    p.play(m).play(r).legalMoves().any((x) => mate(p.play(m).play(r).play(x)))))
              m.uci,
        };
      case 'enfilade':
        // Tour, fou ou dame seule à faire échec, à l'abri ; derrière le roi, sur la même ligne, une pièce noire (pas un pion).
        return {
          for (final m in moves)
            if ('RBQ'.contains(p.board[m.from]!) &&
                checkers(p.play(m)).length == 1 &&
                checkers(p.play(m)).single == m.to &&
                !p.play(m).attacked(m.to, byWhite: false) &&
                (() {
                  final q = p.play(m);
                  final k = q.kingOf(false)!;
                  final (sr, sf) = ((k ~/ 8 - m.to ~/ 8).sign, (k % 8 - m.to % 8).sign);
                  for (var (r, f) = (k ~/ 8 + sr, k % 8 + sf); r >= 0 && r < 8 && f >= 0 && f < 8; (r, f) = (r + sr, f + sf)) {
                    final c = q.board[r * 8 + f];
                    if (c != null) return !isWhitePiece(c) && c != 'p';
                  }
                  return false;
                })())
              m.uci,
        };
    }
    throw StateError('thème inconnu $theme');
  }

  test('quinze leçons de problèmes', () {
    expect(problems.map((s) => s.id).toSet(), {
      'roque', 'promotion', 'en-passant', 'piece-gratuite', 'fourchette', 'mat-couloir', //
      'mat-escalier', 'mat-baiser', 'clouage', 'enfilade', 'decouverte', 'double-echec', //
      'mat-etouffee', 'attaque-double-dame', 'deviation',
    });
  });

  for (final s in problems) {
    test('${s.id} : solutions = tous les coups qui réussissent', () {
      for (final it in s.items) {
        final p = Position.fen(it.fen!);
        expect(p.whiteToMove, isTrue, reason: it.fen);
        expect(p.inCheck, isFalse, reason: '${it.fen} : les Blancs ne commencent pas en échec');
        // Les Noirs ne sont pas en échec non plus (position possible).
        expect(Position(List.of(p.board), whiteToMove: false).inCheck, isFalse, reason: it.fen);
        expect(it.moves.toSet(), winning(s.params['theme'] as String, p), reason: it.fen);
      }
    });
  }
}
