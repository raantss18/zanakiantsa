# 0059 — L'espace parent a le visuel du site

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa : « même visuel que le site, surtout l'à propos, visuellement mauvais »).
- **Décision** : `lib/parent/notebook_style.dart` reprend les jetons du site (ADR 0055) pour l'espace parent seulement : papier
  Seyès et marge rouge, titres en Playwrite FR, encre violette #2B1458, boutons violets en pilule, choix en jaune soleil.
  Les écrans des enfants gardent leurs mondes (ADR 0014).
- **À propos** : une fiche bordée d'encre ; « Une question ? Un souci ? », une ligne par contact avec son icône (texte
  sélectionnable pour le copier), le code QR du site sur fond blanc. Côte à côte sur grand écran, l'un sous l'autre sur téléphone.
- **Vérifié** : tests ; émulateur au format SM-X135G. **Pas vérifié** : grand écran, mode sombre du système.
