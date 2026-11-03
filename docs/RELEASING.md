# Publier une version (ADR 0011)

Seul Antsa publie. La clé privée Ed25519 est dans `release-keys/ed25519.pem` (hors de Git) : **la sauvegarder
ailleurs** — sans elle, plus aucune mise à jour ne peut être signée et les apps installées refuseront toute autre clé.

1. Monter la version dans `app/pubspec.yaml` (`version: x.y.z+n`, `n` toujours croissant).
2. `cd app && flutter test && tool/release.sh "Ce que la version permet de faire."`
   → `release-out/` : l'APK arm64, `release.json` (build = versionCode réel de l'APK, Flutter ajoute 2000 pour
   arm64), `release.json.sig`. `flutter test test/release_out_test.dart` vérifie la signature avec la clé de l'app.
3. Essai sur l'émulateur `zanakiantsa_tab` (`adb -s <série> install -r release-out/*.apk`), en portrait et en
   paysage (voir `CLAUDE.md`).
4. Publication (action publique, à la main) :
   `gh release create app-vX.Y.Z release-out/* --title "Zanak'i Antsa X.Y.Z" --notes "…"`.
   L'app lit `https://github.com/raantss18/zanakiantsa/releases/latest/download/release.json`.

Le format de `release.json` ne change jamais : toute version de l'app doit savoir lire la dernière.
