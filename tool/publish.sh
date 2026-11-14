#!/usr/bin/env bash
# Publie la version préparée par app/tool/release.sh, puis vérifie qu'elle se voit sur le site (CLAUDE.md, ADR 0055).
# Action publique : seulement avec l'accord d'Antsa.
set -euo pipefail
cd "$(dirname "$0")/.."
SITE=https://raantss18.github.io/zanakiantsa/
# Deux lectures : des notes sur plusieurs lignes seraient coupées à la première par un seul `read` (audit du 2026-11-14).
VERSION=$(python3 -c "import json;print(json.load(open('release-out/release.json'))['latest']['version'])")
NOTES=$(python3 -c "import json;print(json.load(open('release-out/release.json'))['latest']['notes'])")
APK="release-out/zanakiantsa-$VERSION-arm64-v8a.apk"
[ -f "$APK" ] || { echo "Fichier absent : $APK" >&2; exit 1; }
gh release create "app-v$VERSION" "$APK" release-out/release.json release-out/release.json.sig \
  --title "Zanak'i Antsa $VERSION" --notes "$NOTES"
echo "Version $VERSION publiée. J'attends le site…"
for _ in $(seq 1 40); do
  sleep 15
  if curl -fsSL "$SITE?v=$RANDOM" | grep -q "Version $VERSION,"; then
    echo "Le site annonce la version $VERSION : $SITE"
    exit 0
  fi
done
echo "Le site n'annonce toujours pas la version $VERSION après 10 minutes : voir le flux « Site vitrine » sur GitHub." >&2
exit 1
