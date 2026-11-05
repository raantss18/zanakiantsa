# 0049 — Le sens du tracé des lettres attachées est vérifié

- **Date** : 2026-11-05 · **Statut** : accepté (TODO : « sens du tracé des lettres »)
- **Source** : éduscol, « L'écriture à l'école maternelle — La forme des lettres », septembre 2015
  (https://eduscol.education.fr/document/13564/download) : en cursive, « le ductus doit être respecté » ; le rond de
  a, c, d, g, o, q « se trace en rotation à gauche à partir d'un repère situé en haut de la forme et suffisamment à
  droite » (le « 2 » d'une horloge) ; pour les capitales, « il n'est pas nécessaire d'imposer un ductus particulier ».
- **Décision** (`core/ductus.dart`) : seules les lettres attachées sont vérifiées, les capitales jamais.
  - Rond (a, c, d, g, o, q) : départ en haut à droite, tracé vers la gauche. Un point vert montre le départ.
  - Autres lettres : d'un seul geste, de gauche à droite (sauf le point du i et du j, la barre du t).
  - Le message dit ce qui ne va pas, sans donner la solution. Le tracé reste d'abord jugé sur la couverture de la lettre.
- **Limite connue** : le modèle affiché (police Playwrite FR) n'a pas toujours de trait d'attaque, et le « s » finit à
  gauche. La règle gauche-droite ne vaut donc que pour e, i, l, m, n, r, t, u (vus à l'écran). Les autres lettres
  (b, f, h, j, k, p, s, v, w, x, y, z) ne sont pas vérifiées dans le sens.
- **Aussi corrigé** : le guide gris de la cursive est réduit (0,95 → 0,68) : la hampe du « l » sortait du cadre.
- **Vérifié** : `test/ductus_test.dart`. Sur l'émulateur : « n » tracé à l'envers refusé avec explication, bon sens
  accepté ; point vert sur c et a. **Pas vérifié** : un rond tracé en vrai (a, c, o), au doigt d'un enfant.
