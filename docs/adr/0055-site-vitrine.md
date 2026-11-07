# 0055 — Un site vitrine sur GitHub Pages, en cahier d'écolier

- **Date** : 2026-11-07 · **Statut** : accepté, en ligne depuis le 2026-11-07 (demande d'Antsa : « un site vitrine,
  attractif et convivial, simple pour télécharger l'app et avoir les nouvelles sur l'éducation et l'app »).
- **Décision** : `site/` (HTML, CSS, un script de 10 lignes pour copier l'empreinte), publié par `.github/workflows/site.yml`.
  `tool/build_site.py` écrit dans la page la dernière version (numéro, taille, empreinte SHA-256 donnée par GitHub, lien du
  fichier) et les 3 dernières versions, à partir de l'API des versions ; il écrit aussi le flux Atom (`feed.xml`). Reconstruit à
  chaque version publiée. Aucune requête vers un autre site, aucun cookie, aucune police ni image distantes : le site tient
  la promesse de l'application.
- **Design** : un cahier Seyès (lignes de 32 px, marge rouge), titres dans l'écriture d'école Playwrite FR (la police du
  tracé cursif de l'application, SIL OFL), texte en Andika (« police de lecture », SIL OFL), encre violette et violet de
  l'application. Seul mouvement : le titre de l'accueil s'écrit ; coupé si l'appareil demande moins d'animations. Les
  images sont de vraies captures de l'application (tablette en paysage), pas des maquettes.
- **Contenu** : chaque phrase vient de `docs/` (vision, pédagogie, ADR). Les « notes de lecture » (`site/notes.json`) ne
  reprennent que les résultats lus dans `docs/pedagogie.md`, avec leurs limites et leurs sources. Dit sans détour : pas sur
  Google Play, exception ML Kit, pas encore d'essai avec un groupe d'enfants, voix de synthèse.
- **Vérifié** : en ligne (https://raantss18.github.io/zanakiantsa/, déploiement réussi, page, flux et police servis) ; rendu à 390, 768, 1360 et 1920 px, sans débordement horizontal ; polices chargées ; le flux Atom est du XML
  valide. **Pas vérifié** : lecteurs d'écran ; Safari et Firefox.
