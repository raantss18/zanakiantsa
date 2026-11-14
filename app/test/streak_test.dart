import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/progress.dart';
import 'package:zanakiantsa/core/report.dart';
import 'package:zanakiantsa/core/streak.dart';

// Série de jours, défi du jour, question proche après une erreur, bilan de la semaine (ADR 0071).
void main() {
  SessionLog s(int day, {int hour = 10}) => SessionLog(theme: 'lire', started: DateTime(2026, 11, day, hour), ended: DateTime(2026, 11, day, hour, 10));
  final now = DateTime(2026, 11, 14, 18);

  group('série de jours, sans punition', () {
    test('rien joué : pas de série', () {
      final st = streakOf(const [], now);
      expect((st.days, st.best, st.playedToday), (0, 0, false));
    });

    test('jours de suite jusqu\'à aujourd\'hui', () {
      final st = streakOf([s(12), s(13), s(13, hour: 16), s(14)], now);
      expect((st.days, st.playedToday), (3, true));
    });

    test('un jour de repos ne casse pas la série et ne compte pas', () {
      final st = streakOf([s(9), s(10), s(12), s(14)], now);
      expect(st.days, 4);
    });

    test('pas encore joué aujourd\'hui ni hier : la série attend toujours', () {
      final st = streakOf([s(11), s(12)], now);
      expect((st.days, st.playedToday), (2, false));
    });

    test('deux jours de suite sans jouer : une nouvelle série commence, la meilleure est gardée', () {
      expect(streakOf([s(1), s(2), s(3), s(4), s(13), s(14)], now).days, 2);
      expect(streakOf([s(1), s(2), s(3), s(4), s(13), s(14)], now).best, 4);
      expect(streakOf([s(8), s(9), s(10), s(11)], now).days, 0);
      expect(streakOf([s(8), s(9), s(10), s(11)], now).best, 4);
    });
  });

  group('défi du jour', () {
    final pool = ['a', 'b', 'c', 'd', 'e'];
    test('le même toute la journée, un autre le lendemain', () {
      expect(dailyChallenge(pool, 100), dailyChallenge(pool, 100));
      expect({for (var d = 100; d < 110; d++) dailyChallenge(pool, d)!.join()}.length, greaterThan(5));
    });

    test('huit questions, chaque notion une fois avant d\'en reprendre une', () {
      final c = dailyChallenge(pool, 7)!;
      expect(c.length, dailyChallengeSize);
      expect(c.take(5).toSet(), pool.toSet());
    });

    test('rien d\'acquis : pas de défi', () => expect(dailyChallenge(const [], 3), isNull));
  });

  test('question proche : la notion revient deux questions plus loin, une question de plus', () {
    expect(Progress.withRetry(['a', 'b', 'c', 'd', 'e'], 1, 'b'), ['a', 'b', 'c', 'd', 'b', 'e']);
    expect(Progress.withRetry(['a', 'b'], 1, 'b'), ['a', 'b', 'b']);
  });

  test('révisions dues d\'un domaine : les plus anciennes d\'abord', () {
    Answer a(String skill, int day) => Answer(skill: skill, attempts: 1, correct: true, demonstrated: false, millis: 1, at: DateTime(2026, 11, day));
    final p = Progress(const [SkillRef('x', []), SkillRef('y', []), SkillRef('z', [])], [
      for (var i = 0; i < 5; i++) a('x', 10),
      for (var i = 0; i < 5; i++) a('y', 8),
      for (var i = 0; i < 5; i++) a('z', 14),
    ]);
    expect([for (final d in p.due(now)) d.$1], ['y', 'x']);
  });

  test('bilan : jours joués et notions acquises cette semaine', () {
    Answer a(String skill, DateTime at) => Answer(skill: skill, attempts: 1, correct: true, demonstrated: false, millis: 1, at: at);
    final st = parentStats([
      for (var i = 0; i < 5; i++) a('ancienne', DateTime(2026, 11, 1)),
      a('ancienne', DateTime(2026, 11, 12)),
      for (var i = 0; i < 5; i++) a('nouvelle', DateTime(2026, 11, 13)),
      a('en-cours', DateTime(2026, 11, 13)),
    ], [s(8), s(12), s(12, hour: 15), s(14), s(2)], now);
    expect(st.daysPlayed, 3);
    expect(st.learned, ['nouvelle']);
  });
}
