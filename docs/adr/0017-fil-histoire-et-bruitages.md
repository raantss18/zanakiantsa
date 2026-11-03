# 0017 — Fil d'histoire et bruitages par monde

- **Date** : 2026-11-03 · **Statut** : accepté (suite de l'ADR 0014, « Vas-y » d'Antsa)
- **Fil d'histoire** : chaque monde a 8 épisodes courts (`content/univers.yaml`, ≤ 70 caractères, validés par
  `tool/build_content.dart`). Chaque séance finie fait gagner l'épisode suivant : il est écrit et dit en fin de séance,
  puis reste sur la carte de l'accueil (« Épisode 3 » + pastilles). Avant la 1re séance : l'intro. Le dernier épisode
  reste ouvert (« Chaque jour… ») : rien ne se perd, rien ne se termine en échec.
- **Compteur** : le nombre de séances finies, commun aux mondes (changer de monde ne remet pas l'histoire à zéro).
- **Bruitages** : un son court (≤ 0,6 s, crête 0,5) par monde à la bonne réponse, une fanfare commune en fin de séance ;
  **synthétisés par code** (`lib/audio/sfx.dart`), donc originaux, sans licence tierce. Aucun son d'erreur (ADR 0008).
  La voix attend la fin du son pour ne pas se chevaucher.
- **Reste à tester** : effet sur l'envie de revenir et sur la gêne sonore, à l'essai (`docs/essai-01.md`).
