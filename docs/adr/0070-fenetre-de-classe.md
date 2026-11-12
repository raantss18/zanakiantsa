# 0070 — La fenêtre de la classe : deux en dessous, deux au-dessus

- **Date** : 2026-11-12 · **Statut** : accepté (demande d'Antsa : « si l'enfant est en 6e, les cours qu'il doit pouvoir
  voir sont CM1 à 4e »).
- **Décision** : un enfant ne voit et ne reçoit que les leçons de sa classe −2 à sa classe +2. Le plancher existait
  (ADR 0065) ; le plafond est nouveau (`ceilingForClass` dans `core/progress.dart`) : au-delà, une leçon n'est ni dans le
  carnet, ni dans « Tout explorer », ni choisie comme leçon nouvelle, ni au test de départ, ni à l'entraînement.
- **Domaines hors école** (code, échecs) : plancher = entrée de la tranche (ADR 0069), plafond = classe +2 (jamais sous
  l'entrée). **Dessin** (`sans_age`) : pas de fenêtre.
- **Quand tout est acquis** jusqu'au plafond : entraînement varié dans la fenêtre ; les leçons suivantes s'ouvrent
  quand l'enfant change de classe (âge ou classe saisis par le parent).
- **Vérifié** : `test/floor_test.dart` (6e : CM1 à 4e, chaque domaine). **Reste à tester** : essai sur la tablette.
