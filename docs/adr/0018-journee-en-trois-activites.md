# 0018 — Journée en trois activités

- **Date** : 2026-11-03 · **Statut** : accepté (demande d'Antsa : « trois activités différentes par jour… à peu près
  1 h 30 », pour que l'enfant soit autonome)
- **Décision** : l'accueil propose chaque jour 3 domaines en grandes cartes ; deux journées alternent à minuit (date
  locale) : nombres / vivant / dessin, puis suites / sons / échecs (`app/lib/core/day.dart`). La carte suivante est mise
  en avant (contour + ▶ qui pulse), les cartes finies portent ✔ « Fini ». L'enfant peut en choisir une autre.
- **Temps** : réglé par le parent (30, 45, 60 ou 90 min ; **90 par défaut**, demande d'Antsa), partagé en trois. Le
  temps compte les séances finies et interrompues (table `sessions`, colonnes `theme`, `complete`, base v2).
  Domaine fini : la fin d'activité propose une **pause** (bouger, boire) ; journée finie : « À demain ». Rien n'est
  bloqué : les cartes restent jouables (limite dure = décision parentale à prendre si besoin).
- **Repère de santé** : l'OMS (2019, https://www.who.int/publications/i/item/9789241550536) recommande au plus 1 h
  d'écran sédentaire par jour entre 3 et 4 ans (« moins, c'est mieux ») ; ses lignes directrices s'arrêtent avant
  5 ans. Le chiffre est repris des résumés, le PDF n'a pas été relu : **à vérifier**. Le rappel est affiché au parent.
- **Reste à tester** : durée réelle d'une séance de 8 questions, et si l'enfant enchaîne seul (essai).
