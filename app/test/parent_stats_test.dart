import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/report.dart';

// Le tableau de bord de l'espace parent (ADR 0061).
void main() {
  final now = DateTime(2026, 11, 7, 18);
  Answer a(String skill, DateTime at, {int attempts = 1, bool correct = true, List<String> errors = const []}) =>
      Answer(skill: skill, attempts: attempts, correct: correct, demonstrated: false, millis: 1000, at: at, errors: errors);
  SessionLog s(DateTime at, int min) => SessionLog(theme: 'compter', started: at, ended: at.add(Duration(minutes: min)));

  test('minutes par jour, du plus ancien à aujourd\'hui ; rien au-delà de 7 jours', () {
    final st = parentStats(const [], [s(DateTime(2026, 11, 7, 9), 20), s(DateTime(2026, 11, 7, 15), 10), s(DateTime(2026, 11, 1, 9), 15), s(DateTime(2026, 10, 30), 99)], now);
    expect(st.minutesPerDay, [15, 0, 0, 0, 0, 0, 30]);
  });

  test('réussite du premier coup, cette semaine et la semaine d\'avant', () {
    final st = parentStats([
      a('x', DateTime(2026, 11, 6)),
      a('x', DateTime(2026, 11, 6), attempts: 2),
      a('x', DateTime(2026, 11, 5)),
      a('x', DateTime(2026, 11, 4), correct: false, attempts: 3),
      a('y', DateTime(2026, 10, 28), attempts: 2),
      a('y', DateTime(2026, 10, 27)),
    ], const [], now);
    expect(st.firstTryThisWeek, 0.5);
    expect(st.firstTryLastWeek, 0.5);
    expect(parentStats(const [], const [], now).firstTryThisWeek, isNull);
  });

  test('à revoir : au moins deux difficultés, avec l\'explication la plus fréquente', () {
    final st = parentStats([
      a('dur', DateTime(2026, 11, 6), correct: false, attempts: 3, errors: ['Compte les dizaines.']),
      a('dur', DateTime(2026, 11, 6), correct: false, attempts: 3, errors: ['Compte les dizaines.', 'Autre.']),
      a('dur', DateTime(2026, 11, 6)),
      a('une-fois', DateTime(2026, 11, 6), correct: false, attempts: 3),
    ], const [], now);
    expect(st.toReview.map((r) => r.skill), ['dur']);
    expect(st.toReview.single.error, 'Compte les dizaines.');
    expect((st.toReview.single.failures, st.toReview.single.answers), (2, 3));
  });
}
