# 0013 — Écrans adaptatifs (portrait et paysage)

- **Date** : 2026-11-02 · **Statut** : accepté
- **Constat** : sur la 2e SM-X135G (`R8YL11BAJ7D`, sw601dp, densité 213), l'app s'ouvrait en paysage malgré
  `screenOrientation="portrait"`. Android 16 ignore l'orientation imposée par les apps ciblant l'API 36 sur les écrans
  ≥ 600 dp (https://developer.android.com/about/versions/16/behavior-changes-16, vérifié le 2026-11-02 ; la dérogation
  existe mais disparaît à l'API 37). La 1re tablette (densité forcée à 280, sw457dp) reste en portrait.
- **Décision** : chaque écran s'adapte (`split()` dans `ui/theme.dart`) : commandes en bas en portrait, à droite en
  paysage ; les objets à compter sont replacés à la rotation. Pas de dérogation temporaire.
- **Reste à améliorer** : objets assez petits en paysage (hauteur utile réduite par la bande d'aide).
