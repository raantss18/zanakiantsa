# CLAUDE.md — Zanak'i Antsa

> Application éducative hors ligne pour enfants de **5 à 10 ans** (GS → CM2, cycles 1-3 du programme français),
> en **français et malgache**. Relire ce fichier au début de chaque étape et après chaque `/compact`.
> Ordre en cas de conflit : ce fichier > `docs/adr/` > le reste.

## Règles qui ne se discutent pas

1. **Rien d'inventé.** Toute affirmation pédagogique, technique ou légale cite une source primaire (URL). Chaque
   livrable sépare **Vérifié / Supposé / Reste à tester**. Sans source : écrire « non vérifié ».
2. **Plan d'abord**, puis une tranche verticale minimale, puis élargissement. Jamais toutes les activités d'un coup.
3. **Rien casser.** Une décision = un ADR ≤ 15 lignes (`docs/adr/NNNN-titre.md`). Commits courts en français
   (Conventional Commits), chemins explicites (jamais `git add -A`), `main` toujours vert.
4. **Ne jamais dire « fini » sans l'avoir fait tourner** : tests, puis essai réel sur la tablette (ci-dessous).
5. **100 % hors ligne pour le cœur.** Aucun compte enfant, aucune pub, aucun achat intégré, aucune télémétrie :
   le journal d'événements reste sur l'appareil.
6. **Aucun secret dans Git** (clés de signature dans `release-keys/`, ignoré).
7. **Pas de copie** : on analyse ce qui est publiquement observable (fiches, docs, code open source). Aucun APK
   décompilé, aucun asset, texte ou personnage repris. Code AGPL (GCompris, Lichess) : inspiration d'architecture
   seulement, sauf ADR contraire.
8. **YouTube** : jamais de téléchargeur (Snaptube, etc.), jamais de cache hors ligne ; lecteur officiel seulement.
9. **Principes repris d'academik/COMIMa** : pas de vies ni de punition ; le bouton **← retour** (et le retour Android)
   ≠ le bouton **Accueil** ; cibles tactiles ≥ 48 dp ; clair et sombre ; une erreur signalée est corrigée à la
   cause, puis protégée par un test.

## Appareil de référence (mesuré le 2026-11-02 par `adb`)

Samsung Galaxy Tab A11 **SM-X135G** · Android 16 / One UI 8 · MediaTek MT8781 (8 cœurs) · RAM 3,7 Go
(≈ 1,1–1,3 Go disponibles en usage) · écran 800 × 1340 px, densité 280 · GLES 3.2, Vulkan 1 · caméra, micro.
Profil supervisé par **Family Link** (propriétaire du profil) : ne jamais le modifier ni le contourner.

## Budgets (⚠ hypothèses à recaler après la première mesure)

| Élément | Budget |
| --- | --- |
| APK de base | < 60 Mo |
| Pic de mémoire (PSS) | < 250 Mo |
| Démarrage à froid sur SM-X135G | < 3 s |
| Animations simples | 60 i/s |
| Cœur de l'app | 100 % hors ligne |

## Stack

**Non tranchée.** A priori Flutter (+ Flame pour les mini-jeux), comme l'app COMIMa ; à confirmer par un spike d'un
jour sur la tablette (ADR à venir). Outillage présent : Flutter 3.47.7 / Dart 3.13.5, SDK Android 36, JDK 17.

## Commandes

```bash
adb devices -l                    # la tablette doit apparaître en « device »
adb shell dumpsys meminfo <pkg>   # mémoire réelle de l'app
```

Les commandes de build et de test seront ajoutées ici quand la stack sera tranchée.

## Organisation

- `docs/vision.md` : quoi et pour qui. `docs/adr/` : décisions. `docs/teardown.md`, `docs/pedagogie.md`,
  `docs/conformite.md`, `docs/licences.md` : livrables des étapes 1 à 3.
- Format de compte rendu à chaque étape : résumé ≤ 5 lignes · fichiers créés · Vérifié / Supposé / Reste à tester ·
  sources (URL).
- Sous-agents pour la recherche parallèle (teardown, pédagogie, légal) ; le contexte principal sert à l'implémentation.
