#!/usr/bin/env bash
# Reconstruit app/android/app/src/main/jniLibs/arm64-v8a/liblc0.so : le moteur lc0, sans aucune modification de ses
# sources, compilé pour Android arm64 (ADR 0051). lc0 est sous GPL-3 : ses sources sont à l'adresse ci-dessous.
#   Sources : https://github.com/LeelaChessZero/lc0  (étiquette v0.32.1, commit fd71a2d921b689c5f479d3227c3806c8e272d9c5)
# Outils : meson, ninja, git, et le NDK Android (r27c ou plus récent ; mesuré avec 28.2.13676358).
set -euo pipefail
NDK="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/28.2.13676358}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/app/android/app/src/main/jniLibs/arm64-v8a/liblc0.so"
WORK="${1:-$(mktemp -d)}"
export PATH="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

git clone --quiet --depth 1 --branch v0.32.1 https://github.com/LeelaChessZero/lc0.git "$WORK/lc0"
cd "$WORK/lc0"
[ "$(git rev-parse HEAD)" = fd71a2d921b689c5f479d3227c3806c8e272d9c5 ] || { echo "commit inattendu" >&2; exit 1; }
# Réglages de compilation prévus par lc0 pour son propre paquet Android (appveyor.yml) : pas de recherche en parallèle.
printf '#define DEFAULT_MAX_PREFETCH 0\n#define DEFAULT_TASK_WORKERS 0\n' > params_override.h
meson setup arm64 --buildtype release -Dgtest=false -Dopenblas=false -Dispc=false -Dblas=true \
  -Ddefault_library=static -Donnx=false -Dpython_bindings=false --cross-file cross-files/aarch64-linux-android
ninja -C arm64 lc0 -j"$(nproc)"
llvm-strip -o "$OUT" arm64/lc0
sha256sum "$OUT"
