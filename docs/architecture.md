# Architecture — Zanak'i Antsa

> Flutter + Flame (ADR 0010). Tout ce qui est marqué ⚠ est un choix à mesurer, pas un fait établi.

## 1. Vue d'ensemble

```
content/*.yaml ──(tool/build_content.dart : valide + compile)──▶ assets/content/*.json
                                                                   │
lib/                                                               ▼
  core/      moteur pur Dart, sans Flutter : graphe de compétences, maîtrise, Leitner, règles d'aide, journal
  content/   chargement des paquets JSON, modèles typés
  activities/  une activité = un type (dénombrer, composer, tracer…) : widget Flutter + jeu Flame si besoin
  audio/     voix : fichier enregistré si présent, sinon synthèse fr-FR (ADR 0002) ; sons courts
  ui/        thème, écran d'accueil enfant (fil rouge), fin de séance
  parent/    espace parent (porte par petit calcul), réglages, rapport local
  store/     SQLite (journal d'événements en ajout seul + états dérivés)
  update/    mise à jour de l'app et des paquets de contenu par l'app elle-même (ADR 0011)
```

Règle : `core/` ne dépend de rien d'autre que Dart ; il est testé à 100 % par des tests unitaires.

## 2. Données (100 % locales)

- **SQLite via `sqflite`** (BSD-2-Clause) plutôt que Drift (MIT, mais génération de code `build_runner`) : moins
  d'outillage pour un développeur seul. ⚠ À revoir si les requêtes se compliquent.
- **Journal d'événements en ajout seul** (repris d'academik D-007) : `réponse(compétence, variante, essai, aide,
  durée, juste)`, `séance(début, fin)`. Rien n'est jamais modifié ni envoyé.
- **États dérivés** recalculables depuis le journal : boîte de Leitner par compétence, fenêtre des 5 dernières
  questions (maîtrise ≥ 4/5, ADR 0007), position sur le fil rouge.
- **Profil** : prénom facultatif, âge (pour ADR 0006), réglages. Pas de compte, pas d'identifiant.

## 3. Contenu séparé du code

- Une compétence = un fichier YAML dans `content/<thème>/` : id stable, cycle et niveau (GS→CM2), prérequis,
  type d'activité, paramètres, variantes, phrases dites (id de voix stable), aides (3 niveaux), démonstration.
- `tool/build_content.dart` : **valide** (schéma versionné écrit à la main en Dart — le paquet `json_schema` a une
  licence non déclarée sur pub.dev, écarté), vérifie que chaque prérequis existe, que le graphe n'a pas de cycle, que
  chaque phrase a un id ; puis écrit un paquet JSON par thème dans `assets/content/`. Le build échoue sinon.
- Le même outil génère `docs/voix/script.csv` (phrases à enregistrer, ADR 0002).

## 4. Moteur pédagogique (`core/`)

| Règle | Source |
| --- | --- |
| 3 essais, aide croissante ; après le 3e : démonstration si < 6 ans, indice sinon | ADR 0006 |
| Maîtrise = ≥ 4 réussites sur les 5 dernières questions (réussie = dans les 3 essais, sans démonstration ⚠) | ADR 0007 |
| Révisions : 5 boîtes de Leitner, intervalles ⚠ 1-2-4-8-16 j ; réussite → boîte suivante, échec → boîte 1 | ADR 0007 |
| Séance : révisions dues d'abord, puis une compétence nouvelle dont les prérequis sont maîtrisés ; fin claire | `docs/pedagogie.md` |
| Fil rouge : avance à chaque séance terminée, ne recule jamais | `docs/vision.md` |
| Retour : descriptif + encouragement ; aucun son négatif | ADR 0008 |

## 5. Rendu et performances

- Interface en widgets Flutter ; **Flame** seulement dans les activités animées (objets à toucher, déplacer).
- Rendu GPU **Vulkan** (Impeller) vérifié dans le journal à chaque version ; écran 90 Hz (`spikes/RESULTATS.md`).
- Dessins **générés par code** (formes, comme le spike) plutôt qu'images lourdes, à l'image d'academik (D-018/D-023).
- Voix enregistrées en Opus/OGG ⚠ mono, pour tenir l'APK < 60 Mo.

## 6. Navigation et écrans

- **← retour** (et bouton retour d'Android) ≠ **Accueil** (repris d'academik D-022).
- Écran enfant : pictogrammes + voix, bouton haut-parleur pour réécouter ; aucune lecture obligatoire pour 5–6 ans.
- Espace parent : derrière une petite opération à résoudre ; réglages (âge, volume), rapport hebdomadaire local,
  téléchargement unique des modèles ML Kit (ADR 0009).

## 7. Mises à jour (ADR 0011)

L'app télécharge elle-même `release.json` (signé Ed25519), puis l'APK (SHA-256 vérifié), et lance l'installateur
Android ; même chaîne pour les paquets de contenu. Proposée seulement dans l'espace parent, jamais bloquante.

## 8. Qualité

- Tests : `core/` en unitaires (règles des ADR 0006-0008), widgets clés, captures de référence (golden).
- CI GitHub Actions : `flutter analyze`, `flutter test`, `dart run tool/build_content.dart --check`, build APK release
  et **échec si l'APK dépasse 60 Mo**.
- Essai réel sur les deux SM-X135G avant de dire « fini » (ADR 0004) : mémoire (`dumpsys meminfo`), premier rendu,
  parcours complet.

## Vérifié / Supposé / Reste à tester

- **Vérifié** : licences et versions des paquets (pub.dev, 2026-11-02, `docs/licences.md`) ; rendu Vulkan et budgets
  tenus par Flutter + Flame sur la tablette (spike).
- **Supposé** ⚠ : intervalles de Leitner, format audio, `sqflite` suffisant, définition de « question réussie ».
- **Reste à tester** : ML Kit sous Flutter sur la tablette ; poids réel des voix enregistrées.
