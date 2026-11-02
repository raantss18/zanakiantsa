/// État dérivé du journal : maîtrise, cartes de révision, prochaine séance, fil rouge.
library;

import 'events.dart';
import 'leitner.dart';
import 'mastery.dart';

/// Ce que le moteur a besoin de savoir d'une compétence.
class SkillRef {
  const SkillRef(this.id, this.prerequisites);
  final String id;
  final List<String> prerequisites;
}

/// Questions par séance (⚠ choix produit : vise ≈ 10–15 min, à mesurer).
const questionsPerSession = 8;

class Progress {
  Progress(this.skills, List<Answer> journal, {this.sessionsDone = 0}) {
    for (final a in journal) {
      _bySkill.putIfAbsent(a.skill, () => []).add(a);
    }
  }

  /// Compétences dans l'ordre du thème.
  final List<SkillRef> skills;

  /// Séances terminées : position sur le fil rouge, qui ne recule jamais.
  final int sessionsDone;
  final Map<String, List<Answer>> _bySkill = {};

  List<Answer> answersOf(String id) => _bySkill[id] ?? const [];

  bool mastered(String id) => isMastered(answersOf(id));

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
    final next = skills.where((s) => !mastered(s.id) && unlocked(s)).firstOrNull;
    // Une révision = une question ; le reste de la séance va à la compétence nouvelle.
    final reviews = out.take(questionsPerSession ~/ 2).toList();
    if (next == null) return reviews.isEmpty ? [for (final s in skills.take(questionsPerSession)) s.id] : reviews;
    return [...reviews, for (var i = reviews.length; i < questionsPerSession; i++) next.id];
  }
}
