# 0020 — Cours d'échecs pas à pas

- **Date** : 2026-11-03 · **Statut** : accepté (priorité 1 d'Antsa)
- **Décision** : 13 leçons dans le domaine « échecs », dans l'ordre : déplacer tour, fou, dame, roi, cavalier, pion
  (étoiles) ; le pion prend en diagonale ; prendre avec la tour, avec le cavalier ; faire échec avec la dame, avec le
  cavalier ; échec et mat en un coup avec dame + roi, puis tour + roi. Chaque leçon cite l'article des règles FIDE
  2023 (3.1.1, 3.2–3.7, 3.9.1, 5.1.1 ; https://handbook.fide.com/chapter/E012023, relu le 2026-11-03).
- **Moteur** (`app/lib/core/chess.dart`) : déplacements avec obstacles, prise, échec, mat, sur des positions à peu de
  pièces (Blancs contre un roi noir, ou des pions noirs immobiles). Pas de roque, prise en passant, promotion ni pat
  dans les leçons. Positions tirées au hasard, gardées seulement si elles ont une solution (testé sur 150 tirages).
- **Retour** : coup interdit ou coup qui ne fait pas échec/mat = essai manqué, la position revient, des points
  montrent les cases permises ; la démonstration entoure un coup juste.
- **Reste à tester** : la marche vers le mat à 5–6 ans, et s'il faut ajouter des parties contre l'app plus tard.
