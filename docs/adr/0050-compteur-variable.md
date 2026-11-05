# 0050 — Programmer avec une variable : le compteur

- **Date** : 2026-11-05 · **Statut** : accepté (TODO : « variables (compteur) » en programmation par blocs)
- **Source** : la fiche éduscol « Programmer » (cycles 3 et 4, https://eduscol.education.fr/document/14773/download)
  cite « variable » parmi les instructions simples. Elle ne dit rien de sa forme : la forme choisie ici est un choix de
  l'app (**non vérifié**). Compétence « Le compteur : une variable », niveau CM2, après « La condition ».
- **Décision** : trois blocs de plus (ADR 0041) :
  - « ajouter 1 au compteur » (le compteur commence à 0) ;
  - « si gemme ici » ;
  - « répéter jusqu'à compteur = n » (n réglable de 1 à 9).
  Le robot marche sur une rangée de gemmes ; il doit s'arrêter sur la gemme marquée d'un drapeau (la forme, pas seulement
  la couleur), toujours la même en comptant depuis la gauche.
- **Pourquoi une variable est nécessaire** : le programme est essayé sur **trois parcours** où les gemmes ne sont pas
  aux mêmes endroits, et les objets sont à des distances toutes différentes. « Avancer n fois » ne marche donc que sur
  un parcours (test). Le message dit pourquoi : « ça marchait sur le parcours d'avant, mais pas sur celui-ci ».
- **Écran** : le compteur est écrit en grand pendant l'essai (« Compteur : 2 · Parcours 1 sur 3 »), et chaque ajout est
  un pas animé. Limite de blocs : la solution (4) plus 2.
- **Garde-fous** : une boucle qui ne fait rien s'arrête (« tourne en rond ») ; un compteur qui ne monte jamais mène au
  mur, le robot s'arrête et l'explication le dit.
- **Vérifié** : `test/blocks_test.dart` (200 parcours tirés : la solution marche sur les trois, « avancer n fois »
  échoue ailleurs, l'animation suit le compteur). **Reste à tester** : sur l'émulateur ; avec un enfant de CM2.
