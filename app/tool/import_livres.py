#!/usr/bin/env python3
"""Importe des livres d'African Storybook (https://www.africanstorybook.org) pour la bibliothèque hors ligne (ADR 0026).

Ne garde que les livres dont la dernière page indique « Creative Commons: Attribution 4.0 » (sans « NonCommercial »).
Écrit app/assets/livres/<id>/<n>.webp (images réduites) et app/assets/livres/catalogue.json (texte, crédits, licence).
Usage (depuis app/) : python3 tool/import_livres.py
Le choix des livres et leur étagère sont faits à la main ci-dessous (livres approuvés, en français, niveaux 1 à 5).
Les livres du domaine public ajoutés par tool/import_classiques.py sont gardés.
"""
import html
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

SITE = "https://www.africanstorybook.org/"
OUT = Path("assets/livres")
IMAGES = OUT / "images"  # un seul dossier : Flutter n'embarque pas les sous-dossiers d'assets
CACHE = Path("build/livres_cache")  # hors de l'APK : évite de tout retélécharger
UA = {"User-Agent": "zanakiantsa-import/0.4 (application familiale hors ligne ; github.com/raantss18/zanakiantsa)"}

SHELVES = {
    "apprendre": "Compter et apprendre",
    "nature": "Animaux et nature",
    "vie": "Ma vie",
    "contes": "Contes et fables",
    "curiosite": "Curiosité",
    "grands": "Pour les grands",
}

BOOKS = [
    # Compter et apprendre
    (12654, "apprendre"), (13276, "apprendre"), (10687, "apprendre"), (32198, "apprendre"), (32695, "apprendre"),
    (9922, "apprendre"), (34104, "apprendre"), (12709, "apprendre"), (14535, "apprendre"),
    # Animaux et nature
    (34101, "nature"), (12679, "nature"), (12700, "nature"), (32693, "nature"), (35178, "nature"), (34108, "nature"),
    (12660, "nature"),
    # Ma vie
    (13156, "vie"), (34105, "vie"), (13272, "vie"), (14537, "vie"), (35180, "vie"), (10942, "vie"), (33158, "vie"),
    (14536, "vie"),
    # Ajouts 2026-11-07 : niveaux 1 et 3, les plus minces (35762 écarté : texte mal encodé, « Ã¨ » laissé)
    (33851, "vie"), (13771, "vie"), (47159, "vie"), (35173, "vie"),
    (10844, "vie"), (13271, "vie"), (12665, "vie"),
    # Contes et fables
    (9965, "contes"), (10936, "contes"), (10839, "contes"), (10856, "contes"), (12655, "contes"), (9954, "contes"),
    (9963, "contes"), (12658, "contes"), (36529, "contes"),
    (13275, "contes"), (10838, "contes"), (10842, "contes"), (39918, "contes"),
    # Curiosité : vies célèbres, espace, nature, métiers, le monde (niveaux 3 à 5)
    (10136, "curiosite"), (12706, "curiosite"), (40638, "curiosite"), (13770, "curiosite"), (13774, "curiosite"),
    (33844, "curiosite"), (13270, "curiosite"), (12866, "curiosite"), (13159, "curiosite"), (9926, "curiosite"),
    (36522, "curiosite"),
    # Pour les grands : contes plus longs (niveaux 4 et 5)
    (10141, "grands"), (12680, "grands"), (37978, "grands"), (9959, "grands"), (12656, "grands"), (36532, "grands"),
    (39948, "grands"), (36546, "grands"), (10853, "grands"), (22566, "grands"), (12661, "grands"), (36547, "grands"),
    (10840, "grands"), (36541, "grands"), (12437, "grands"),
]


def fix(text: str) -> str:
    """Le site renvoie de l'UTF-8 lu comme du latin-1 (« Ã© ») : on le remet d'aplomb, sinon on garde tel quel."""
    for enc in ("latin-1", "cp1252"):
        try:
            return text.encode(enc).decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            continue
    return text


def clean(fragment: str) -> str:
    fragment = re.sub(r"<br\s*/?>|</p>|</div>", "\n", fragment, flags=re.I)
    fragment = re.sub(r"<[^>]+>", " ", fragment)
    lines = [" ".join(fix(html.unescape(l)).split()) for l in fragment.split("\n")]
    return "\n".join(l for l in lines if l)


def fetch(url: str, data: dict | None = None) -> bytes:
    body = urllib.parse.urlencode(data).encode() if data else None
    with urllib.request.urlopen(urllib.request.Request(url, data=body, headers=UA), timeout=60) as r:
        return r.read()


def save_image(rel: str, dest: Path) -> None:
    img = Image.open(io.BytesIO(fetch(SITE + rel))).convert("RGB")
    if img.width > 720:
        img = img.resize((720, round(img.height * 720 / img.width)), Image.LANCZOS)
    img.save(dest, "WEBP", quality=70, method=6)


def import_book(book_id: int, shelf: str, level: str) -> dict | None:
    raw = fetch(SITE + "read/readbook.php", {"id": book_id, "d": 0, "a": 1}).decode("utf-8", errors="replace")
    slides = re.split(r'(?=<div class="swiper-slide)', raw.split("<!--|-->")[0])[1:]
    if len(slides) < 3:
        print(f"  {book_id} : pas de pages", file=sys.stderr)
        return None
    licence = clean(slides[-1])
    if "Attribution 4.0" not in licence or re.search(r"Non.?Commercial", licence, re.I):
        print(f"  {book_id} : licence écartée ({licence[-120:]})", file=sys.stderr)
        return None
    title = clean(slides[0]).split("\n")[0]
    IMAGES.mkdir(parents=True, exist_ok=True)
    pages = []
    for n, slide in enumerate(slides[1:-1]):
        img = re.findall(r"url\(['\"]?(illustrations/[^'\")]+)", slide)
        name = None
        if img:
            name = f"{book_id}-{n}.webp"
            save_image(img[0], IMAGES / name)
            time.sleep(0.3)
        pages.append({"texte": clean(slide), "image": name})
    # Crédits : la ligne d'attribution demandée par le livre, de « Author » jusqu'à « Source ».
    credit = licence[licence.find(title):] if title in licence else licence
    return {
        "id": book_id,
        "titre": title,
        "etagere": shelf,
        "niveau": int(level),
        "pages": pages,
        "credits": credit,
        "licence": "CC BY 4.0",
        "source": f"{SITE}#!/book/{book_id}",
    }


def main() -> None:
    listing = fetch(SITE + "booklistjs.php").decode("utf-8", errors="replace")
    levels = dict(re.findall(r'\{id:"(\d+)",.*?level:"(\d)"', listing))
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    books = []
    for book_id, shelf in BOOKS:
        cache = CACHE / f"{book_id}.json"
        if cache.exists():
            b = json.loads(cache.read_text(encoding="utf-8")) | {"etagere": shelf}
        else:
            print(f"{book_id} …")
            b = import_book(book_id, shelf, levels.get(str(book_id), "1"))
            time.sleep(0.5)
        if b:
            cache.write_text(json.dumps(b, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            books.append(b)
    # Les classiques du domaine public (tool/import_classiques.py) sont gardés tels quels, après ces livres-ci :
    # relancer l'un ou l'autre script redonne le même catalogue.
    path = OUT / "catalogue.json"
    old = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"etageres": {}, "livres": []}
    others = [b for b in old["livres"] if b.get("licence") == "Domaine public"]
    shelves = SHELVES | {k: v for k, v in old["etageres"].items() if k not in SHELVES and any(b["etagere"] == k for b in others)}
    catalogue = {"source": "African Storybook Initiative, https://www.africanstorybook.org", "etageres": shelves, "livres": books + others}
    path.write_text(json.dumps(catalogue, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    size = sum(f.stat().st_size for f in OUT.rglob("*") if f.is_file())
    print(f"{len(books)} livres, {size / 1e6:.1f} Mo")


if __name__ == "__main__":
    main()
