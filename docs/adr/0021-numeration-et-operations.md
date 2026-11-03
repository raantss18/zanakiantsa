# 0021 — Bâtonnets, multiplication, partage

- **Date** : 2026-11-03 · **Statut** : accepté (priorité 2 d'Antsa)
- **Décision** : 8 compétences ajoutées au domaine « nombres », après les compléments à 10 (programme de
  mathématiques du cycle 2, annexe 4, citations exactes dans chaque compétence) :
  dizaines à lire et à construire avec des **bâtonnets en paquets de dix** (CP) ; paquets pareils (sens de la
  multiplication, ≤ 30, CP) ; doubles de 1 à 15 (CE1) ; **partage équitable** en distribuant un à un (CP) ; moitiés des
  nombres pairs jusqu'à 30 (CE1) ; tables de 2, 5, 10 puis de 3 et 4 (CE1).
- **Activités** (`app/lib/activities/numbers.dart`) : `batonnets` (lire : 3 réponses dont le nombre aux chiffres
  inversés, l'erreur que cite le programme ; construire : compteurs paquets / bâtonnets), `groupes` et `tables`
  (paquets ou quadrillage d'objets du monde, couché s'il est trop haut), `partage` (on touche un enfant pour lui
  donner un objet ; parts inégales = essai manqué, on recommence).
- **Progression** : chaque compétence s'ouvre quand la précédente est maîtrisée (ADR 0007) ; un enfant de 5 ans n'y
  arrive qu'après les compétences de maternelle.
- **Reste à tester** : la division « combien de parts » (groupements) et les tables de 6 à 9, non faites.
