#!/usr/bin/env bash
# Mesure un APK de spike sur une tablette : taille, démarrage à froid (médiane de 5), PSS, fps.
# Usage : measure.sh <série adb> <paquet> <apk> <activité>   (ex. activité : .MainActivity)
set -euo pipefail
export LC_NUMERIC=C
serial=$1 pkg=$2 apk=$3 act=$4
a() { adb -s "$serial" "$@" </dev/null; }

size=$(stat -c %s "$apk")
a install -r -g "$apk" >/dev/null

starts=()
for _ in 1 2 3 4 5; do
  a shell am force-stop "$pkg"
  sleep 2
  t=$(a shell am start -S -W -n "$pkg/$act" | tr -d '\r' | awk -F': ' '/TotalTime/{print $2}')
  starts+=("$t")
  sleep 3
done
median=$(printf '%s\n' "${starts[@]}" | sort -n | sed -n 3p)

# Dernier lancement : 20 s d'animation, puis mémoire et fps.
a logcat -c
sleep 21
pss=$(a shell dumpsys meminfo "$pkg" | tr -d '\r' | awk '/TOTAL PSS:/{print $3; exit} /^ *TOTAL /{print $2; exit}')
fps=$(a logcat -d | tr -d '\r' | grep -o 'SPIKE fps [0-9.]*' | awk '{s+=$3; n++} END{if(n) printf "%.1f", s/n; else print "?"}')

printf '%s\t%s\tapk=%.1f Mo\tstart_med=%s ms (%s)\tpss=%.0f Mo\tfps=%s\n' \
  "$serial" "$pkg" "$(echo "$size/1048576" | bc -l)" "$median" "${starts[*]}" "$(echo "${pss:-0}/1024" | bc -l)" "$fps"
