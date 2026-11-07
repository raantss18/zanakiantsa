/// Évaluation diagnostique avant une notion nouvelle (ADR 0061, choix d'Antsa du 2026-11-07) :
///   - on ne vérifie que les prérequis directs de la notion, ceux qui viennent avant elle dans la progression ; jamais la
///     notion elle-même, qui n'a pas encore été enseignée ;
///   - chaque prérequis est vérifié, même s'il vient d'être réussi : une question, sans aide ;
///   - prérequis manqué : rappel clair (idée et exemple résolu), il repasse en révision, puis on enseigne la notion.
/// Pur Dart : la séance (ui/session.dart) suit les étapes données ici.
library;

import 'progress.dart';

enum StepKind { check, reminder }

class DiagStep {
  const DiagStep(this.kind, this.skill);
  final StepKind kind;
  final String skill;

  @override
  bool operator ==(Object other) => other is DiagStep && other.kind == kind && other.skill == skill;
  @override
  int get hashCode => Object.hash(kind, skill);
  @override
  String toString() => '${kind.name}:$skill';
}

/// Les prérequis à vérifier avant [skill] : ses prérequis directs qui existent dans ce domaine, dans l'ordre du domaine.
/// Une notion sans prérequis (la première d'un domaine, ou une notion indépendante) n'a pas de diagnostic.
List<String> prerequisitesToCheck(SkillRef skill, List<SkillRef> domain) {
  final order = [for (final s in domain) s.id];
  final pre = skill.prerequisites.where(order.contains).toSet().toList();
  pre.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
  return pre;
}

/// Les étapes qui précèdent une notion nouvelle : d'abord une question par prérequis ; chaque réponse fausse ajoute
/// juste après le rappel de ce prérequis.
class Diagnostic {
  Diagnostic(List<String> prerequisites) : _steps = [for (final p in prerequisites) DiagStep(StepKind.check, p)];
  final List<DiagStep> _steps;

  bool get done => _steps.isEmpty;

  /// L'étape suivante, retirée de la file ; null quand le diagnostic est fini.
  DiagStep? next() => _steps.isEmpty ? null : _steps.removeAt(0);

  /// Résultat d'une question de vérification : manquée, son rappel passe en tête de file.
  void answered(String skill, {required bool ok}) {
    if (!ok) _steps.insert(0, DiagStep(StepKind.reminder, skill));
  }
}
