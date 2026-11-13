#!/usr/bin/env bash
# Petit émulateur au format de la Samsung SM-X135G (800 × 1340, densité 280), pour essayer l'app quand la tablette
# n'est pas branchée (demande d'Antsa du 2026-11-13). La tablette reste la référence : l'émulateur ne mesure ni la
# mémoire, ni la fluidité, ni le démarrage réels (CLAUDE.md).
#
#   tool/emulateur.sh            crée l'émulateur s'il manque, le démarre sans fenêtre et attend qu'il soit prêt
#   tool/emulateur.sh --fenetre  idem, avec la fenêtre de l'émulateur
#   tool/emulateur.sh --app      puis construit l'app (x86_64) et l'installe
#   tool/emulateur.sh --stop     l'arrête
set -euo pipefail

# Le SDK qui a l'émulateur (sur ce poste, ANDROID_SDK_ROOT peut pointer vers un SDK sans émulateur).
SDK=""
for d in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "$HOME/Android/Sdk"; do
  [ -n "$d" ] && [ -x "$d/emulator/emulator" ] && { SDK="$d"; break; }
done
[ -n "$SDK" ] || { echo "aucun SDK Android avec l'émulateur (ANDROID_SDK_ROOT, ANDROID_HOME, ~/Android/Sdk)"; exit 1; }
export ANDROID_SDK_ROOT="$SDK" ANDROID_HOME="$SDK"
AVD=zanakiantsa_tab
IMAGE="system-images;android-36;google_apis;x86_64"
EMU="$SDK/emulator/emulator"
ADB="$SDK/platform-tools/adb"
CMD="$SDK/cmdline-tools/latest/bin"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

serie() {  # la série de notre émulateur parmi ceux qui tournent (d'autres projets en ont sur ce poste)
  for s in $("$ADB" devices | awk '/^emulator-/{print $1}'); do
    [ "$("$ADB" -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')" = "$AVD" ] && { echo "$s"; return; }
  done
}

if [ "${1:-}" = --stop ]; then
  s=$(serie); [ -n "$s" ] && "$ADB" -s "$s" emu kill; exit 0
fi

if ! "$EMU" -list-avds | grep -qx "$AVD"; then
  "$CMD/sdkmanager" "$IMAGE" >/dev/null
  echo no | "$CMD/avdmanager" create avd -n "$AVD" -k "$IMAGE" -d pixel_tablet --force
  cfg="$HOME/.android/avd/$AVD.avd/config.ini"
  sed -i -e 's/^hw.lcd.width=.*/hw.lcd.width=800/' -e 's/^hw.lcd.height=.*/hw.lcd.height=1340/' \
         -e 's/^hw.lcd.density=.*/hw.lcd.density=280/' -e 's/^hw.ramSize=.*/hw.ramSize=4096/' "$cfg"
  grep -q '^hw.audioOutput' "$cfg" || echo 'hw.audioOutput=yes' >> "$cfg"
fi

s=$(serie)
if [ -z "$s" ]; then
  fen=(-no-window); [ "${1:-}" = --fenetre ] && fen=()
  # GPU logiciel : le GPU de l'ordinateur (gfxstream) fait planter l'émulateur au redémarrage de l'app (2026-11-03).
  nohup "$EMU" -avd "$AVD" -no-snapshot -no-boot-anim -gpu swiftshader_indirect "${fen[@]}" >/tmp/emulateur-$AVD.log 2>&1 &
  for _ in $(seq 120); do s=$(serie); [ -n "$s" ] && break; sleep 2; done
fi
[ -n "$s" ] || { echo "l'émulateur n'a pas démarré (voir /tmp/emulateur-$AVD.log)"; exit 1; }
"$ADB" -s "$s" wait-for-device
until [ "$("$ADB" -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
echo "prêt : $s"

if [ "${1:-}" = --app ]; then
  cd "$ROOT/app"
  flutter build apk --release --split-per-abi --target-platform android-x64
  "$ADB" -s "$s" install -r build/app/outputs/flutter-apk/app-x86_64-release.apk
  "$ADB" -s "$s" shell monkey -p mg.zanakiantsa.app -c android.intent.category.LAUNCHER 1 >/dev/null
fi
