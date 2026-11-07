#!/usr/bin/env python3
"""Ajoute à la bibliothèque (ADR 0026, 0057) des classiques du domaine public, en texte seul, pris sur Wikisource.

Chaque texte : auteur ET traducteur morts depuis plus de 70 ans (vérifié ci-dessous, AUTEURS ; le script refuse sinon).
Le texte est nettoyé (en-têtes et bandeaux Wikisource, numéros de page, notes, images, titres) puis découpé en pages
de quelques paragraphes pour la tablette. Ces livres prennent les numéros 900001 et suivants, l'étagère « classiques »,
la licence « Domaine public », et gardent auteur, source (URL exacte) et crédits.

Le catalogue reste réimportable : ce script remplace ses propres livres et garde ceux d'African Storybook ;
tool/import_livres.py garde de même les livres du domaine public. Relancer les deux, dans n'importe quel ordre,
redonne le même catalogue.
Usage (depuis app/) : python3 tool/import_classiques.py   ·   --dump <id> : affiche le texte d'un livre, page par page.
"""
import html
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

API = "https://fr.wikisource.org/w/api.php"
WIKI = "https://fr.wikisource.org/wiki/"
OUT = Path("assets/livres")
CACHE = Path("build/classiques_cache")  # hors de l'APK : on ne redemande jamais une page déjà lue
UA = {"User-Agent": "zanakiantsa-import/0.4 (application familiale hors ligne ; github.com/raantss18/zanakiantsa)"}
LICENCE = "Domaine public"
SHELF = ("classiques", "Classiques")
FIRST_ID = 900001  # loin des numéros d'African Storybook (moins de 100 000)
YEAR = 2026  # domaine public en France : 70 ans après la mort, au 1er janvier suivant (CPI L123-1)

# Auteurs et traducteurs : (naissance, mort), d'après leur page « Auteur: » de Wikisource (lue le 2026-11-07).
AUTEURS = {
    "Jean de La Fontaine": (1621, 1695),
    "Charles Perrault": (1628, 1703),
    "Hans Christian Andersen": (1805, 1875),
    "David Soldi": (1819, 1884),
    "Alphonse Daudet": (1840, 1897),
    "Guy de Maupassant": (1850, 1893),
    "Jules Verne": (1828, 1905),
    "Michel Verne": (1861, 1925),
    "Victor Hugo": (1802, 1885),
    "Jules Renard": (1864, 1910),
}

# (titre, auteur, traducteur, niveau, parties). Une partie : page Wikisource, ou (page, [sections à garder]).
# Niveaux : 5 (lecteurs autonomes, fin d'école), 6 (collège), 7 (lycée et adultes).
LF = "Fables de La Fontaine (éd. 1874)/"
CA = "Contes d’Andersen/"
LM = "Lettres de mon moulin/"
CF = "Contes des fées (Montréal, 1886)/"  # texte de Perrault (1697) ; l'édition de 1843 est gravée, en images
CLASSIQUES = [
    ("La Cigale et la Fourmi", "Jean de La Fontaine", None, 5, [LF + "La Cigale et la Fourmi"]),
    ("Le Corbeau et le Renard", "Jean de La Fontaine", None, 5, [LF + "Le Corbeau et le Renard"]),
    ("Le Loup et l’Agneau", "Jean de La Fontaine", None, 5, [LF + "Le Loup et l’Agneau"]),
    ("Le Lièvre et la Tortue", "Jean de La Fontaine", None, 5, [LF + "Le Lièvre et la Tortue"]),
    ("Le Chêne et le Roseau", "Jean de La Fontaine", None, 5, [LF + "Le Chêne et le Roseau"]),
    ("Le Petit Chaperon rouge", "Charles Perrault", None, 5, [CF + "Le Petit Chaperon Rouge"]),
    ("Le Chat botté", "Charles Perrault", None, 5, [CF + "Le Chat Botté"]),
    ("Les Fées", "Charles Perrault", None, 5, [CF + "Les Fées"]),
    ("Cendrillon", "Charles Perrault", None, 5, [CF + "Cendrillon"]),
    ("Les Habits neufs du Grand-Duc", "Hans Christian Andersen", "David Soldi", 5, [CA + "Les Habits neufs du Grand-Duc"]),
    ("Le Vilain Petit Canard", "Hans Christian Andersen", "David Soldi", 5, [CA + "Le Vilain Petit Canard"]),
    ("L’Intrépide Soldat de plomb", "Hans Christian Andersen", "David Soldi", 6, [CA + "L’Intrépide Soldat de plomb"]),
    ("Le Rossignol", "Hans Christian Andersen", "David Soldi", 6, [CA + "Le Rossignol"]),
    ("La Petite Fille et les allumettes", "Hans Christian Andersen", "David Soldi", 6, [CA + "La Petite Fille et les allumettes"]),
    ("La Chèvre de monsieur Seguin", "Alphonse Daudet", None, 6, [LM + "La chèvre de monsieur Seguin"]),
    ("Le Secret de maître Cornille", "Alphonse Daudet", None, 6, [LM + "Le secret de maître Cornille"]),
    ("La Mule du pape", "Alphonse Daudet", None, 6, [LM + "La mule du Pape"]),
    ("Histoires naturelles (choix)", "Jules Renard", None, 6, [("Histoires naturelles/ill. Rabier", [
        "Le Chasseur d’images", "La Poule", "Le Chat", "L’Âne", "Le Cochon et les perles", "Le Lézard", "Le Ver", "La Puce",
        "Le Papillon", "Les Fourmis", "L’Escargot", "L’Araignée", "Le Hérisson", "Le Serpent", "La Souris", "Le Corbeau",
    ])]),
    ("Les Étoiles", "Alphonse Daudet", None, 7, [LM + "Les étoiles"]),
    ("La Dernière Classe", "Alphonse Daudet", None, 7, ["Les Contes du lundi/La Dernière classe"]),
    ("La Parure", "Guy de Maupassant", None, 7, ["Contes du jour et de la nuit (éd. Flammarion, 1885)/La Parure"]),
    ("Aux champs", "Guy de Maupassant", None, 7, ["Contes de la bécasse (Havard, 1894)/Aux champs"]),
    ("La Ficelle", "Guy de Maupassant", None, 7, ["Miss Harriet (recueil)/Édition Conard, 1910/La Ficelle"]),
    ("Deux Amis", "Guy de Maupassant", None, 7, ["Mademoiselle Fifi (recueil, Ollendorff 1898)/Deux amis"]),
    ("Frritt-Flacc", "Jules Verne", None, 7, ["Frritt-Flacc"]),
    ("Au XXIXe siècle : la journée d’un journaliste américain en 2889", "Jules Verne", "Michel Verne", 7, ["Au XXIXe siècle"]),
    ("Poèmes choisis", "Victor Hugo", None, 7, [
        "Les Contemplations/Vieille chanson du jeune temps",
        "Saison des semailles. Le soir",
        "Les Contemplations/« Demain, dès l’aube, à l’heure où blanchit la campagne »",
        "La Légende des siècles/Après la bataille",
    ]),
]

TARGET, MAX = 650, 900  # caractères par page : quelques paragraphes, lisibles sans trop défiler


def api(**params) -> dict:
    params |= {"format": "json", "formatversion": 2}
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(6):
        time.sleep(2)  # courtois avec le serveur
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 5:
                raise
            wait = int(e.headers.get("Retry-After") or 30)
            print(f"  trop de requêtes, pause de {wait} s", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError(url)


def fetch(page: str) -> str:
    """HTML rendu d'une page Wikisource (avec les pages du fac-similé transcluses), en cache dans build/."""
    cache = CACHE / (re.sub(r"[^\w.-]+", "_", page) + ".json")
    if cache.exists():
        return json.loads(cache.read_text(encoding="utf-8"))["html"]
    print(f"  {page} …")
    r = api(action="parse", page=page, prop="text", disablelimitreport=1, redirects=1)["parse"]
    cache.write_text(json.dumps({"page": page, "html": r["text"]}, ensure_ascii=False), encoding="utf-8")
    return r["text"]


SKIP_CLASS = re.compile(
    r"ws-noexport|headertemplate|pagenum|reference|mw-editsection|audioplayer|noprint|ws-summary|mw-cite|"
    r"footertemplate|ws-data|Z3988|nopopups|tableItem|mw-empty-elt"
)
SKIP_TAG = {"style", "script", "figure", "table", "img", "audio", "math"}
BLOCK = {"p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "dd", "blockquote", "center"}
VOID = {"br", "img", "hr", "link", "meta", "source", "wbr", "input"}


class Blocks(HTMLParser):
    """Découpe le HTML en blocs de texte (paragraphes, strophes, titres), sans ce que Wikisource ajoute autour."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack: list[tuple[bool, bool]] = []  # pour chaque balise ouverte : (à sauter, poème)
        self.blocks: list[tuple[str, str]] = []  # (genre, texte) ; genre : "h" titre, "v" vers, "p" prose
        self.buf: list[str] = []
        self.kind = "p"

    def skipping(self) -> bool:
        return any(s for s, _ in self.stack)

    def in_poem(self) -> bool:
        return any(p for _, p in self.stack)

    def flush(self):
        text, self.buf = "".join(self.buf), []
        lines = [" ".join(l.replace("\ufeff", "").split()) for l in text.split("\n")]
        kind = "v" if self.in_poem() and self.kind != "h" else self.kind
        if kind == "v":  # une ligne vide entre deux vers sépare deux strophes : on la garde (une seule)
            lines = [l for i, l in enumerate(lines) if l or (i and lines[i - 1])]
            while lines and not lines[-1]:
                lines.pop()
            while lines and not lines[0]:
                lines.pop(0)
        else:
            lines = [l for l in lines if l]
        if lines:
            self.blocks.append((kind, "\n".join(lines) if kind == "v" else " ".join(lines)))
        self.kind = "p"

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = a.get("class") or ""
        if tag in VOID:
            if tag == "br" and not self.skipping():
                self.buf.append("\n")
            return
        style = (a.get("style") or "").replace(" ", "")
        skip = tag in SKIP_TAG or bool(SKIP_CLASS.search(cls)) or "display:none" in style or "visibility:hidden" in style
        if tag in BLOCK and not self.skipping():
            self.flush()
            if tag[0] == "h" and tag[1:].isdigit():
                self.kind = "h"
        self.stack.append((skip, "poem" in cls.split()))

    def handle_endtag(self, tag):
        if tag in VOID or not self.stack:
            return
        if tag in BLOCK and not self.skipping():
            self.flush()
        self.stack.pop()

    def handle_data(self, data):
        if not self.skipping():
            self.buf.append(data.replace("\n", " "))  # seul <br> fait un vers ; un saut de ligne du source, non

    def close(self):
        super().close()
        self.flush()


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", html.unescape(s).lower().replace("’", "'").translate(str.maketrans("àâäéèêëîïôöùûüç", "aaaeeeeiioouuuc")))


ROMAN = re.compile(r"^[IVXLC]+\.?$")


def blocks_of(page_html: str, title: str, author: str) -> list[tuple[str, str]]:
    p = Blocks()
    p.feed(page_html)
    p.close()
    out = []
    t = norm(title)
    for kind, text in p.blocks:
        n = norm(text)
        if not n or ROMAN.match(text.strip()) or n in {"conte", "fin", "fable", "ou"} or re.match(r"LIVRE\b", text):
            continue
        if re.search(r"\(Page \d+\.\)$", text):  # légende d'une illustration du livre papier
            continue
        if kind == "h" or len(text) < 90:  # titres, ou rappel du titre en tête : déjà affiché par la liseuse
            if t and (t in n or n in t) and len(n) > 3:
                continue
        text = re.sub(r"\s*\[\d+\]", "", text)  # appels de note restés dans le texte
        out.append((kind, text))
    # En tête, avant le premier vrai paragraphe : restes du titre en capitales (« MAÎTRE CHAT », « AU XXIX SIÈCLE. »).
    def capitals(x: str) -> bool:
        letters = [c for c in x if c.isalpha()]
        return bool(letters) and sum(c.isupper() for c in letters) >= 0.7 * len(letters)

    while out and len(out[0][1]) < 90 and capitals(out[0][1]) and (t or out[0][0] != "h"):
        out.pop(0)
    # À la fin : la signature de l'auteur (« Jules Verne. »).
    if out and norm(out[-1][1]) == norm(author):
        out.pop()
    return out


def sections(bl: list[tuple[str, str]], keep: list[str]) -> list[tuple[str, str]]:
    """Ne garde que les sections dont le titre est dans keep, chacune précédée de son titre."""
    wanted = {norm(k) for k in keep}
    out, on = [], False
    for kind, text in bl:
        if kind == "h":
            on = norm(text) in wanted
        if on:
            out.append((kind, text))
    return out


def split_long(text: str) -> list[str]:
    """Coupe un paragraphe trop long entre deux phrases."""
    if len(text) <= MAX:
        return [text]
    parts, cur = [], ""
    for s in re.split(r"(?<=[.!?…»])\s+(?=[«A-ZÀÂÉÈÊÎÔÙÇ—–-])", text):
        if cur and len(cur) + len(s) > TARGET:
            parts.append(cur)
            cur = s
        else:
            cur = f"{cur} {s}".strip()
    return parts + ([cur] if cur else [])


def join_verses(bl: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Une strophe coupée par un changement de page du livre papier se recolle (vers sans ponctuation finale)."""
    out: list[tuple[str, str]] = []
    for kind, text in bl:
        if kind == "v" and out and out[-1][0] == "v" and not re.search(r"[.!?…»;:]$", out[-1][1]):
            out[-1] = ("v", out[-1][1] + "\n" + text)
        else:
            out.append((kind, text))
    return out


def paginate(bl: list[tuple[str, str]]) -> list[str]:
    bl = join_verses(bl)
    pages, cur = [], []
    size = lambda: sum(len(c) for c in cur)
    for kind, text in bl:
        for piece in split_long(text) if kind == "p" else [text]:
            # Un titre (poème, section) ouvre toujours une nouvelle page.
            limit = MAX if kind == "v" or len(piece) < 120 else TARGET  # un poème court, sa date, tiennent sur une page
            if cur and (kind == "h" or size() + len(piece) > limit):
                pages.append(cur)
                cur = []
            cur.append(piece)
    if cur:
        pages.append(cur)
    # Une page qui ne serait qu'un titre se colle à la suivante.
    merged = []
    for pg in pages:
        if merged and len(merged[-1]) == 1 and len(merged[-1][0]) < 60:
            merged[-1] = merged[-1] + pg
        else:
            merged.append(pg)
    return ["\n\n".join(pg) for pg in merged]


def meta(page_html: str, cls: str) -> str:
    m = re.search(rf'<span class="{cls}">(.*?)</span>(?=<span class="ws-|</div>)', page_html, re.S)
    return " ".join(html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).split()) if m else ""


def check_public_domain(*names: str | None) -> None:
    for name in filter(None, names):
        born, died = AUTEURS[name]
        if YEAR - died <= 70:
            sys.exit(f"{name} (mort en {died}) n'est pas dans le domaine public en {YEAR}")


def build(n: int, entry) -> dict:
    title, author, translator, level, parts = entry
    check_public_domain(author, translator)
    blocks, urls, refs = [], [], []
    for part in parts:
        page, keep = part if isinstance(part, tuple) else (part, None)
        h = fetch(page)
        # L'en-tête Wikisource sert à vérifier l'auteur et le traducteur déclarés ici, puis il est retiré du texte.
        ws_author, ws_trans = meta(h, "ws-author"), meta(h, "ws-translator")
        if ws_author and author not in ws_author:
            sys.exit(f"{page} : auteur {ws_author!r} ≠ {author!r}")
        if ws_trans and (translator or "") not in ws_trans:
            sys.exit(f"{page} : traducteur {ws_trans!r} ≠ {translator!r}")
        if keep is not None:  # morceaux choisis d'une même page : chacun garde son titre
            bl = sections(blocks_of(h, "", author), keep)
        elif len(parts) > 1:  # recueil de plusieurs pages (poèmes) : chaque texte s'ouvre sur son titre
            name = page.rsplit("/", 1)[-1].strip("« »")
            bl = [("h", name)] + blocks_of(h, name, author)
        else:
            bl = blocks_of(h, title, author)
        blocks += bl
        urls.append(WIKI + urllib.parse.quote(page.replace(" ", "_"), safe="/(),'"))
        ref = ", ".join(x for x in (meta(h, "ws-publisher"), meta(h, "ws-year")) if x)
        if ref and ref not in refs:
            refs.append(ref)
    pages = paginate(blocks)
    who = author + (f", traduction de {translator}" if translator else "")
    credits = f"{title} — {who}" + (f" ({'; '.join(refs)})" if refs else "") + ". Texte transcrit par Wikisource. "
    credits += f"Domaine public : {author} est mort en {AUTEURS[author][1]}"
    credits += f", {translator} en {AUTEURS[translator][1]}." if translator else "."
    return {
        "id": n,
        "titre": title,
        "auteur": author,
        **({"traducteur": translator} if translator else {}),
        "etagere": SHELF[0],
        "niveau": level,
        "pages": [{"texte": p, "image": None} for p in pages],
        "credits": credits,
        "licence": LICENCE,
        "source": " ; ".join(urls),
    }


def main() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) == 3 and sys.argv[1] == "--dump":
        b = build(int(sys.argv[2]), CLASSIQUES[int(sys.argv[2]) - FIRST_ID])
        for i, p in enumerate(b["pages"]):
            print(f"--- page {i + 1} ({len(p['texte'])} car.)\n{p['texte']}")
        print("---", b["credits"], "\n", b["source"])
        return
    books = [build(FIRST_ID + i, e) for i, e in enumerate(CLASSIQUES)]
    path = OUT / "catalogue.json"
    cat = json.loads(path.read_text(encoding="utf-8"))
    kept = [b for b in cat["livres"] if b.get("licence") != LICENCE]
    shelves = {k: v for k, v in cat["etageres"].items() if k != SHELF[0]} | {SHELF[0]: SHELF[1]}
    cat |= {"etageres": shelves, "livres": kept + books}
    before = path.stat().st_size
    path.write_text(json.dumps(cat, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    pages = sum(len(b["pages"]) for b in books)
    print(f"{len(books)} classiques, {pages} pages ; catalogue {before / 1e3:.0f} → {path.stat().st_size / 1e3:.0f} ko")


if __name__ == "__main__":
    main()
