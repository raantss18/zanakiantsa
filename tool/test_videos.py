"""Essais du niveau lu dans les titres (python3 tool/test_videos.py)."""
import videos as V

CASES = {
    'Les parties d’un récit (3e cycle) | Français | Primaire': 10,
    'Répondre (3e à 6e année) | Primaire': 8,
    'Le texte d’opinion | Français | Primaire': 6,
    'Résoudre — Secondaire 2 — HexaTerra': 13,
    'Polysémie CM1 - CM2 - Cycle 3': 9,
    'les personnages secondaires': None,
    'La 6e partie': None,
    'La Seconde Guerre mondiale': None,
    'Cycle 2 CP CE1': 6,
}
for text, age in CASES.items():
    assert V.youngest_age(text) == age, (text, V.youngest_age(text), age)
alloprof = {'ages': [6, 17], 'sans_niveau_ages': [12, 17]}
assert not V.fits_level({'t': 'L’osmose et la diffusion'}, alloprof, 7)
assert V.fits_level({'t': 'Le texte d’opinion | Primaire'}, alloprof, 7)
assert V.fits_level({'t': 'Philosophie CE2 - CM1 - CM2'}, {'ages': [6, 11]}, 7)
assert not V.fits_level({'t': 'Polysémie CM1 - CM2'}, {'ages': [6, 11]}, 7)
print('ok')
