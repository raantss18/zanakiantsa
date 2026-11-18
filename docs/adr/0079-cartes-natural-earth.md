# ADR 0079 — Vraies cartes dans les questions de géographie (Natural Earth)

- **Statut** : accepté (2026-11-18, accord d'Antsa pour télécharger les contours).
- **Contexte** : 23 questions (continents, océans, France, outre-mer, détroits) décrivaient une carte en mots (ADR 0078).
- **Décision** : figure `carte` (`app/lib/activities/carte.dart`) dessinée à partir de Natural Earth v5.1.2, domaine
  public (https://github.com/nvkelso/natural-earth-vector/blob/v5.1.2/LICENSE.md), converti par `tool/cartes.py` dans
  `app/assets/carte/` (316 Ko : monde au 1:110 M, zooms au 1:50 M, quatre fleuves). Monde en projection Equal Earth
  (surfaces justes : comparer les océans a un sens) ; zooms à plat. Pays mis en avant en orange hachuré à contour épais,
  lieux par un point cerclé, « ? » écrit : jamais la couleur seule, jamais le nom de la réponse sur la carte. Hauteur
  bornée au tiers de l'écran.
- **Vérifié** : 345 tests (codes de pays et fleuves connus, repères dans leur vue, rendu à 360 et 760 px) ; rendu de
  chaque carte regardé ; émulateur 800 × 1340 en version publiée (France, Suez, Malacca, outre-mer, monde).
- **Reste à tester** : vraie tablette ; téléphone. Lacs non dessinés (anneaux intérieurs ignorés).
