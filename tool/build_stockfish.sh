#!/usr/bin/env bash
# Reconstruit app/android/app/src/main/jniLibs/arm64-v8a/libstockfish.so : Stockfish 11, sans aucune modification de ses
# sources, compilé pour Android arm64 (ADR 0053). Stockfish est sous GPL-3 : ses sources sont à l'adresse ci-dessous.
#   Sources : https://github.com/official-stockfish/Stockfish  (étiquette sf_11, commit c3483fa9a7d7c0ffa9fcc32b467ca844cfb63790)
# Outils : git et le NDK Android (mesuré avec 28.2.13676358). Le Makefile de sf_11 ne connaît ni le NDK ni arm64 :
# on appelle le compilateur directement, avec ses réglages (-O3, -flto, 64 bits, popcount).
set -euo pipefail
NDK="${ANDROID_NDK_ROOT:-$HOME/Android/Sdk/ndk/28.2.13676358}"
OUT="$(cd "$(dirname "$0")/.." && pwd)/app/android/app/src/main/jniLibs/arm64-v8a/libstockfish.so"
WORK="${1:-$(mktemp -d)}"
export PATH="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

git clone --quiet --depth 1 --branch sf_11 https://github.com/official-stockfish/Stockfish.git "$WORK/stockfish"
cd "$WORK/stockfish"
[ "$(git rev-parse HEAD)" = c3483fa9a7d7c0ffa9fcc32b467ca844cfb63790 ] || { echo "commit inattendu" >&2; exit 1; }
cd src
aarch64-linux-android24-clang++ -std=c++11 -O3 -flto -DNDEBUG -DIS_64BIT -DUSE_POPCNT -fno-exceptions -pthread -pie \
  -static-libstdc++ -Wno-deprecated ./*.cpp syzygy/*.cpp -o "$WORK/stockfish.bin"
llvm-strip -o "$OUT" "$WORK/stockfish.bin"
sha256sum "$OUT"
