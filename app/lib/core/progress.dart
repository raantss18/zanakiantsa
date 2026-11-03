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

  /// Rang du niveau scolaire : 0 MS, 1 GS, 2 CP, 3 CE1, 4 CE2 (voir [levelRank]).
  final int level;
}

/// Rang d'un niveau du contenu (« MS », « GS », « CP »…).
int levelRank(String level) => const {'PS': 0, 'MS': 0, 'GS': 1, 'CP': 2, 'CE1': 3, 'CE2': 4, 'CM1': 5, 'CM2': 6}[level] ?? 0;

/// Point de départ selon l'âge (ADR 0034) : les niveaux en dessous sont tenus pour acquis (on ne les impose pas, ils
/// restent jouables). 5 ans : tout ; 6 ans : dès la GS ; 7 ans : dès le CP ; 8 ans : dès le CE1.
int startLevelForAge(int age) => (age - 5).clamp(0, 6);

/// Questions par séance (⚠ choix produit : vise ≈ 10–15 min, à mesurer).
const questionsPerSession = 8;

class Progress {
  Progress(this.skills, List<Answer> journal, {this.sessionsDone = 0, this.startLevel = 0}) {
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

  bool skipped(String id) => skills.firstWhere((s) => s.id == id, orElse: () => SkillRef(id, const [], level: 99)).level < startLevel;
  final Map<String, List<Answer>> _bySkill = {};

  List<Answer> answersOf(String id) => _bySkill[id] ?? const [];

  bool mastered(String id) => skipped(id) || isMastered(answersOf(id));

  /// Maîtrisée par l'enfant lui-même (pas seulement tenue pour acquise à cause de son âge).
  bool earned(String id) => isMastered(answersOf(id));

  ReviewCard? card(String id) => cardFrom(answersOf(id), isMastered);

  bool unlocked(SkillRef s) => s.prerequisites.every(mastered);

  /// Révisions dues (les plus anciennes d'abord), puis la première compétence ouverte non maîtrisée.
  List<String> plan(DateTime now) {
    final due = <(String, DateTime)>[];
    for (final s in skills) {
      final c = card(s.id);
      if (c != null && isDue(c, now)) due.add((s.id, c.due));
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
      return [for (var i = 0; i < questionsPerSession; i++) skills[r.nextInt(skills.length)].id];
    }
    // Entrelacé (ADR 0037) : une question sur trois revient sur une compétence déjà acquise, au lieu de huit fois la
    // même d'affilée (Rohrer & Taylor 2007 : mélanger les types de problèmes améliore l'apprentissage).
    return [...reviews, for (var i = reviews.length; i < questionsPerSession; i++) (i % 3 == 2 ? practice(r, not: next.id) : null) ?? next.id];
  }

  /// La compétence à apprendre en ce moment : la première ouverte et pas encore acquise.
  String? get newSkill => skills.where((s) => !mastered(s.id) && unlocked(s)).firstOrNull?.id;

  /// Une compétence que l'enfant a lui-même acquise, au hasard, autre que [not] ; null s'il n'y en a pas. Pas celles
  /// tenues pour acquises à cause de l'âge : trop faciles, elles ennuieraient.
  String? practice(Random r, {String? not}) {
    final pool = [for (final s in skills) if (s.id != not && earned(s.id)) s.id];
    return pool.isEmpty ? null : pool[r.nextInt(pool.length)];
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
