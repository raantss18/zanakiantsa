# CLAUDE.md — Zanak'i Antsa

> Application éducative hors ligne pour enfants de **5 à 10 ans** (GS → CM2, cycles 1-3 du programme français),
> interface **en français**, avec l'**anglais** comme thème d'apprentissage (ADR 0005). Relire ce fichier au début de chaque étape et après chaque `/compact`.
> Ordre en cas de conflit : ce fichier > `docs/adr/` > le reste.

## Règles qui ne se discutent pas

1. **Rien d'inventé.** Toute affirmation pédagogique, technique ou légale cite une source primaire (URL). Chaque
   livrable sépare **Vérifié / Supposé / Reste à tester**. Sans source : écrire « non vérifié ».
2. **Plan d'abord**, puis une tranche verticale minimale, puis élargissement. Jamais toutes les activités d'un coup.
3. **Rien casser.** Une décision = un ADR ≤ 15 lignes (`docs/adr/NNNN-titre.md`). Commits courts en français
   (Conventional Commits), chemins explicites (jamais `git add -A`), `main` toujours vert.
4. **Ne jamais dire « fini » sans l'avoir fait tourner** : tests, puis essai sur l'émulateur `zanakiantsa_tab`
   (ci-dessous) ; depuis le 2026-11-03, plus de tablette physique disponible pour les essais.
5. **100 % hors ligne pour le cœur.** Aucun compte enfant, aucune pub, aucun achat intégré, aucune télémétrie de
   l'app : le journal d'événements reste sur l'appareil. Ni image, ni voix, ni tracé ne quitte l'appareil ;
   **exception connue** : ML Kit envoie à Google des statistiques techniques d'usage (ADR 0012, `docs/conformite.md`).
6. **Aucun secret dans Git** (clés de signature dans `release-keys/`, ignoré).
7. **Pas de copie** : on analyse ce qui est publiquement observable (fiches, docs, code open source). Aucun APK
   décompilé, aucun asset, texte ou personnage repris. Code AGPL (GCompris, Lichess) : inspiration d'architecture
   seulement, sauf ADR contraire.
8. **YouTube** : jamais de téléchargeur (Snaptube, etc.), jamais de cache hors ligne ; lecteur officiel seulement.
9. **Le site suit l'app** (demande d'Antsa, ADR 0055) : toute mise à jour ou nouvelle de l'app se voit automatiquement sur
   https://raantss18.github.io/zanakiantsa/, sans geste à la main. Publier avec `tool/publish.sh` ; une nouvelle sans
   version va dans `site/notes.json`. Les notes de version s'affichent telles quelles : les écrire pour des parents.
10. **Principes repris d'academik/COMIMa** : pas de vies ni de punition ; le bouton **← retour** (et le retour Android)
   ≠ le bouton **Accueil** ; cibles tactiles ≥ 48 dp ; clair et sombre ; une erreur signalée est corrigée à la
   cause, puis protégée par un test.

## Appareil de référence (mesuré le 2026-11-02 par `adb`)

Samsung Galaxy Tab A11 **SM-X135G** · Android 16 / One UI 8 · MediaTek MT8781 (8 cœurs) · RAM 3,7 Go
(≈ 1,1–1,3 Go disponibles en usage) · écran 800 × 1340 px, densité 280 · GLES 3.2, Vulkan 1 · caméra, micro.
Profil supervisé par **Family Link** (propriétaire du profil) : ne jamais le modifier ni le contourner.

**Émulateur d'essai** (AVD `zanakiantsa_tab`) : Android 16 x86_64 avec traduction ARM (`libndk_translation`, l'APK
arm64 s'installe tel quel), écran 800 × 1340, densité 280 comme la SM-X135G. Tablette B (paysage, sw601) :
`adb shell wm density 213` puis relancer l'app. Lancement :
`ANDROID_SDK_ROOT=$HOME/Android/Sdk ~/Android/Sdk/emulator/emulator -avd zanakiantsa_tab -no-snapshot -gpu swiftshader_indirect`
(le GPU de l'ordinateur via gfxstream fait planter l'émulateur au redémarrage de l'app, 2026-11-03).
Format téléphone : `adb shell wm size 1080x2400 && adb shell wm density 440` (+ `settings put system font_scale
1.15`), puis `wm size reset`, `wm density reset`.
⚠ D'autres projets ont leurs émulateurs sur ce poste : avant toute commande, vérifier le nom avec `adb -s <série> emu avd name`.
⚠ L'émulateur ne mesure ni la mémoire, ni le démarrage, ni la fluidité de la SM-X135G (GPU et CPU différents).

## Budgets (⚠ hypothèses à recaler après la première mesure)

| Élément | Budget |
| --- | --- |
| APK de base | < 60 Mo |
| Pic de mémoire (PSS) | < 250 Mo |
| Démarrage à froid sur SM-X135G | < 3 s |
| Animations simples | 60 i/s |
| Cœur de l'app | 100 % hors ligne |

## Stack

**Flutter + Flame** (`docs/adr/0010`, accepté), choisi après le spike comparatif mesuré sur les deux
tablettes (`spikes/RESULTATS.md`). **Rendu GPU** : Vulkan (Mali-G57 MC2) ; vérifier le moteur dans le journal à chaque
version, ne jamais forcer le rendu logiciel. Écran 90 Hz. Voix : TTS pour prototyper, voix enregistrées avant tout essai avec des enfants (`docs/adr/0002`).
Outillage présent : Flutter 3.47.7 / Dart 3.13.5, SDK Android 36, JDK 17.

## Commandes

```bash
cd app
dart run tool/build_content.dart          # content/*.yaml → assets/content/*.json + docs/voix/script.csv
flutter analyze && flutter test           # avant tout commit
flutter build apk --release --split-per-abi --target-platform android-arm64
adb -s <série> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
flutter build apk … --dart-define=DEV_SKILL=<id>   # essai d'une compétence précise (jamais publié)
adb shell dumpsys meminfo mg.zanakiantsa.app       # mémoire réelle
tool/release.sh "notes"                   # version signée (voir docs/RELEASING.md)
```

Paquet Android : `mg.zanakiantsa.app`, activité `mg.zanakiantsa.zanakiantsa.MainActivity`.

## Organisation

- **`docs/TODO.md`** : la liste des tâches, seule source d'avancement, mise à jour à chaque tâche.
- **Mises à jour** : uniquement par l'app elle-même (ADR 0011), jamais par un store ni un APK copié à la main.
- `docs/vision.md` : quoi et pour qui. `docs/adr/` : décisions. `docs/teardown.md`, `docs/pedagogie.md`,
  `docs/conformite.md`, `docs/licences.md` : livrables des étapes 1 à 3.
- Format de compte rendu à chaque étape : résumé ≤ 5 lignes · fichiers créés · Vérifié / Supposé / Reste à tester ·
  sources (URL).
- Sous-agents pour la recherche parallèle (teardown, pédagogie, légal) ; le contexte principal sert à l'implémentation.
