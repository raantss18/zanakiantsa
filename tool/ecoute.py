#!/usr/bin/env python3
"""Écouter la tablette pendant un essai : enregistre le son de l'app, puis le transcrit (le texte de chaque phrase, avec son heure)
et donne la langue de chaque phrase d'après le journal du moteur de voix.

Le son vient de la tablette par scrcpy (Android ≥ 11, `--audio-dup` le laisse aussi jouer sur l'appareil) ; la
transcription se fait sur l'ordinateur avec faster-whisper, hors ligne une fois le modèle téléchargé.

  ~/.local/share/zanak-ecoute/bin/python tool/ecoute.py 20                 # écoute 20 s
  ~/.local/share/zanak-ecoute/bin/python tool/ecoute.py 20 -- adb -s R8YYA0CZ5ZV shell input tap 400 900
      (la commande après « -- » est lancée une seconde après le début de l'écoute)
"""
import argparse
import os
import signal
import subprocess
import sys
import tempfile
import time

SERIE = os.environ.get('SERIE', 'R8YYA0CZ5ZV')


def enregistrer(secondes: float, sortie: str, commande: list[str]) -> None:
    subprocess.run(['adb', '-s', SERIE, 'logcat', '-c'], check=False)
    rec = subprocess.Popen(
        ['scrcpy', '-s', SERIE, '--no-video', '--no-playback', '--no-window', '--audio-dup', '--audio-codec=opus',
         f'--record={sortie}'],
        stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    time.sleep(1.5)
    if commande:
        subprocess.run(commande, check=False)
    time.sleep(secondes)
    rec.send_signal(signal.SIGINT)
    _, err = rec.communicate(timeout=15)
    if not os.path.exists(sortie) or os.path.getsize(sortie) < 1000:
        sys.exit('rien enregistré :\n' + err.decode(errors='replace')[-800:])


def echantillons(fichier: str):
    """Le son en 16 kHz mono flottant, décodé par ffmpeg (le PyAV installé ne suit pas toujours faster-whisper)."""
    import numpy as np
    brut = subprocess.run(['ffmpeg', '-v', 'error', '-i', fichier, '-f', 's16le', '-ac', '1', '-ar', '16000', '-'],
                          capture_output=True, check=True).stdout
    return np.frombuffer(brut, np.int16).astype(np.float32) / 32768.0


def transcrire(fichier: str, modele: str) -> None:
    from faster_whisper import WhisperModel
    son = echantillons(fichier)
    try:
        m = WhisperModel(modele, device='cuda', compute_type='float16')
        segments, _ = m.transcribe(son, vad_filter=True, multilingual=True)
        segments = list(segments)
    except Exception:  # pas de CUDA utilisable : le processeur suffit pour quelques secondes de son
        m = WhisperModel(modele, device='cpu', compute_type='int8')
        segments = list(m.transcribe(son, vad_filter=True, multilingual=True)[0])
    if not segments:
        print('(silence)')
    for s in segments:
        print(f'{s.start:6.1f}–{s.end:5.1f} s  {s.text.strip()}')


def langues() -> None:
    """La langue de chaque phrase, d'après le moteur de voix Google (plus sûr que Whisper pour un mot isolé)."""
    journal = subprocess.run(['adb', '-s', SERIE, 'logcat', '-d', '-s', 'GoogleTTSServiceImpl:I'],
                             capture_output=True, text=True).stdout
    vues = [l.split('locale ')[1].split()[0] for l in journal.splitlines() if 'Synthesis request for locale' in l]
    print('voix demandées :', ' → '.join(vues) if vues else '(aucune par le moteur Google : voix enregistrée ou silence)')


def main() -> None:
    args = sys.argv[1:]
    commande = []
    if '--' in args:
        i = args.index('--')
        args, commande = args[:i], args[i + 1:]
    p = argparse.ArgumentParser()
    p.add_argument('secondes', type=float)
    p.add_argument('--modele', default='small')
    p.add_argument('--garder', help='copie du son enregistré')
    a = p.parse_args(args)
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, 'son.opus')
        enregistrer(a.secondes, f, commande)
        if a.garder:
            subprocess.run(['cp', f, a.garder], check=True)
        transcrire(f, a.modele)
    langues()


if __name__ == '__main__':
    main()
