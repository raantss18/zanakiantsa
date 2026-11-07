# 0064 — L'app en français ou en anglais

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa : « un switch français/anglais dans l'espace parent, attention à la
  voix » ; choix d'Antsa : toute l'app, leçons comprises ; le domaine « L'anglais » reste en anglais).
- **Réglage** : « Langue de l'application » en haut de l'espace parent, pour tout l'appareil (clé `langue`, commune aux enfants).
  La progression ne change pas : elle est rangée par notion, pas par langue.
- **Textes** : l'interface écrit `t('…')` ; la clé est le français, la traduction dans `lib/l10n/en.dart` et `en_activites.dart`.
  Le contenu porte un bloc `en:` par leçon et par domaine (mêmes phrases, mêmes questions, mêmes images, vérifié par
  `tool/build_content.dart`). Un domaine n'apparaît en anglais que s'il est entièrement traduit : jamais deux langues mêlées.
  Les mots fabriqués par le code (heure, fractions, dizaines, solides, pas des suites, syllabes) existent dans les deux langues.
- **Voix** : chaque phrase est dite dans la langue de l'app, réglée avant chaque phrase (ADR 0044). Les voix enregistrées n'existent
  qu'en français. Langue étudiée ≠ langue de l'app : ses passages entre « » ont leur propre voix — l'anglais du domaine
  « L'anglais » quand l'app est en français ; le français des leçons de lecture et de grammaire, qui deviennent « French »,
  quand l'app est en anglais. Les livres (en français) gardent la voix française. Changer de langue coupe la voix en cours.
- **Reste à vérifier** : la voix anglaise sur la tablette ; relecture des traductions par un anglophone.
