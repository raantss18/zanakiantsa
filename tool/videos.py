#!/usr/bin/env python3
"""Catalogue des vidéos éducatives (ADR 0068) : les vidéos des chaînes de content/videos/chaines.yaml, filtrées.

Passe par l'interface officielle YouTube Data API v3 (clé dans la variable YOUTUBE_API_KEY, gardée en secret GitHub,
jamais dans Git). Ne télécharge aucune vidéo : seulement leurs identifiants, titres et durées ; l'app les lit ensuite avec
le lecteur officiel de YouTube.

Garde une vidéo si elle est publique, intégrable, sans restriction d'âge, pas en direct, et dure de 1 à 60 min (l'app
applique ensuite la limite de 10 min jusqu'au collège). Coût : ≈ 10 unités de quota par chaîne (10 000 par jour offertes).

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


def keep(v: dict) -> bool:
    st, cd, sn = v.get('status', {}), v.get('contentDetails', {}), v.get('snippet', {})
    return (
        st.get('privacyStatus') == 'public'
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
    ids = [c['id'] for c in channels]
    uploads = {}
    for i in range(0, len(ids), 50):
        for item in get('channels', part='contentDetails', id=','.join(ids[i:i + 50]), maxResults=50).get('items', []):
            uploads[item['id']] = item['contentDetails']['relatedPlaylists']['uploads']
    for c in channels:
        if c['id'] not in uploads:
            print(f"chaîne introuvable, ignorée : {c['nom']} ({c['id']})", file=sys.stderr)
            continue
        index = len(out_channels)
        out_channels.append({k: c[k] for k in ('id', 'nom', 'langue', 'ages', 'domaines')})
        vids, token = [], None
        while len(vids) < per_channel:
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
