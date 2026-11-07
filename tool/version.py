#!/usr/bin/env python3
"""Numéro de version de l'app (ADR 0062, règle d'Antsa) : trois chiffres de 0 à 9 qui se retiennent comme un compteur.
0.1.9 → 0.2.0, 0.9.9 → 1.0.0, 1.9.9 → 2.0.0. Le numéro de build (après +) augmente toujours de 1.

  python3 tool/version.py            affiche la version actuelle et la suivante
  python3 tool/version.py --bump     écrit la suivante dans app/pubspec.yaml
  python3 tool/version.py --set 1.0.0 --bump   (une seule fois : passage à la règle depuis 0.13.0)
"""
import argparse
import re
from pathlib import Path

PUBSPEC = Path(__file__).resolve().parent.parent / 'app' / 'pubspec.yaml'


def suivante(v: str) -> str:
    a, b, c = (int(x) for x in v.split('.'))
    if not all(0 <= x <= 9 for x in (b, c)):
        raise SystemExit(f'{v} ne suit pas la règle (chiffres de 0 à 9) : utiliser --set')
    n = a * 100 + b * 10 + c + 1
    return f'{n // 100}.{n // 10 % 10}.{n % 10}'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bump', action='store_true')
    ap.add_argument('--set', help='version imposée (passage à la règle)')
    a = ap.parse_args()
    s = PUBSPEC.read_text(encoding='utf-8')
    m = re.search(r'^version: (\d+\.\d+\.\d+)\+(\d+)$', s, re.M)
    v, build = m[1], int(m[2])
    new = a.set or suivante(v)
    if not re.fullmatch(r'\d+\.\d\.\d', new):
        raise SystemExit(f'{new} : la version doit être de la forme X.Y.Z, Y et Z entre 0 et 9')
    if a.bump:
        PUBSPEC.write_text(s.replace(m[0], f'version: {new}+{build + 1}'), encoding='utf-8')
        print(f'{v}+{build} → {new}+{build + 1}')
    else:
        print(f'actuelle {v}+{build}, suivante {new}+{build + 1}')


if __name__ == '__main__':
    main()
