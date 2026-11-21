#!/usr/bin/env bash
# Prépare une version signée (ADR 0011) dans ../release-out/ : APK arm64, release.json, release.json.sig.
# Usage (depuis app/) : tool/release.sh "Ce que la version permet de faire (une à trois lignes)"
# La clé privée Ed25519 est dans ../release-keys/ed25519.pem (jamais dans Git). La publication sur GitHub
# (gh release create … release-out/*) se fait à la main, après vérification.
set -euo pipefail
notes=${1:?notes de version}
version=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
flutter build apk --release --split-per-abi --target-platform android-arm64
apk=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
aapt2=$(ls -d "$HOME"/Android/Sdk/build-tools/*/aapt2 | tail -1)
# Signature (ADR 0080) : la clé de l'app (release-keys/zanakiantsa.jks) remplace la clé debug Android, que Play Protect
# tient pour suspecte. Rotation v3 : la lignée (release-keys/lineage.bin) prouve que l'ancienne clé a signé la nouvelle,
# donc les tablettes déjà installées acceptent la mise à jour sans rien perdre (Android 9 et plus ; avant, l'ancienne
# clé signe toujours). https://source.android.com/docs/security/features/apksigning/v3
apksigner=$(ls -d "$HOME"/Android/Sdk/build-tools/*/apksigner | tail -1)
keys=../release-keys
ZANAK_STORE_PASS=$(sed -n 's/^storePassword=//p' "$keys/key.properties") "$apksigner" sign \
  --ks "$HOME/.android/debug.keystore" --ks-key-alias androiddebugkey --ks-pass pass:android \
  --next-signer --ks "$keys/zanakiantsa.jks" --ks-key-alias zanakiantsa --ks-pass env:ZANAK_STORE_PASS \
  --lineage "$keys/lineage.bin" --rotation-min-sdk-version 28 --v1-signing-enabled false "$apk"
# Le versionCode réel de l'APK (Flutter ajoute 2000 pour arm64 avec --split-per-abi) : c'est lui que l'app compare.
build=$("$aapt2" dump badging "$apk" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")
out=../release-out
mkdir -p "$out"
name="zanakiantsa-$version-arm64-v8a.apk"
cp "$apk" "$out/$name"
sha=$(sha256sum "$out/$name" | cut -d' ' -f1)
bytes=$(stat -c %s "$out/$name")
url="https://github.com/raantss18/zanakiantsa/releases/download/app-v$version/$name"
python3 -I - "$out/release.json" "$build" "$version" "$notes" "$url" "$sha" "$bytes" <<'PY'
import json, sys
path, build, version, notes, url, sha, size = sys.argv[1:]
json.dump({"format": 1, "latest": {"build": int(build), "version": version, "notes": notes,
           "apk": {"url": url, "sha256": sha, "bytes": int(size)}}}, open(path, "w"), ensure_ascii=False, indent=2)
PY
openssl pkeyutl -sign -inkey ../release-keys/ed25519.pem -rawin -in "$out/release.json" | base64 -w0 > "$out/release.json.sig"
echo "Prêt dans $out : $name (build $build), release.json, release.json.sig"
