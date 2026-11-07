/// Programme du jour (ADR 0018) : trois domaines différents chaque jour, en alternance, chacun avec un temps visé.
/// L'enfant enchaîne seul ; le temps total est réglé par le parent.
library;

import 'events.dart';

/// Les journées qui tournent sur 4 jours (ADR 0018, 0031) : lire et écrire 3 jours sur 4 — c'est le cœur de la grande
/// section et du CP —, chaque autre domaine au moins une fois. Tous les domaines restent ouverts à tout moment
/// (« Tout explorer »).
const dayGroups = [
  ['lire', 'compter', 'dessin'],
  ['lire', 'nature', 'echecs'],
  ['lire', 'motifs', 'sons'],
  ['anglais', 'code', 'explorer'],
];

/// Minutes par jour proposées au parent ; 90 = demande d'Antsa (voir ADR 0018 pour les repères de santé).
const dailyMinuteChoices = [30, 45, 60, 90];
const defaultDailyMinutes = 90;

/// Essais seulement : `--dart-define=DEV_DAY=1` montre la journée de demain. 0 en version publiée.
const devDayShift = int.fromEnvironment('DEV_DAY');

/// Jours écoulés depuis une date fixe, en date locale : change à minuit, pas toutes les 24 h.
int dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(2026)).inDays;

/// La journée d'un grand (ADR 0057) : un domaine dont le plus haut niveau est à 3 classes ou plus sous la sienne laisse la
/// place au domaine le plus avancé pas encore dans la journée. Il reste ouvert dans « Tout explorer ».
List<String> adaptGroup(List<String> group, Map<String, int> tops, int classe) {
  final out = [...group];
  final others = [for (final t in tops.keys) if (!group.contains(t)) t]..sort((a, b) => tops[b]!.compareTo(tops[a]!));
  for (final (i, t) in group.indexed) {
    if (others.isEmpty) break;
    final top = tops[t];
    if (top != null && classe - top >= 3 && tops[others.first]! > top) out[i] = others.removeAt(0);
  }
  return out;
}

/// En anglais, seuls les domaines traduits existent (ADR 0064) : ceux de la journée qui manquent sont remplacés par les
/// premiers domaines proposés qui n'y sont pas déjà. Sans liste (toutes les langues traduites), rien ne change.
List<String> onlyVisible(List<String> group, List<String>? visible) {
  if (visible == null) return group;
  final out = [for (final g in group) if (visible.contains(g)) g];
  for (final v in visible) {
    if (out.length >= group.length) break;
    if (!out.contains(v)) out.add(v);
  }
  return out;
}

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
  /// [tops] : le plus haut niveau de chaque domaine ; [classe] : celle de l'enfant (voir [adaptGroup]).
  factory DayPlan.of(DateTime now, List<SessionLog> sessions,
      {int minutes = defaultDailyMinutes, Map<String, int> tops = const {}, int classe = 0, List<String>? visible}) {
    final group = adaptGroup(onlyVisible(dayGroups[(dayNumber(now) + devDayShift) % dayGroups.length], visible), tops, classe);
    final today = DateTime(now.year, now.month, now.day);
    final target = Duration(minutes: minutes ~/ group.length);
    Duration spent(String theme) => sessions
        .where((s) => s.theme == theme && !s.started.isBefore(today) && s.started.isBefore(today.add(const Duration(days: 1))))
        .fold(Duration.zero, (d, s) => d + s.length);
    return DayPlan([for (final t in group) DayItem(t, spent(t), target)]);
  }
}
