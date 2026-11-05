# 0046 — Opérations posées : l'enfant écrit chaque chiffre

- **Date** : 2026-11-05 · **Statut** : accepté (remplace le choix entre 3 résultats de l'ADR 0035)
- **Pourquoi** : le texte du programme cité dans le contenu dit « poser et **effectuer** » l'addition en colonnes,
  et introduire la soustraction posée « par cassage ». Choisir un résultat parmi trois ne fait pas effectuer le calcul.
- **Décision** : `core/column.dart` découpe l'opération en étapes, de droite à gauche :
  - addition : chiffre des unités, retenue en haut de la colonne suivante, dizaines, centaine s'il en reste ;
  - soustraction : si on ne peut pas enlever, on casse une dizaine (l'enfant écrit combien il en reste, l'ancien
    chiffre est barré et un petit 1 s'ajoute aux unités), puis le chiffre du résultat. Pas de zéro inutile à gauche.
- **Écran** : clavier de 0 à 9 (touches de 60 dp). La case à remplir a un cadre épais et une flèche, pas seulement une
  couleur. La consigne de l'étape est écrite et dite, dans une zone de hauteur fixe : le clavier ne bouge pas d'une
  étape à l'autre (sinon le doigt tombe sur une autre touche, vu sur l'émulateur).
- **Erreur** : un mauvais chiffre compte comme un essai manqué de la question. L'explication dit où regarder sans
  donner le chiffre (test).
- **Vérifié** : `test/column_test.dart` (toutes les opérations du contenu redonnent le bon résultat). Sur l'émulateur :
  addition avec retenue (dont l'oubli de la retenue) et soustraction avec dizaine cassée, au format tablette et au
  format téléphone avec police à 115 %.
- **Supposé** : le nombre de cases montre parfois que le résultat n'a qu'un chiffre (81 − 76) ; à observer avec
  l'enfant.
