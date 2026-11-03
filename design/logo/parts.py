"""Identité visuelle de Zanak'i Antsa (ADR 0027) : logo-texte « autocollant » et icône, générés en SVG.

Style inspiré (sans rien reprendre) des logos enfants que nous a montrés Antsa : lettres de couleurs différentes,
légèrement penchées et décalées, contour blanc épais d'autocollant et ombre, fond en nuage, points et étoiles autour.
Lettres : police Fredoka Gras (SIL OFL 1.1), converties en tracés (le SVG n'a besoin d'aucune police).
Usage (depuis design/logo/) : python3 -I parts.py ../../app/assets/fonts/Fredoka-Bold.ttf
"""
import math
import sys

from fontTools.pens.areaPen import AreaPen
from fontTools.pens.recordingPen import RecordingPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

# Palette de l'identité (aussi dans docs/design.md § 7).
TEAL, PINK, YELLOW, MAROON, PURPLE, INK, WHITE = '#1FA3B2', '#E6337A', '#F7B42C', '#8C2F57', '#5B4BA6', '#2A1F5C', '#FFFFFF'

font = TTFont(sys.argv[1] if len(sys.argv) > 1 else '../../app/assets/fonts/Fredoka-Bold.ttf')
glyphs = font.getGlyphSet()
cmap = font.getBestCmap()
upm = font['head'].unitsPerEm


def glyph(ch):
    """Tracé complet de la lettre, tracé sans ses trous (contours extérieurs seulement, pour le contour blanc et
    l'ombre : les boucles restent blanches), et chasse."""
    name = cmap[ord(ch)]
    rec = RecordingPen()
    glyphs[name].draw(rec)
    contours, cur = [], []
    for op in rec.value:
        cur.append(op)
        if op[0] in ('closePath', 'endPath'):
            contours.append(cur)
            cur = []
    def area(c):
        a = AreaPen(glyphs)
        for op, args in c:
            getattr(a, op)(*args)
        return a.value
    def svg(cs):
        pen = SVGPathPen(glyphs)
        for c in cs:
            for op, args in c:
                getattr(pen, op)(*args)
        return pen.getCommands()
    if not contours:
        return '', '', glyphs[name].width
    outer_sign = math.copysign(1, max((area(c) for c in contours), key=abs))
    outer = [c for c in contours if math.copysign(1, area(c)) == outer_sign]
    return svg(contours), svg(outer), glyphs[name].width


def word(text, x, y, size, colors, tilt=6.0, jitter=0.06, track=0.02):
    """Une rangée de lettres posées sur la ligne [y], chacune de sa couleur, penchée et décalée tour à tour.
    Rend trois couches : ombre, contour blanc, couleur (l'ordre fait l'effet autocollant)."""
    k = size / upm
    shadow, outline, fill = [], [], []
    cx = x
    for i, ch in enumerate(text):
        d, d_out, adv = glyph(ch)
        w = adv * k
        if d:
            angle = tilt * (1 if i % 2 == 0 else -1) * (0.6 + 0.4 * ((i * 7) % 3) / 2)
            dy = size * jitter * (1 if (i * 5) % 3 == 0 else -1 if (i * 5) % 3 == 1 else 0)
            t = f'translate({cx + w / 2:.1f} {y + dy:.1f}) rotate({angle:.1f}) translate({-w / 2:.1f} 0) scale({k:.4f} {-k:.4f})'
            shadow.append(f'<path d="{d_out}" transform="translate(7 9) {t}" fill="{INK}" stroke="{INK}" stroke-width="{2 * 20 / k:.0f}" stroke-linejoin="round"/>')
            outline.append(f'<path d="{d_out}" transform="{t}" fill="{WHITE}" stroke="{WHITE}" stroke-width="{2 * 20 / k:.0f}" stroke-linejoin="round"/>')
            color = colors[i % len(colors)]
            fill.append(f'<path d="{d}" transform="{t}" fill="{color}"/>')
            # Points blancs dans les lettres larges (comme les lettres « à ampoules ») : deux petits ronds,
            if ch in "ZkntAN" and adv > 480:  # lettres sans trou : les points ne tombent pas dans une boucle
                fill.append(f'<g transform="{t}"><circle cx="{adv * 0.32:.0f}" cy="{upm * 0.30:.0f}" r="34" fill="{WHITE}" opacity="0.9"/>'
                            f'<circle cx="{adv * 0.62:.0f}" cy="{upm * 0.42:.0f}" r="24" fill="{WHITE}" opacity="0.9"/></g>')
        cx += w * (1 + track)
    return ''.join(shadow), ''.join(outline), ''.join(fill), cx - x


def star(cx, cy, r, fill, points=5):
    pts = []
    for n in range(points * 2):
        rr = r if n % 2 == 0 else r * 0.45
        a = -math.pi / 2 + n * math.pi / points
        pts.append(f'{cx + rr * math.cos(a):.1f},{cy + rr * math.sin(a):.1f}')
    return f'<polygon points="{" ".join(pts)}" fill="{fill}" stroke="{fill}" stroke-width="3" stroke-linejoin="round"/>'


def sparkle(cx, cy, r, fill):
    q = r * 0.2
    return (f'<path d="M{cx} {cy - r} Q{cx + q} {cy - q} {cx + r} {cy} Q{cx + q} {cy + q} {cx} {cy + r} '
            f'Q{cx - q} {cy + q} {cx - r} {cy} Q{cx - q} {cy - q} {cx} {cy - r} Z" fill="{fill}"/>')


def cloud(circles, fill, grow=0):
    return ''.join(f'<circle cx="{x}" cy="{y}" r="{r + grow}" fill="{fill}"/>' for x, y, r in circles)


def wordmark():
    """Logo-texte : « Zanak'i » au-dessus de « Antsa », sur un nuage violet bordé de blanc, étoiles et points."""
    blob = [(250, 290, 200), (430, 210, 190), (600, 220, 190), (760, 300, 190), (560, 380, 210), (360, 390, 190), (180, 330, 150), (840, 360, 140)]
    s1, o1, f1, w1 = word("Zanak'i", 0, 0, 190, [TEAL, YELLOW, PINK, YELLOW, TEAL, PINK, YELLOW])
    s2, o2, f2, w2 = word('Antsa', 0, 0, 250, [PINK, YELLOW, TEAL, PINK, YELLOW], tilt=5)
    line1 = f'<g transform="translate({500 - w1 / 2:.1f} 255)">{s1}{o1}{f1}</g>'
    line2 = f'<g transform="translate({500 - w2 / 2:.1f} 480)">{s2}{o2}{f2}</g>'
    deco = (star(120, 150, 26, YELLOW) + star(905, 170, 22, YELLOW) + sparkle(860, 520, 22, WHITE) + sparkle(160, 520, 18, WHITE)
            + ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{WHITE}" opacity="0.85"/>'
                      for x, y, r in [(230, 160, 9), (790, 150, 8), (930, 300, 10), (90, 300, 8), (700, 545, 9), (300, 548, 7)]))
    ring = ''.join(f'<path d="{d}" fill="none" stroke="{PURPLE}" stroke-width="8" stroke-linecap="round"/>'
                   for d in ['M40 260 Q30 330 70 400', 'M960 250 Q975 320 950 390', 'M420 30 Q500 18 580 30'])
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 600">{ring}{cloud(blob, WHITE, 22)}{cloud(blob, PURPLE)}'
            f'{deco}{line1}{line2}</svg>\n')


def monogram(scale=1.0, bg=True, mono=False, empty=False):
    """Icône : « Za » sur un nuage violet, sur fond jaune ; [mono] : silhouette blanche (icônes à thème)."""
    s, o, f, w = word('Za', 0, 0, 260, [TEAL, PINK], tilt=7)
    blob = [(200, 250, 120), (310, 220, 120), (300, 320, 120), (190, 330, 100), (256, 270, 130)]
    if mono:
        f_white = f.replace(TEAL, WHITE).replace(PINK, WHITE)
        body = f'<g transform="translate({256 - w / 2:.1f} 345)">{f_white}</g>'
    else:
        body = (cloud(blob, WHITE, 14) + cloud(blob, PURPLE) + star(390, 130, 26, YELLOW) + sparkle(120, 150, 20, WHITE)
                + f'<g transform="translate({256 - w / 2:.1f} 345)">{s}{o}{f}</g>')
    g = '' if empty else f'<g transform="translate(256 256) scale({scale}) translate(-256 -256)">{body}</g>'
    back = (f'<rect width="512" height="512" fill="{YELLOW}"/>'
            + ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{WHITE}" opacity="0.45"/>' for x, y, r in
                      [(70, 80, 12), (450, 70, 9), (460, 440, 14), (60, 450, 10), (400, 260, 7), (110, 300, 6)])) if bg else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">{back}{g}</svg>\n'


def rounded(svg):
    return svg.replace('<rect width="512" height="512"', '<rect width="512" height="512" rx="112"', 1)


files = {
    'wordmark.svg': wordmark(),
    'logo.svg': rounded(monogram(scale=0.95)),               # icône classique (avant Android 8) et petit logo
    'foreground.svg': monogram(scale=0.66, bg=False),         # icône adaptative : dans la zone sûre de 66/108
    'background.svg': monogram(bg=True, empty=True),         # fond jaune à points seulement
    'monochrome.svg': monogram(scale=0.66, bg=False, mono=True),
}
for name, text in files.items():
    open(name, 'w').write(text)
print('écrit', ', '.join(files))
