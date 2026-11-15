# ADR 0075 — Le niveau écrit dans le titre d'une vidéo compte, pas seulement l'âge de la chaîne

- **Statut** : accepté (2026-11-15, essai sur la Xiaomi Pad 7 d'Antsa).
- **Constat (Vérifié)** : à 7 ans, « Pour toi » proposait « L'osmose et la diffusion » (Alloprof) et des leçons CM1-CM2
  (Maître Lucas). L'âge n'était réglé que par chaîne (ADR 0068) : Alloprof va de 6 à 17 ans, du primaire au secondaire.
- **Décision** : `tool/videos.py` lit le niveau dans le titre et les mots-clés (CP à CM2, « Cycle 3 », 6e, lycée ;
  au Québec « 3e année », « 2e cycle », « Secondaire 2 », « Primaire ») et garde la vidéo dès un an avant ce niveau.
  Sans niveau écrit, la chaîne peut donner `sans_niveau_ages` : pour Alloprof, [12, 17], car ses vidéos du primaire
  portent « Primaire ». Essais : `tool/test_videos.py`, lancé par le flux du site avant chaque catalogue.
- **Effet (Vérifié sur le catalogue du 2026-11-15)** : à 7 ans, 423 → 364 vidéos (27 Alloprof, 32 Maître Lucas retirées) ;
  à 15 ans, rien ne change. Rien n'est retiré pour les plus grands : l'app n'a pas d'âge maximum (ADR 0057).
- **Reste à tester** : regarder les rangées d'autres âges sur tablette ; d'autres chaînes larges peuvent demander
  `sans_niveau_ages`.
