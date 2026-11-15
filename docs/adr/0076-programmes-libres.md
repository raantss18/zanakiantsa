# ADR 0076 — Programmes libres : le robot qui dessine et joue des notes

- **Statut** : accepté (2026-11-15, demande d'Antsa : « Rajoute les programmes libres »).
- **Contexte** : le code n'avait que des parcours à réussir (ADR 0023, 0041, 0050). Scratch montre l'autre moitié :
  créer sans bonne réponse. Repère : la fiche éduscol « Programmer » (cycles 3 et 4) parle de « séquences d'instructions »
  et de « boucles » (https://eduscol.education.fr/document/14773/download) ; la tortue qui dessine vient de Logo (Papert,
  *Mindstorms*, 1980). Aucun code ni dessin de Scratch ou de Logo repris (CLAUDE.md règle 7).
- **Décision** : dans « Le code », « Programme libre » et « Mes programmes ». Huit blocs : avancer (1 à 9 pas), tourner à
  gauche ou à droite (15° à 180°), répéter (2 à 12 fois, emboîtable), lever ou poser le crayon, couleur (six, nommées),
  jouer une note (do à do aigu, sons fabriqués par l'app). Pas d'étoile ni de faute. Sept idées à ouvrir et à changer
  (carré, escalier, étoile, hexagone, fleur, Frère Jacques, danse). Programmes enregistrés sur l'appareil, par enfant
  (réglage `programmes`, 40 au plus), effacés avec l'enfant. Au plus 60 blocs et 600 pas par essai.
- **Corrigé au passage** : `bounded` n'attendait jamais la fin d'un son (erreur de type, « son ignoré ») ; les notes, et
  les sons des exercices d'écoute, se coupaient. Test dans `test/sound_bounded_test.dart`.
- **Vérifié** : 302 tests ; émulateur 800 × 1340 (téléphone et densité tablette) : dessin, boucle, notes l'une après
  l'autre, note écrite pendant qu'elle joue, enregistrer, quitter sans enregistrer, supprimer.
- **Reste à tester** : sur la Xiaomi Pad 7 et la SM-X135G ; avec un enfant (les 60 blocs suffisent-ils ?).
