# ADR 0077 — Défis du robot : refaire un dessin modèle

- **Statut** : accepté (2026-11-15, « Corrige, innove et publie » d'Antsa).
- **Contexte** : les programmes libres (ADR 0076) laissent créer, mais rien ne guide vers les boucles et les angles.
  Repère : la fiche éduscol « Programmer » (cycles 3 et 4) demande de « programmer des déplacements »
  (https://eduscol.education.fr/document/14773/download). Refaire une figure donnée : idée classique des activités Logo
  (Papert, *Mindstorms*, 1980) ; aucun défi, dessin ni texte repris (CLAUDE.md règle 7).
- **Décision** : « Défis du robot » dans « Le code » : onze dessins modèles, d'une ligne à un moulin (boucle dans une
  boucle). Le modèle s'affiche en pointillés gris sous le dessin de l'enfant (jamais la couleur seule). Réussi si les deux
  dessins se recouvrent au dixième de pas près : le chemin, le sens et la couleur ne comptent pas. Après la réussite,
  le nombre de blocs de la solution la plus courte connue est dit, comme une idée et sans note. Défis réussis gardés par
  enfant (réglage `defis`). Pas de vie, pas de limite d'essais.
- **Vérifié** : tests `test/studio_challenge_test.dart` (même dessin par d'autres chemins, miroir refusé, crayon levé).
- **Supposé** : onze défis suffisent pour une première version ; l'ordre suit la difficulté (non mesuré avec des enfants).
- **Reste à tester** : sur une vraie tablette ; avec un enfant (les pointillés se voient-ils assez ?).
