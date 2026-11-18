#!/usr/bin/env python3
"""Fabrique les contours de cartes de l'app à partir de Natural Earth (domaine public).

Source : https://github.com/nvkelso/natural-earth-vector, étiquette v5.1.2, dossier geojson/ :
  ne_110m_admin_0_countries.geojson, ne_50m_admin_0_countries.geojson, ne_50m_rivers_lake_centerlines.geojson

Usage : python3 -I tool/cartes.py <dossier des geojson> app/assets/carte

Sortie :
  monde.json  : tous les pays au 1:110 M, au dixième de degré (cartes du monde) ;
  detail.json : pays au 1:50 M dans les zones zoomées (Europe, Caraïbes, océan Indien, Moyen-Orient, Asie du Sud-Est),
                au cinquantième de degré, et quatre grands fleuves de France.
Chaque anneau est une liste plate [lon0, lat0, lon1, lat1, …] en entiers (degrés × échelle).
"""
import json
import sys
from pathlib import Path

# Zones zoomées : [lon min, lat min, lon max, lat max], un peu plus larges que les vues de l'app.
ZONES = [(-30, 25, 45, 72), (-95, -10, -40, 30), (25, -35, 80, 20), (25, 5, 70, 40), (90, -12, 135, 30)]
FLEUVES = {'Loire', 'Seine', 'Rhône', 'Garonne'}


def dp(points, tol):
    """Douglas-Peucker itératif."""
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        a, b = stack.pop()
        (ax, ay), (bx, by) = points[a], points[b]
        dx, dy = bx - ax, by - ay
        n = (dx * dx + dy * dy) ** 0.5
        best, idx = 0.0, -1
        for i in range(a + 1, b):
            px, py = points[i]
            d = abs(dy * (px - ax) - dx * (py - ay)) / n if n else ((px - ax) ** 2 + (py - ay) ** 2) ** 0.5
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            keep[idx] = True
            stack += [(a, idx), (idx, b)]
    return [p for p, k in zip(points, keep) if k]


def ring(coords, tol, scale, closed=True):
    pts = dp([(x, y) for x, y in coords], tol)
    flat, last = [], None
    for x, y in pts:
        q = (round(x * scale), round(y * scale))
        if q != last:
            flat += q
            last = q
    return flat if len(flat) >= (6 if closed else 4) else None


def polygons(geom):
    return geom['coordinates'] if geom['type'] == 'MultiPolygon' else [geom['coordinates']]


def bbox(geom):
    xs = [x for poly in polygons(geom) for x, _ in poly[0]]
    ys = [y for poly in polygons(geom) for _, y in poly[0]]
    return min(xs), min(ys), max(xs), max(ys)


def overlaps(b, z):
    return b[0] <= z[2] and b[2] >= z[0] and b[1] <= z[3] and b[3] >= z[1]


def countries(path, tol, scale, keep=lambda g: True):
    out = {}
    for f in json.loads(Path(path).read_text())['features']:
        code, g = f['properties']['ADM0_A3'], f['geometry']
        if not keep(g):
            continue
        # Les trous (lacs) sont ignorés : seul l'anneau extérieur compte.
        rings = [r for poly in polygons(g) if (r := ring(poly[0], tol, scale))]
        if rings:
            out.setdefault(code, []).extend(rings)
    return out


def main(src, dst):
    src, dst = Path(src), Path(dst)
    dst.mkdir(parents=True, exist_ok=True)
    monde = {'echelle': 10, 'pays': countries(src / 'ne_110m_admin_0_countries.geojson', 0.15, 10)}
    detail = {'echelle': 50, 'pays': countries(src / 'ne_50m_admin_0_countries.geojson', 0.04, 50,
                                               lambda g: any(overlaps(bbox(g), z) for z in ZONES))}
    fleuves = {}
    for f in json.loads((src / 'ne_50m_rivers_lake_centerlines.geojson').read_text())['features']:
        name = f['properties'].get('name')
        if name in FLEUVES and f['properties'].get('featurecla') == 'River':
            g = f['geometry']
            lines = g['coordinates'] if g['type'] == 'MultiLineString' else [g['coordinates']]
            fleuves.setdefault(name, []).extend(r for l in lines if (r := ring(l, 0.02, 50, closed=False)))
    detail['fleuves'] = fleuves
    for name, data in (('monde.json', monde), ('detail.json', detail)):
        (dst / name).write_text(json.dumps(data, separators=(',', ':'), ensure_ascii=False))
        print(name, (dst / name).stat().st_size, 'octets,', len(data['pays']), 'pays')


if __name__ == '__main__':
    main(*sys.argv[1:3])
