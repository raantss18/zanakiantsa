/// L'analyse fine d'une partie avec Stockfish (ADR 0053). Le moteur est passé en paramètre : on peut donc tester ces règles
/// sans lui. Les commentaires de core/engine.dart gardent leurs explications ; le moteur ajoute ce qu'une recherche à deux
/// coups ne voit pas, et retire les fausses alertes.
library;

import 'engine.dart';
import 'game.dart';
import 'uci.dart';

/// Une perte de moins d'un demi-pion n'est pas une erreur : la recherche courte varie d'autant d'un essai à l'autre.
const fineSameLoss = 50;

/// À partir d'un pion et demi de perte, on en parle.
const fineErrorLoss = 150;

/// Encore 3 pions d'avance après le coup, ou déjà 3 pions de retard avant : ce coup ne change plus rien pour un enfant.
const fineDecided = 300;

/// Un mat manqué compte s'il tient en 3 coups ou moins ; au-delà, un enfant ne pouvait pas le voir.
const fineMateShown = 3;

/// Reprend [base] (les commentaires de `analyseGame`) avec le jugement du moteur. [search] renvoie meilleur coup et note
/// d'une position ; [onProgress] reçoit la part faite (0 à 1). Toute erreur du moteur remonte : l'appelant garde [base].
Future<List<MoveNote>> deepAnalyse({
  required String fen,
  required List<String> moves,
  required bool white,
  required List<MoveNote> base,
  required Future<SearchResult> Function(String fen) search,
  void Function(double)? onProgress,
  bool Function()? cancelled,
}) async {
  final out = <MoveNote>[];
  var p = Position.fen(fen);
  for (final (ply, u) in moves.indexed) {
    if (cancelled?.call() ?? false) return base;
    final m = Move.parse(u);
    final next = p.play(m);
    if (p.whiteToMove == white) {
      final note = base.where((n) => n.ply == ply).firstOrNull;
      // Mat donné ou mat en un coup manqué : la règle du jeu suffit, sans moteur.
      if (note != null && (note.kind == 'mat' || note.kind == 'mat_manque')) {
        out.add(note);
      } else {
        final before = await search(p.fen);
        final after = await search(next.fen);
        final fine = judgeFine(p, m, ply, before, after, note);
        if (fine != null) out.add(fine);
      }
    }
    p = next;
    onProgress?.call((ply + 1) / moves.length);
  }
  return out;
}

/// Le jugement d'un coup : [before] la position avant le coup (pour le joueur), [after] après (pour l'adversaire).
MoveNote? judgeFine(Position p, Move m, int ply, SearchResult before, SearchResult after, MoveNote? note) {
  final now = -after.score;
  final loss = before.score - now;
  final isBest = before.best == m.uci;
  // Le coup est aussi bon que le meilleur : ce que la petite recherche reprochait était une fausse alerte.
  if (isBest || loss < fineSameLoss) {
    final alert = note != null && (note.kind == 'gaffe' || note.kind == 'prise_manquee');
    return alert ? null : note;
  }
  final best = before.best;
  if (best == null || !p.legalMoves().any((o) => o.uci == best)) return note;
  final san = p.san(m), bestSan = p.san(Move.parse(best));
  // Un mat permis passe avant tout : la petite recherche ne voit que le matériel et dirait « fait perdre du matériel ».
  if (now < -(mateScore - 100) && before.score > -(mateScore - 100)) {
    final n = mateScore + now;
    return MoveNote(ply, 'mat_permis', 'Après $san, l\'adversaire peut faire échec et mat en $n coup${n > 1 ? 's' : ''}. Mieux : $bestSan.', better: best);
  }
  if (note != null) return note;
  final mateFor = before.score > mateScore - 100 ? mateScore - before.score : null;
  if (mateFor != null && mateFor <= fineMateShown && now <= mateScore - 100) {
    return MoveNote(ply, 'fort', 'Il y avait un échec et mat en $mateFor coups, en commençant par $bestSan.', better: best);
  }
  if (loss < fineErrorLoss || now >= fineDecided || before.score <= -fineDecided) return null;
  return MoveNote(ply, 'fort', 'Il y avait plus fort que $san : $bestSan.', better: best);
}
