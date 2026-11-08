# 0068 — Vidéos éducatives et livres selon l'âge

- **Date** : 2026-11-08 · **Statut** : accepté (demande d'Antsa ; choix : chaînes choisies, toujours actif, livres de son
  âge ; pas de limite de durée, à aucun âge, tant que c'est éducatif — 2026-11-08, remplace « 10 min avant le lycée »).
- **Livres** : seulement ceux de la tranche d'âge et du niveau juste en dessous (≤ 7 ans : niveaux 1–3 ; 8–11 : 2–5 ; 12+ : 4–7).
- **Vidéos** : pas de NewPipe ni d'extraction des flux (conditions d'utilisation de YouTube, règle 8 de `CLAUDE.md`) :
  lecteur officiel (IFrame API, `youtube_player_iframe`), mode confidentialité renforcée (youtube-nocookie), aucune sortie
  vers YouTube ni le navigateur, suggestions limitées à la chaîne. Les publicités ne peuvent pas être bloquées.
  - Liste blanche `content/videos/chaines.yaml` (langue, âges, matières). Chaque jour, `tool/videos.py` (interface YouTube
    Data API v3, clé en secret GitHub `YOUTUBE_API_KEY`) publie `site/videos.json` : vidéos publiques, intégrables, sans
    restriction d'âge, 1–60 min. L'app garde la langue de l'app et les chaînes de son âge.
  - Liste de départ (matières du jour, pas vues d'abord), recherche limitée aux vidéos permises, « Vu » à 60 %, d'autres
    vidéos proposées ensuite. Avec internet seulement ; le catalogue est gardé pour s'afficher hors connexion.
  - Liste blanche stricte dans le lecteur (2026-11-08) : vidéo hors liste arrêtée ; en pause et à la fin, un écran de l'app
    couvre les vidéos proposées par YouTube. Plein écran (bouton, ou tablette tournée) ; la SM-X135G ignore les demandes
    d'orientation des apps (`ignoreOrientationRequest=true`).
- **Confidentialité** : regarder une vidéo envoie des données à Google (YouTube) ; à écrire dans `docs/conformite.md` et
  dans l'espace parent. ⚠ Activé sans réglage parent, à la demande d'Antsa.
- **Vérifié** : `test/videos_test.dart`, `test/books_test.dart`. Catalogue réel (2 506 vidéos, 20 chaînes) et lecteur
  essayés sur la tablette le 2026-11-08. **Reste à tester** : plein écran tablette tournée à la main.
