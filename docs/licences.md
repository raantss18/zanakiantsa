# Registre des licences

> Règle (ADR 0001) : code Apache-2.0, contenu original CC BY-SA 4.0, aucune dépendance sous licence non OSI sans
> ADR. Licences lues sur pub.dev (balises `license:`) le 2026-11-02. Mettre ce tableau à jour à chaque ajout.

## Dépendances prévues

| Paquet | Version | Licence | OSI | Usage | Source |
| --- | --- | --- | --- | --- | --- |
| flame | 1.38.2 | MIT | oui | mini-jeux 2D | https://pub.dev/packages/flame |
| flutter_tts | 4.2.5 | MIT | oui | synthèse vocale de secours | https://pub.dev/packages/flutter_tts |
| audioplayers | 6.8.1 | MIT | oui | voix enregistrées, sons | https://pub.dev/packages/audioplayers |
| sqflite | 2.4.5 | BSD-2-Clause | oui | journal local | https://pub.dev/packages/sqflite |
| path_provider | 2.1.6 | BSD-3-Clause | oui | dossier de la base | https://pub.dev/packages/path_provider |
| path | 1.9.1 | BSD-3-Clause | oui | chemin de la base | https://pub.dev/packages/path |
| http | 1.6.0 | BSD-3-Clause | oui | mises à jour (ADR 0011) | https://pub.dev/packages/http |
| cryptography | 2.9.0 | Apache-2.0 | oui | signature des mises à jour (ADR 0011) | https://pub.dev/packages/cryptography |
| flutter_svg | 2.3.2 | MIT | oui | dessins des univers | https://pub.dev/packages/flutter_svg |
| yaml (outil de build seulement) | 3.1.4 | MIT | oui | lecture du contenu | https://pub.dev/packages/yaml |
| flutter_lints (dév.) | 6.0.0 | BSD-3-Clause | oui | analyse | https://pub.dev/packages/flutter_lints |
| google_mlkit_digital_ink_recognition | 0.16.1 | MIT (plugin) | oui | écriture | https://pub.dev/packages/google_mlkit_digital_ink_recognition |
| google_mlkit_image_labeling | 0.16.1 | MIT (plugin) | oui | photo d'objet | https://pub.dev/packages/google_mlkit_image_labeling |

## ⚠ Cas à trancher : ML Kit

Les plugins Flutter sont MIT, mais ils embarquent le **SDK ML Kit de Google**, régi par les « ML Kit Terms »
qui « incorporate and are subject to the Google APIs Terms of Service » (https://developers.google.com/ml-kit/terms,
lu le 2026-11-02) : **pas une licence open source**, et interdiction de rétro-ingénierie des modèles. Cela contredit
la règle « aucune dépendance non OSI » de l'ADR 0001. **Exception accordée par l'ADR 0012** (usage familial).

## Écartés

| Paquet | Raison |
| --- | --- |
| json_schema 5.2.2 | licence non déclarée sur pub.dev (`license:unknown`) |
| Code de GCompris, Lichess | AGPL-3.0 : imposerait l'AGPL à l'app (`docs/teardown.md`) |

## Données et contenus tiers

| Élément | Licence | Statut |
| --- | --- | --- |
| Base de puzzles Lichess | CC0 (https://database.lichess.org/, lu le 2026-11-02) | réutilisable, thème échecs |
| `assets/echecs/*.svg` (pièces d'échecs) | Cburnett, Wikimedia Commons | CC BY-SA 3.0 (`assets/echecs/LICENCE.txt`) |
| `assets/audio/sfx/*.wav` (bruitages) | synthétisés par code (`lib/audio/sfx.dart`, `tool/build_sounds.dart`) | original |
| Illustrations Twemoji v17.0.3 (135 SVG, `app/assets/art/`) | CC BY 4.0, attribution dans l'espace parent et `assets/art/LICENCE.txt` (https://github.com/jdecked/twemoji, lu le 2026-11-02) | réutilisables |

## Polices

**Andika 7.000** (SIL, Open Font License ; « literacy font » pour les lecteurs débutants, https://software.sil.org/andika/,
lu le 2026-11-02) : Regular et Bold dans `app/assets/fonts/`, avec `OFL.txt`.
