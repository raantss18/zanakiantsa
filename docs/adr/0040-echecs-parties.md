# 0040 — Jouer de vraies parties d'échecs, les garder et les revoir

- **Date** : 2026-11-03 · **Statut** : accepté (demande d'Antsa : après les leçons, jouer contre le robot ou une
  personne, enregistrer les parties pour les analyser)
- **Règles** : moteur complet écrit pour l'app (`core/game.dart`) d'après les FIDE Laws of Chess 2023
  (https://handbook.fide.com/chapter/E012023) : roque, prise en passant, promotion au choix, mat, pat, matériel
  insuffisant, triple répétition, 50 coups. Vérifié par les comptages « perft » publiés
  (https://www.chessprogramming.org/Perft_Results) sur 4 positions.
- **Robot** (`core/engine.dart`) : alpha-bêta + prises, matériel et centre ; niveaux 1 (souvent au hasard), 2, 3 ;
  calcul hors du fil de l'interface. Contre le robot, l'enfant peut reprendre son coup.
- **Parties** : 30 dernières par enfant, sur l'appareil. **Revue** coup par coup, commentaires : mat manqué, pièce
  laissée en prise, prise gratuite manquée, prises avec échec ; le coup conseillé est encadré d'or.
- Domaine « Les échecs » : un accueil (leçons, robot, à deux, mes parties).
- **Reste à mesurer** : temps du niveau 3 sur la SM-X135G (0,7 s sur l'ordinateur).
