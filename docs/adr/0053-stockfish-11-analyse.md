# 0053 — Stockfish 11 pour l'analyse fine des parties, sans réseau à télécharger

- **Date** : 2026-11-06 · **Statut** : accepté, à confirmer par Antsa (remplace le point 1 de l'ADR 0047, qui prévoyait
  Stockfish 19 et un téléchargement de 79 Mo).
- **Mesuré** : Stockfish 19 demande un réseau de 78,9 Mo (`src/evaluate.h`, tag `sf_19`), plus que tout le budget de l'APK
  (60 Mo), donc un téléchargement. Stockfish 11 (tag `sf_11`, avant les réseaux) tient en un programme de 993 Ko : l'APK
  passe de 35,4 à 35,8 Mo. Compilation reproduite deux fois, même empreinte (`tool/build_stockfish.sh`).
- **Décision** : livrer Stockfish 11, non modifié, comme programme séparé (`libstockfish.so`, GPL-3, même méthode que lc0,
  ADR 0051). Rien à télécharger : l'analyse reste hors ligne (CLAUDE.md, règle 5). Stockfish 19 serait plus fort ; pour
  les parties d'un enfant, ce gain n'est pas utile (⚠ jugement, non mesuré).
- **Usage** : à l'ouverture de la revue d'une partie, les commentaires de l'app s'affichent d'abord, puis le moteur regarde
  chaque coup de l'enfant (`go nodes 50000`, deux recherches par coup, un fil, 16 Mo). Un nombre de positions fixe donne le
  même jugement sur tous les appareils ; 120 ms proposaient c3 après 1.f3 sur l'émulateur.
- **Règles** (`core/deep_analysis.dart`, seuils choisis par nous, ⚠ à revoir après un essai avec un enfant) : mat permis,
  toujours dit ; mat manqué en 3 coups ou moins ; perte de 150 centièmes ou plus, sauf partie déjà décidée (3 pions) ;
  perte de moins de 50 centièmes : l'alerte de la petite recherche est retirée. Le moteur s'arrête dès l'analyse finie, ou
  quand on quitte la page. Moteur absent ou muet : les commentaires de l'app restent, on réessaie à l'ouverture suivante.
- **Vérifié** : 155 tests ; émulateur, 1.f3 e5 2.g4 Dh4# : « Il y avait plus fort que f3 : e4 », « Après g4, l'adversaire
  peut faire échec et mat en 1 coup. Mieux : e4. » ; 4 recherches en 1,9 s lancement compris ; le processus disparaît ensuite.
- **Reste à tester** : durée sur une vraie tablette (émulateur : ARM traduit), partie longue, mémoire réelle.
