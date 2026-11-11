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

/// À partir du CM1 (ADR 0069, demande d'Antsa du 2026-11-08 : « compter, lire ne marche pas pour un grand enfant ») : la
/// journée suit les horaires officiels de sa classe au lieu du tour de 4 jours fait pour la GS et le CP. Poids = heures par
/// semaine × 2, lues dans les textes officiels le 2026-11-08 :
/// - CM1-CM2 : arrêté du 9 novembre 2015, article 2 (https://www.legifrance.gouv.fr/loda/id/JORFTEXT000031518724) :
///   français 8 h, maths 5 h, langues 1 h 30, sciences et technologie 2 h, histoire-géographie-EMC 2 h 30, arts 2 h ;
/// - 6e et cycle 4 : arrêté du 19 mai 2015 modifié le 10 mars 2026, annexes 1 et 2
///   (https://www.legifrance.gouv.fr/jorf/id/JORFTEXT000053652601) : 6e français 4 h 30, maths 4 h 30, langue 4 h, SVT et
///   physique-chimie 3 h, histoire-géographie 3 h ; 5e-3e français 4 h 30 (4 h en 3e), maths 3 h 30, LV1 3 h, SVT 1 h 30
///   + physique-chimie 1 h 30, technologie 1 h 30, histoire-géographie 3 h ;
/// - 2de : arrêté du 16 juillet 2018, annexe 1 (https://www.legifrance.gouv.fr/loda/id/JORFTEXT000037202776) : français 4 h,
///   maths 4 h, LVA + LVB 5 h 30 (l'anglais compté pour la moitié), physique-chimie 3 h + SVT 1 h 30, histoire-géographie
///   3 h, SNT 1 h 30 (le code).
/// Hors des grilles, choix de l'app (supposé) : le code 1 h avant la 5e, les échecs 1 h ; au CM, les 2 h d'arts partagées
/// entre le dessin (arts plastiques) et les sons (éducation musicale, leçons jusqu'au CM2), 1 h chacun.
const dayWeights = <String, Map<String, int>>{
  'cm': {'lire': 16, 'compter': 10, 'anglais': 3, 'nature': 4, 'explorer': 5, 'dessin': 2, 'sons': 2, 'code': 2, 'echecs': 2},
  '6e': {'lire': 9, 'compter': 9, 'anglais': 8, 'nature': 6, 'explorer': 6, 'dessin': 2, 'code': 2, 'echecs': 2},
  'cycle4': {'lire': 9, 'compter': 7, 'anglais': 6, 'nature': 6, 'explorer': 6, 'code': 3, 'echecs': 2},
  'lycee': {'lire': 8, 'compter': 8, 'anglais': 6, 'nature': 9, 'explorer': 6, 'code': 3, 'echecs': 2},
};

/// La grille d'une classe (rang dans `schoolLevels`) ; null avant le CM1 : le tour de 4 jours ([dayGroups]) s'applique.
Map<String, int>? weightsFor(int classe) => switch (classe) {
      < 5 => null,
      5 || 6 => dayWeights['cm'],
      7 => dayWeights['6e'],
      8 || 9 || 10 => dayWeights['cycle4'],
      _ => dayWeights['lycee'],
    };

/// Les trois domaines du jour [day] selon des poids : chaque domaine revient en proportion de son poids, jamais deux fois
/// le même jour, dans un ordre qui tourne (tourniquet pondéré à crédits, déterministe). [candidates] : les domaines que la
/// journée peut proposer, dans l'ordre de préférence (voir [dayCandidates]) ; un domaine sans poids y compte pour 1.
List<String> weightedDay(int day, Map<String, int> weights, List<String> candidates) {
  final pool = [for (final c in candidates) if ((weights[c] ?? 0) > 0) c];
  for (final c in candidates) {
    if (pool.length >= 3) break;
    if (!pool.contains(c)) pool.add(c);
  }
  if (pool.length <= 3) return pool;
  final w = {for (final c in pool) c: weights[c] ?? 1};
  final total = w.values.reduce((a, b) => a + b);
  final credit = {for (final c in pool) c: 0};
  var picked = <String>[];
  for (var d = 0; d <= day; d++) {
    for (final c in pool) {
      credit[c] = credit[c]! + 3 * w[c]!;
    }
    picked = ([...pool]..sort((a, b) {
          final x = credit[b]!.compareTo(credit[a]!);
          return x != 0 ? x : pool.indexOf(a).compareTo(pool.indexOf(b));
        }))
        .take(3)
        .toList();
    for (final c in picked) {
      credit[c] = credit[c]! - total;
    }
  }
  return picked;
}

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

/// Les domaines que la journée peut proposer (ADR 0065) : d'abord ceux de [shown] où l'enfant a encore une leçon à
/// apprendre à son niveau ([learning]), les plus avancés d'abord ; les autres seulement s'il en manque pour faire trois.
List<String> dayCandidates(List<String> shown, {required Set<String> learning, required Map<String, int> tops}) {
  final learn = [for (final t in shown) if (learning.contains(t)) t]..sort((a, b) => (tops[b] ?? 0).compareTo(tops[a] ?? 0));
  return learn.length >= 3 ? learn : [...learn, for (final t in shown) if (!learn.contains(t)) t];
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
    final day = dayNumber(now) + devDayShift;
    final weights = weightsFor(classe);
    final group = weights != null && visible != null && visible.length >= 3
        ? weightedDay(day, weights, visible)
        : adaptGroup(onlyVisible(dayGroups[day % dayGroups.length], visible), tops, classe);
    final today = DateTime(now.year, now.month, now.day);
    final target = Duration(minutes: minutes ~/ group.length);
    Duration spent(String theme) => sessions
        .where((s) => s.theme == theme && !s.started.isBefore(today) && s.started.isBefore(today.add(const Duration(days: 1))))
        .fold(Duration.zero, (d, s) => d + s.length);
    return DayPlan([for (final t in group) DayItem(t, spent(t), target)]);
  }
}
