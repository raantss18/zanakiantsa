#!/usr/bin/env python3
"""Catalogue des vidéos éducatives (ADR 0068) : les vidéos des chaînes de content/videos/chaines.yaml, filtrées.

Passe par l'interface officielle YouTube Data API v3 (clé dans la variable YOUTUBE_API_KEY, gardée en secret GitHub,
jamais dans Git). Ne télécharge aucune vidéo : seulement leurs identifiants, titres et durées ; l'app les lit ensuite avec
le lecteur officiel de YouTube.

Garde une vidéo si elle est publique, intégrable, sans restriction d'âge, pas en direct, et dure de 1 à 60 min (pas de
limite plus courte : les vidéos longues sont permises à tout âge, ADR 0068). Coût : ≈ 10 unités de quota par chaîne (10 000 par jour offertes).

  YOUTUBE_API_KEY=… python3 tool/videos.py --out site/videos.json [--par-chaine 200]
Sans clé : écrit un catalogue vide (l'app affiche alors « pas encore de vidéos »), sans échouer.
"""
import argparse
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


def keep(v: dict) -> bool:
    st, cd, sn = v.get('status', {}), v.get('contentDetails', {}), v.get('snippet', {})
    return (
        not made_by_ai(v)
        and st.get('privacyStatus') == 'public'
        and st.get('embeddable', False)
        and cd.get('contentRating', {}).get('ytRating') != 'ytAgeRestricted'
        and sn.get('liveBroadcastContent', 'none') == 'none'
        and 60 <= seconds(cd.get('duration')) <= 3600
    )


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
        before, ai = len(videos), 0
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
        must = (c.get('titre_contient') or '').lower()
        for i in range(0, len(vids), 50):
            batch = [v for v in vids[i:i + 50] if v not in excluded]
            if not batch:
                continue
            for v in get('videos', part='snippet,contentDetails,status', id=','.join(batch)).get('items', []):
                ai += made_by_ai(v)
                if not keep(v):
                    continue
                sn = v['snippet']
                if must and must not in sn['title'].lower():
                    continue
                # Langue de la vidéo, quand YouTube la connaît : celle de la chaîne (NASA Space Place publie aussi en espagnol).
                spoken = sn.get('defaultAudioLanguage') or sn.get('defaultLanguage') or ''
                if spoken and not spoken.lower().startswith(c['langue']):
                    continue
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
        print(f"{c['nom'][:40]:40} {c['langue']} {str(c['ages']):8} lues {len(vids):4}  gardées {len(mine):4}  ≤10 min {short:4}  IA écartées {ai}",
              file=sys.stderr)
    return {'genere': dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%dT%H:%MZ'), 'chaines': out_channels, 'videos': videos}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--chaines', default='content/videos/chaines.yaml')
    ap.add_argument('--out', required=True)
    ap.add_argument('--par-chaine', type=int, default=200)
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


if __name__ == '__main__':
    main()
