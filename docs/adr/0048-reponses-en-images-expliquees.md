# 0048 — Une image fausse est nommée, et l'app dit pourquoi elle ne va pas

- **Date** : 2026-11-05 · **Statut** : accepté (TODO : « explications pour les réponses en images », suite de l'ADR 0029)
- **Avant** : toucher une mauvaise image donnait seulement l'indice général de la compétence. L'enfant ne savait pas ce
  qu'il avait touché, ni en quoi c'était faux.
- **Décision** :
  - L'image touchée est d'abord nommée (« Ça, c'est la vache. », « Ça, ce sont les bras. »), pour les images à
    choisir, les planètes et le corps.
  - Une compétence peut aussi dire pourquoi, avec une phrase `erreur` qui contient `{choisi}`. Rimes : « « tomate »
    ne finit pas comme « citron » » (sans article entre guillemets). Premier son, lire des mots, anglais : « Écoute
    encore : « red » ».
  - L'explication ne nomme jamais la bonne réponse (test).
- **Aussi corrigé** : une explication, une idée ou une démonstration restait à l'écran le temps de la voix seulement.
  Sans voix française sur l'appareil, elle disparaissait aussitôt. Elle reste maintenant au moins le temps de la lire.
- **Vérifié** : `test/choice_error_test.dart` (chaque mauvaise image de chaque question). Sur l'émulateur, les rimes.
