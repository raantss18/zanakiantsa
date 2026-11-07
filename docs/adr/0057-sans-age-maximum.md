# 0057 — Pas d'âge maximum : la classe décide, l'interface reste

- **Date** : 2026-11-07 · **Statut** : accepté (demande d'Antsa : « ne pas limiter à 10 ans ; même interface, les leçons, les
  cours et l'âge s'adaptent ; simple et beau pour le parent »).
- **Décision** :
  - **Âge et classe**, côte à côte dans l'espace parent, réglés par − et + (de 4 à 99 ans). La classe suit l'âge (5 ans, GS ;
    11 ans, 6e ; au-delà de la Terminale, « Après le lycée ») ; le parent peut la changer pour un enfant en avance ou qui reprend,
    et revenir à la classe de son âge d'un geste. Une phrase dit où commencent les leçons, et jusqu'où elles vont.
  - **Rien ne change jusqu'à 10 ans** : mêmes points de départ (une classe en dessous), mêmes rangs, même écran pour l'enfant
    (`test/levels_test.dart`). L'âge décide toujours de l'aide après trois essais (ADR 0006).
  - **Dans un domaine**, le départ ne dépasse jamais son niveau le plus haut : un grand a toujours quelque chose à y apprendre.
  - **La journée** : un domaine à 3 classes ou plus sous celle de l'enfant laisse sa place au plus avancé ; il reste dans « Tout
    explorer ». À 14 ans : Les nombres, Le code, Explorer.
  - **Activité `quiz`** : question écrite, réponses écrites, chaque mauvaise réponse explique ce qu'elle montre. Une leçon s'écrit
    dans le contenu, sans code : c'est ce qui permet d'élargir à toutes les matières.
- **Sources** : programmes du cycle 3 (6e) et du cycle 4, citations dans chaque compétence,
  https://www.education.gouv.fr/sites/default/files/document/Annexe%202%20%E2%80%93%20Programme%20de%20math%C3%A9matiques%20pour%20le%20cycle%204-480716.pdf
  (lu le 2026-11-07). ⚠ Ce texte cite 5e, 4e, 3e ; l'année d'application de chaque classe n'est pas vérifiée.
- **Vérifié** : tests ; émulateur : réglage à 14 et 20 ans, classe choisie à la main, accueil à 14 ans, 7 leçons. Réponses
  calculées par programme à l'écriture. **Pas vérifié** : un grand devant l'app ; la lecture de « −5 » par la voix.
- **2026-11-07** : 6 leçons de 4e–3e de plus ; puissances écrites en exposants (10⁴), toutes les petites puissances gardées dans la police (`tool/subset_fonts.py`).
