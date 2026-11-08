# 0069 — La journée suit la classe ; le code et les échecs partent du début

- **Date** : 2026-11-08 · **Statut** : accepté (signalé par Antsa : à 12 ans, « compter jusqu'à 10 » encore visible, des
  journées « compter, lire » faites pour la GS, et en informatique « un code que l'enfant n'a jamais vu » dès la 1re question).
- **Carnet** : les leçons sous le plancher (ADR 0065) n'y sont plus listées ; une ligne dit qu'elles sont acquises pour son âge.
- **Journée** : jusqu'au CE2, le tour de 4 jours (ADR 0018). À partir du CM1, chaque domaine revient en proportion des
  horaires officiels de la classe (`dayWeights` dans `core/day.dart`, tourniquet pondéré, jamais deux fois le même jour),
  parmi les domaines où il reste à apprendre à son niveau. Sources lues sur Légifrance : arrêté du 9/11/2015 art. 2 (CM1-CM2),
  arrêté du 19/5/2015 modifié le 10/3/2026 annexes 1-2 (6e, cycle 4), arrêté du 16/7/2018 annexe 1 (2de). Code hors grille
  avant la 5e, échecs, dessin : poids choisis par l'app (supposé).
- **Domaines hors école** (`hors_ecole` : code, échecs) : l'âge ne dit pas ce que l'enfant sait. Plancher = départ = l'entrée
  de sa tranche (`entree`, sinon le début du domaine) : rien au-dessus n'est tenu pour acquis, donc pas de diagnostic sur une
  notion jamais apprise, et le cours (idée, exemple résolu) vient avant toute question. Code, 12 ans et plus : les programmes
  écrits de 6e ; avant : le robot. Échecs : la marche des pièces. « Je sais déjà » saute ce qui est connu.
- **Vérifié** : `test/floor_test.dart`. **Reste à tester** : essai sur la tablette, avis d'enseignants sur les poids.
