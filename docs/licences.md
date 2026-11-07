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

## Programmes séparés sous GPL-3 (ADR 0051)

| Élément | Version | Licence | Usage | Source |
| --- | --- | --- | --- | --- |
| lc0 (Leela Chess Zero), non modifié | v0.32.1, `fd71a2d921b689c5f479d3227c3806c8e272d9c5` | GPL-3 (texte : `docs/moteurs/lc0-COPYING.txt`) | moteur du robot Maia, `liblc0.so` | https://github.com/LeelaChessZero/lc0 |
| Poids Maia-1 (1100, 1500, 1900) | v1.0 | GPL-3 | niveaux du robot Maia | https://github.com/CSSLab/maia-chess |
| Stockfish, non modifié (ADR 0053) | 11, `c3483fa9a7d7c0ffa9fcc32b467ca844cfb63790` | GPL-3 (texte : `docs/moteurs/stockfish-COPYING.txt`) | analyse fine des parties, `libstockfish.so` | https://github.com/official-stockfish/Stockfish |

Pourquoi l'app reste sous Apache-2.0 : l'app et ces moteurs sont des programmes séparés qui ne se parlent que par un processus et le
protocole texte UCI, jamais dans le même programme ; la FSF dit que « pipes, sockets and command-line arguments are
communication mechanisms normally used between two separate programs » et qu'un agrégat peut contenir un programme GPL
avec d'autres (https://www.gnu.org/licenses/gpl-faq.html#MereAggregation). ⚠ Lecture de la FAQ, pas un avis
juridique. Obligations GPL tenues : texte de la licence et sources cités ici et dans l'espace parent ; recette de
compilation exacte dans `tool/build_lc0.sh` et `tool/build_stockfish.sh`.

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
| Police Fredoka (`assets/fonts/Fredoka-Bold.ttf`, sous-ensemble) | The Fredoka Project Authors | SIL OFL 1.1 (`assets/fonts/OFL-Fredoka.txt`) |
| Logo et icône (`design/logo/`) | créés pour l'app (ADR 0027) | comme le contenu de l'app |
| `assets/livres/` (livres illustrés) | African Storybook Initiative et auteurs cités dans chaque livre (`catalogue.json`, page « Fin ») | CC BY 4.0, livre par livre (ADR 0026) |
| `assets/livres/catalogue.json`, étagère « Classiques » (livres 900001 et suivants, texte seul) | Textes transcrits par Wikisource (https://fr.wikisource.org), auteur, traducteur, édition et URL exacte dans chaque livre (`auteur`, `credits`, `source`, page « Fin ») ; liste ci-dessous | Domaine public (auteurs et traducteurs morts avant 1956, `app/tool/import_classiques.py`) |
| `assets/echecs/*.svg` (pièces d'échecs) | Cburnett, Wikimedia Commons | CC BY-SA 3.0 (`assets/echecs/LICENCE.txt`) |
| `assets/audio/sfx/*.wav` (bruitages) | synthétisés par code (`lib/audio/sfx.dart`, `tool/build_sounds.dart`) | original |
| Illustrations Twemoji v17.0.3 (157 SVG, `app/assets/art/`) | CC BY 4.0, attribution dans l'espace parent et `assets/art/LICENCE.txt` (https://github.com/jdecked/twemoji, lu le 2026-11-02) | réutilisables |

## Polices

**Andika 7.000** (SIL, Open Font License ; « literacy font » pour les lecteurs débutants, https://software.sil.org/andika/,
lu le 2026-11-02) : Regular et Bold dans `app/assets/fonts/`, avec `OFL.txt`.

## Classiques du domaine public (bibliothèque, étagère « Classiques »)

Importés par `app/tool/import_classiques.py` depuis Wikisource (lu le 2026-11-07), en texte seul, sans notes ni
illustrations. Règle : en France, une œuvre entre dans le domaine public le 1er janvier qui suit les 70 ans de la mort de
l'auteur (Code de la propriété intellectuelle, art. L123-1 ;
texte non relu sur Légifrance, qui refuse l'accès automatique — non vérifié ici) ; pour une traduction, il faut aussi que le
traducteur soit mort depuis plus de 70 ans. Dates de mort relevées sur les pages « Auteur: » de Wikisource.

| Auteur (mort en) | Traducteur (mort en) | Édition transcrite | Textes |
| --- | --- | --- | --- |
| Jean de La Fontaine (1695) | — | Fables, Bernardin-Béchet, 1874 | La Cigale et la Fourmi, Le Corbeau et le Renard, Le Loup et l’Agneau, Le Lièvre et la Tortue, Le Chêne et le Roseau |
| Charles Perrault (1703) | — | Contes des fées, Beauchemin et Valois, Montréal, 1886 | Le Petit Chaperon rouge, Le Chat botté, Les Fées, Cendrillon |
| Hans Christian Andersen (1875) | David Soldi (1884) | Contes d’Andersen, Hachette, 1876 | Les Habits neufs du Grand-Duc, Le Vilain Petit Canard, L’Intrépide Soldat de plomb, Le Rossignol, La Petite Fille et les allumettes |
| Alphonse Daudet (1897) | — | Lettres de mon moulin ; Contes du lundi | La Chèvre de monsieur Seguin, Le Secret de maître Cornille, La Mule du pape, Les Étoiles, La Dernière Classe |
| Jules Renard (1910) | — | Histoires naturelles, 1909 | Histoires naturelles (choix) |
| Guy de Maupassant (1893) | — | éditions de 1885 à 1910 | La Parure, Aux champs, La Ficelle, Deux Amis |
| Jules Verne (1905), revu par Michel Verne (1925) | — | Un billet de loterie, suivi de Frritt-Flacc, 1886 ; Hier et demain, 1910 | Frritt-Flacc, Au XXIXe siècle |
| Victor Hugo (1885) | — | Les Contemplations ; Les Chansons des rues et des bois ; La Légende des siècles | Poèmes choisis |

L’URL exacte de chaque texte est dans le champ `source` du livre (`app/assets/livres/catalogue.json`).
