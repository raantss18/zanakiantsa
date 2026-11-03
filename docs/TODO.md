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
- ✅ Calcul aux couleurs du monde : objets du monde sous les nombres, énoncé-histoire avec la mascotte (« Robi a 1
  engrenage. Il en arrive 5. Combien en tout ? »), résultat trouvé affiché dans la case ; a et b ≥ 1 dans les histoires
- ✅ Scène de réussite propre à chaque monde, vérifiée en capture sur les 6 mondes (2026-11-03)
- ✅ Fil d'histoire (8 épisodes par monde, un par séance finie) et bruitages par monde synthétisés par code (ADR 0017) ;
  vérifié sur tablette A (robots) : épisode en fin de séance et à l'accueil, son joué (lecteur à 22 050 Hz relevé) ; 27 tests
- ✅ Vérifié sur l'émulateur `zanakiantsa_tab` (Android 16, 800 × 1340) : monde des fées, épisodes 1 à 3, sons joués,
  fin de séance et accueil en paysage (densité de la tablette B)
- ✅ Version 0.2.0 publiée (2026-11-03, `app-v0.2.0`, build 2002) ; sur l'émulateur, la 0.1.0 trouve, télécharge et
  vérifie la 0.2.0 puis ouvre l'installateur Android ; la dernière étape (autoriser « sources inconnues ») reste à
  faire par Antsa, réglage de sécurité
- ⏳ Mesures mémoire / démarrage / fluidité de la 0.2.0 : impossibles sans tablette physique (l'émulateur ne les reproduit pas)
- ⏳ Voix enregistrées : les phrases dépendent maintenant de l'univers et des nombres → la synthèse vocale reste
  nécessaire pour elles ; à décider (ADR 0002)
- ⏳ Essai avec les enfants : observer l'effet des autocollants sur l'intérêt pour l'activité (ADR 0015)

## Étape 4 ter — Journée en 3 activités et nouveaux domaines 🔄 (2026-11-03)

- ✅ Journée de 3 activités qui alternent (nombres / vivant / dessin, puis suites / sons / échecs), temps réglé par
  le parent (90 min par défaut), pause entre deux, « À demain » (ADR 0018)
- ✅ Nouveaux domaines (ADR 0019) sourcés sur le programme de maternelle consolidé 2026 et les règles FIDE :
  vivant (4 compétences, 21 questions), suites (4), sons (4), dessin (8 sujets, « Mes dessins »), échecs (5 pièces)
- ✅ Vérifié sur l'émulateur : accueil portrait et paysage, vivant (bonne/mauvaise réponse), dessin jusqu'à
  l'album, suites, sons (lecture des deux sons), échecs (coup interdit → points) ; 38 tests
- ⏳ Pas vérifié : passage de la pause et de « journée finie » en conditions réelles (il faut 30 min par activité ;
  couvert par les tests unitaires du temps compté), cavalier et dame jusqu'au bout, sons en paysage
- ⏳ Voix enregistrées pour les nouvelles phrases (`docs/voix/script.csv`)

## Priorités demandées par Antsa (2026-11-03) ✅ première tranche de chacune

1. ✅ **Cours d'échecs** (ADR 0020) : 13 leçons, des déplacements au mat en un coup ; ⏳ parties contre l'app, roque,
   promotion
2. ✅ **Bâtonnets, multiplication, partage** (ADR 0021) : 12 compétences CP–CE2, dont soustraire en cassant une
   dizaine, faire des paquets (combien de parts ?), tables de 6 à 9 (2026-11-03) ; ⏳ addition et soustraction posées
3. ✅ **Anglais** (ADR 0022) : couleurs, nombres, animaux, corps ; ⏳ recaler sur le programme publié au BO (source
   actuelle : projet de juin 2025), voix anglaise hors ligne sur la tablette
4. ✅ **Exploration 3D sur GPU** (ADR 0024) : système solaire et corps ; ⏳ organes, fluidité sur vraie tablette
5. ✅ **Programmer un robot par blocs** (ADR 0023) ; ⏳ boucles, programmes libres type Scratch
6. ✅ **Solides en 3D** (ADR 0024) ; ⏳ manipulation libre type GeoGebra
- ✅ 3e journée : anglais / code / explorer (les journées tournent sur 3 jours, ADR 0018)
- ✅ Vérifié sur l'émulateur : mat en un coup, bâtonnets (lire, construire), paquets, partage, tables, solide 3D,
  planètes, corps, robot (programme faux puis juste), anglais (voix en-GB utilisée) ; 47 tests
- ✅ Version 0.3.0 publiée (2026-11-03, build 2003) ; montée 0.2.0 → 0.3.0 vérifiée sur l'émulateur (base v1 → v2,
  réglages conservés)
- ✅ Corrigé : une voix de synthèse muette bloquait la séance (attente sans fin de la fin de phrase) → chaque attente
  de voix est bornée (`speechBudget`)
- ✅ Interrupteurs voix / musique dans chaque leçon, trame sonore douce par monde (ADR 0025)
- ✅ Bibliothèque hors ligne (ADR 0026) : 55 livres African Storybook (CC BY 4.0), 6 étagères dont « Curiosité » et
  « Pour les grands » (niveaux 4–5), liseuse avec « Lis-moi », marque-page par livre, « Mon livre en cours »
- ✅ Corrigé (signalé par Antsa sur téléphone) : noms des cartes du jour coupés (« Les n… ») → carte compacte sous
  440 dp ; rangée du bas, carte « livre en cours » et choix d'images revus ; vérifié au format téléphone
  (1080 × 2400, densité 440, police 115 %)
- ✅ Version 0.4.0 publiée (2026-11-03, build 2004)
- ✅ Identité visuelle « autocollant » : logo-texte, icône adaptative et monochrome, écran de démarrage, titres
  (ADR 0027) ; ressources : pause du son en arrière-plan, polices réduites, caches bornés (ADR 0028)
- ✅ Retours d'Antsa du 2026-11-03 : calcul qui se répète → tirage sans répétition et énoncés variés (ADR 0030) ;
  « Lire et écrire » (ADR 0031) ; questions de sciences trop redondantes → 55 questions et 2 compétences de plus
  (milieux de vie, besoins) ; « Tout explorer » (ADR 0032) ; animation de méthode par domaine (ADR 0033) ; profils
  enfants et point de départ selon l'âge (ADR 0034) ; contenu CE1 (ADR 0035)
- ✅ Suites de nombres (de 1, 2, 10 en 10 ; à rebours ; bande jusqu'à 1000) et états de l'eau (CP, CE1), ADR 0036
- ✅ Version 0.6.0 publiée (2026-11-03, build 2006) ; montée 0.5.0 → 0.6.0 vérifiée sur l'émulateur (réglages repris
  dans le profil « Enfant 1 »)
- ⏳ Sens du tracé des lettres ; test de départ par domaine ; plus de contenu CE1-CE2 (sons, anglais, problèmes)
- ✅ Version 0.5.0 publiée (2026-11-03, build 2005) ; montée 0.4.0 → 0.5.0 vérifiée sur l'émulateur
- ✅ Pédagogie inspirée de Brilliant (ADR 0029) : découverte guidée (idée + exemple résolu) à la première rencontre
  de 51 compétences ; erreurs expliquées (nombres, échecs, robot) ; erreurs typiques proposées en priorité
- ⏳ Test de départ par domaine (sauter ce qui est déjà su) ; explications pour les réponses en images
- ⏳ APK 45 Mo avec les livres (budget 60 Mo) : au-delà, proposer des livres en téléchargement depuis l'app
- ⏳ Contenu de cycle 3 pour les plus grands (au-delà des livres) : à planifier
- ⏳ Voix enregistrées pour toutes les nouvelles phrases ; essai avec l'enfant

## Avant la version 0.7.0 — retours d'Antsa sur téléphone (2026-11-03), par ordre de priorité

Aucune publication tant que toute cette liste n'est pas faite et vérifiée sur l'émulateur (tablette et téléphone).

1. ✅ **Blocage** : exercice d'écoute figé, voix coupée — tout appel au son est borné et ses erreurs rattrapées ;
   l'état « occupé » est toujours libéré (`test/sound_bounded_test.dart`).
2. ✅ **Voix** : le français dit avec l'accent anglais après l'anglais — un seul moteur de synthèse, langue réglée
   avant chaque phrase (ADR 0037). ⏳ à confirmer à l'oreille sur le téléphone.
3. ✅ **Reprendre où l'enfant s'est arrêté** (ADR 0039) : sortir d'un domaine en cours de séance puis y revenir reprend à la même
   question (même plan, mêmes étoiles), sans recommencer au début.
4. ✅ **Ennui** : séance entrelacée (une question sur trois sur ce qui est acquis), compétence acquise = on passe à la
   suivante (ADR 0037) ; corps humain posé par l'usage et les vêtements.
5. ✅ **Consignes** : toutes réécrites — quoi faire, comment répondre, quand c'est réussi (ADR 0037).
6. ✅ **Dessin** : sujets précis avec critères ; vérifié (traits, taille, puis modèle de dessins sur l'appareil) ;
   pas reconnu → « On dirait plutôt… » et ce qu'il manque ; plus de « Bravo » pour un gribouillis (ADR 0038).
7. ✅ **Fin de série** : « Continuer » (flèche vers l'avant, « nouvelles questions ») au lieu de « Encore » ↻.
8. ✅ **Bandeau « Nouveau »** qui débordait sur téléphone.
9. ✅ **Échecs** : ✅ jouer contre le robot (niveaux) ou à deux ; ✅ parties enregistrées ; ✅ analyse des parties (pièce
   laissée en prise, mat manqué, prise gratuite manquée), ADR 0040 ; ✅ leçons avancées : roque, promotion, prise en passant,
   fourchette, pièce non protégée, mat du couloir (règles : FIDE ; tactiques : positions vérifiées par le moteur, `test/problems_test.dart`). Corrigé au passage :
   les pièces noires autres que roi et pion étaient invisibles (images manquantes).
10. ✅ **Programmation type Scratch** : blocs emboîtés « répéter n fois », « répéter jusqu'à l'objet », « si rocher
    devant » (ADR 0041). ⏳ variables (« compteur ») : plus tard.
11. ✅ Même profondeur pour chaque domaine (ADR 0042) : accueil de domaine (apprendre, défi avec record, mon
    carnet), erreurs gardées au journal et montrées à l'enfant et au parent, anglais CE1. ⏳ Sons au-delà de la GS :
    source à trouver.
12. ✅ **Son** (retour du 2026-11-03 au soir) : la voix ne continue plus après avoir quitté un écran ni en
    arrière-plan ; une erreur du moteur ne laisse plus de longs silences ; « La voix » dans l'espace parent (moteur,
    essai, conseil) — ADR 0043. ⏳ À confirmer à l'oreille sur le téléphone.
13. ⏳ Version 0.7.0 : tests, émulateur tablette + téléphone, publication après accord d'Antsa.

## Étape 5 — Thèmes suivants ⏳

Lecture/phonologie → écriture manuscrite → algorithmique → échecs/sudoku → photo d'objet → corps humain/nature →
création/dessin → anglais (place à fixer, ADR 0005). Pour chaque thème : revue des 4 piliers, mesure mémoire et APK.
