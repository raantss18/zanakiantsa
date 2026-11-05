# 0045 — « Je sais déjà » : un test de départ dans chaque domaine

- **Date** : 2026-11-05 · **Statut** : accepté (TODO : « sauter ce qui est déjà su » ; une enfant de 7 ans s'ennuyait)
- **Décision** : carte « Je sais déjà » dans l'accueil de chaque domaine (sauf le dessin), tant qu'il reste au moins deux
  compétences non acquises. Elle teste les compétences non acquises dans l'ordre du domaine, sans attendre qu'elles soient
  ouvertes : au plus 6 compétences, 2 questions chacune, sans exemple guidé.
- **Résultat** : deux réussites du premier coup = compétence sue (`test_depart`, par enfant). Le test s'arrête à la
  première hésitation (un essai manqué), et c'est là que l'enfant commence. L'écran de fin dit ce qui est su et où on
  commence. « Continuer » lance l'apprentissage.
- **Pas une étiquette définitive** : une compétence sue au test compte comme acquise tant que l'enfant n'a pas 5 réponses
  sur elle. Ensuite, la règle habituelle décide seule (4 sur 5, ADR 0007). Un acquis du test oublié redevient donc à
  apprendre.
- **Journal** : les questions du test sont notées comme celles du défi. Elles ne privent pas l'enfant de l'exemple guidé
  quand il rencontre ensuite la compétence pour de vrai.
- **Non vérifié** (choix produit, sans source) : 2 questions par compétence, 6 compétences, arrêt au premier essai
  manqué. À revoir après l'essai avec les enfants.
- **Vérifié** : `test/placement_test.dart`. Sur l'émulateur, deux parcours :
  - « Les nombres » : additions jusqu'à 5 sues, arrêt à « jusqu'à 10 », « Continuer » démarre à « jusqu'à 10 » ;
  - « Les suites » : arrêt dès la première question.
