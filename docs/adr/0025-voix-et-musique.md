# 0025 — Interrupteurs voix / musique et trame sonore

- **Date** : 2026-11-03 · **Statut** : accepté (demande d'Antsa : « option visible d'activation ou désactivation de la
  voix et des trames sonores qui ne dérangent pas, pour chaque leçon et exercice »)
- **Décision** : deux interrupteurs ronds de 48 dp dans la barre du haut de chaque leçon et du dessin (spécification :
  `docs/design.md` § 5). État mémorisé (`voix`, `musique`). Voix coupée : tout reste écrit, « Réécouter » dit quand
  même. Musique coupée : ni trame ni bruitages ; les sons d'un exercice d'écoute jouent toujours (c'est la question).
- **Trame sonore** : une boucle de 16 s par monde, notes douces d'une gamme pentatonique et basse lente, **fabriquée
  par l'app** (`ambience`, `lib/audio/sfx.dart`, rien à créditer, rien dans l'APK). Volume 0,15, baissé à 0,04 pendant
  la voix, arrêtée pendant « Les sons » et en fin de séance, absente de l'accueil.
- **Reste à tester** : si la trame aide ou gêne l'attention d'un enfant de 5 ans (essai) ; volume sur la tablette.
