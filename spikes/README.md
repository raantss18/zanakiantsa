# Spike de stack (ADR 0003)

La **même** mini-activité dans trois technologies, mesurée sur les deux SM-X135G. Code jetable : il ne sert qu'à
mesurer, rien n'est repris tel quel dans l'app.

## Activité commune « Compte les pommes »

1. Écran portrait, fond uni. **N pommes** (N = 5 au premier tour, puis 3 à 7) dessinées par code (cercle rouge +
   feuille verte), placées par un générateur à **graine fixe** (mêmes positions partout), qui **flottent**
   doucement (animation continue, pour charger le rendu).
2. Au démarrage, la synthèse vocale (fr-FR) dit : « Touche chaque pomme pour la compter. »
3. Toucher une pomme : elle s'entoure, son numéro (1, 2, 3…) s'affiche, la voix dit le nombre. Une pomme déjà
   comptée ne compte pas deux fois.
4. Toutes comptées : trois boutons-nombres (N−1, N, N+1, ordre fixe) et la voix demande « Combien de pommes ? ».
5. Bonne réponse : son court (`ding.wav`, généré par `make_ding.py`, aucun asset tiers) + « Oui, il y a N pommes.
   Bravo ! » puis nouveau tour. Mauvaise : « Compte encore. » (pas de son négatif, ADR 0006/0008).
6. Cibles tactiles ≥ 48 dp.

## Instrumentation commune (logcat, étiquette `SPIKE`)

- `SPIKE first_frame` au premier rendu de l'activité.
- `SPIKE fps <valeur>` toutes les 5 s : images rendues pendant la fenêtre ÷ 5.

## Mesures (script `measure.sh <paquet> <apk>`)

| Mesure | Méthode |
| --- | --- |
| Taille d'APK | `stat` de l'APK **release**, ABI `arm64-v8a` seule |
| Démarrage à froid | `am start -S -W`, champ `TotalTime`, médiane de 5 lancements |
| Mémoire | `dumpsys meminfo <paquet>`, `TOTAL PSS`, après 20 s d'animation |
| Fluidité | `SPIKE fps`, moyenne sur 20 s |

Paquets : `mg.zanakiantsa.spike.flutter`, `mg.zanakiantsa.spike.compose`, `mg.zanakiantsa.spike.godot`.
Les APK de spike sont désinstallés à la fin (ADR 0004).
