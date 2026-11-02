"""Génère ding.wav : deux notes sinusoïdales amorties (mi5 puis la5), 0,35 s, 22 050 Hz, mono 16 bits.

Son créé par code pour le spike : aucun asset tiers, aucune licence à suivre.
"""
import math
import struct
import sys
import wave

RATE = 22050


def note(freq, dur):
    n = int(RATE * dur)
    return [math.sin(2 * math.pi * freq * i / RATE) * math.exp(-6 * i / n) for i in range(n)]


samples = note(659.25, 0.15) + note(880.0, 0.20)
out = sys.argv[1] if len(sys.argv) > 1 else "ding.wav"
with wave.open(out, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", int(s * 0.6 * 32767)) for s in samples))
