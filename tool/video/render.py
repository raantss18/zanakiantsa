#!/usr/bin/env python3
"""Monte la vidéo d'aide (ADR 0058) à partir des vrais enregistrements de la tablette et de `plan.py`.

  python3 tool/video/render.py --clips DOSSIER --assets DOSSIER --out guide.mp4 [--preview planche.png]

Dessiné image par image avec Pillow, encodé par ffmpeg : génériques, cartons de chapitre, textes, doigt animé qui
touche le vrai bouton, zoom doux sur la zone utile, musique douce composée ici (music.py). Aucune voix : tout est écrit.
"""
import argparse
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, os.path.dirname(__file__))
from plan import PLAN  # noqa: E402

W, H, FPS = 1280, 720, 30
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
PAPER = (251, 251, 255)
LINE = (118, 138, 214)
MARGE = (217, 58, 99)
ENCRE = (43, 20, 88)
VIOLET = (123, 31, 162)
TEXTE = (38, 33, 58)
SOLEIL = (255, 200, 61)


def font(name, size):
    return ImageFont.truetype({
        'script': f'{ROOT}/app/assets/fonts/PlaywriteFR-Regular.ttf',
        'bold': f'{ROOT}/design/fonts/Andika-Bold.ttf',
        'regular': f'{ROOT}/design/fonts/Andika-Regular.ttf',
    }[name], size)


# ---------------------------------------------------------------- outils d'animation
def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def back(x):
    """Petit rebond à l'arrivée."""
    x = max(0.0, min(1.0, x))
    c = 1.70158
    return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2


def paper():
    """Le cahier Seyès du site : interlignes, gros carreaux, marge rouge."""
    im = Image.new('RGB', (W, H), PAPER)
    d = ImageDraw.Draw(im)
    for y in range(0, H, 8):
        d.line([(0, y), (W, y)], fill=(236, 239, 250))
    for y in range(0, H, 32):
        d.line([(0, y), (W, y)], fill=(214, 220, 246))
    for x in range(0, W, 32):
        d.line([(x, 0), (x, H)], fill=(238, 240, 251))
    d.line([(56, 0), (56, H)], fill=MARGE, width=3)
    return im


PAPER_IM = None


def wrap(text, f, width):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if f.getlength(t) <= width:
            cur = t
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


# ---------------------------------------------------------------- images des enregistrements
class Clips:
    """Les enregistrements, ré-échantillonnés à 10 images par seconde dans fr_<clip>/00001.jpg… (voir ADR 0058)."""

    def __init__(self, folder):
        self.folder = folder
        self.cache = {}

    def _path(self, clip, i):
        import glob
        n = len(glob.glob(f'{self.folder}/fr_{clip}/*.jpg'))
        return f'{self.folder}/fr_{clip}/{min(max(1, i), n):05d}.jpg'

    def frame(self, clip, sec):
        key = (clip, sec)
        if key not in self.cache:
            self.cache[key] = Image.open(self._path(clip, int(sec * 10) + 6)).convert('RGB')
        return self.cache[key]

    def frames(self, clip, a, b):
        return [Image.open(self._path(clip, i)).convert('RGB') for i in range(int(a * 10) + 1, int(b * 10) + 1)]


# ---------------------------------------------------------------- la tablette à l'écran
SCREEN_H = 610
SCREEN_W = round(SCREEN_H * 800 / 1340)
TAB_X, TAB_Y = 840, (H - SCREEN_H) // 2
BEZEL = 16


def tablet(canvas, screen, zoom=1.0, focus=(400, 670)):
    """Pose l'écran de la tablette dans son cadre ; [zoom] grossit autour de [focus]. Renvoie la fonction qui place un
    point de l'écran de la tablette sur la vidéo."""
    cw, ch = 800 / zoom, 1340 / zoom
    x0 = min(max(focus[0] - cw / 2, 0), 800 - cw)
    y0 = min(max(focus[1] - ch / 2, 0), 1340 - ch)
    crop = screen.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch))).resize((SCREEN_W, SCREEN_H), Image.LANCZOS)
    sh = Image.new('RGBA', (SCREEN_W + 2 * BEZEL + 60, SCREEN_H + 2 * BEZEL + 60), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((30, 40, 30 + SCREEN_W + 2 * BEZEL, 40 + SCREEN_H + 2 * BEZEL), 34, fill=(43, 20, 88, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(14))
    canvas.paste(sh, (TAB_X - BEZEL - 30, TAB_Y - BEZEL - 30), sh)
    d = ImageDraw.Draw(canvas)
    d.rounded_rectangle((TAB_X - BEZEL, TAB_Y - BEZEL, TAB_X + SCREEN_W + BEZEL, TAB_Y + SCREEN_H + BEZEL), 30, fill=(28, 24, 48))
    canvas.paste(crop, (TAB_X, TAB_Y))
    if zoom > 1.02:
        # Une loupe, pour dire qu'on regarde de plus près.
        d.ellipse((TAB_X + SCREEN_W - 44, TAB_Y + 10, TAB_X + SCREEN_W - 8, TAB_Y + 46), fill=(255, 255, 255), outline=ENCRE, width=3)
        d.line((TAB_X + SCREEN_W - 32, TAB_Y + 22, TAB_X + SCREEN_W - 20, TAB_Y + 34), fill=ENCRE, width=3)

    def place(p):
        return (TAB_X + (p[0] - x0) / cw * SCREEN_W, TAB_Y + (p[1] - y0) / ch * SCREEN_H)
    return place


# ---------------------------------------------------------------- éléments
class Assets:
    def __init__(self, folder):
        self.doigt = Image.open(f'{folder}/doigt.png').convert('RGBA')
        self.wordmark = Image.open(f'{folder}/wordmark.png').convert('RGBA')
        self.qr = Image.open(f'{folder}/qr.png').convert('RGBA')
        self.icons = {k: Image.open(f'{folder}/{k}.png').convert('RGBA') for k in ['1f4d6', '1f522', '265f', '1f916', '2b50', '1f4da', '1f512', '2699']}


def finger(canvas, a, tip, k, press):
    """Le doigt (pointe en haut au milieu de l'image) arrive par en bas et touche [tip]. k : 0 → 1 l'arrivée ; press : 0 → 1 l'appui."""
    s = 92 * (1 - 0.12 * math.sin(math.pi * min(1, press)))
    img = a.doigt.resize((round(s), round(s)), Image.LANCZOS)
    dx = (1 - back(k)) * 160
    dy = (1 - back(k)) * 260
    x = tip[0] - s * 0.40 + dx
    y = tip[1] - s * 0.04 + dy
    if press > 0:
        d = ImageDraw.Draw(canvas)
        for j, r0 in enumerate([0, 0.25]):
            q = (press - r0) / 0.75
            if 0 < q < 1:
                r = 10 + 46 * q
                col = tuple(int(c * (1 - q) + p * q) for c, p in zip(SOLEIL, (255, 255, 255)))
                d.ellipse((tip[0] - r, tip[1] - r, tip[0] + r, tip[1] + r), outline=col, width=max(1, round(7 * (1 - q))))
    canvas.paste(img, (round(x), round(y)), img)


def caption(canvas, title, body, t, number=None):
    """Le titre et le texte à gauche, qui glissent à l'entrée."""
    k = ease(t / 0.5)
    k2 = ease((t - 0.25) / 0.5)
    ft, fb = font('bold', 44), font('regular', 32)
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = 96, 150
    if number:
        d.ellipse((x, y - 66, x + 52, y - 14), fill=ENCRE + (round(255 * k),))
        f = font('script', 30)
        d.text((x + 26, y - 40), str(number), font=f, fill=(255, 255, 255, round(255 * k)), anchor='mm')
    for line in wrap(title, ft, 640):
        d.text((x + (1 - k) * -30, y), line, font=ft, fill=ENCRE + (round(255 * k),))
        y += 58
    y += 14
    for line in wrap(body, fb, 640):
        d.text((x + (1 - k2) * -30, y), line, font=fb, fill=TEXTE + (round(255 * k2),))
        y += 46
    canvas.paste(layer, (0, 0), layer)


# ---------------------------------------------------------------- les plans
STILL = 6.5   # s par arrêt sur image : le temps de lire, puis de voir le doigt
CHAP = 2.6



def shot_frames(spec, clips, a, chapter):
    """Génère les images d'un plan."""
    kind = spec[0]
    if kind == 'chap':
        _, n, title = spec
        total = round(CHAP * FPS)
        for i in range(total):
            t = i / FPS
            im = PAPER_IM.copy()
            d = ImageDraw.Draw(im)
            k = back(t / 0.6)
            r = 70 * k
            d.ellipse((W / 2 - r, 250 - r, W / 2 + r, 250 + r), fill=VIOLET)
            if k > 0.3:
                d.text((W / 2, 250), str(n), font=font('script', 72), fill=(255, 255, 255), anchor='mm')
            f = font('script', 64)
            tw = f.getlength(title)
            reveal = ease((t - 0.35) / 0.9)
            layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(layer).text((W / 2, 410), title, font=f, fill=ENCRE, anchor='mm')
            mask = Image.new('L', (W, H), 0)
            ImageDraw.Draw(mask).rectangle((0, 0, W / 2 - tw / 2 + tw * reveal + 10, H), fill=255)
            im.paste(layer, (0, 0), Image.composite(layer.split()[3], Image.new('L', (W, H), 0), mask))
            yield im
        return
    if kind == 'play':
        _, clip, a0, b0, dur = spec
        fr = clips.frames(clip, a0, b0) or [clips.frame(clip, a0)]
        total = round(dur * FPS)
        for i in range(total):
            im = PAPER_IM.copy()
            tablet(im, fr[min(len(fr) - 1, int(i / total * len(fr)))])
            yield im
        return
    _, clip, t0, title, body, target = spec
    screen = clips.frame(clip, t0)
    total = round(STILL * FPS)
    for i in range(total):
        t = i / FPS
        im = PAPER_IM.copy()
        zoom, focus = 1.0, (400, 670)
        if target:
            zoom = 1 + 0.28 * ease((t - 0.8) / 1.0)
            focus = target
        place = tablet(im, screen, zoom, focus)
        caption(im, title, body, t, number=chapter)
        if target:
            tip = place(target)
            k = (t - 2.2) / 0.8
            if k > 0:
                press = (t - 4.2) / 0.9 if t > 4.2 else 0
                finger(im, a, tip, k, min(1, press))
        yield im





def intro(a):
    total = round(5.5 * FPS)
    for i in range(total):
        t = i / FPS
        im = PAPER_IM.copy()
        k = back(t / 0.8)
        wm = a.wordmark.resize((max(1, round(420 * k)), max(1, round(252 * k))), Image.LANCZOS)
        im.paste(wm, (round(W / 2 - wm.width / 2), round(190 - wm.height / 2)), wm)
        f = font('script', 54)
        for j, line in enumerate(['Installer et utiliser', 'Zanak’i Antsa']):
            reveal = ease((t - 0.9 - j * 1.0) / 1.0)
            layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            ImageDraw.Draw(layer).text((W / 2, 380 + j * 74), line, font=f, fill=ENCRE, anchor='mm')
            tw = f.getlength(line)
            mask = Image.new('L', (W, H), 0)
            ImageDraw.Draw(mask).rectangle((0, 0, W / 2 - tw / 2 + tw * reveal + 10, H), fill=255)
            im.paste(layer, (0, 0), Image.composite(layer.split()[3], Image.new('L', (W, H), 0), mask))
        k2 = ease((t - 3.0) / 0.6)
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((W / 2, 560), 'Le guide pas à pas pour les parents, sur une vraie tablette', font=font('regular', 30),
                                   fill=TEXTE + (round(255 * k2),), anchor='mm')
        im.paste(layer, (0, 0), layer)
        for j, key in enumerate(['1f4d6', '1f522', '265f', '1f916', '2b50']):
            kk = back((t - 1.2 - j * 0.15) / 0.6)
            if kk > 0:
                ic = a.icons[key].resize((max(1, round(64 * kk)), max(1, round(64 * kk))), Image.LANCZOS)
                x = [160, 280, 1000, 1120, 1060][j]
                y = [120, 300, 140, 300, 470][j] + 6 * math.sin(t * 2 + j)
                im.paste(ic, (round(x - ic.width / 2), round(y - ic.height / 2)), ic)
        yield im


def outro(a):
    total = round(10 * FPS)
    for i in range(total):
        t = i / FPS
        im = PAPER_IM.copy()
        d = ImageDraw.Draw(im)
        k = ease(t / 0.6)
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        dl = ImageDraw.Draw(layer)
        dl.text((96, 96), 'Une question ? Un souci ?', font=font('script', 50), fill=ENCRE + (round(255 * k),))
        lines = [('bold', 'RANIRIAMANJAKA Antsa'), ('regular', 'antsa.raniriamanjaka@univ-antananarivo.mg'),
                 ('regular', 'Téléphone et WhatsApp : +261 33 43 838 82'), ('regular', 'raantss18.github.io/zanakiantsa')]
        for j, (w, line) in enumerate(lines):
            kj = ease((t - 0.5 - j * 0.35) / 0.5)
            dl.text((96 + (1 - kj) * -30, 220 + j * 56), line, font=font(w, 34), fill=TEXTE + (round(255 * kj),))
        kq = back((t - 1.6) / 0.7)
        if kq > 0:
            s = max(1, round(300 * kq))
            q = a.qr.resize((s, s), Image.NEAREST)
            card = Image.new('RGBA', (s + 24, s + 24), (255, 255, 255, 255))
            card.paste(q, (12, 12), q)
            layer.paste(card, (round(1000 - card.width / 2), round(320 - card.height / 2)))
        kk = ease((t - 2.4) / 0.6)
        dl.text((1000, 500), 'Le site, avec le téléchargement', font=font('regular', 26), fill=TEXTE + (round(255 * kk),), anchor='mm')
        dl.text((1000, 534), 'et les nouvelles', font=font('regular', 26), fill=TEXTE + (round(255 * kk),), anchor='mm')
        kf = ease((t - 4.5) / 0.8)
        dl.text((W / 2, 640), 'Merci, et bonne découverte !', font=font('script', 40), fill=VIOLET + (round(255 * kf),), anchor='mm')
        im.paste(layer, (0, 0), layer)
        if t > 8.6:
            fade = ease((t - 8.6) / 1.4)
            im = Image.blend(im, Image.new('RGB', (W, H), PAPER), fade)
        yield im


def crossfade(gen_a_last, gen_b, n=8):
    first = None
    for j, im in enumerate(gen_b):
        if j < n and gen_a_last is not None:
            im = Image.blend(gen_a_last, im, (j + 1) / (n + 1))
        yield im


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--clips', required=True)
    ap.add_argument('--assets', required=True)
    ap.add_argument('--out', default='guide.mp4')
    ap.add_argument('--music')
    ap.add_argument('--preview')
    args = ap.parse_args()
    global PAPER_IM
    PAPER_IM = paper()
    clips, a = Clips(args.clips), Assets(args.assets)

    if args.preview:
        stills = [s for s in PLAN if s[0] == 'still']
        tw, th = 240, 402
        sheet = Image.new('RGB', (8 * tw, ((len(stills) + 7) // 8) * (th + 30)), 'white')
        for j, s in enumerate(stills):
            _, clip, t0, title, body, target = s
            im = clips.frame(clip, t0).copy()
            d = ImageDraw.Draw(im)
            if target:
                x, y = target
                d.ellipse((x - 30, y - 30, x + 30, y + 30), outline=(255, 0, 0), width=8)
                d.line((x - 50, y, x + 50, y), fill=(255, 0, 0), width=4)
                d.line((x, y - 50, x, y + 50), fill=(255, 0, 0), width=4)
            im = im.resize((tw, th))
            sheet.paste(im, ((j % 8) * tw, (j // 8) * (th + 30)))
            ImageDraw.Draw(sheet).text(((j % 8) * tw + 4, (j // 8) * (th + 30) + th + 4), f'{j} {title[:30]}', fill='black')
        sheet.save(args.preview)
        return

    cmd = ['ffmpeg', '-v', 'error', '-y', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-']
    if args.music:
        cmd += ['-i', args.music, '-map', '0:v', '-map', '1:a', '-c:a', 'aac', '-b:a', '128k', '-shortest']
    cmd += ['-c:v', 'libx264', '-preset', 'slow', '-crf', '24', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', args.out]
    enc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    last = None
    count = 0
    chapter = None
    gens = [intro(a)]
    for s in PLAN:
        if s[0] == 'chap':
            chapter = s[1]
        gens.append(shot_frames(s, clips, a, chapter if s[0] == 'still' else None))
    gens.append(outro(a))
    for g in gens:
        for im in crossfade(last, g):
            enc.stdin.write(im.tobytes())
            last = im
            count += 1
    enc.stdin.close()
    enc.wait()
    print(f'{count} images, {count / FPS:.1f} s → {args.out}')


if __name__ == '__main__':
    main()
