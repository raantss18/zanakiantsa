/// Journal d'événements en ajout seul (repris d'academik D-007). Rien n'est modifié ni envoyé.
library;

/// Une question terminée.
class Answer {
  const Answer({
    required this.skill,
    required this.attempts,
    required this.correct,
    required this.demonstrated,
    required this.millis,
    required this.at,
    this.errors = const [],
    this.challenge = false,
  });

  /// Ce que montraient les essais manqués, tel que l'app l'a expliqué (« Tu as compté de un en un… »), pour le carnet
  /// et le rapport : les erreurs fréquentes (ADR 0042).
  final List<String> errors;

  /// Question d'un défi (ADR 0042).
  final bool challenge;

  final String skill;

  /// Essais utilisés (1 à 3).
  final int attempts;

  /// Trouvée dans les 3 essais.
  final bool correct;

  /// La démonstration a été montrée (moins de 6 ans, 3 essais manqués).
  final bool demonstrated;
  final int millis;
  final DateTime at;

  /// Réussite au sens de la maîtrise : trouvée dans les 3 essais, sans démonstration (ADR 0007, choix provisoire).
  bool get success => correct && !demonstrated;

  Map<String, Object> toMap() => {
        'skill': skill,
        'attempts': attempts,
        'correct': correct ? 1 : 0,
        'demonstrated': demonstrated ? 1 : 0,
        'millis': millis,
        'at': at.millisecondsSinceEpoch,
        'errors': errors.join('\n'),
        'challenge': challenge ? 1 : 0,
      };

  factory Answer.fromMap(Map<String, Object?> m) => Answer(
        skill: m['skill']! as String,
        attempts: m['attempts']! as int,
        correct: m['correct'] == 1,
        demonstrated: m['demonstrated'] == 1,
        millis: m['millis']! as int,
        at: DateTime.fromMillisecondsSinceEpoch(m['at']! as int),
        errors: [for (final e in (m['errors'] as String? ?? '').split('\n')) if (e.isNotEmpty) e],
        challenge: m['challenge'] == 1,
      );
}

/// Un temps de jeu dans un domaine (ADR 0018) : séance finie, ou interrompue par le retour (`complete` faux).
class SessionLog {
  const SessionLog({required this.theme, required this.started, required this.ended, this.complete = true});
  final String theme;
  final DateTime started, ended;
  final bool complete;

  Duration get length => ended.difference(started);
}
