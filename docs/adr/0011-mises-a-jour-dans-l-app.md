# 0011 — Mises à jour faites par l'application elle-même

- **Date** : 2026-11-02 · **Statut** : accepté (demande d'Antsa) ; mise en œuvre à tester sur la tablette
- **Décision** : l'app vérifie et installe ses mises à jour **elle-même** (pas de store, pas d'APK copié à la main),
  sur le modèle éprouvé de COMIMa (`comima/app/lib/core/updater.dart`) :
  1. `release.json` (format figé pour toujours) + signature **Ed25519** `release.json.sig` ; clé publique dans l'app ;
  2. APK téléchargé vérifié par son **SHA-256** annoncé dans le fichier signé ;
  3. Android exige la même clé de signature que l'app installée.
- **Contenu** : les paquets de contenu se mettent à jour de la même façon (manifeste signé + SHA-256), sans nouvelle
  version de l'app.
- **Enfant** : la proposition de mise à jour n'apparaît que dans l'**espace parent** ; l'app reste 100 % utilisable
  hors ligne, la vérification n'a lieu que si le réseau est là.
- **Distribution** : APK direct seulement (usage familial). Google Play interdit qu'une app s'y mette à jour autrement
  que par Play (Device and Network Abuse, https://support.google.com/googleplay/android-developer/answer/9888379,
  vérifié le 2026-11-02) : une version Play devrait retirer ce mécanisme.
- **Signature** : paquet Dart `cryptography` 2.9.0 (Apache-2.0, pub.dev) ⚠ à confirmer ; clés hors de Git (`release-keys/`).
- **Vérifié (2026-11-02, `dumpsys user` / `dumpsys device_policy`, deux tablettes)** : la restriction
  `no_install_unknown_sources` n'est **pas** dans les restrictions effectives du profil supervisé (politique résolue
  `null`). **Reste à tester** : l'autorisation « installer des applis inconnues » de l'app, accordée à la main, puis
  une vraie mise à jour de bout en bout.
