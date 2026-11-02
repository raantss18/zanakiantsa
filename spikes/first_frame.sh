#!/usr/bin/env bash
# Temps réel jusqu'au premier rendu de l'activité : écart entre « Start proc » (ActivityManager) et « SPIKE first_frame »,
# lus dans logcat (horodatage de l'appareil). Médiane de 5 lancements à froid. L'app est arrêtée ensuite.
# Usage : first_frame.sh <série adb> <paquet> <activité>
set -eu
export LC_NUMERIC=C
serial=$1 pkg=$2 act=$3
a() { adb -s "$serial" "$@" </dev/null; }
ms() { awk '{split($2,t,":"); printf "%.0f\n", (t[1]*3600+t[2]*60+t[3])*1000}'; }

vals=()
for _ in 1 2 3 4 5; do
  a shell am force-stop "$pkg"; sleep 2; a logcat -c
  a shell am start -n "$pkg/$act" >/dev/null
  for _ in $(seq 1 40); do a logcat -d | grep -q "SPIKE first_frame" && break; sleep 0.5; done
  log=$(a logcat -d | tr -d '\r')
  t0=$(echo "$log" | grep -m1 "Start proc.*$pkg" | ms)
  t1=$(echo "$log" | grep -m1 "SPIKE first_frame" | ms)
  vals+=($((t1 - t0)))
done
a shell am force-stop "$pkg"
printf '%s\t%s\tfirst_frame_med=%s ms (%s)\n' "$serial" "$pkg" "$(printf '%s\n' "${vals[@]}" | sort -n | sed -n 3p)" "${vals[*]}"
