"""Contrastes WCAG 2.x des palettes d'univers (docs/design.md). Usage : python3 tool/contrast.py"""
def lum(h):
    h = h.lstrip("#")
    def c(v):
        v = int(v, 16) / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = c(h[0:2]), c(h[2:4]), c(h[4:6])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def ratio(a, b):
    la, lb = sorted([lum(a), lum(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)

INK, WHITE = "#1B211D", "#FFFFFF"
U = {
    "robots":     dict(bg1="#E3F0FA", bg2="#C9DFF0", primary="#1F5F8B", accent="#B26B00"),
    "voitures":   dict(bg1="#FFF3E0", bg2="#FFE0B2", primary="#B71C1C", accent="#1565C0"),
    "espace":     dict(bg1="#1A1F4A", bg2="#2D1E5C", primary="#FFC83D", accent="#5E35B1", on="#1B211D"),
    "fees":       dict(bg1="#F6E8F8", bg2="#E3F4FB", primary="#7B1FA2", accent="#2E7D32"),
    "mode":       dict(bg1="#FDE7EF", bg2="#FFF6E0", primary="#AD1457", accent="#6A1B9A"),
    "princesses": dict(bg1="#EEE8F8", bg2="#FFF7CC", primary="#5E2A8C", accent="#9A6700"),
}
ok = True
for name, p in U.items():
    rows = [
        ("texte/primaire", ratio(p.get("on", WHITE), p["primary"]), 4.5),
        ("encre/carte", ratio(INK, WHITE), 4.5),
        ("primaire/carte", ratio(p["primary"], WHITE), 3.0),
        ("accent/carte", ratio(p["accent"], WHITE), 3.0),
        ("primaire/fond1", ratio(p["primary"], p["bg1"]), 3.0),
        ("primaire/fond2", ratio(p["primary"], p["bg2"]), 3.0),
    ]
    # Univers de nuit (texte foncé sur primaire clair) : le primaire n'est jamais posé sur une carte blanche ; c'est
    # l'accent qui sert sur les cartes (docs/design.md).
    if "on" in p:
        rows = [row for row in rows if row[0] != "primaire/carte"]
    for label, r, need in rows:
        flag = "OK" if r >= need else "KO"
        ok &= r >= need
        print(f"{name:11} {label:15} {r:5.2f} (≥{need}) {flag}")
print("TOUT OK" if ok else "À CORRIGER")
