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
    }
    throw StateError('thème inconnu $theme');
  }

  test('six leçons de problèmes', () {
    expect(problems.map((s) => s.id).toSet(), {'roque', 'promotion', 'en-passant', 'piece-gratuite', 'fourchette', 'mat-couloir'});
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
