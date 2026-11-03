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
