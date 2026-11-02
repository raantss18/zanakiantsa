# Vision — Zanak'i Antsa

## En une phrase

Une application hors ligne où un enfant de 5 à 10 ans apprend **seul**, chaque jour, 10 à 15 minutes ⚠, en
français ou en malgache, en jouant à des activités courtes qui le font réfléchir.

## Pour qui

- **Enfant** (5–10 ans, GS → CM2) : utilise l'app sans adulte. Pour les 5–6 ans, l'écran enfant fonctionne en
  pictogrammes et voix off, sans texte obligatoire.
- **Parent** : espace protégé (petit calcul) pour les réglages et un rapport local. Aucun compte.
- **Auteur** (Antsa, enseignant) : écrit le contenu en fichiers JSON/YAML, sans coder.

## Ce que l'app fait

- **Un défi du jour** et une fin de séance claire (pas de défilement infini).
- **Fil rouge sans perte** ⚠ : une piste qui avance à chaque visite et ne revient jamais à zéro (choix de design : pas
  de série qu'on perd).
- **Thèmes progressifs**, chacun avec un graphe de compétences, un seuil de maîtrise et des révisions espacées.
- **Erreur = information** : aide en 3 niveaux (indice → exemple → démonstration), jamais de buzzer ni d'« échec »
  affiché.
- **Récompenses intrinsèques** (mondes et personnages liés au contenu) ; ni monnaie, ni pub, ni achat, ni minuteur.

## Thèmes (ordre prévu)

1. Compter & calculer (5–7 ans) — **tranche verticale**
2. Lecture et phonologie (micro) · 3. Écriture manuscrite · 4. Algorithmique (blocs) · 5. Échecs ⚠ et sudoku ·
6. Photo d'objet · 7. Corps humain et nature · 8. Création et dessin.
Musique (piano par le micro) : à placer après la tranche verticale.

## Ce qu'on ne fera pas

Compte enfant, pub, achat intégré, pistage, envoi d'images ou de voix en ligne, téléchargement de vidéos YouTube,
copie d'applis existantes.

## Contraintes

Appareil de référence : Galaxy Tab A11 SM-X135G, 3,7 Go de RAM, supervisé par Family Link (voir `CLAUDE.md`).
Budgets : voir `CLAUDE.md`.

## Vérifié / Supposé / Reste à tester

- **Vérifié** : caractéristiques de la tablette (mesurées par `adb`, 2026-11-02) ; outillage Flutter/Android présent.
- **Supposé** ⚠ : durée de séance 10–15 min, budgets, Flutter comme stack, « Echec » = jeu d'échecs, intérêt du fil
  rouge sans perte.
- **Reste à tester** : tout le reste, à commencer par le spike de stack sur la tablette.
