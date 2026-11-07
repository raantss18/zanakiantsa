# 0062 — Numéros de version : un compteur à trois chiffres

- **Date** : 2026-11-07 · **Statut** : accepté (règle d'Antsa : « 0.1.9 → 0.2.0 et ainsi de suite, 1.9.9 → 2.0.0 »).
- **Règle** : version X.Y.Z, Y et Z de 0 à 9 ; la version suivante ajoute 1 au dernier chiffre avec retenue, comme un compteur
  (0.1.9 → 0.2.0, 0.9.9 → 1.0.0, 1.9.9 → 2.0.0). Le build Android (`+n`) augmente toujours de 1 : c'est lui que l'app compare
  pour proposer une mise à jour (ADR 0011), donc la règle ne change rien aux mises à jour.
- **Passage** : la dernière version publiée hors règle est 0.13.0 ; la suivante est **1.0.0** (demande d'Antsa).
- **Outil** : `tool/version.py --bump` (testé de 0.1.9 à 9.9.9) ; refuse une version hors règle.
