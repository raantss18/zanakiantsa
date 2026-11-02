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

## Étape 4 — Tranche verticale « Compter & calculer » (5–7 ans) ⏳

1. ⏳ Squelette Flutter : thème, navigation (← retour ≠ Accueil), espace parent avec porte
2. ⏳ `core/` : maîtrise 4/5, Leitner, règle des 3 essais selon l'âge, journal — tests unitaires
3. ⏳ Format de contenu YAML + `tool/build_content.dart` (validation, graphe, script de voix)
4. ⏳ Écran d'accueil à voix off + fil rouge
5. ⏳ Activité 1 : dénombrer
6. ⏳ Activité 2 : composer des nombres (manipulation)
7. ⏳ Activité 3 : calcul mental, chiffres tracés à la main
8. ⏳ Échelle d'aides + retour audio
9. ⏳ Rapport hebdomadaire local (espace parent)
10. ⏳ Mise à jour depuis l'app (`release.json` signé, test sur tablette)
11. ⏳ CI : analyze, tests, contenu, taille d'APK < 60 Mo
12. ⏳ Mesures sur les deux tablettes (mémoire, premier rendu, parcours complet)
13. ⏳ Voix enregistrées avant l'essai enfants (ADR 0002)
14. ⏳ Essai avec 3–5 enfants (accord parental) → `docs/essai-01.md`

## Étape 5 — Thèmes suivants ⏳

Lecture/phonologie → écriture manuscrite → algorithmique → échecs/sudoku → photo d'objet → corps humain/nature →
création/dessin → anglais (place à fixer, ADR 0005). Pour chaque thème : revue des 4 piliers, mesure mémoire et APK.
