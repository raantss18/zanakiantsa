# 0023 — Programmer un robot (blocs)

- **Date** : 2026-11-03 · **Statut** : accepté (priorité 5 d'Antsa : « type Scratch »)
- **Décision** : un domaine « le code » : on aligne des blocs puis ▶ fait rouler la mascotte sur un quadrillage
  jusqu'à l'objet. Trois compétences sourcées : flèches absolues (maternelle : « coder à l'aide de flèches le
  déplacement… sur un tableau à cases ») ; avancer / pivoter, 3 à 5 instructions (maternelle, à partir de 5 ans) ;
  contourner des rochers, au plus 10 instructions dont 2 virages (CP, programme de mathématiques du cycle 2).
- **Moteur** (`app/lib/core/robot.dart`) : parcours tirés au hasard, gardés si le plus court programme (recherche en
  largeur) respecte les bornes ; un choc arrête le robot. Testé sur 200 tirages.
- **Inspiration** : l'idée des blocs de ScratchJr, sans code ni dessin repris (CLAUDE.md règle 7).
- **Reste à faire** : boucles (« répéter ») et programmes d'animation libres, plus proches de Scratch (cycle 3).
