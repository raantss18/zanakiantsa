# 0026 — Bibliothèque de livres hors ligne

- **Date** : 2026-11-03 · **Statut** : accepté (demandes d'Antsa : « catalogue de livres à lire… en priorité »,
  « pour les âges supérieurs et la curiosité », « dernier livre lu et marque-page »)
- **Source** : African Storybook (https://www.africanstorybook.org), livres **approuvés**, en français, niveaux 1 à 5.
  `app/tool/import_livres.py` ne garde que ceux dont la page de licence dit « Creative Commons: Attribution 4.0 »
  (les « non commercial » sont écartés) et recopie la ligne d'attribution, affichée à la fin de chaque livre.
  StoryWeaver (aussi CC BY 4.0) écarté : le texte des livres n'est lisible qu'avec un compte.
- **Choix** (à la main, relus sur le résumé) : étagères « Compter et apprendre », « Animaux et nature », « Ma vie »,
  « Contes et fables », « Curiosité » (vies célèbres, espace, nature, métiers), « Pour les grands » (niveaux 4–5).
  Écartés pour 5–7 ans : accident, séparation, abandon, maladie grave, enlèvement.
- **Intégration** : bouton « Mes livres » à l'accueil ; liseuse avec « Lis-moi » (voix, même coupée, car demandée) ;
  **marque-page** par livre et « Mon livre en cours » en tête de la bibliothèque ; une étoile au premier livre fini ;
  temps de lecture compté au rapport du parent (thème `lecture`). Images réduites en WebP (720 px, qualité 70).
- **Reste à tester** : lisibilité des pages de texte longues (niveaux 4–5) et intérêt de l'enfant.
