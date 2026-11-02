# TODO — Zanak'i Antsa

> Une seule liste, tenue à jour à chaque tâche. Statuts : ✅ fait · 🔄 en cours · ⏳ à faire · ❓ décision d'Antsa.
> Une tâche n'est ✅ qu'après tests + essai réel sur les tablettes (`CLAUDE.md`).

## 0. Erreurs signalées

Aucune pour l'instant. (Une erreur signalée s'inscrit ici avant d'être corrigée.)

## Étape 0 — Cadrage ✅

- ✅ `CLAUDE.md`, `docs/vision.md`, dépôt public `raantss18/zanakiantsa`
- ✅ ADR 0001 dépôt et licences · 0002 voix · 0003 méthode du spike · 0004 tablettes de test

## Étape 1 — Teardown ✅

- ✅ `docs/teardown.md` : 11 applis, matrice, 16 pistes de différenciation

## Étape 2 — Pédagogie ✅

- ✅ `docs/pedagogie.md` : règles sourcées + checklist de revue d'activité
- ✅ Décisions d'Antsa : ADR 0005 langue · 0006 trois essais · 0007 maîtrise 4/5 + Leitner · 0008 retour positif ·
  0009 ML Kit

## Étape 3 — Choix techniques ✅

- ✅ Spike Flutter / Compose / Godot mesuré sur les deux SM-X135G (`spikes/RESULTATS.md`)
- ✅ ADR 0010 : Flutter + Flame
- ✅ ADR 0011 : mises à jour faites par l'app elle-même
- ✅ `docs/architecture.md`
- ✅ `docs/licences.md`
- ✅ `docs/conformite.md` (YouTube III.E.1, CNIL, loi malgache 2014-038, Google Play, ML Kit, TTS)
- ⏳ `docs/confidentialite.md` : seulement si l'app sort un jour de la famille (obligatoire sur Google Play)
- ⏳ Vérifier les permissions ajoutées par les plugins `google_mlkit_*` au manifeste (au moment de les intégrer)
- ✅ ADR 0012 : ML Kit accepté (usage familial) malgré sa licence non open source
- ✅ Restriction « sources inconnues » absente du profil supervisé (vérifié par `dumpsys`, deux tablettes)
- ⏳ Mise à jour réelle de bout en bout sous Family Link (étape 4, tâche 10)

## Étape 4 — Tranche verticale « Compter & calculer » (5–7 ans) 🔄

1. ✅ Squelette Flutter (`app/`) : thème, navigation (← retour ≠ Accueil), espace parent derrière une multiplication
2. ✅ `core/` : maîtrise 4/5, Leitner, 3 essais selon l'âge, journal, rapport — 12 tests unitaires
3. ✅ Contenu YAML (7 compétences sourcées sur les programmes officiels) + `tool/build_content.dart` (validation,
   graphe, `docs/voix/script.csv`, 51 phrases)
4. ✅ Accueil à voix off + fil rouge (pierre étoilée par séance finie, testé sur tablette)
5. ✅ Activité 1 : dénombrer (Flame) — testée sur tablette, y compris la démonstration après 3 erreurs (5 ans)
6. ✅ Activité 2 : composer (jetons carrés = déjà là, ronds = ajoutés) — testée sur tablette
7. ✅ Activité 3 : calcul, chiffres tracés au doigt reconnus par ML Kit (3 sur 3 sur tablette) ; trois choix sans modèle
8. ✅ Aide qui monte (indice → exemple → démonstration/indice) + retour descriptif + encouragement
9. ✅ Rapport des 7 derniers jours (espace parent), testé sur tablette
10. 🔄 Mise à jour depuis l'app : chaîne de signature vérifiée (`tool/release.sh` → test Dart) ; **pas encore testée de
    bout en bout** (première publication GitHub à faire par Antsa, `docs/RELEASING.md`)
11. ✅ CI GitHub Actions : contenu à jour, analyse, tests, APK < 60 Mo (`.github/workflows/app.yml`) — pas encore
    exécutée sur GitHub
12. ✅ Mesures (2026-11-02) : APK arm64 26,4 Mo ; démarrage à froid 471 / 473 ms ; mémoire 108–119 Mo à l'accueil,
    119–133 Mo en séance (tablettes A / B)
13. ✅ Écrans adaptatifs portrait/paysage (ADR 0013), testés sur la tablette B en paysage
14. ⏳ Activité 3 en paysage et composer en paysage : vérifier sur tablette (seul dénombrer l'a été)
15. ⏳ Voix enregistrées avant l'essai enfants (ADR 0002) — script : `docs/voix/script.csv`
16. ⏳ Essai avec 3–5 enfants (accord parental) → `docs/essai-01.md`
17. ⏳ Objets plus grands en paysage ; durée réelle d'une séance de 8 questions à mesurer

## Étape 4 bis — Univers visuels et contenu enrichi ✅ (2026-11-03)

- ✅ Design system `docs/design.md` (skill design-system), contrastes AA vérifiés par `app/tool/contrast.py`
- ✅ 6 univers selon le genre (ADR 0014) : robots, voitures, espace / fées, poupées & mode, princesses ; Twemoji + Andika
- ✅ Énoncé écrit + dit dans un bandeau narrateur à hauteur fixe (ADR 0016) ; consignes raccourcies (≤ 60 car.)
- ✅ Récompenses : étoiles, autocollants, album (ADR 0015), célébration aux objets de l'univers
- ✅ Phrases accordées à l'univers : genre (un/une, chacun/chacune), élision (d'engrenages), singulier pour 0 et 1
- ✅ Défauts corrigés et protégés par tests : grille de placement à 9 cases pour 10 objets, chevauchement possible
  d'objets voisins, « 1 couronnes », chemin du fil rouge peu visible, bouton inactif invisible sur fond de nuit
- ✅ Vérifié sur tablette : 6 univers (accueil + 1re question), choix du monde, album, composer (A portrait, B
  paysage), calcul avec démonstration ; 25 tests ; APK 27,9 Mo ; démarrage 0,48–0,66 s ; mémoire 125–145 Mo
- ⏳ Voix enregistrées : les phrases dépendent maintenant de l'univers et des nombres → la synthèse vocale reste
  nécessaire pour elles ; à décider (ADR 0002)
- ⏳ Essai avec les enfants : observer l'effet des autocollants sur l'intérêt pour l'activité (ADR 0015)

## Étape 5 — Thèmes suivants ⏳

Lecture/phonologie → écriture manuscrite → algorithmique → échecs/sudoku → photo d'objet → corps humain/nature →
création/dessin → anglais (place à fixer, ADR 0005). Pour chaque thème : revue des 4 piliers, mesure mémoire et APK.
