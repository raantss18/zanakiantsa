# 0067 — Les notations de maths dites en mots

- **Date** : 2026-11-08 · **Statut** : accepté.
- **Contexte** : les leçons du collège et du lycée écrivent « −5 », « 3/4 », « x² », « 10⁻³ », « uₙ₊₁ », « f′(x) »,
  « ]3 ; +∞[ ». La synthèse vocale lit ce qu'elle voit : une date pour « 3/4 », un tiret, des signes sautés.
- **Décision** : juste avant la synthèse vocale, `spoken(texte, langue)` réécrit ces notations en mots, en français ou en
  anglais selon la langue réglée pour la phrase ; l'écran garde l'écriture mathématique. Les voix enregistrées ne
  passent pas par là. Ce qui n'est pas une notation (heures, dates complètes, phrases) ne change pas.
- **Vérifié** : `test/spoken_test.dart`. **Reste à tester** : à l'oreille sur la SM-X135G (`tool/ecoute.py`).
