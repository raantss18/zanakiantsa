/// Règles pédagogiques figées par les ADR. Pur Dart : aucune dépendance à Flutter.
library;

/// Nombre d'essais par question (ADR 0006).
const maxAttempts = 3;

/// Ce qui se passe après le 3e essai manqué (ADR 0006).
enum AfterLastMiss { demonstration, hintOnly }

/// Moins de 6 ans : démonstration ; 6 ans ou plus : indice seulement (ADR 0006).
AfterLastMiss afterLastMiss(int ageYears) => ageYears < 6 ? AfterLastMiss.demonstration : AfterLastMiss.hintOnly;

/// Aide qui monte à chaque erreur : aucune avant la 1re erreur, puis indice, puis exemple, puis la fin (ADR 0006).
enum Help { none, hint, example, last }

Help helpAfter(int misses) => switch (misses) {
      <= 0 => Help.none,
      1 => Help.hint,
      2 => Help.example,
      _ => Help.last,
    };
