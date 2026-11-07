#!/usr/bin/env python3
"""Musique de fond de la vidéo d'aide (ADR 0058) : une boîte à musique douce, composée ici par calcul (rien à créditer).
Gamme pentatonique de do, 104 battements par minute (76 était trop lent, retour d'Antsa), mélodie de 8 mesures qui revient, basse lente, fondu au début et à la fin.

  python3 tool/video/music.py --seconds 240 --out musique.wav
"""
import argparse
import wave

import numpy as np

SR = 44100
BPM = 104
BEAT = 60 / BPM
# Do pentatonique : do ré mi sol la (Hz), sur deux octaves.
NOTE = {'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'G4': 392.00, 'A4': 440.00,
        'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'G5': 783.99, 'A5': 880.00,
        'C3': 130.81, 'G2': 98.00, 'A2': 110.00, 'F2': 87.31, 'F3': 174.61, 'D3': 146.83}
# Mélodie (note, durée en temps) : 8 mesures de 4 temps.
MELODY = [
    ('E5', 1), ('G5', 1), ('E5', 1), ('D5', 1), ('C5', 2), ('D5', 1), ('E5', 1),
    ('G5', 1.5), ('A5', 0.5), ('G5', 1), ('E5', 1), ('D5', 3), (None, 1),
    ('C5', 1), ('D5', 1), ('E5', 1), ('G5', 1), ('A5', 2), ('G5', 1), ('E5', 1),
    ('D5', 1), ('E5', 1), ('D5', 1), ('C5', 1), ('C5', 3), (None, 1),
]
BASS = ['C3', 'A2', 'F2', 'G2', 'C3', 'A2', 'F2', 'G2']  # une note par mesure


def bell(freq, dur, amp):
    t = np.arange(int(SR * dur)) / SR
    env = np.exp(-t * 4.5) * (1 - np.exp(-t * 400))
    w = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t * 6) + 0.12 * np.sin(2 * np.pi * 3.01 * freq * t) * np.exp(-t * 9)
    return amp * env * w


def pad(freq, dur, amp):
    t = np.arange(int(SR * dur)) / SR
    env = np.minimum(1, t / 0.8) * np.minimum(1, (dur - t) / 0.8).clip(0)
    w = np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 1.5 * t) + 0.25 * np.sin(2 * np.pi * freq * 2 * t)
    return amp * env * w


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seconds', type=float, required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    n = int(SR * (a.seconds + 4))
    out = np.zeros(n)
    loop = 32 * BEAT
    start = 0.0
    while start < a.seconds:
        t = start
        for note, beats in MELODY:
            if note and t < a.seconds:
                s = bell(NOTE[note], min(3.0, beats * BEAT + 1.2), 0.22)
                i = int(t * SR)
                out[i:i + len(s)] += s[:max(0, n - i)]
            t += beats * BEAT
        for k, b in enumerate(BASS):
            tt = start + k * 4 * BEAT
            if tt < a.seconds:
                s = pad(NOTE[b], 4 * BEAT, 0.05)
                i = int(tt * SR)
                out[i:i + len(s)] += s[:max(0, n - i)]
            # Arpège en croches (fondamentale, quinte, octave, quinte) : il donne l'allant.
            root = NOTE[b] * 2
            for j, r in enumerate([1, 1.5, 2, 1.5, 1, 1.5, 2, 1.5]):
                t2 = tt + j * BEAT / 2
                if t2 < a.seconds:
                    s = bell(root * r, 0.6, 0.07)
                    i = int(t2 * SR)
                    out[i:i + len(s)] += s[:max(0, n - i)]
        start += loop
    out = out[:int(SR * a.seconds)]
    # Un peu d'écho, comme dans une pièce.
    d = int(0.23 * SR)
    out[d:] += 0.25 * out[:-d]
    tt = np.arange(len(out)) / SR
    out *= np.minimum(1, tt / 2.0) * np.minimum(1, (a.seconds - tt) / 4.0).clip(0)
    out = out / max(1e-9, np.abs(out).max()) * 0.5  # volume doux
    with wave.open(a.out, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((out * 32767).astype(np.int16).tobytes())


if __name__ == '__main__':
    main()
