# Publier une version (ADR 0011)

Seul Antsa publie. La clé privée Ed25519 est dans `release-keys/ed25519.pem` (hors de Git) : **la sauvegarder
ailleurs** — sans elle, plus aucune mise à jour ne peut être signée et les apps installées refuseront toute autre clé.

**Clés Android à sauvegarder** (ADR 0080, copies sur le NAS) : `release-keys/zanakiantsa.jks`, `key.properties`,
`lineage.bin` et `~/.android/debug.keystore`. `tool/release.sh` signe avec les deux clés (rotation v3 : l'ancienne clé debug
pour Android 7 et 8, la clé de l'app dès Android 9) ; si l'une manque, les tablettes refusent la mise à jour (il faudrait
désinstaller l'app, donc perdre le journal de l'enfant).

1. Monter la version : `python3 tool/version.py --bump`. Règle (ADR 0062) : trois chiffres de 0 à 9 qui se retiennent
   comme un compteur, 0.1.9 → 0.2.0, 1.9.9 → 2.0.0 ; le build (`+n`) augmente toujours de 1.
2. `cd app && flutter test && tool/release.sh "Ce que la version permet de faire."`
   → `release-out/` : l'APK arm64, `release.json` (build = versionCode réel de l'APK, Flutter ajoute 2000 pour
   arm64), `release.json.sig`. `flutter test test/release_out_test.dart` vérifie la signature avec la clé de l'app.
3. Essai sur l'émulateur `zanakiantsa_tab` (`adb -s <série> install -r release-out/*.apk`), en portrait et en
   paysage (voir `CLAUDE.md`).
4. Publication (action publique, à la main) : `tool/publish.sh`. Le script vérifie que le pubspec est à cette version, pousse `main`,
   pose le tag sur ce commit, publie la version avec les notes de `release.json`,
   attend la reconstruction du site, puis vérifie que https://raantss18.github.io/zanakiantsa/ annonce bien cette version
   (ADR 0055). Les notes s'y affichent telles quelles : les écrire pour des parents.
   L'app lit `https://github.com/raantss18/zanakiantsa/releases/latest/download/release.json`.

Le format de `release.json` ne change jamais : toute version de l'app doit savoir lire la dernière.
