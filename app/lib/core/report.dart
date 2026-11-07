/// Rapport hebdomadaire local pour le parent (calculé sur l'appareil, jamais envoyé).
library;

import 'events.dart';
import 'mastery.dart';

class SkillLine {
  const SkillLine(this.skill, this.answers, this.successes, this.helped, this.mastered);
  final String skill;
  final int answers, successes, helped;
  final bool mastered;
}

class WeekReport {
  const WeekReport(this.sessions, this.minutes, this.lines);
  final int sessions, minutes;
  final List<SkillLine> lines;
}

/// Les 7 derniers jours (jour courant compris). [skills] donne l'ordre d'affichage ; la maîtrise tient compte de tout
/// le journal.
WeekReport weekReport(List<String> skills, List<Answer> journal, List<SessionLog> sessions, DateTime now) {
  final from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
  final week = journal.where((a) => !a.at.isBefore(from)).toList();
  final weekSessions = sessions.where((s) => !s.started.isBefore(from)).toList();
  final minutes = weekSessions.fold<int>(0, (m, s) => m + s.length.inMinutes);
  return WeekReport(weekSessions.where((s) => s.complete).length, minutes, [
    for (final id in skills)
      if (week.any((a) => a.skill == id))
        SkillLine(
          id,
          week.where((a) => a.skill == id).length,
          week.where((a) => a.skill == id && a.success).length,
          week.where((a) => a.skill == id && (a.attempts > 1 || a.demonstrated || !a.correct)).length,
          isMastered(journal.where((a) => a.skill == id)),
        ),
  ]);
}

/// Le tableau de bord de l'espace parent (ADR 0061, choix d'Antsa) : quatre lectures simples.
class DomainProgress {
  const DomainProgress(this.topic, this.name, this.mastered, this.total);
  final String topic, name;
  final int mastered, total;
}

class ToReview {
  const ToReview(this.skill, this.failures, this.answers, this.error);
  final String skill;
  final int failures, answers;

  /// L'explication que l'app a donnée le plus souvent pour cette notion, s'il y en a une.
  final String? error;
}

class ParentStats {
  const ParentStats({required this.minutesPerDay, required this.firstTryThisWeek, required this.firstTryLastWeek, required this.toReview});

  /// Minutes jouées chacun des 7 derniers jours, du plus ancien à aujourd'hui.
  final List<int> minutesPerDay;

  /// Part des réponses trouvées du premier coup (0 à 1) ; null s'il n'y a pas eu de réponse.
  final double? firstTryThisWeek, firstTryLastWeek;

  /// Les notions où l'enfant bloque cette semaine, les plus difficiles d'abord (3 au plus).
  final List<ToReview> toReview;
}

double? _firstTry(Iterable<Answer> a) {
  final l = a.toList();
  return l.isEmpty ? null : l.where((x) => x.correct && x.attempts <= 1 && !x.demonstrated).length / l.length;
}

ParentStats parentStats(List<Answer> journal, List<SessionLog> sessions, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final from = today.subtract(const Duration(days: 6));
  final before = from.subtract(const Duration(days: 7));
  int minutes(DateTime day) => sessions
      .where((s) => !s.started.isBefore(day) && s.started.isBefore(day.add(const Duration(days: 1))))
      .fold<int>(0, (m, s) => m + s.length.inMinutes);
  final week = journal.where((a) => !a.at.isBefore(from));
  final last = journal.where((a) => !a.at.isBefore(before) && a.at.isBefore(from));
  final bySkill = <String, List<Answer>>{};
  for (final a in week) {
    bySkill.putIfAbsent(a.skill, () => []).add(a);
  }
  final review = <ToReview>[];
  bySkill.forEach((skill, answers) {
    final failures = answers.where((a) => !a.success).length;
    // Au moins deux questions difficiles, et pas encore maîtrisée : un essai raté isolé n'est pas un blocage.
    if (failures >= 2 && !isMastered(journal.where((a) => a.skill == skill))) {
      final counts = <String, int>{};
      for (final e in answers.expand((a) => a.errors)) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
      final top = counts.entries.isEmpty ? null : (counts.entries.toList()..sort((x, y) => y.value.compareTo(x.value))).first.key;
      review.add(ToReview(skill, failures, answers.length, top));
    }
  });
  review.sort((a, b) => (b.failures / b.answers).compareTo(a.failures / a.answers));
  return ParentStats(
    minutesPerDay: [for (var i = 6; i >= 0; i--) minutes(today.subtract(Duration(days: i)))],
    firstTryThisWeek: _firstTry(week),
    firstTryLastWeek: _firstTry(last),
    toReview: review.take(3).toList(),
  );
}
