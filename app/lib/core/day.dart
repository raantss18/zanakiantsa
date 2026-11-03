/// Programme du jour (ADR 0018) : trois domaines différents chaque jour, en alternance, chacun avec un temps visé.
/// L'enfant enchaîne seul ; le temps total est réglé par le parent.
library;

import 'events.dart';

/// Les deux journées qui alternent (choix d'Antsa : « maths/biologie/dessin puis algo/musique/échecs »).
const dayGroups = [
  ['compter', 'nature', 'dessin'],
  ['motifs', 'sons', 'echecs'],
];

/// Minutes par jour proposées au parent ; 90 = demande d'Antsa (voir ADR 0018 pour les repères de santé).
const dailyMinuteChoices = [30, 45, 60, 90];
const defaultDailyMinutes = 90;

/// Essais seulement : `--dart-define=DEV_DAY=1` montre la journée de demain. 0 en version publiée.
const devDayShift = int.fromEnvironment('DEV_DAY');

/// Jours écoulés depuis une date fixe, en date locale : change à minuit, pas toutes les 24 h.
int dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026)).inDays;

class DayItem {
  const DayItem(this.theme, this.done, this.target);
  final String theme;
  final Duration done, target;

  bool get finished => done >= target;
  double get ratio => target.inSeconds == 0 ? 1 : (done.inSeconds / target.inSeconds).clamp(0.0, 1.0);
}

class DayPlan {
  DayPlan(this.items);
  final List<DayItem> items;

  /// Le prochain domaine proposé : le premier pas encore fini, dans l'ordre du jour.
  DayItem? get next => items.where((i) => !i.finished).firstOrNull;
  bool get finished => next == null;

  DayItem item(String theme) => items.firstWhere((i) => i.theme == theme);

  /// [sessions] : tout le journal des séances ; seules celles commencées aujourd'hui comptent.
  factory DayPlan.of(DateTime now, List<SessionLog> sessions, {int minutes = defaultDailyMinutes}) {
    final group = dayGroups[(dayNumber(now) + devDayShift) % dayGroups.length];
    final today = DateTime(now.year, now.month, now.day);
    final target = Duration(minutes: minutes ~/ group.length);
    Duration spent(String theme) => sessions
        .where((s) => s.theme == theme && !s.started.isBefore(today) && s.started.isBefore(today.add(const Duration(days: 1))))
        .fold(Duration.zero, (d, s) => d + s.length);
    return DayPlan([for (final t in group) DayItem(t, spent(t), target)]);
  }
}
