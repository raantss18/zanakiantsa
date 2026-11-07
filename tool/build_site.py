#!/usr/bin/env python3
"""Construit le site vitrine (dossier site/) dans un dossier de sortie, prêt pour GitHub Pages.

Le site est du HTML statique. Ce script y écrit ce qui change à chaque version, à partir de la liste des versions publiées
sur GitHub (JSON de `gh api repos/<dépôt>/releases`) : numéro, taille, empreinte, lien de téléchargement, notes de version,
et les domaines de cette version (noms, nombre de compétences, résumés, lus dans son étiquette Git) ; il écrit les notes de lecture (site/notes.json) et le flux Atom. Aucune bibliothèque : Python 3 seulement.

Usage : python3 tool/build_site.py --releases releases.json --out _site
"""
import argparse
import html
import json
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
SITE = RACINE / 'site'
URL = 'https://raantss18.github.io/zanakiantsa/'
MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre']


def date_fr(iso: str) -> str:
    d = datetime.fromisoformat(iso.replace('Z', '+00:00'))
    return f"{d.day}{'er' if d.day == 1 else ''} {MOIS[d.month - 1]} {d.year}"


def taille_fr(octets: int) -> str:
    return f"{octets / 1e6:.1f}".replace('.', ',') + ' Mo'


def e(texte: str) -> str:
    return html.escape(texte, quote=True)


def versions(releases):
    """Versions de l'application qui ont un fichier .apk, la plus récente d'abord."""
    out = []
    for r in releases:
        apk = next((a for a in r.get('assets', []) if a['name'].endswith('.apk')), None)
        if r.get('draft') or r.get('prerelease') or not apk:
            continue
        out.append({
            'tag': r['tag_name'],
            'version': r['tag_name'].removeprefix('app-v'),
            'date': r['published_at'],
            'notes': (r.get('body') or '').strip(),
            'url': r['html_url'],
            'apk': apk['browser_download_url'],
            'taille': apk['size'],
            'sha256': (apk.get('digest') or '').removeprefix('sha256:'),
        })
    return out


# Résumés pour les versions publiées avant l'ajout de `resume` dans content/*/_theme.yaml.
RESUMES_ANCIENS = {
    'lire': "Syllabes, lettres capitales et cursives, tracé des lettres au doigt avec le bon sens du geste.",
    'compter': "Dénombrer, composer, additionner, soustraire, tables, partage, heure, opérations posées chiffre par chiffre.",
    'nature': "Les êtres vivants, leurs besoins, leur corps, leurs milieux de vie.",
    'dessin': "Dessiner un sujet précis. L'application regarde si elle le reconnaît et dit ce qu'il manque.",
    'motifs': "Suites d'images et de nombres : de 1 en 1, de 2 en 2, de 10 en 10, à rebours.",
    'sons': "Écouter, comparer, reconnaître.",
    'echecs': "Les leçons pas à pas, puis de vraies parties contre le robot ou à deux.",
    'anglais': "Couleurs, nombres, animaux, le corps : écouter le mot et toucher l'image.",
    'code': "Programmer un robot avec des flèches, puis des blocs : boucles, conditions, compteur.",
    'explorer': "Le système solaire, le corps humain et les solides, en 3D.",
}
CHIFFRES = {10: 'Dix', 11: 'Onze', 12: 'Douze', 13: 'Treize', 14: 'Quatorze', 15: 'Quinze'}


def git(*args):
    return subprocess.run(['git', *args], cwd=RACINE, check=True, capture_output=True, text=True).stdout


def domaines(tag):
    """Les domaines tels qu'ils sont DANS la version publiée [tag] : le site n'annonce jamais ce qui n'est pas encore sorti."""
    fichiers = git('ls-tree', '-r', '--name-only', tag, 'content/').splitlines()
    ordre = re.search(r'^ordre:\s*\[(.*)\]', git('show', f'{tag}:content/domaines.yaml'), re.M)[1]
    out = []
    for d in [x.strip() for x in ordre.split(',')]:
        theme = git('show', f'{tag}:content/{d}/_theme.yaml')
        champ = lambda c: (m := re.search(rf'^{c}:\s*"?(.*?)"?\s*$', theme, re.M)) and m[1]
        nb = sum(1 for f in fichiers if f.startswith(f'content/{d}/') and f.endswith('.yaml') and not f.rsplit('/', 1)[1].startswith('_'))
        out.append({'id': d, 'nom': champ('nom'), 'icone': champ('icone'), 'nb': nb, 'resume': champ('resume') or RESUMES_ANCIENS[d]})
    return out


def html_sommaire(ds):
    lignes = []
    for d in ds:
        unite = 'compétence' if d['nb'] <= 1 else 'compétences'
        lignes.append(
            f"<li><img src=\"img/{e(d['icone'])}.svg\" alt=\"\" width=\"32\" height=\"32\">"
            f"<span class=\"ligne-pointillee\"><span class=\"nom\">{e(d['nom'])}</span></span>"
            f"<span class=\"nb\">{d['nb']} {unite}</span><p class=\"detail\">{e(d['resume'])}</p></li>")
    return '\n    '.join(lignes)


def html_versions(vs, combien=3):
    blocs = []
    for v in vs[:combien]:
        notes = f"<p>{e(v['notes'])}</p>" if v['notes'] else ''
        blocs.append(
            f"<article class=\"nouvelle\"><h3>Version {e(v['version'])}</h3>"
            f"<time datetime=\"{e(v['date'][:10])}\">{date_fr(v['date'])}</time>{notes}"
            f"<p><a href=\"{e(v['url'])}\">Notes de version sur GitHub</a></p></article>")
    blocs.append('<p><a href="https://github.com/raantss18/zanakiantsa/releases">Toutes les versions</a></p>')
    return '\n      '.join(blocs)


def html_notes(notes):
    blocs = []
    for n in notes:
        suite = ''.join(f"<p>{e(p)}</p>" for p in n['suite'])
        sources = ''.join(f"<li><a href=\"{e(s['url'])}\">{e(s['label'])}</a></li>" for s in n['sources'])
        blocs.append(
            f"<article class=\"nouvelle\" id=\"{e(n['id'])}\"><h3>{e(n['titre'])}</h3>"
            f"<time datetime=\"{e(n['date'])}\">{date_fr(n['date'] + 'T00:00:00Z')}</time><p>{e(n['resume'])}</p>"
            f"<details><summary>Lire la suite et les sources</summary>{suite}"
            f"<p class=\"sources\">Sources :</p><ul class=\"sources\">{sources}</ul></details></article>")
    return '\n      '.join(blocs)


def atom(vs, notes, maintenant):
    entrees = []
    for v in vs[:10]:
        entrees.append(
            f"<entry><id>{e(v['url'])}</id><title>Version {e(v['version'])}</title><updated>{e(v['date'])}</updated>"
            f"<link href=\"{e(v['url'])}\"/><content type=\"text\">{e(v['notes'] or 'Nouvelle version.')}</content></entry>")
    for n in notes:
        entrees.append(
            f"<entry><id>{URL}#{e(n['id'])}</id><title>{e(n['titre'])}</title><updated>{e(n['date'])}T00:00:00Z</updated>"
            f"<link href=\"{URL}#{e(n['id'])}\"/><content type=\"text\">{e(n['resume'])}</content></entry>")
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="fr">'
        f"<id>{URL}</id><title>Zanak'i Antsa : nouvelles</title><subtitle>Versions de l'application et notes de lecture.</subtitle>"
        f"<updated>{maintenant}</updated><link href=\"{URL}feed.xml\" rel=\"self\"/><link href=\"{URL}\"/>"
        f"<author><name>Antsa</name></author>{''.join(entrees)}</feed>\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--releases', required=True, help='JSON de `gh api repos/<dépôt>/releases`')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    vs = versions(json.loads(Path(a.releases).read_text(encoding='utf-8')))
    if not vs:
        raise SystemExit('Aucune version avec un fichier .apk : rien à proposer au téléchargement.')
    notes = sorted(json.loads((SITE / 'notes.json').read_text(encoding='utf-8')), key=lambda n: n['date'], reverse=True)
    dernier = vs[0]

    out = Path(a.out)
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(SITE, out, ignore=shutil.ignore_patterns('notes.json'))

    ds = domaines(dernier['tag'])
    for d in ds:
        shutil.copy(RACINE / 'app/assets/art' / f"{d['icone']}.svg", out / 'img')

    valeurs = {
        'SOMMAIRE': html_sommaire(ds), 'N_DOMAINES': CHIFFRES.get(len(ds), str(len(ds))),
        'N_COMPETENCES': str(sum(d['nb'] for d in ds)),
        'VERSION': e(dernier['version']), 'VERSION_DATE': date_fr(dernier['date']), 'TAILLE': taille_fr(dernier['taille']),
        'APK_URL': e(dernier['apk']), 'SHA256': e(dernier['sha256'] or 'non fournie'), 'RELEASE_URL': e(dernier['url']),
        'VERSIONS': html_versions(vs), 'NOTES': html_notes(notes),
    }
    page = (SITE / 'index.html').read_text(encoding='utf-8')
    for cle, val in valeurs.items():
        page = page.replace('{{' + cle + '}}', val)
    if '{{' in page:
        raise SystemExit('Un champ du modèle n\'a pas de valeur : ' + page[page.index('{{'):][:40])
    (out / 'index.html').write_text(page, encoding='utf-8')
    maintenant = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    (out / 'feed.xml').write_text(atom(vs, notes, maintenant), encoding='utf-8')
    (out / '.nojekyll').write_text('', encoding='utf-8')
    print(f"Site construit dans {out} : version {dernier['version']}, {len(vs)} version(s), {len(notes)} note(s).")


if __name__ == '__main__':
    main()
