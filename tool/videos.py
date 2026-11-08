#!/usr/bin/env python3
"""Catalogue des vidéos éducatives (ADR 0068) : les vidéos des chaînes de content/videos/chaines.yaml, filtrées.

Passe par l'interface officielle YouTube Data API v3 (clé dans la variable YOUTUBE_API_KEY, gardée en secret GitHub,
jamais dans Git). Ne télécharge aucune vidéo : seulement leurs identifiants, titres et durées ; l'app les lit ensuite avec
le lecteur officiel de YouTube.

Garde une vidéo si elle passe le filtre `reject` (publique, intégrable, sans restriction d'âge, ni short, ni direct, ni
promotion, ni IA, 1 à 90 min ; les vidéos longues sont permises à tout âge, ADR 0068). Coût : ≈ 10 unités de quota par chaîne (10 000 par jour offertes).

  YOUTUBE_API_KEY=… python3 tool/videos.py --out site/videos.json [--par-chaine 100]
Sans clé : écrit un catalogue vide (l'app affiche alors « pas encore de vidéos »), sans échouer.
"""
import argparse
import collections
import datetime as dt
import json
import os
import re
import sys
import urllib.parse
import urllib.request

import yaml

API = 'https://www.googleapis.com/youtube/v3/'


def get(endpoint: str, **params) -> dict:
    params['key'] = os.environ['YOUTUBE_API_KEY']
    url = API + endpoint + '?' + urllib.parse.urlencode(params)
    with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'zanakiantsa-videos'}), timeout=30) as r:
        return json.load(r)


def seconds(iso: str) -> int:
    """Durée ISO 8601 (PT1H2M3S) en secondes."""
    m = re.fullmatch(r'P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?', iso or '')
    if not m:
        return 0
    d, h, mi, s = (int(x or 0) for x in m.groups())
    return ((d * 24 + h) * 60 + mi) * 60 + s


# Aucune vidéo générée par IA (règle d'Antsa, 2026-11-08). La liste blanche ne retient que des chaînes faites par des
# équipes humaines identifiées ; en plus, on écarte toute vidéo que son auteur déclare « contenu altéré ou synthétique »
# (status.containsSyntheticMedia, https://developers.google.com/youtube/v3/docs/videos) ou dont le titre, la description
# ou les mots-clés disent qu'elle a été faite par une IA. Une vidéo qui parle de l'IA reste permise.
MADE_BY_AI = re.compile(
    r"(générée?s?|créée?s?|faite?s?|réalisée?s?|animée?s?)\s+(par|avec)\s+(une\s+|l'|l’)?(ia|intelligence artificielle)\b"
    r"|\bai[- ]generated\b|\b(made|created|generated|animated)\s+(with|by|using)\s+(an\s+)?(ai|artificial intelligence)\b"
    r"|#ai(art|generated|video|animation)?\b|#ia\b|\b(midjourney|sora|kling|suno)\b",
    re.IGNORECASE)


def made_by_ai(v: dict) -> bool:
    sn = v.get('snippet', {})
    text = ' '.join([sn.get('title', ''), sn.get('description', ''), ' '.join(sn.get('tags', []))])
    return v.get('status', {}).get('containsSyntheticMedia', False) or bool(MADE_BY_AI.search(text))


# Filtre de chaque vidéo, même dans une chaîne choisie (ADR 0068). Rend la raison du refus, ou None si la vidéo est gardée.
# - shorts : formats verticaux de quelques secondes, faits pour défiler, pas pour apprendre ;
# - anciens directs (liveStreamingDetails), bandes-annonces, promotions, concours, déballages, webinaires : hors sujet ;
# - catégorie « Jeux vidéo » (20) : jamais ;
# - durée de 1 min à 90 min (`duree_max` par chaîne pour changer le maximum) ; pas d'autre limite, à aucun âge ;
# - `titre_contient` (un texte ou une liste : au moins un) et `titre_exclut` (liste) par chaîne.
OFF_TOPIC = re.compile(
    r"bande[- ]annonce|\bteaser\b|\btrailer\b|unboxing|déballage|giveaway|\bconcours\b|code promo|promo code"
    r"|\bsponsoris|webinaire|\bwebinar\b|\bpublicité\b|\bpub\b|#ad\b",
    re.IGNORECASE)
SHORT = re.compile(r"#shorts?\b", re.IGNORECASE)
LIVE = re.compile(r"\blive\b|en direct|\bdirect\b|\bstream", re.IGNORECASE)
NEVER_CATEGORIES = {'20'}  # Gaming


def as_list(x) -> list[str]:
    return [x] if isinstance(x, str) else list(x or [])


def reject(v: dict, c: dict) -> str | None:
    st, cd, sn = v.get('status', {}), v.get('contentDetails', {}), v.get('snippet', {})
    title = sn.get('title', '')
    text = ' '.join([title, sn.get('description', ''), ' '.join(sn.get('tags', []))])
    d = seconds(cd.get('duration'))
    if made_by_ai(v):
        return 'IA'
    if (st.get('privacyStatus') != 'public' or not st.get('embeddable', False)
            or cd.get('contentRating', {}).get('ytRating') == 'ytAgeRestricted'):
        return 'non intégrable'
    # Directs passés : une « Première » YouTube porte aussi liveStreamingDetails ; on ne refuse donc que les vrais
    # directs (longs, ou dits « live », « en direct » dans le titre).
    if sn.get('liveBroadcastContent', 'none') != 'none' or (
            'liveStreamingDetails' in v and (d > 1800 or LIVE.search(title))):
        return 'direct'
    if SHORT.search(text) or d < 60:
        return 'short'
    if d > c.get('duree_max', 5400):
        return 'trop longue'
    # Les chaînes d'échecs sont classées « Jeux vidéo » par YouTube : permis pour elles seules.
    if sn.get('categoryId') in NEVER_CATEGORIES and 'echecs' not in c.get('domaines', []):
        return 'jeux vidéo'
    if OFF_TOPIC.search(title):
        return 'hors sujet'
    low = title.lower()
    must = [m.lower() for m in as_list(c.get('titre_contient'))]
    if must and not any(m in low for m in must):
        return 'titre'
    if any(x.lower() in low for x in as_list(c.get('titre_exclut'))):
        return 'titre'
    # Langue de la vidéo, quand YouTube la connaît : celle de la chaîne (NASA Space Place publie aussi en espagnol).
    spoken = sn.get('defaultAudioLanguage') or sn.get('defaultLanguage') or ''
    if spoken and not spoken.lower().startswith(c['langue']):
        return 'langue'
    return None


def words(sn: dict) -> str:
    """Mots pour la recherche dans l'app : description courte et mots-clés, en minuscules."""
    text = (sn.get('description') or '').split('\n')[0][:200] + ' ' + ' '.join(sn.get('tags', [])[:15])
    return re.sub(r'\s+', ' ', text).strip().lower()


def build(channels: list[dict], per_channel: int) -> dict:
    out_channels, videos = [], []
    # Une entrée est une chaîne (id UC…, on lit toutes ses vidéos) ou une playlist officielle (id PL…, formats courts
    # d'une chaîne aux épisodes longs, par exemple).
    ids = [c['id'] for c in channels if c['id'].startswith('UC')]
    uploads = {c['id']: c['id'] for c in channels if not c['id'].startswith('UC')}
    for i in range(0, len(ids), 50):
        for item in get('channels', part='contentDetails', id=','.join(ids[i:i + 50]), maxResults=50).get('items', []):
            uploads[item['id']] = item['contentDetails']['relatedPlaylists']['uploads']
    for c in channels:
        if c['id'] not in uploads:
            print(f"chaîne introuvable, ignorée : {c['nom']} ({c['id']})", file=sys.stderr)
            continue
        index = len(out_channels)
        out_channels.append({k: c[k] for k in ('id', 'nom', 'langue', 'ages', 'domaines')})
        before = len(videos)
        vids, token = [], None
        wanted = c.get('profondeur', per_channel)
        while len(vids) < wanted:
            page = get('playlistItems', part='contentDetails', playlistId=uploads[c['id']], maxResults=50,
                       **({'pageToken': token} if token else {}))
            vids += [it['contentDetails']['videoId'] for it in page.get('items', [])]
            token = page.get('nextPageToken')
            if not token:
                break
        excluded = set(c.get('exclure', []))
        why, cats = collections.Counter(), collections.Counter()
        for i in range(0, len(vids), 50):
            batch = [v for v in vids[i:i + 50] if v not in excluded]
            if not batch:
                continue
            for v in get('videos', part='snippet,contentDetails,status,liveStreamingDetails',
                         id=','.join(batch)).get('items', []):
                cats[v['snippet'].get('categoryId')] += 1
                r = reject(v, c)
                if r:
                    why[r] += 1
                    continue
                sn = v['snippet']
                videos.append({
                    'id': v['id'],
                    'c': index,
                    't': sn['title'],
                    'd': seconds(v['contentDetails']['duration']),
                    'p': sn['publishedAt'][:10],
                    'm': words(sn),
                })
        mine = videos[before:]
        short = sum(v['d'] <= 600 for v in mine)
        refus = ', '.join(f'{k} {n}' for k, n in why.most_common()) or '-'
        cat = ' '.join(f'{k}:{n}' for k, n in cats.most_common(4))
        print(f"{c['nom'][:34]:34} {c['langue']} {str(c['ages']):8} lues {len(vids):4} gardées {len(mine):4} "
              f"(≤10 min {short}) | refusées : {refus} | catégories {cat}", file=sys.stderr)
    return {'genere': dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%MZ'), 'chaines': out_channels, 'videos': videos}


def per_age(catalogue: dict) -> dict[str, dict]:
    """Un petit catalogue par langue et par âge (5 à 18 ; 18 = 18 ans et plus) : l'app ne télécharge que le sien. À 10 ans en
    français, ≈ 50 Ko compressés au lieu de ≈ 850 Ko pour tout le catalogue (lent sur un téléphone, signalé le 2026-11-08)."""
    out = {}
    for lang in ('fr', 'en'):
        for age in range(5, 19):
            keep = [i for i, c in enumerate(catalogue['chaines'])
                    if c['langue'] == lang and c['ages'][0] <= age and (c['ages'][1] >= 18 or age <= c['ages'][1])]
            index = {i: k for k, i in enumerate(keep)}
            out[f'{lang}-{age}'] = {
                'genere': catalogue['genere'],
                'chaines': [catalogue['chaines'][i] for i in keep],
                'videos': [dict(v, c=index[v['c']], m=v['m'][:80]) for v in catalogue['videos'] if v['c'] in index],
            }
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--chaines', default='content/videos/chaines.yaml')
    ap.add_argument('--out', required=True)
    ap.add_argument('--par-age', help='dossier où écrire un catalogue par langue et par âge (fr-10.json…)')
    ap.add_argument('--par-chaine', type=int, default=100)  # 119 chaînes × 100 : ≈ 3,5 Mo, ≈ 1 Mo compressé
    a = ap.parse_args()
    channels = yaml.safe_load(open(a.chaines, encoding='utf8'))['chaines']
    if not os.environ.get('YOUTUBE_API_KEY'):
        print('YOUTUBE_API_KEY absente : catalogue vide.', file=sys.stderr)
        catalogue = {'genere': None, 'chaines': [], 'videos': []}
    else:
        catalogue = build(channels, a.par_chaine)
    os.makedirs(os.path.dirname(a.out) or '.', exist_ok=True)
    with open(a.out, 'w', encoding='utf8') as f:
        json.dump(catalogue, f, ensure_ascii=False, separators=(',', ':'))
    print(f"{len(catalogue['videos'])} vidéos de {len(catalogue['chaines'])} chaînes → {a.out}")
    if a.par_age:
        os.makedirs(a.par_age, exist_ok=True)
        for key, part in per_age(catalogue).items():
            with open(os.path.join(a.par_age, f'{key}.json'), 'w', encoding='utf8') as f:
                json.dump(part, f, ensure_ascii=False, separators=(',', ':'))
        print(f"catalogues par âge → {a.par_age}")


if __name__ == '__main__':
    main()
