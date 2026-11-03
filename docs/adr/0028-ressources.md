# 0028 — Gestion des ressources

- **Date** : 2026-11-03 · **Statut** : accepté (demande d'Antsa : « meilleure gestion des ressources »)
- **Son** : appli cachée ou écran éteint → la voix se tait et la trame se met en pause (vérifié : lecteur « paused »),
  reprise au retour ; une seule trame en mémoire (celle du monde en cours) ; voix anglaise créée au premier mot
  anglais seulement (une liaison au moteur de synthèse en moins).
- **Images** : cache d'images Flutter borné à 48 Mo ; pages de livres décodées à la largeur de l'écran (≤ 720 px) ;
  couvertures à 400 px.
- **Animations** : le solide 3D cesse de tourner tout seul dès qu'on le touche (plus de dessin à chaque image).
- **Polices** : Andika réduite aux caractères utilisés (`app/tool/subset_fonts.py`, originaux dans `design/fonts/`) :
  783 → 104 Ko chacune, variantes de lettres d'écolier gardées.
- **Mesure (émulateur, à refaire sur la SM-X135G)** : PSS à l'accueil 223 Mo (0.4.0) → 197 Mo ; APK 45,2 → 44,6 Mo.
