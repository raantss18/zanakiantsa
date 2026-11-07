/// État dérivé du journal : maîtrise, cartes de révision, prochaine séance, fil rouge.
library;

import 'dart:math';

import 'events.dart';
import 'leitner.dart';
import 'mastery.dart';

/// Ce que le moteur a besoin de savoir d'une compétence.
class SkillRef {
  const SkillRef(this.id, this.prerequisites, {this.level = 0});
  final String id;
  final List<String> prerequisites;

  /// Rang du niveau scolaire : sa place dans [schoolLevels].
  final int level;
}

/// Les classes, de la moyenne section à l'après-lycée (ADR 0057). Il n'y a pas d'âge maximum : la dernière vaut pour tous
/// ceux qui ont passé le lycée.
const schoolLevels = ['MS', 'GS', 'CP', 'CE1', 'CE2', 'CM1', 'CM2', '6e', '5e', '4e', '3e', '2de', '1re', 'Terminale', 'Après le lycée'];

/// Rang d'un niveau du contenu (« MS », « GS », « CP »…).
int levelRank(String level) => level == 'PS' ? 0 : max(0, schoolLevels.indexOf(level));

/// La classe habituelle à un âge : 5 ans, GS ; 6 ans, CP ; 11 ans, 6e…
int classForAge(int age) => (age - 4).clamp(0, schoolLevels.length - 1);

/// Point de départ d'une classe (ADR 0034, 0057) : on commence au niveau juste en dessous, et les niveaux plus bas sont
/// tenus pour acquis (on ne les impose pas, ils restent jouables).
int startLevelForClass(int classe) => max(0, classe - 1);

int startLevelForAge(int age) => startLevelForClass(classForAge(age));

/// Plancher d'une classe (ADR 0065, demande d'Antsa du 2026-11-08 : « à douze ans on ne compte plus les voitures ni les
/// syllabes ») : une notion à deux classes ou plus sous celle de l'enfant n'est plus jamais proposée — ni en diagnostic, ni
/// en révision, ni en entraînement, ni au défi. Elle est tenue pour acquise.
int floorForClass(int classe) => max(0, classe - 2);

/// Le point de départ dans un domaine : jamais au-delà de ce que ce domaine propose de plus avancé. Sans cela, pour un
/// grand, toutes ses compétences compteraient comme acquises et il n'y aurait plus rien à y apprendre.
int startLevelIn(List<SkillRef> skills, int start) => skills.isEmpty ? start : min(start, skills.map((s) => s.level).reduce(max));

/// Questions par séance (⚠ choix produit : vise ≈ 10–15 min, à mesurer).
const questionsPerSession = 8;

/// Test de départ (ADR 0045) : questions par compétence, et compétences testées au plus d'une fois.
const placementPerSkill = 2, placementSkills = 6;

class Progress {
  Progress(this.skills, List<Answer> journal, {this.sessionsDone = 0, this.startLevel = 0, this.floor = 0, this.placed = const {}}) {
    for (final a in journal) {
      _bySkill.putIfAbsent(a.skill, () => []).add(a);
    }
  }

  /// Compétences dans l'ordre du thème.
  final List<SkillRef> skills;

  /// Séances terminées : position sur le fil rouge, qui ne recule jamais.
  final int sessionsDone;

  /// Niveau de départ de l'enfant : les compétences plus basses comptent comme acquises.
  final int startLevel;

  /// Plancher : les compétences plus basses ne sont plus proposées (voir [floorForClass]).
  final int floor;

  int _level(String id) => skills.firstWhere((s) => s.id == id, orElse: () => SkillRef(id, const [], level: 99)).level;

  /// Trop facile pour la classe de l'enfant : jamais proposée.
  bool belowFloor(String id) => _level(id) < floor;

  /// Les prérequis à vérifier au diagnostic : ceux qui ne sont pas sous le plancher.
  List<String> checkable(List<String> prerequisites) => [for (final p in prerequisites) if (!belowFloor(p)) p];

  bool skipped(String id) => skills.firstWhere((s) => s.id == id, orElse: () => SkillRef(id, const [], level: 99)).level < startLevel;
  final Map<String, List<Answer>> _bySkill = {};

  List<Answer> answersOf(String id) => _bySkill[id] ?? const [];

  bool mastered(String id) => skipped(id) || earned(id);

  /// Compétences réussies au test de départ (ADR 0045).
  final Set<String> placed;

  /// Maîtrisée par l'enfant lui-même (pas seulement tenue pour acquise à cause de son âge). Réussie au test de
  /// départ : acquise, jusqu'à ce que l'enfant ait assez répondu pour que la règle habituelle décide seule.
  bool earned(String id) {
    final a = answersOf(id);
    return isMastered(a) || (placed.contains(id) && a.length < masteryWindow);
  }

  /// Test de départ : les compétences pas encore acquises, dans l'ordre du domaine (sans attendre qu'elles soient
  /// ouvertes : c'est le test qui le dira), [placementPerSkill] questions chacune. null s'il n'y a pas au moins deux
  /// compétences à tester (sauter ne servirait à rien).
  List<String>? placementPlan() {
    final todo = [for (final s in skills) if (!mastered(s.id)) s.id].take(placementSkills).toList();
    if (todo.length < 2) return null;
    return [for (final id in todo) for (var i = 0; i < placementPerSkill; i++) id];
  }

  ReviewCard? card(String id) => cardFrom(answersOf(id), isMastered);

  bool unlocked(SkillRef s) => s.prerequisites.every(mastered);

  /// Révisions dues (les plus anciennes d'abord), puis la première compétence ouverte non maîtrisée.
  List<String> plan(DateTime now) {
    final due = <(String, DateTime)>[];
    for (final s in skills) {
      final c = card(s.id);
      if (c != null && isDue(c, now) && !belowFloor(s.id)) due.add((s.id, c.due));
    }
    due.sort((a, b) => a.$2.compareTo(b.$2));
    final out = [for (final d in due) d.$1];
    final next = skills.where((s) => s.id == newSkill).firstOrNull;
    // Une révision = une question ; le reste de la séance va à la compétence nouvelle.
    final reviews = out.take(questionsPerSession ~/ 2).toList();
    final r = Random(now.millisecondsSinceEpoch);
    if (next == null) {
      if (reviews.isNotEmpty) return reviews;
      // Tout est acquis : de l'entraînement varié sur tout le domaine (plus jamais la même suite fixe, ADR 0030).
      final pool = [for (final s in skills) if (!belowFloor(s.id)) s.id];
      final from = pool.isEmpty ? [for (final s in skills) s.id] : pool;
      return [for (var i = 0; i < questionsPerSession; i++) from[r.nextInt(from.length)]];
    }
    // Entrelacé (ADR 0037) : une question sur trois revient sur une compétence déjà acquise, au lieu de huit fois la
    // même d'affilée (Rohrer & Taylor 2007 : mélanger les types de problèmes améliore l'apprentissage).
    return [...reviews, for (var i = reviews.length; i < questionsPerSession; i++) (i % 3 == 2 ? practice(r, not: next.id) : null) ?? next.id];
  }

  /// Défi (ADR 0042) : [n] questions mêlées de tout ce que l'enfant a acquis (et du niveau juste en dessous de son
  /// âge), chaque compétence une fois par tour, dans le désordre. null : rien d'acquis encore, pas de défi.
  List<String>? challengePlan(Random r, {int n = 10}) {
    final pool = [for (final s in skills) if (!belowFloor(s.id) && (earned(s.id) || (skipped(s.id) && s.level == startLevel - 1))) s.id];
    if (pool.isEmpty) return null;
    final out = <String>[];
    while (out.length < n) {
      out.addAll([...pool]..shuffle(r));
    }
    return out.take(n).toList();
  }

  /// La compétence à apprendre en ce moment : la première ouverte et pas encore acquise.
  String? get newSkill => skills.where((s) => !mastered(s.id) && unlocked(s)).firstOrNull?.id;

  /// Une compétence que l'enfant a lui-même acquise, au hasard, autre que [not] ; null s'il n'y en a pas. Pas celles
  /// tenues pour acquises à cause de l'âge : trop faciles, elles ennuieraient.
  String? practice(Random r, {String? not}) {
    final pool = [for (final s in skills) if (s.id != not && earned(s.id) && !belowFloor(s.id)) s.id];
    return pool.isEmpty ? null : pool[r.nextInt(pool.length)];
  }

  /// Leçon choisie par l'enfant dans « Tout explorer » (ADR 0065) : les questions de cette leçon, une sur trois revenant sur
  /// une compétence déjà acquise (entrelacé, ADR 0037).
  List<String> focusPlan(String id, Random r) =>
      [for (var i = 0; i < questionsPerSession; i++) (i % 3 == 2 ? practice(r, not: id) : null) ?? id];

  /// Peut-on choisir cette leçon ? Jusqu'à la classe de l'enfant, oui ; au-dessus, quand toutes les leçons de sa classe et
  /// d'en dessous sont acquises dans ce domaine (« un élève avancé peut monter quand il a fini son niveau »).
  bool choosable(String id, int classe) {
    final l = _level(id);
    if (l < floor) return false;
    if (l <= classe) return true;
    return skills.where((s) => s.level <= classe).every((s) => mastered(s.id));
  }

  /// En cours de séance (ADR 0037) : la suite du plan à partir de [index], une fois la réponse enregistrée. Si
  /// [target] vient d'être acquise, ses questions restantes passent à la compétence suivante (ou à de l'entraînement) :
  /// on ne fait pas répéter ce qui est su.
  List<String> adapt(List<String> plan, int index, String target, Random r) {
    if (!earned(target)) return plan;
    final next = newSkill;
    return [
      for (final (i, id) in plan.indexed)
        i >= index && id == target ? (next ?? practice(r, not: target) ?? target) : id,
    ];
  }
}
