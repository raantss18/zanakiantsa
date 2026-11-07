# 0056 — Les fractions, du CE1 au CM1

- **Date** : 2026-11-07 · **Statut** : accepté (suite du TODO : contenu au-delà du CE1 ; le programme les introduit dès le CE1,
  l'app n'en avait aucune).
- **Sources** : programme du cycle 2 (fractions d'un tout au CE1, dénominateurs 2, 3, 4, 5, 6, 8 ou 10 ; bande-unité au CE2),
  https://www.education.gouv.fr/sites/default/files/document/Annexe%204%20%E2%80%93%20Programme%20de%20math%C3%A9matiques%20du%20cycle%202-403821.pdf ;
  programme du cycle 3 (fractions supérieures à 1, fraction d'une quantité au CM1, dénominateur ≤ 20),
  https://www.education.gouv.fr/sites/default/files/programme-de-math-matiques-pour-le-cycle-3-439827.pdf (lus le 2026-11-07).
- **Décision** : une activité `fraction` et 9 compétences dans « Les nombres » : une part (1/d), lire, colorier, comparer à même
  dénominateur, comparer à numérateur 1, ajouter (CE1) ; placer sur une bande graduée (CE2) ; écrire au-delà de 1 comme entier
  + fraction, un d-ième d'une quantité (CM1). Les réponses proposées sont les erreurs typiques, et chacune est expliquée
  (`core/fractions.dart`) : parts blanches comptées, fraction à l'envers, dénominateurs ajoutés, « 1/6 > 1/3 parce que 6 > 3 »,
  que le programme signale comme contre-intuitif. Parts rayées en plus d'être colorées (jamais la couleur seule).
- **Choix à revoir** : dénominateurs limités à 8 pour colorier et placer, sous les 10 et 12 du programme, pour garder de grandes
  cibles sur téléphone ; ni soustraction de fractions, ni égalités (CE2), ni fractions décimales (CM1) pour l'instant.
- **Vérifié** : `test/fractions_test.dart` (mots, réponses, erreurs, toucher, 2 700 tirages) ; émulateur en tablette 1163 × 776 dp et
  téléphone : les 9 écrans, coloriage trop rempli puis juste. **Pas vérifié** : un enfant ; placer et comparer jusqu'à la réussite.
