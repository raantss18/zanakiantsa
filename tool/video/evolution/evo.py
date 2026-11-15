# « De l'origine des versions » : la vidéo de l'évolution de Zanak'i Antsa (1.0.0 → 1.1.7), style carnet de naturaliste.
# Chaque image est calculée ici (PIL) et envoyée à ffmpeg ; aucune image ni musique reprise. Captures : vraies versions sur
# l'émulateur. Voix : Piper (fr_FR-siwis). Musique : son/musique.py (calculée).
import math, os, random, subprocess, sys, wave
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps, ImageEnhance

E = os.path.dirname(os.path.abspath(__file__))
S = os.path.dirname(E)
DEMO = os.path.join(S, 'demo')
FONTS = os.path.expanduser('~/GitHub/zanakiantsa/app/assets/fonts')
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(E, 'evolution.mp4')
PREVIEW = os.environ.get('PREVIEW')  # « 12.5,40 » : n'écrit que ces instants en PNG
W, H, FPS = 1080, 1920, 30

PAPER = (244, 236, 216)
INK = (59, 47, 42)
SEPIA = (112, 84, 58)
ACCENT = (122, 31, 162)   # violet du logo, pour les numéros d'étape
GREEN = (29, 122, 51)


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)


HAND = lambda s: font('PlaywriteFR-Regular.ttf', s)
TITLE = lambda s: font('Fredoka-Bold.ttf', s)
BODY = lambda s: font('Andika-Bold.ttf', s)


def dur(name):
    with wave.open(os.path.join(E, 'voix', name + '.wav')) as w:
        return w.getnframes() / w.getframerate()


# ---------- papier ----------
random.seed(7)
paper = Image.new('RGB', (W, H), PAPER)
pd = ImageDraw.Draw(paper)
for _ in range(9000):  # grain
    x, y = random.randrange(W), random.randrange(H)
    c = random.randint(-14, 8)
    pd.point((x, y), fill=tuple(max(0, min(255, v + c)) for v in PAPER))
for y in range(150, H, 64):  # lignes très pâles du carnet
    pd.line([(70, y), (W - 70, y)], fill=(230, 220, 196), width=2)
pd.line([(110, 0), (110, H)], fill=(222, 170, 160), width=3)  # marge
vign = Image.new('L', (W, H), 0)
vd = ImageDraw.Draw(vign)
for i in range(60):
    vd.rectangle([i * 4, i * 4, W - i * 4, H - i * 4], outline=int(120 * (1 - i / 60)))
paper = Image.composite(Image.new('RGB', (W, H), (205, 188, 152)), paper, vign.filter(ImageFilter.GaussianBlur(40)))


# ---------- outils ----------
def ease(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def text_layer(txt, f, fill=INK, maxw=None):
    """Texte (avec retours à la ligne si maxw) rendu sur un calque transparent."""
    lines = []
    for para in txt.split('\n'):
        if maxw is None:
            lines.append(para)
            continue
        cur = ''
        for w in para.split(' '):
            t = (cur + ' ' + w).strip()
            if f.getlength(t) <= maxw:
                cur = t
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
    asc, desc = f.getmetrics()
    lh = int((asc + desc) * 1.12)
    wmax = int(max(f.getlength(l) for l in lines)) + 8
    im = Image.new('RGBA', (wmax, lh * len(lines) + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i, l in enumerate(lines):
        d.text((0, i * lh), l, font=f, fill=fill)
    return im


def reveal(base, layer, xy, p, mode='wipe'):
    """Écrit [layer] à [xy] : de gauche à droite (comme à la plume) ou en fondu."""
    if p <= 0:
        return
    if mode == 'wipe':
        w = int(layer.width * ease(p))
        if w <= 0:
            return
        base.alpha_composite(layer.crop((0, 0, w, layer.height)), xy)
    else:
        l = layer.copy()
        l.putalpha(l.getchannel('A').point(lambda a: int(a * ease(p))))
        base.alpha_composite(l, xy)


def center_x(layer):
    return (W - layer.width) // 2


def phone(shot_path, box_h, crop_bottom=0):
    """Une capture dans un cadre de téléphone ou de tablette, et sa version « gravure » sépia (figée)."""
    im = Image.open(shot_path).convert('RGB')
    if crop_bottom:
        im = im.crop((0, 0, im.width, im.height - crop_bottom))
    sc = box_h / im.height
    im = im.resize((int(im.width * sc), box_h), Image.LANCZOS)
    pad = 22
    frame = Image.new('RGBA', (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, frame.width - 1, frame.height - 1], radius=48, fill=(40, 34, 32, 255))
    mask = Image.new('L', im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=30, fill=255)
    color = frame.copy()
    color.paste(im, (pad, pad), mask)
    g = ImageOps.grayscale(im)
    g = ImageOps.autocontrast(g, cutoff=2)
    sep = ImageOps.colorize(g, black=(58, 40, 28), white=(246, 236, 212))
    # Traits de gravure : hachures légères.
    hatch = Image.new('L', im.size, 0)
    hd = ImageDraw.Draw(hatch)
    for k in range(-im.height, im.width, 9):
        hd.line([(k, 0), (k + im.height, im.height)], fill=30, width=1)
    sep = Image.composite(Image.new('RGB', im.size, (80, 60, 40)), sep, hatch)
    engraved = frame.copy()
    engraved.paste(sep, (pad, pad), mask)
    shadow = Image.new('RGBA', (frame.width + 60, frame.height + 60), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([30, 40, frame.width + 30, frame.height + 40], radius=52, fill=(60, 40, 20, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    return engraved, color, shadow


# ---------- frise de l'évolution (en bas) ----------
VERSIONS = ['1.0.0', '1.0.1', '1.0.2', '1.0.3', '1.0.4', '1.0.5', '1.0.6', '1.0.7', '1.0.8', '1.0.9',
            '1.1.0', '1.1.1', '1.1.2', '1.1.3', '1.1.4', '1.1.5', '1.1.6', '1.1.7']
SMALL = BODY(26)


def frieze(base, upto, p=1.0):
    """La marche du progrès : un point par version, la ligne avance jusqu'à [upto] (indice)."""
    y = H - 150
    x0, x1 = 150, W - 110
    d = ImageDraw.Draw(base)
    step = (x1 - x0) / (len(VERSIONS) - 1)
    d.line([(x0, y), (x1, y)], fill=(200, 184, 150), width=4)
    reach = x0 + step * upto * ease(p) if upto > 0 else x0
    d.line([(x0, y), (reach, y)], fill=SEPIA, width=6)
    for i, v in enumerate(VERSIONS):
        x = x0 + i * step
        on = x <= reach + 1
        r = 11 if v in ('1.0.0', '1.0.6', '1.1.1', '1.1.5', '1.1.7') else 7
        d.ellipse([x - r, y - r, x + r, y + r], fill=SEPIA if on else PAPER, outline=SEPIA, width=3)
    for v, lab in (('1.0.0', '1.0.0'), ('1.1.7', '1.1.7')):
        i = VERSIONS.index(v)
        tw = SMALL.getlength(lab)
        d.text((x0 + i * step - tw / 2, y + 22), lab, font=SMALL, fill=SEPIA)


# ---------- scènes ----------
class Scene:
    def __init__(self, name, voice, minimum=0.0, pad=1.4):
        self.name, self.voice = name, voice
        self.d = max(minimum, (dur(voice) if voice else 0) + pad)

    def draw(self, img, t):
        raise NotImplementedError


class Title(Scene):
    def __init__(self):
        super().__init__('titre', 'titre', 11.0, 1.6)
        self.l1 = text_layer("De l'origine", HAND(92), INK)
        self.l2 = text_layer('des versions', HAND(92), INK)
        self.l3 = text_layer("L'évolution de", TITLE(64), SEPIA)
        self.logo = Image.open(os.path.join(E, 'logo.png')).convert('RGBA')
        self.l4 = text_layer('1.0.0  →  1.1.7', BODY(84), ACCENT)
        self.l5 = text_layer('Carnet de naturaliste, novembre 2026', HAND(36), SEPIA)

    def draw(self, img, t):
        reveal(img, self.l1, (center_x(self.l1), 300), t / 1.6)
        reveal(img, self.l2, (center_x(self.l2), 430), (t - 1.0) / 1.6)
        d = ImageDraw.Draw(img)
        p = ease((t - 2.4) / 0.8)
        if p > 0:
            d.line([(W / 2 - 260 * p, 600), (W / 2 + 260 * p, 600)], fill=SEPIA, width=3)
        reveal(img, self.l3, (center_x(self.l3), 690), (t - 3.0) / 0.8, 'fade')
        if t > 3.6:
            p = ease((t - 3.6) / 1.0)
            lg = self.logo.resize((int(self.logo.width * (0.9 + 0.1 * p)), int(self.logo.height * (0.9 + 0.1 * p))))
            reveal(img, lg, (center_x(lg), 790), p, 'fade')
        reveal(img, self.l4, (center_x(self.l4), 1290), (t - 5.0) / 1.2)
        reveal(img, self.l5, (center_x(self.l5), 1440), (t - 6.2) / 1.2)
        frieze(img, 17, (t - 5.0) / 4.0)


class Tree(Scene):
    """L'arbre de la vie, à la manière du croquis de Darwin (« I think », 1837) : il pousse branche par branche."""

    def __init__(self):
        super().__init__('arbre', 'arbre', 8.0, 1.4)
        self.head = text_layer('Je pense', HAND(70), INK)
        random.seed(3)
        self.branches = []  # (x0, y0, x1, y1, profondeur, étiquette)
        root = (W / 2, 1600)

        def grow(x, y, ang, length, depth):
            x2, y2 = x + length * math.cos(ang), y - length * math.sin(ang)
            self.branches.append((x, y, x2, y2, depth))
            if depth < 4:
                for da in (-0.42 - random.random() * 0.18, 0.38 + random.random() * 0.2):
                    grow(x2, y2, ang + da, length * (0.68 + random.random() * 0.08), depth + 1)

        grow(root[0], root[1], math.pi / 2, 330, 0)
        tips = [b for b in self.branches if b[4] == 4]
        tips.sort(key=lambda b: b[2])
        # Les cinq espèces, réparties sur la couronne ; les autres bouts de branche restent des points.
        named = {0: '1.0.0', len(tips) // 4: '1.0.6', len(tips) // 2: '1.1.1', 3 * len(tips) // 4: '1.1.5', len(tips) - 1: '1.1.7'}
        self.tips = [(b[2], b[3], named.get(i, '')) for i, b in enumerate(tips)]
        self.lab = {n: text_layer(n, BODY(30), SEPIA) for _, _, n in self.tips if n}
        self.cap = text_layer("Chaque mise à jour, une branche nouvelle.", HAND(40), SEPIA, maxw=860)

    def draw(self, img, t):
        reveal(img, self.head, (180, 210), t / 1.2)
        d = ImageDraw.Draw(img)
        grow_t = 5.0
        for (x, y, x2, y2, depth) in self.branches:
            s = depth / 5 * grow_t
            p = ease((t - 0.6 - s) / (grow_t / 5))
            if p <= 0:
                continue
            d.line([(x, y), (x + (x2 - x) * p, y + (y2 - y) * p)], fill=INK, width=max(2, 12 - depth * 2))
        for (x, y, n) in self.tips:
            p = ease((t - 5.4) / 0.8)
            if not n:
                if p > 0:
                    d.ellipse([x - 5, y - 5, x + 5, y + 5], fill=SEPIA)
                continue
            if p > 0:
                r = 9
                d.ellipse([x - r, y - r, x + r, y + r], fill=ACCENT if n == '1.1.7' else SEPIA)
                lab = self.lab[n]
                reveal(img, lab, (int(x - lab.width / 2), int(y - 52)), p, 'fade')
        reveal(img, self.cap, (center_x(self.cap), 1690), (t - 2.0) / 1.5)


class Species(Scene):
    """Une planche : nom latin, version, capture figée (gravure) qui s'anime en couleurs, caractères nouveaux."""

    def __init__(self, voice, plate, latin, versions, shots, traits, upto, prev=None):
        super().__init__(voice, voice, 9.0, 1.4)
        self.n = text_layer(f'Planche {plate}', HAND(40), SEPIA)
        self.latin = text_layer(latin, HAND(76), INK)
        self.ver = text_layer(versions, BODY(46), ACCENT)
        self.box_h = 900
        self.shots = [phone(p, self.box_h, cb) for p, cb in shots]
        self.prev = prev
        self.traits = [text_layer('— ' + tr, BODY(42), INK, maxw=880) for tr in traits]
        self.upto = upto

    def draw(self, img, t):
        reveal(img, self.n, (150, 110), t / 0.6, 'fade')
        reveal(img, self.latin, (150, 160), (t - 0.2) / 1.2)
        reveal(img, self.ver, (150, 290), (t - 0.8) / 0.8, 'fade')
        # Capture : d'abord figée (gravure), puis la vie revient (couleurs) ; une seconde capture prend la suite.
        n = len(self.shots)
        seg = (self.d - 1.0) / n
        k = min(n - 1, int(max(0, t - 0.6) // seg)) if n > 1 else 0
        engraved, color, shadow = self.shots[k]
        local = t - 0.6 - k * seg
        life = ease((local - 0.8) / 1.6)
        frame = Image.blend(engraved, color, life)
        zoom = 1.0 + 0.025 * ease(local / seg)
        fw, fh = int(frame.width * zoom), int(frame.height * zoom)
        frame = frame.resize((fw, fh), Image.BILINEAR)
        x, y = (W - fw) // 2, 400 + (self.box_h + 44 - fh) // 2
        # L'espèce d'avant se fond dans la nouvelle (évolution), au début de la planche.
        if k == 0 and self.prev is not None and t < 1.2:
            pe, pc, _ = self.prev
            old = pc.resize((int(pc.width * self.box_h / (pc.height - 44)), self.box_h + 44)) if False else pc
            ox, oy = (W - old.width) // 2, 400
            o = old.copy()
            o.putalpha(o.getchannel('A').point(lambda a: int(a * (1 - ease(t / 1.2)))))
            img.alpha_composite(o, (ox, oy))
        a = ease(local / 0.6) if (k > 0 or self.prev is None or t >= 0.5) else ease(t / 1.2)
        sh = shadow.copy()
        sh.putalpha(sh.getchannel('A').point(lambda v: int(v * a)))
        img.alpha_composite(sh, (x - 30, y - 30))
        f2 = frame.copy()
        f2.putalpha(f2.getchannel('A').point(lambda v: int(v * a)))
        img.alpha_composite(f2, (x, y))
        # Étiquette de spécimen.
        d = ImageDraw.Draw(img)
        if life > 0.95:
            d.text((x + fw - 40, y + fh - 10), '', font=SMALL, fill=SEPIA)
        ty = 1390
        for i, tr in enumerate(self.traits):
            reveal(img, tr, (150, ty), (t - 2.2 - i * 1.4) / 1.0)
            ty += tr.height + 10
        frieze(img, self.upto, (t - 0.3) / 2.0)

    @property
    def last(self):
        return self.shots[-1]


class Steps(Scene):
    """Guide en étapes : capture à gauche du texte de l'étape, numérotée, au rythme de la voix."""

    def __init__(self, voice, title, steps):
        super().__init__(voice, voice, 10.0, 1.6)
        self.title = text_layer(title, TITLE(78), INK)
        self.steps = []
        total = sum(s[2] for s in steps)
        t = 1.0
        for i, (path, txt, weight, cb) in enumerate(steps):
            span = (self.d - 1.6) * weight / total
            self.steps.append((t, span, phone(path, 1040, cb), text_layer(txt, BODY(46), INK, maxw=740), i + 1))
            t += span
        self.num = {i + 1: text_layer(str(i + 1), TITLE(64), (255, 255, 255)) for i in range(len(steps))}

    def draw(self, img, t):
        reveal(img, self.title, (center_x(self.title), 110), t / 0.9)
        d = ImageDraw.Draw(img)
        cur = None
        for st in self.steps:
            if t >= st[0]:
                cur = st
        # Petits ronds de progression des étapes.
        n = len(self.steps)
        for i in range(n):
            x = W / 2 + (i - (n - 1) / 2) * 56
            on = cur is not None and i + 1 <= cur[4]
            d.ellipse([x - 14, 238, x + 14, 266], fill=ACCENT if on else PAPER, outline=ACCENT, width=3)
        if cur is None:
            return
        start, span, (eng, col, shadow), txt, num = cur
        local = t - start
        a = ease(local / 0.45)
        frame = Image.blend(eng, col, ease((local - 0.15) / 0.6))
        x, y = (W - frame.width) // 2, 300
        sh = shadow.copy()
        sh.putalpha(sh.getchannel('A').point(lambda v: int(v * a)))
        img.alpha_composite(sh, (x - 30, y - 30))
        f2 = frame.copy()
        f2.putalpha(f2.getchannel('A').point(lambda v: int(v * a)))
        img.alpha_composite(f2, (x, y))
        # Numéro et texte de l'étape.
        cy = y + frame.height + 56
        d.ellipse([130, cy, 230, cy + 100], fill=ACCENT)
        nl = self.num[num]
        img.alpha_composite(nl, (180 - nl.width // 2, cy + 12))
        reveal(img, txt, (260, cy + 6), (local - 0.1) / 0.7)


class End(Scene):
    def __init__(self):
        super().__init__('fin', 'fin', 9.5, 2.2)
        self.l1 = text_layer("L'évolution continue.", HAND(70), INK)
        self.l2 = text_layer('Mettez à jour aujourd’hui', TITLE(84), ACCENT, maxw=900)
        self.l3 = text_layer('Espace parent  ›  Mettre à jour', BODY(52), INK)
        self.icon = Image.open(os.path.join(E, 'icone.png')).convert('RGBA')
        self.l4 = text_layer('raantss18.github.io/zanakiantsa', BODY(46), SEPIA)
        self.l5 = text_layer('Gratuite · sans publicité · hors ligne', HAND(40), SEPIA)

    def draw(self, img, t):
        reveal(img, self.l1, (center_x(self.l1), 260), t / 1.4)
        reveal(img, self.l2, (center_x(self.l2), 470), (t - 1.0) / 1.0, 'fade')
        reveal(img, self.l3, (center_x(self.l3), 720), (t - 2.0) / 1.0)
        p = ease((t - 2.8) / 1.0)
        if p > 0:
            ic = self.icon.resize((int(300 * (0.85 + 0.15 * p)),) * 2)
            reveal(img, ic, (center_x(ic), 880), p, 'fade')
        reveal(img, self.l4, (center_x(self.l4), 1290), (t - 3.8) / 1.0)
        reveal(img, self.l5, (center_x(self.l5), 1400), (t - 4.6) / 1.2)
        frieze(img, 17, 1.0)


def build():
    def ev(v):
        return os.path.join(E, f'{v}-accueil.png')
    primus = Species('primus', 'I', 'Zanakius primus', 'Version 1.0.0 · 7 novembre 2026', [(ev('1.0.0'), 0)],
                     ['Dès 5 ans, jusqu’au collège', 'Vérifie d’abord ce qu’il faut savoir', 'Hors ligne, sans pub, sans compte'], 0)
    mundi = Species('mundi', 'II', 'Zanakius mundi', 'Versions 1.0.1 → 1.0.9', [(ev('1.0.6'), 0), (os.path.join(E, '1.0.6-explorer.png'), 0)],
                    ['Français ou anglais', 'Mondes, livres et leçons selon l’âge', 'Vidéos éducatives choisies une par une'], 9, prev=primus.last)
    memor = Species('memor', 'III', 'Zanakius memor', 'Versions 1.1.0 → 1.1.4', [(ev('1.1.1'), 0)],
                    ['« À revoir » juste avant d’oublier', 'Défi du jour et série de jours', 'Bilan de la semaine pour les parents'], 14, prev=mundi.last)
    faber = Species('faber', 'IV', 'Zanakius faber', 'Versions 1.1.5 → 1.1.6', [(os.path.join(E, 'fleur.png'), 0), (os.path.join(DEMO, 'c2.png'), 0)],
                    ['Programmes libres : le robot dessine et joue', 'Onze défis du robot'], 16, prev=memor.last)
    illus = Species('illustratus', 'V', 'Zanakius illustratus', 'Version 1.1.7 · aujourd’hui', [(os.path.join(DEMO, 't1.png'), 0), (os.path.join(DEMO, 'm1.png'), 170)],
                    ['« Reprendre » là où l’on s’est arrêté', 'Les cours sur une page de cahier', 'Plus de 200 questions illustrées'], 17, prev=faber.last)
    I = os.path.join(E, 'inst')
    M = os.path.join(E, 'maj')
    inst = Steps('installer', 'Installer', [
        (os.path.join(I, '0-site.jpg'), 'Sur le site, touchez « Télécharger ».', 2.6, 0),
        (os.path.join(I, '1-fichiers.png'), 'Ouvrez le fichier téléchargé.', 1.6, 0),
        (os.path.join(I, '2-securite.png'), 'Android demande : touchez « Paramètres ».', 2.0, 0),
        (os.path.join(I, '3-autoriser.png'), 'Autorisez cette source.', 1.6, 0),
        (os.path.join(I, '5-installer.png'), 'Touchez « Installer ».', 2.0, 0),
        (os.path.join(I, '9-porte.png'), 'Un adulte ouvre l’espace parent…', 2.4, 0),
        (os.path.join(I, '11-age.png'), '… et choisit l’âge de l’enfant.', 2.4, 0),
    ])
    maj = Steps('majour', 'Mettre à jour', [
        (os.path.join(M, '1-accueil.png'), 'La pastille « Mise à jour » apparaît sur l’accueil.', 3.0, 0),
        (os.path.join(M, '3-proposee.png'), 'Dans l’espace parent : « Mettre à jour ».', 3.2, 0),
        (os.path.join(M, '5-autoriser.png'), 'Autorisez l’installation, une seule fois.', 2.6, 0),
        (os.path.join(M, '6-retour.png'), 'La mise à jour reprend toute seule.', 2.2, 0),
        (os.path.join(M, '8-apres.png'), 'C’est fait : la progression est gardée.', 3.0, 0),
    ])
    return [Title(), Tree(), primus, mundi, memor, faber, illus, inst, maj, End()]


def main():
    scenes = build()
    total = sum(s.d for s in scenes)
    print(f'durée {total:.1f} s', file=sys.stderr)
    # Voix posées au début de chaque scène (+0,4 s), musique dessous.
    starts, t = [], 0.0
    for s in scenes:
        starts.append(t)
        t += s.d
    with open(os.path.join(E, 'timeline.txt'), 'w') as f:
        for s, st in zip(scenes, starts):
            f.write(f'{s.voice} {st + 0.4:.3f}\n')
    if PREVIEW:
        for ts in [float(x) for x in PREVIEW.split(',')]:
            i = max(j for j, st in enumerate(starts) if st <= ts)
            img = paper.copy().convert('RGBA')
            scenes[i].draw(img, ts - starts[i])
            img.convert('RGB').save(os.path.join(E, f'prev_{ts:.1f}.png'))
        return
    silent = os.path.join(E, 'images.mp4')
    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS),
                           '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '20', '-pix_fmt', 'yuv420p', silent], stdin=subprocess.PIPE)
    n = int(total * FPS)
    base = paper.convert('RGBA')
    for k in range(n):
        tt = k / FPS
        i = max(j for j, st in enumerate(starts) if st <= tt)
        img = base.copy()
        scenes[i].draw(img, tt - starts[i])
        # Fondu d'une page à l'autre (comme on tourne une page du carnet).
        to_end = starts[i] + scenes[i].d - tt
        if to_end < 0.35 and i + 1 < len(scenes):
            nxt = base.copy()
            scenes[i + 1].draw(nxt, 0.0)
            img = Image.blend(img, nxt, 1 - to_end / 0.35)
        ff.stdin.write(img.convert('RGB').tobytes())
        if k % 300 == 0:
            print(f'{tt:.0f} s', file=sys.stderr)
    ff.stdin.close()
    ff.wait()


if __name__ == '__main__':
    main()
