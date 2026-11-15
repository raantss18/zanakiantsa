#!/usr/bin/env bash
# Assemble images.mp4 + voix (aux instants de timeline.txt) + musique (baissée sous la voix) → vidéo finale.
set -euo pipefail
E=$(dirname "$0"); OUT=${1:-$HOME/GitHub/zanakiantsa/demo/zanakiantsa-evolution.mp4}
args=(-i "$E/images.mp4" -i "$E/musique.wav"); filt=""; labels=""; n=2
while read -r name start; do
  args+=(-i "$E/voix/$name.wav")
  ms=$(python3 -c "print(int($start*1000))")
  filt+="[$n:a]aresample=48000,adelay=${ms}|${ms},volume=1.6[v$n];"
  labels+="[v$n]"; n=$((n+1))
done < "$E/timeline.txt"
cnt=$((n-2))
filt+="${labels}amix=inputs=${cnt}:normalize=0,apad=whole_dur=122.1,asplit=2[voice][key];"
filt+="[1:a]volume=0.32[mus];[mus][key]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=400[duck];"
filt+="[voice][duck]amix=inputs=2:normalize=0,afade=t=out:st=119.5:d=2.5,alimiter=limit=0.95[a]"
ffmpeg -y -loglevel error "${args[@]}" -filter_complex "$filt" -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$OUT"
ffprobe -v error -show_entries format=duration,size -of default=nw=1 "$OUT"
