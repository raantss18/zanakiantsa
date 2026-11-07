# 0058 — Un guide vidéo d'installation, sur de vrais écrans

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa : aider les parents peu familiers de la technologie, Android
  étant devenu plus restrictif).
- **Décision** : vidéo de 4 min 23 s, sans voix (choix d'Antsa : texte à l'écran), montée par `tool/video/render.py` à partir de
  vrais enregistrements (`screenrecord`) de la tablette SM-X135G le 2026-11-07 : téléchargement, installation, espace parent,
  jeu, exploration, mise à jour 0.11.0 → 0.11.1. Un doigt animé touche chaque bouton ; positions relevées sur les images
  (`tool/video/plan.py`). Musique de boîte à musique composée par calcul (`music.py`), rien à créditer. Générique de fin :
  coordonnées de l'auteur et code QR du site, aussi dans « À propos » de l'app.
- **Sur le site** : section « Le guide en vidéo », sous l'accueil, lue dans la page (balise `video` ; pas de lecture
  automatique avec le son, que les navigateurs bloquent), avec des boutons par chapitre. Les étapes écrites suivent le chemin filmé.
- **Constaté en filmant** : sur cette Samsung, ouvrir l'APK depuis Chrome ne lançait rien ; il faut « Mes fichiers ». Google Play
  Protect : « Plus de détails », puis « Installer sans analyser » (« Analyser l'appli » non essayé).
- **Reste à faire** : refaire la vidéo quand les écrans changent ; la voir sur téléphone ; l'écouter.
