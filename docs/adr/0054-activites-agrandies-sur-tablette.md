# 0054 — Les activités remplissent la place d'une grande tablette

- **Date** : 2026-11-07 · **Statut** : accepté (suite de l'ADR 0052 : « les autres écrans gardent leur disposition »).
- **Constat** (émulateur réglé comme la Xiaomi Pad 7 : 3200 × 2136 px, 440 dpi, soit 1163 × 776 dp, police 125 %) : les 25
  activités étaient dessinées pour un téléphone ou une petite tablette. En paysage, le bandeau du narrateur courait sur toute
  la largeur et l'activité, minuscule, flottait au milieu d'un écran vide (boutons de 50 dp, réponses collées au haut).
- **Décision** :
  - Paysage assez large (`activityBesideText` : 15 % plus large que haut et au moins 380 dp à côté de la colonne) : le
    narrateur passe dans une colonne à gauche, comme pour les échecs, et l'activité prend toute la hauteur.
  - `ScaledActivity` : l'activité se dessine à sa taille habituelle, dans une zone réduite, puis tout (objets, textes, boutons,
    cibles tactiles) est agrandi d'un coup, d'au plus 1,6 fois (`activityScale`). Aucune des 25 activités n'est modifiée ;
    les touchers restent justes. Zone de référence : 460 × 520 dp (la plus haute : l'opération posée et son clavier).
  - Sous cette taille (téléphone, SM-X135G en portrait) le facteur est 1 : rien ne change.
  - Ne sont pas agrandies (elles remplissent déjà leur zone, les agrandir réduirait leur élément principal) : échecs,
    problèmes d'échecs, programmer, blocs, planètes, corps, solides, tracer, dénombrer, composer.
- **Piège relevé** : un `LayoutBuilder` imbriqué dans la zone agrandie figeait l'écran (le bouton d'essai faisait avancer
  l'état mais rien ne se redessinait en version publiée). Le facteur est donc calculé dans `SessionPage`, où la taille est
  déjà connue, et `ScaledActivity` n'est plus qu'un `Transform.scale`.
- **Pages de listes** : accueil de domaine, carnet, espace parent et liste des parties restent dans une colonne centrée de 760 dp
  (`readablePadding`) ; en paysage les lignes couraient sur 1163 dp. Bibliothèque, liseuse, album, « Tout explorer » et le
  choix du monde étaient déjà corrects en paysage : inchangés.
- **Aussi** : bouton d'essai ⏭ visible seulement avec `--dart-define=DEV_SKILL=…` (jamais publié) pour passer d'une compétence
  à l'autre sans jouer.
- **Vérifié** : 158 tests (`test/adaptive_test.dart`) ; émulateur, les 25 compétences en paysage (Xiaomi Pad 7) et en
  portrait. **Pas vérifié** : une vraie Pad 7 ; le test de départ et la fin de séance en paysage ;
  le panneau de blocs reste petit en portrait.
