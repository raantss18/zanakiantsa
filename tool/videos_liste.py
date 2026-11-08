#!/usr/bin/env python3
"""Écrit docs/videos-chaines.md : les chaînes de la liste blanche (content/videos/chaines.yaml), par âge puis par matière.
Généré, ne pas modifier à la main : python3 tool/videos_liste.py"""
import yaml

NOMS = {'lire': 'Français, lecture', 'compter': 'Mathématiques', 'nature': 'Sciences', 'explorer': 'Histoire, géographie, monde',
        'anglais': 'Anglais', 'code': 'Informatique', 'echecs': 'Échecs', 'dessin': 'Arts, dessin', 'sons': 'Musique',
        'motifs': 'Logique, énigmes, jeux'}
TRANCHES = [('5 à 7 ans', 5, 7), ('8 à 11 ans', 8, 11), ('12 à 14 ans', 12, 14), ('15 ans et plus', 15, 99)]

chaines = yaml.safe_load(open('content/videos/chaines.yaml', encoding='utf8'))['chaines']
out = ['# Chaînes vidéo de Zanak\'i Antsa', '',
       f'Généré depuis `content/videos/chaines.yaml` ({len(chaines)} chaînes) par `tool/videos_liste.py`. Une chaîne apparaît '
       'dans chaque tranche d\'âge et chaque matière qu\'elle couvre. Règles (ADR 0068) : chaînes faites par des personnes '
       'identifiées, aucune vidéo générée par IA, ni short, ni direct, ni promotion ; une vidéo hors de cette liste ne se lit '
       'jamais. Nouvelles chaînes : ticket « Vidéos : chaînes candidates » chaque lundi ; refusées : `ecartees.yaml`.', '']
for titre, lo, hi in TRANCHES:
    out += [f'## {titre}', '']
    for d, nom in NOMS.items():
        rows = [c for c in chaines if d in c['domaines'] and c['ages'][0] <= hi and (c['ages'][1] >= 18 or c['ages'][1] >= lo)]
        if not rows:
            out += [f'- **{nom}** : aucune chaîne pour l\'instant.']
            continue
        fr = sorted(c['nom'] for c in rows if c['langue'] == 'fr')
        en = sorted(c['nom'] for c in rows if c['langue'] == 'en')
        out += [f'- **{nom}** — en français : {", ".join(fr) or "aucune"} · en anglais : {", ".join(en) or "aucune"}']
    out.append('')
open('docs/videos-chaines.md', 'w', encoding='utf8').write('\n'.join(out))
print(f'{len(chaines)} chaînes → docs/videos-chaines.md')
