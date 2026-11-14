import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/engine.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/leitner.dart';

// Défauts trouvés à la revue du 2026-11-14.
void main() {
  test('analyse : un pat ne fait plus échouer l\'analyse de la partie', () {
    // Roi et dame contre roi seul : Df7 fait pat. Avant, `reduce` sur une liste vide levait « No element ».
    final n = analyseGame(('7k/8/4QK2/8/8/8/8/8 w - - 0 1', ['e6f7'], true));
    expect(n, isNotEmpty);
    expect(n.single['kind'] ?? n.single.values.join(' '), anyOf(contains('gaffe'), contains('pat')));
  });

  test('révision : l\'échéance tombe à minuit du bon jour, par le calendrier', () {
    final c = review(null, true, DateTime(2026, 3, 28, 17));
    expect(c.due, DateTime(2026, 3, 29));
    final c2 = review(ReviewCard(4, DateTime(2026)), true, DateTime(2026, 10, 20, 9));
    expect((c2.box, c2.due), (5, DateTime(2026, 11, 5)));
    expect(c2.due.hour, 0);
  });

  test('une réponse garde ses erreurs expliquées à l\'aller-retour du journal', () {
    final a = Answer(skill: 'x', attempts: 3, correct: false, demonstrated: false, millis: 1, at: DateTime(2026, 11, 14), errors: const ['A', 'B']);
    expect(Answer.fromMap(a.toMap()).errors, ['A', 'B']);
  });
}
