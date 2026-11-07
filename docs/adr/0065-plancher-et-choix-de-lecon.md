# 0065 — Plancher de classe et choix de la leçon

- **Date** : 2026-11-08 · **Statut** : accepté (demande d'Antsa : « à douze ans on ne compte plus les voitures ni les
  syllabes » ; « dans chaque catégorie je veux que l'élève choisisse l'activité qu'il veut faire dans Explorer, mais
  n'oublie pas l'éval diag et le cours »).
- **Cause** : à 12 ans, la première leçon de maths (pourcentages, 6e) vérifiait son prérequis direct « fraction d'une
  quantité » (CM1), posé avec les jouets de l'univers (« un quart de 16 voitures »).
- **Décision** :
  - **Plancher** = classe − 2. Une notion plus basse n'est jamais proposée : ni diagnostic, ni révision, ni entraînement,
    ni défi. Elle est tenue pour acquise. Un domaine entièrement sous le plancher n'est plus proposé (à 12 ans : les sons,
    les suites de maternelle) ; le dessin libre et les échecs (`sans_age`) restent pour tous :
    un débutant de 15 ans apprend aussi la marche du pion.
  - **Les trois activités du jour** : seulement des domaines où il reste une leçon à apprendre à son niveau (les plus
    avancés d'abord) ; les autres seulement s'il en manque. L'animation de méthode d'un domaine (« compter des pommes »)
    n'est plus montrée quand ses premières leçons sont sous le plancher.
  - **Monter** : un élève avancé ouvre les leçons au-dessus de sa classe quand celles de sa classe sont acquises.
  - **Choisir sa leçon** : dans chaque domaine, « Choisir ma leçon ». Séance : diagnostic des prérequis (non acquise),
    puis toujours le cours (idée, exemple résolu), puis les questions. Le parcours guidé « Apprendre » reste.
- **Vérifié** : `test/floor_test.dart` ; tablette SM-X135G à 12 ans (journée lire, nombres, code ; « Choisir ma leçon »
  dès le CM2 ; diagnostic, puis cours, puis questions, écoutés avec `tool/ecoute.py`), puis remise à 7 ans.
