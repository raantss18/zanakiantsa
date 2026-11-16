# ADR 0078 — Reprise partout, cours sur cahier, bulle lisible, figures dans les questions

- **Statut** : accepté (2026-11-15, demande d'Antsa avec deux captures de téléphone).
- **Contexte** : la reprise (ADR 0039) ne couvrait que le parcours d'un domaine, jamais la vérification des prérequis,
  la leçon choisie, le défi ou la révision ; la bulle rétrécissait un long rappel jusqu'à l’illisible ; cours et
  exercices avaient le même fond ; 233 questions décrivaient en mots une figure (triangle, droite graduée, carte).
- **Décision** :
  1. Reprise après chaque réponse, pour toutes les séances (parcours, leçon, défi, test, révision et défi du jour le
     jour même), au même endroit, vérification des prérequis comprise ; bouton « Reprendre » sur l'accueil.
  2. Bulle : 24 points au mieux, jamais sous 19 (téléphone) ou 21 (tablette) ; elle grandit jusqu'à 40 % de l'écran puis
     défile. Pastille « Nouveau / Rappel » sur deux lignes. Quiz : la bulle montre la consigne, la question est écrite
     une fois, en grand. `textOn` et `test/contrast_test.dart` gardent le contraste des textes sur fond coloré.
  3. Cours, exemple résolu et rappel sur une page de cahier (lignes, marge) ; questions sur le décor du monde.
  4. Questions écrites : `figure:` dessinée par l'app (17 types, `activities/figure.dart`, dont tableau, quadrillage du robot, échiquier) et `image:` (Twemoji déjà
     embarqués). 269 questions illustrées ; jamais la réponse dans l'image.
- **Vérifié** : 334 tests ; émulateur, téléphone 1080 × 2400 et tablette 800 × 1340 : reprise après une réponse, cours sur
  cahier, bulle d'un long rappel, figures de Pythagore et de Thalès.
- **Reste à tester** : vraie tablette, téléphone d'Antsa ; cartes du monde et de France (données à choisir).
- **Corrigé (2026-11-16)** : en 1.1.7, un LayoutBuilder imbriqué figeait la page après « J'ai compris » dans la version
  publiée ; la zone de l'activité se calcule maintenant sans lui (`test/session_layout_test.dart`).
