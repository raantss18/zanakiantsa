import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/leitner.dart';
import 'package:zanakiantsa/core/mastery.dart';
import 'package:zanakiantsa/core/progress.dart';
import 'package:zanakiantsa/core/rules.dart';

final t0 = DateTime(2026, 11, 2, 10);

Answer ans(String skill, {bool correct = true, bool demo = false, DateTime? at}) =>
    Answer(skill: skill, attempts: 1, correct: correct, demonstrated: demo, millis: 1000, at: at ?? t0);

void main() {
  group('ADR 0006 — trois essais', () {
    test('démonstration avant 6 ans, indice seul à partir de 6 ans', () {
      expect(afterLastMiss(5), AfterLastMiss.demonstration);
      expect(afterLastMiss(6), AfterLastMiss.hintOnly);
      expect(afterLastMiss(9), AfterLastMiss.hintOnly);
    });
    test("l'aide monte à chaque erreur", () {
      expect([0, 1, 2, 3].map(helpAfter), [Help.none, Help.hint, Help.example, Help.last]);
      expect(maxAttempts, 3);
    });
  });

  group('ADR 0007 — maîtrise 4/5', () {
    test('moins de 5 réponses : pas maîtrisé', () {
      expect(isMastered(List.generate(4, (_) => ans('a'))), isFalse);
    });
    test('4 réussites sur les 5 dernières : maîtrisé', () {
      expect(isMastered([ans('a', correct: false), ans('a'), ans('a'), ans('a'), ans('a')]), isTrue);
    });
    test('3 sur 5 : pas maîtrisé ; seules les 5 dernières comptent', () {
      final three = [ans('a', correct: false), ans('a', correct: false), ans('a'), ans('a'), ans('a')];
      expect(isMastered(three), isFalse);
      expect(isMastered([...three, ans('a'), ans('a')]), isTrue);
    });
    test('une démonstration ne compte pas comme réussite', () {
      expect(isMastered([ans('a'), ans('a'), ans('a'), ans('a', demo: true), ans('a', demo: true)]), isFalse);
    });
  });

  group('ADR 0007 — Leitner', () {
    test('réussite : boîte suivante ; échec : boîte 1', () {
      final c1 = review(null, true, t0);
      expect(c1.box, 1);
      expect(c1.due, DateTime(2026, 11, 3));
      final c2 = review(c1, true, t0);
      expect((c2.box, c2.due), (2, DateTime(2026, 11, 4)));
      expect(review(c2, false, t0).box, 1);
    });
    test('la boîte 5 est un plafond', () {
      var c = review(null, true, t0);
      for (var i = 0; i < 10; i++) {
        c = review(c, true, t0);
      }
      expect(c.box, 5);
      expect(c.due, DateTime(2026, 11, 18));
    });
    test('échéance atteinte le jour même', () {
      final c = review(null, true, t0);
      expect(isDue(c, DateTime(2026, 11, 2, 23)), isFalse);
      expect(isDue(c, DateTime(2026, 11, 3, 0, 1)), isTrue);
    });
  });

  group('Progression', () {
    const skills = [SkillRef('a', []), SkillRef('b', ['a'])];
    test('au départ, toute la séance va à la première compétence ouverte', () {
      expect(Progress(skills, []).plan(t0), List.filled(questionsPerSession, 'a'));
    });
    test('b reste fermée tant que a n’est pas maîtrisée', () {
      final p = Progress(skills, List.generate(4, (_) => ans('a')));
      expect(p.unlocked(skills[1]), isFalse);
    });
    test('a maîtrisée : b ouverte ; révision de a due le lendemain, placée en premier', () {
      final p = Progress(skills, List.generate(5, (_) => ans('a')));
      expect(p.unlocked(skills[1]), isTrue);
      expect(p.plan(t0).toSet(), {'b'});
      final tomorrow = p.plan(DateTime(2026, 11, 3, 9));
      expect(tomorrow.first, 'a');
      expect(tomorrow.length, questionsPerSession);
      expect(tomorrow.skip(1).toSet(), {'b'});
    });
  });
}
