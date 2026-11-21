# ADR 0080 — Clé de signature propre à l'app (fin de la clé debug)

- **Statut** : accepté (2026-11-21). Antsa a vu Play Protect déclarer l'app suspecte sur une tablette après la 1.1.9.
- **Contexte** : tous les APK étaient signés avec la clé *debug* Android du poste (`CN=Android Debug`, ADR 0072), celle
  des versions d'essai ; une app installée hors Play Store avec ce certificat, qui installe elle-même ses mises à jour
  (`REQUEST_INSTALL_PACKAGES`), ressemble à une app reconditionnée. Permissions vérifiées : ni SMS, ni accessibilité,
  ni écoute des notifications (les cas que Google bloque : https://developers.google.com/android/play-protect/warning-dev-guidance).
- **Décision** : clé RSA 4096 `release-keys/zanakiantsa.jks` (« Zanak'i Antsa », MG), mot de passe dans
  `key.properties`, copie sur le NAS. Rotation APK v3 (https://source.android.com/docs/security/features/apksigning/v3) :
  `release-keys/lineage.bin` prouve que l'ancienne clé a signé la nouvelle, donc la mise à jour s'installe par-dessus
  sans désinstaller (journal gardé). `tool/release.sh` signe : v2 avec l'ancienne clé (Android 7 et 8), v3 avec la
  nouvelle dès Android 9 (`--rotation-min-sdk-version 28`). Les quatre fichiers servent à chaque version.
- **Vérifié** : `apksigner verify` (v2 + v3, signataire « Zanak'i Antsa ») ; émulateur Android 16 : APK tourné installé
  par-dessus la 1.1.9 signée debug, sans désinstaller, progression et « Reprendre » intacts ; Android garde l'ancienne
  clé dans `past signatures`.
- **Supposé** : Play Protect cesse d'alerter une fois la nouvelle clé connue (non vérifiable sans la tablette ; Google
  ne publie pas ses critères). **Reste à tester** : la mise à jour par l'app elle-même sur la vraie tablette.
