# 0043 — Une voix qui se tait quand on sort, et qui dit quand elle ne marche pas

- **Date** : 2026-11-03 · **Statut** : accepté (retour d'Antsa : « le son ne marche pas bien, et même si on sort ça
  parle toujours »)
- **Causes** : (1) une question ou une séance enchaîne plusieurs phrases (bravo, encouragement, histoire…) ; quitter
  l'écran coupait la phrase en cours, mais la suivante partait quand même, et aussi en arrière-plan. (2) flutter_tts
  4.2.5 (code Android lu) ne termine jamais l'attente de fin de phrase quand le moteur échoue (voix française absente) :
  l'app restait muette jusqu'à la limite de temps, puis coupait la phrase suivante.
- **Décision** : chaque écran et chaque question a sa « parole » (`Speech`), fermée en le quittant : plus rien n'est
  dit ensuite. App cachée : aucune phrase ni aucun son jusqu'au retour. Accueil : le message s'arrête au premier
  toucher. Erreur du moteur : l'attente finit tout de suite. `stop()` termine lui-même l'attente en cours.
- **Espace parent** : « La voix » — moteur utilisé, français disponible ou non, choix du moteur, « Tester la voix »
  (fin bien signalée, ou erreur avec la marche à suivre dans les réglages du téléphone, que l'app ne change jamais).
- **Vérifié sur l'émulateur** : test de la voix (erreur -4 de Google TTS, voix française absente) en 3 s au lieu de 13 ;
  aucune phrase demandée après avoir quitté une séance. **Reste à tester** : à l'oreille, sur le téléphone d'Antsa.
