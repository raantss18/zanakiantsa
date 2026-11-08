#!/usr/bin/env python3
"""Découverte de nouvelles chaînes éducatives (ADR 0068) : la liste blanche n'est pas figée.

Chaque semaine (GitHub Action « Découverte de chaînes »), ce script cherche sur YouTube (interface officielle Data API v3)
les recherches de content/videos/recherche.yaml, en recherche sûre (safeSearch=strict), vidéos intégrables seulement.
Les chaînes trouvées qui ne sont ni retenues (chaines.yaml) ni écartées (ecartees.yaml) sont examinées sur leurs 50
dernières vidéos, avec le même filtre que le catalogue (tool/videos.py : IA, shorts, directs, promotion…), puis notées.

Rien n'entre seul dans l'app : le script écrit un rapport Markdown (publié en ticket GitHub) ; une chaîne n'est ajoutée à
chaines.yaml qu'après relecture humaine (vraies personnes identifiées, ton, exactitude), et une chaîne refusée va dans
ecartees.yaml pour ne plus revenir.

  YOUTUBE_API_KEY=… python3 tool/videos_decouverte.py --out rapport.md [--max 40]
Coût : 100 unités par recherche (≈ 48 recherches) + ≈ 3 unités par chaîne examinée, sous les 10 000 par jour.
"""
import argparse
import collections
import datetime as dt
import os
import sys

import yaml

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from videos import get, made_by_ai, reject, seconds  # noqa: E402

EDUCATION = {'27', '28'}  # Éducation, Science et technologie
# Seuils pour qu'une chaîne soit proposée (les autres sont listées à part, sans être proposées).
MIN_KEPT = 20          # vidéos gardées par le filtre, sur les 50 dernières
MAX_SHORTS = 0.4       # part de shorts
MIN_EDUCATION = 0.5    # part des vidéos en catégorie Éducation ou Sciences
MAX_SILENCE_DAYS = 365


def search(q: str, lang: str, after: str) -> list[dict]:
    return get('search', part='snippet', q=q, type='video', maxResults=50, safeSearch='strict',
               videoEmbeddable='true', relevanceLanguage=lang, publishedAfter=after).get('items', [])


def examine(channel_id: str, lang: str) -> dict:
    ch = get('channels', part='snippet,statistics,contentDetails,status', id=channel_id).get('items', [])
    if not ch:
        return {}
    ch = ch[0]
    uploads = ch['contentDetails']['relatedPlaylists']['uploads']
    ids = [it['contentDetails']['videoId'] for it in
           get('playlistItems', part='contentDetails', playlistId=uploads, maxResults=50).get('items', [])]
    vids = get('videos', part='snippet,contentDetails,status,liveStreamingDetails', id=','.join(ids)).get('items', []) if ids else []
    why = collections.Counter(reject(v, {'langue': lang}) for v in vids)
    n = len(vids) or 1
    last = max((v['snippet']['publishedAt'][:10] for v in vids), default='')
    silence = (dt.date.today() - dt.date.fromisoformat(last)).days if last else 9999
    kept = why[None]
    shorts = why['short'] / n
    ai = sum(made_by_ai(v) for v in vids)
    edu = sum(v['snippet'].get('categoryId') in EDUCATION for v in vids) / n
    titles = [v['snippet']['title'] for v in vids if reject(v, {'langue': lang}) is None][:5]
    durations = sorted(seconds(v['contentDetails']['duration']) for v in vids)
    problems = []
    if ai:
        problems.append(f'{ai} vidéo(s) IA')
    if kept < MIN_KEPT:
        problems.append(f'{kept} vidéos gardées sur {len(vids)}')
    if shorts > MAX_SHORTS:
        problems.append(f'{shorts:.0%} de shorts')
    if edu < MIN_EDUCATION:
        problems.append(f'{edu:.0%} en Éducation/Sciences')
    if silence > MAX_SILENCE_DAYS:
        problems.append(f'rien depuis {last}')
    sn, stats = ch['snippet'], ch.get('statistics', {})
    return {
        'id': channel_id, 'nom': sn['title'], 'langue': lang, 'pseudo': sn.get('customUrl', ''),
        'abonnes': None if stats.get('hiddenSubscriberCount') else int(stats.get('subscriberCount', 0)),
        'videos': int(stats.get('videoCount', 0)), 'pour_enfants': ch.get('status', {}).get('madeForKids'),
        'gardees': kept, 'lues': len(vids), 'shorts': shorts, 'education': edu, 'dernier': last,
        'mediane': durations[len(durations) // 2] if durations else 0,
        'refus': {k: c for k, c in why.items() if k}, 'titres': titles,
        'description': ' '.join(sn.get('description', '').split())[:220], 'problemes': problems,
    }


def report(found: list[dict], hits: collections.Counter, queries: dict) -> str:
    ok = [c for c in found if not c['problemes']]
    ko = [c for c in found if c['problemes']]
    ok.sort(key=lambda c: (-hits[c['id']], -(c['abonnes'] or 0)))
    out = [f"# Chaînes candidates — {dt.date.today().isoformat()}", '',
           "Trouvées par la découverte hebdomadaire (ADR 0068). **Aucune n'est dans l'app** : à relire (vraies personnes "
           "identifiées, ton, exactitude, publicité), puis à ajouter à `content/videos/chaines.yaml` ou à "
           "`content/videos/ecartees.yaml`.", '',
           f"{sum(len(q) for q in queries.values())} recherches · {len(found)} chaînes examinées · "
           f"**{len(ok)} proposées** · {len(ko)} sous les seuils.", '', '## Proposées', '']
    for c in ok:
        subs = 'abonnés cachés' if c['abonnes'] is None else f"{c['abonnes']:,} abonnés".replace(',', ' ')
        out += [f"### {c['nom']} ({c['langue']}) — trouvée {hits[c['id']]} fois",
                f"- https://www.youtube.com/channel/{c['id']} {c['pseudo']} · {subs} · {c['videos']} vidéos · "
                f"dernière : {c['dernier']} · pour enfants : {c['pour_enfants']}",
                f"- {c['gardees']}/{c['lues']} gardées · shorts {c['shorts']:.0%} · Éducation/Sciences "
                f"{c['education']:.0%} · durée médiane {c['mediane'] // 60} min · refus : {c['refus'] or '-'}",
                f"- {c['description']}",
                *[f"  - « {t} »" for t in c['titres']], '']
    out += ['## Sous les seuils (pour mémoire)', '']
    out += [f"- {c['nom']} ({c['langue']}, {c['id']}) : {', '.join(c['problemes'])}" for c in ko]
    return '\n'.join(out) + '\n'


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--max', type=int, default=40, help='chaînes examinées au plus')
    ap.add_argument('--jours', type=int, default=365, help='vidéos publiées depuis')
    a = ap.parse_args()
    if not os.environ.get('YOUTUBE_API_KEY'):
        sys.exit('YOUTUBE_API_KEY absente.')
    queries = yaml.safe_load(open('content/videos/recherche.yaml', encoding='utf8'))
    known = {c['id'] for c in yaml.safe_load(open('content/videos/chaines.yaml', encoding='utf8'))['chaines']}
    known |= {c['id'] for c in yaml.safe_load(open('content/videos/ecartees.yaml', encoding='utf8'))['ecartees']}
    after = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=a.jours)).strftime('%Y-%m-%dT%H:%M:%SZ')
    hits, lang_of = collections.Counter(), {}
    for lang, qs in queries.items():
        for q in qs:
            for it in search(q, lang, after):
                cid = it['snippet']['channelId']
                if cid not in known:
                    hits[cid] += 1
                    lang_of.setdefault(cid, lang)
    found = []
    for cid, _ in hits.most_common(a.max):
        c = examine(cid, lang_of[cid])
        if c:
            found.append(c)
            print(f"{c['nom'][:40]:40} {c['langue']} gardées {c['gardees']}/{c['lues']} {c['problemes'] or 'proposée'}",
                  file=sys.stderr)
    open(a.out, 'w', encoding='utf8').write(report(found, hits, queries))
    print(f"{len(found)} chaînes examinées → {a.out}")


if __name__ == '__main__':
    main()
