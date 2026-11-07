# 0061 — Diagnostic des prérequis avant chaque notion, et tableau de bord parent

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa ; choix faits par Antsa le même jour).
- **Diagnostic** (`core/diagnostic.dart`) : avant la première rencontre d'une notion, une question sans aide sur chacun de ses
  **prérequis directs** (ceux qui viennent avant elle dans la progression) ; **jamais la notion elle-même**, pas encore enseignée.
  Chaque prérequis est vérifié, même déjà réussi. Manqué : rappel clair (idée + exemple résolu) ; la réponse fausse reste au
  journal, donc il repasse en révision ; puis la notion nouvelle est enseignée. Pas de diagnostic pendant un défi ou le test
  de départ. Badges : « À vérifier d'abord », « Rappel », « Nouveau ».
- **Prérequis repris** : 121 notions ; nouvelles leçon « Le présent » (prérequis de l'imparfait) ; liens corrigés (relatifs ←
  soustraction posée, identités ← carrés et équations, produit nul ← équations, passé simple ← imparfait). Sans prérequis, et
  donc sans diagnostic : la première notion de chaque domaine et les notions indépendantes (anglais : couleurs, nombres,
  animaux, corps ; sons ; sens, déplacements, œufs ; corps humain, planètes).
- **Tableau de bord parent** (`parent/dashboard.dart`) : temps des 7 derniers jours face au temps réglé ; réussite du premier
  coup, comparée à la semaine d'avant ; notions acquises par domaine ; à revoir (au moins deux difficultés, avec l'explication
  la plus donnée). Remplace la liste « Les 7 derniers jours ».
- **Vérifié** : 189 tests ; émulateur : imparfait → vérification du présent manquée → rappel → notion nouvelle ; tableau de bord.
  **Pas vérifié** : un enfant ; le temps ajouté par le diagnostic sur une séance.
