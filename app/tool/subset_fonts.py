#!/usr/bin/env python3
"""Réduit les polices Andika aux caractères dont l'app a besoin (ADR 0028) : latin de base, latin-1, latin étendu A,
ponctuation générale, et tout caractère présent dans le contenu, les livres ou le code. Les originaux (SIL OFL) sont
gardés dans design/fonts/ ; relancer après un ajout de contenu dans une autre écriture.
Usage (depuis app/) : python3 tool/subset_fonts.py
"""
import glob
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

used = set()
for f in glob.glob('assets/content/*.json') + ['assets/livres/catalogue.json'] + glob.glob('lib/**/*.dart', recursive=True):
    used |= {ord(c) for c in Path(f).read_text(encoding='utf-8')}
unicodes = (set(range(0x20, 0x7F)) | set(range(0xA0, 0x180)) | set(range(0x2010, 0x2028)) | set(range(0x2030, 0x205F))
            | {0x20AC, 0x2212, 0x2260, 0x2264, 0x2265, 0x2248, 0xB2, 0xB3, 0xB9} | set(range(0x2070, 0x208F)) | {u for u in used if u > 0x7E})
for name in ['Andika-Regular', 'Andika-Bold']:
    src = Path(f'../design/fonts/{name}.ttf')
    font = TTFont(src)
    opts = subset.Options()
    opts.layout_features = ['*']  # garde les variantes de lettres d'Andika (a et g « d'écolier »)
    opts.name_IDs = ['*']
    opts.notdef_outline = True
    s = subset.Subsetter(opts)
    s.populate(unicodes=unicodes)
    s.subset(font)
    font.save(f'assets/fonts/{name}.ttf')
    print(name, src.stat().st_size // 1024, '→', Path(f'assets/fonts/{name}.ttf').stat().st_size // 1024, 'Ko')
