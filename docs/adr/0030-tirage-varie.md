# 0030 — Tirage varié au bon niveau

- **Date** : 2026-11-03 · **Statut** : accepté (signalé par Antsa : « trois fois le thème calcul, exactement le même
  calcul »)
- **Cause** : le tirage était bien aléatoire, mais une séance de débutant enchaîne 8 questions d'une même compétence
  qui n'a que quelques questions possibles (10 additions jusqu'à 5), et seule la question précédente était évitée.
- **Décision** : (1) chaque question a une **signature** ; le tirage évite celles déjà posées dans la séance **et** les
  12 dernières de la compétence, gardées d'une séance à l'autre (réglage `recents`) ; (2) **variantes d'énoncé**
  (`variantes`, 17 compétences de calcul) : « Combien font 3 et 4 ? », « 3 + 4 = ? », une petite histoire… pour la
  même difficulté ; (3) les bornes du niveau ne changent pas (programme, ADR 0021).
- **Écarté** : mêler des révisions non dues aux nouvelles questions (cela fausserait le calendrier de Leitner, ADR
  0007).
