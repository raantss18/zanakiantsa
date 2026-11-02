# Teardown — applis existantes

> Étape 1. But : **combiner et améliorer** sans copier. Méthode : uniquement ce qui est **publiquement observable**
> (fiches stores, sites officiels, documentation, études publiées, code open source). Aucun APK décompilé, aucun asset,
> texte ou personnage repris. Toutes les URL ont été consultées le **2026-11-02** (statut dans [Sources](#sources)).
>
> Légende : **V** = vérifié (source lue, numéro entre crochets) · **S** = supposé · **NV** = non vérifié.
> Une fiche store (« déclaré par l'éditeur ») reste une déclaration, pas un audit.

## Résumé (5 lignes)

1. Les meilleures preuves d'efficacité viennent de **onebillion** (essai randomisé au Malawi, revue à comité de lecture [7]).
2. **Kolibri** (MIT) et **Seek** montrent qu'un usage 100 % hors ligne et sans compte est faisable [12][14][27].
3. **Duolingo** publie ses chiffres de rétention : la série (streak) marche, mais repose sur l'aversion à la perte [9].
4. Aucune appli analysée ne propose le **malgache** de façon vérifiée ; GCompris ne l'a pas dans ses traductions [26].
5. Code AGPL (GCompris, Lichess) : inspiration seulement. Mais la **base de puzzles Lichess est CC0** [20].

---

## 1. Khan Academy Kids

- **Public** — V : 2–8 ans sur l'App Store [2] ; Common Sense : 3+, contenu maternelle → CP, un peu de CE1 [29].
- **Boucle de jeu** — V : un « learning path » enchaîne les activités ; l'enfant peut aussi parcourir vidéos, jeux,
  livres, chansons [29]. Personnages animaux guides [2][29].
- **Mécanique pédagogique** — V : maths, lecture, phonologie, logique, socio-émotionnel, créativité [29] ;
  conçu avec Stanford GSE, aligné Head Start / Common Core (déclaré) [2].
- **Feedback sur l'erreur** — NV (Common Sense ne le décrit pas [29]).
- **Progression / adaptation** — V : le parcours s'adapte à l'âge et aux performances passées [29]. Algorithme : NV.
- **Rétention** — V : après une activité, l'enfant choisit un prix pour la collection des personnages [29]. Série : NV.
- **Modèle / données** — V : « 100 % gratuit, sans pub, sans abonnement » [2]. Compte parent avec e-mail requis [29].
  Données déclarées non liées à l'identité, dont analytics (ID utilisateur, ID appareil, interactions) [2].
- **Hors ligne** — V : livres et jeux téléchargeables pour jouer sans Wi-Fi [2]. Partiel, pas tout le contenu (S).
- **Faiblesses** — V : bugs signalés par des parents [29] ; micro requis pour certaines activités [29].
  Langues de lecture : anglais ou espagnol [2]. Français / malgache : NV.
- **On garde** : récompense liée aux personnages, pas de pub. **On fait mieux** : aucun compte, aucune analytics,
  tout le contenu embarqué dans l'APK.

## 2. Duolingo ABC + mécanique Duolingo

### Duolingo ABC
- **Public** — V : préscolaire → CE1 (« second grade »), « Made for Ages 0–5 » [10]. Âges cités ailleurs divergents (NV).
- **Boucle de jeu** — V : leçons courtes (« bite-sized ») ; tracé de lettres, glisser-déposer ; histoires lues à voix
  haute avec surlignage du mot prononcé [10].
- **Mécanique pédagogique** — V : alphabet, phonique, mots-outils, vocabulaire [10]. Une paire lettre-son par série
  de leçons : NV (source sponsorisée, non lue en entier).
- **Feedback sur l'erreur** — NV.
- **Progression** — V : plus de 700 leçons [10]. Adaptation : NV.
- **Rétention** — V : étoiles et récompenses, personnages récurrents [10].
- **Modèle / données** — V : gratuit, sans pub [10]. Données liées à l'utilisateur : usage et diagnostics, pour
  analytics (déclaré) [10]. Achats intégrés : aucun mentionné [10].
- **Hors ligne** — V : leçons et jeux utilisables hors ligne [10].
- **Faiblesses** — V : anglais seulement [10]. Date de sortie Android : NV (sources contradictoires, 2022/2023/2024).
- **On garde** : histoire lue avec surlignage du mot. **On fait mieux** : français + malgache, sans analytics.

### Duolingo général : série, gel, chemin
- **Série (streak)** — V : compteur de jours consécutifs avec une leçon [9]. Les apprenants à 7 jours de série ont
  3,6 fois plus de chances de finir leur cours (chiffre de l'éditeur) [9].
- **Gel de série** — V : un jour manqué ne remet pas la série à zéro ; jusqu'à **deux** gels équipés ; cela a augmenté
  les apprenants actifs quotidiens de 0,38 % (relatif) [9]. Prix du gel en gemmes : NV (sources non officielles).
- **Aversion à la perte** — V : Duolingo écrit que la motivation se déplace vers « protéger » la série [9].
  L'article ne parle pas d'enfants [9].
- **Chemin** — V : depuis le 1er novembre 2022, chemin linéaire en unités, ordre fondé sur la répétition espacée,
  révisions intégrées au chemin et comptées comme progression [13]. Critique : perte du choix de la leçon (NV, NBC
  non lu).
- **On garde** : chemin linéaire + révision espacée intégrée ; célébration des paliers.
  **On fait mieux** : pas de série qu'on perd (choix de `vision.md`) ; un « fil rouge » qui ne recule jamais (S :
  intérêt à tester).

## 3. Simply Piano

- **Public** — V : « tous âges », note 4+ [34]. Pas d'âge enfant précis sur le site famille [36].
- **Boucle de jeu** — V : l'appli reconnaît ce qu'on joue (piano acoustique, MIDI, clavier) ; clavier à l'écran
  possible [34]. Parcours : Piano Basics, Essentials 1–3, puis choix Soliste / Accords [16].
- **Mécanique pédagogique** — V : un critique juge l'apprentissage trop « par cœur » et simplifié [16].
- **Feedback sur l'erreur** — V : notes vertes (juste), rouges (fausse), jaunes (aidé après hésitation) ; le rythme
  et la durée des notes ne sont **pas** jugés ; mode « Wait for me » qui attend la bonne note (mode Pratique) [16].
- **Progression** — V : structure peu claire après le niveau débutant selon le critique [16]. Adaptation : NV.
- **Rétention** — V : « récompenses dans l'appli » (site de l'éditeur, sans détail) [36].
- **Modèle / données** — V : 2 cours gratuits puis abonnement ; renouvellement automatique [34]. Essai de 14 jours
  avec moyen de paiement demandé [16]. Identifiants utilisés pour le **suivi entre applis** ; données audio liées
  à l'utilisateur (déclaré) [34]. Plan famille : 5 profils [36].
- **Hors ligne** — NV.
- **Faiblesses** — V : reconnaissance par micro jugée inconstante, le critique conseille le MIDI [16] ; pas de
  statistiques de progrès [16]. Le site de l'éditeur ne cite aucune étude [36].
- **On garde** : code couleur juste / faux / aidé ; « attendre la bonne note ».
  **On fait mieux** : pas de paywall ; pas de couleur seule (forme + son en plus) ; tolérance réglable au micro (S).

## 4. GCompris (open source, AGPL)

- **Public** — V : 2–10 ans, plus de 100 activités [1][21].
- **Boucle de jeu** — V : menu d'activités par catégories (ordinateur, lecture, maths, sciences, géographie, jeux…)
  [21] ; chaque activité a son propre schéma de jeu et une barre d'état commune [26].
- **Mécanique pédagogique** — V : activités variées (couleurs, formes, braille, heure…) [21]. Fondement didactique : NV.
- **Feedback sur l'erreur** — NV. V : certaines activités demandent de valider avec « OK » [38].
- **Progression** — V : étoiles jaunes (1–3) = 2–6 ans, rouges (1–3) = plus de 6 ans ; plusieurs niveaux par
  activité, changés avec des flèches ; on peut passer au niveau suivant sans finir [38]. Pas d'adaptation
  automatique décrite (NV).
- **Rétention** — NV.
- **Modèle / données** — V : libre, dons et mécénat [1][21]. Politique de confidentialité : page en 404 (NV).
- **Hors ligne** — NV directement. Les voix seraient des paquets téléchargeables au premier lancement (extrait de
  recherche, manuel non lu : NV).
- **Technique** — V : QtQuick, réécriture complète [26] ; mode kiosque en ligne de commande (désactive Quitter et
  Configuration) [38]. Licence AGPL v3 [1][26] : **réutiliser son code imposerait l'AGPL** à Zanak'i Antsa.
- **Langues** — V : 24 langues traduites à 100 % en 26.1, dont le français ; **malgache absent** des listes [33].
- **Faiblesses** — S : catalogue large mais sans parcours guidé ni seuil de maîtrise (rien de tel dans [38]).
- **On garde** (idées) : étoiles par tranche d'âge, barre d'état commune, mode kiosque.
  **On fait mieux** : parcours guidé + maîtrise ; malgache ; voix embarquées.

## 5. Kolibri (Learning Equality)

- **Public** — V : K-12, plateforme pour enseigner sans Internet [12]. Pas spécifique 5–10 ans.
- **Boucle de jeu** — V : l'enseignant (« coach ») assigne leçons et quiz ; tableau de bord en temps réel [12].
- **Mécanique pédagogique** — V : bibliothèque de ressources ouvertes, plus de 173 langues ; les éducateurs peuvent
  remixer et créer [6][12].
- **Feedback sur l'erreur** — V : retour immédiat sur les évaluations [12] ; indices optionnels par question [28].
- **Progression** — V : modèle de maîtrise **m sur n** (m bonnes réponses sur n) ; si rien n'est précisé, m = n =
  nombre de questions plafonné à 5 [28]. La maîtrise suit la progression, pas la performance (glossaire : NV, non lu).
- **Rétention** — NV.
- **Modèle / données** — V : gratuit, open source [6][12] ; code sous **MIT** [35]. Données de l'appli Android
  restent sur l'appareil sauf synchro (extrait de recherche : NV).
- **Hors ligne** — V : « offline-first » ; contenu par USB ou pair-à-pair ; appli Android ≥ 6 ; synchro maison →
  école [12]. 4 700 installations, plus de 100 pays (chiffres du dossier MIT Solve) [6].
- **Faiblesses** — V : le matériel et l'électricité restent des freins [6]. S : pensé pour une classe avec
  enseignant, pas pour un enfant seul de 5 ans.
- **On garde** : contenu en fichiers séparés du code, modèle m sur n, synchro optionnelle.
  **On fait mieux** : interface enfant seul, pictogrammes et voix.
  Licence MIT : réutilisation légalement possible avec mention (décision à prendre par ADR).

## 6. Lichess (échecs, AGPL)

- **Public** — V : tous publics, gratuit, sans pub, associatif [4]. Pas de mode enfant décrit (NV).
- **Boucle de jeu** — V : « tactic trainer » (puzzles) [4] ; chaque tentative compte comme une partie classée
  Glicko-2 entre le joueur et le puzzle [20].
- **Mécanique pédagogique** — V : puzzles tirés de 600 millions de parties, réanalysés par Stockfish NNUE, étiquetés
  par thème (« mate », « fork »…) [20].
- **Feedback sur l'erreur** — NV (billet de blog en 403).
- **Progression** — V : la cote Glicko-2 du joueur et celle du puzzle s'ajustent [20] → difficulté adaptée (S :
  mécanisme de sélection exact NV).
- **Rétention** — NV.
- **Modèle / données** — V : dons, sponsors [4]. **Base de 6 193 530 puzzles sous CC0**, réutilisable pour tout
  usage [20].
- **Hors ligne** — NV (site web et serveur).
- **Technique** — V : Scala 3, MongoDB, Elasticsearch, WebSockets, Stockfish distribué [4]. Licence **AGPL** [4] :
  inspiration d'architecture seulement.
- **Faiblesses** — S : puzzles d'adultes, notation, aucun scénario pour un enfant de 6 ans.
- **On garde** : cote Glicko-2 joueur/exercice, étiquettes de thème. **On fait mieux** : filtrer la base CC0 (thèmes
  « mat en 1 », cotes basses) pour les enfants — S, à vérifier puzzle par puzzle.

## 7. onebillion (maths adaptatif, Malawi)

- **Public** — V : élèves de Standards 1–3 à Lilongwe (étude) [7]. Site : lecture et numératie de base [23].
- **Boucle de jeu** — V : l'enfant avance à son rythme et peut refaire les activités à volonté [7].
- **Mécanique pédagogique** — V : apps *Masamu 1, Masamu 2, Count to 10, Count to 20*, en chichewa [7] ;
  9 blocs d'items puis un quiz de révision cumulatif [7].
- **Feedback sur l'erreur** — V : immédiat ; son « négatif » à l'erreur, son « positif » et coche jaune à la
  réussite [7].
- **Progression** — V : passage au bloc suivant seulement après un quiz réussi à **100 %** [7]. Le logiciel actuel
  *onecourse* est « adaptatif » [23].
- **Rétention** — V : les enseignants suivaient les progrès avec des tableaux d'étoiles [7].
- **Modèle / données** — V : association à but non lucratif ; pas de login personnel, aucune donnée personnelle
  d'enfant collectée (déclaré) [23].
- **Hors ligne** — V : tablettes *onetab* hors ligne, rechargeables au solaire [23].
- **Preuves (article revu)** — V : Pitchford 2015, *Frontiers in Psychology* 6:485, essai randomisé, 8 semaines,
  283 enfants analysés ; effet significatif en Standards 2 et 3 sur le contenu enseigné (d = 1,12 et 1,70) et en
  Standard 3 sur un test papier de généralisation (d = 0,82) ; pas d'effet significatif en Standard 1 [7].
  Limites déclarées : une seule école, post-test sur tablette, items proches des quiz, faible puissance [7].
  Le communiqué de 2017 annonce « 2–4 mois d'avance » après 12 semaines sans citer d'article [5].
  Financement partiel via une subvention attribuée à EuroTalk [7]. Neuf essais randomisés revendiqués : NV
  (synthèse de l'organisation, sans références [25]). Article UK (*J. Educ. Psychol.*, 2018) : NV, non lu.
- **Faiblesses** — V : buzzer d'erreur (contraire à notre règle « pas de punition ») [7]. Malgache parmi les
  6 langues : NV [23].
- **On garde** : seuil de maîtrise strict, quiz cumulatif, son en langue maternelle.
  **On fait mieux** : erreur = indice, pas de son négatif ; seuil < 100 % ajustable (S, à tester).

## 8. Trois applis choisies

**Choix et justification.**
- *Écriture manuscrite* : **Writing Wizard** (L'Escapadou). Éditeur avec polices de France, Suisse et Québec, et
  aucune collecte de données déclarée [19] : le cas le plus proche de notre contexte francophone.
- *Algorithmique* : **ScratchJr**. Conçu pour 5–7 ans, code source public sous **BSD-3** (licence permissive,
  contrairement à l'AGPL) [11][32].
- *Photo nature* : **Seek by iNaturalist**. Sans compte, identification sur l'appareil sans Internet, pensé pour les
  enfants [14][37].

### 8a. Writing Wizard
- **Public** — V : « Made for Ages 0–5 », 4+ [19].
- **Boucle / mécanique** — V : modèle de lettre animé, **points-clés** validés le long du tracé ; mode 5 étoiles :
  5 répétitions de difficulté croissante [19].
- **Feedback sur l'erreur** — V : si le doigt sort du tracé, réglage au choix : rester sur place, revenir au dernier
  point-clé, ou au début de la lettre [19]. Tolérance et ordre des traits : NV.
- **Progression** — V : taille, difficulté, lignes-guides réglables par l'adulte [19]. Adaptation auto : NV.
- **Rétention** — NV (étoiles du mode 5 étoiles seulement [19]).
- **Modèle / données** — V : gratuit + achats intégrés (accès complet 9,99 $) ; aucune donnée collectée (déclaré) ;
  contrôle parental par défi [19].
- **Hors ligne** — NV.
- **Faiblesses** — V : cursive vendue à part ; aucune fonction d'accessibilité déclarée [19].
- **On garde** : points-clés + retour au dernier point validé. **On fait mieux** : cursive scolaire française incluse,
  modèle en malgache (S : même alphabet latin), sans achat.

### 8b. ScratchJr
- **Public** — V : 5–7 ans [11][32].
- **Boucle / mécanique** — V : on emboîte des blocs graphiques pour faire bouger, sauter, danser, chanter des
  personnages [32].
- **Feedback sur l'erreur** — NV (création libre, pas d'exercice noté décrit).
- **Progression / rétention** — NV.
- **Modèle / données** — V : gratuit, dons à la Scratch Foundation [32] ; analytics Firebase [11] ; localisation
  approximative et interactions déclarées pour analytics [32].
- **Hors ligne** — NV.
- **Technique** — V : JavaScript partagé + ports natifs Android/iOS ; dépôt **archivé** le 12 août 2022 [11].
- **Faiblesses** — V : note 3,9/5 [32] ; anglais seulement sur la fiche iOS [32].
- **On garde** : blocs graphiques sans lecture (S). **On fait mieux** : défis guidés avec but précis, sans analytics.

### 8c. Seek by iNaturalist
- **Public** — V : « conçu pour être sûr pour les enfants », sans compte [14][37].
- **Boucle / mécanique** — V : identification affichée en temps réel à l'écran [14].
- **Feedback** — NV (affinage par rang taxonomique : NV, guide PDF non lu).
- **Rétention** — V : badges gagnés en privé, défis [14].
- **Modèle / données** — V : rien de personnel collecté sans connexion ; données privées sauf publication volontaire
  d'un utilisateur connecté (13 ans et plus ou permission parentale) [14][37].
- **Hors ligne** — V : fonctionne sans Internet, observations sur l'appareil [14].
- **Faiblesses** — V : modèle plus ancien que celui d'iNaturalist en ligne [14]. Poids du modèle et RAM : NV.
- **On garde** : modèle embarqué, aucune image envoyée. **On fait mieux** : objets du quotidien malgache + noms FR/MG
  (S) ; budget RAM à mesurer sur la SM-X135G.

---

## Matrice fonctionnalité × appli

Codes : KAK Khan Academy Kids · ABC Duolingo ABC · Duo Duolingo général · SP Simply Piano · GC GCompris · Ko Kolibri ·
Li Lichess · 1B onebillion · WW Writing Wizard · SJ ScratchJr · Se Seek. `oui`/`non` = vérifié ; `?` = non vérifié.

| Fonctionnalité | KAK | ABC | Duo | SP | GC | Ko | Li | 1B | WW | SJ | Se |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Gratuit sans achat intégré | oui | oui | ? | non | oui | oui | oui | ? | non | oui | ? |
| Sans publicité | oui | oui | ? | ? | ? | ? | oui | ? | ? | ? | ? |
| Cœur 100 % hors ligne | partiel | oui | ? | ? | ? | oui | ? | oui | ? | ? | oui |
| Aucun compte requis | non | ? | ? | ? | ? | ? | ? | oui | ? | ? | oui |
| Aucune collecte déclarée | non | non | ? | non | ? | ? | ? | oui | oui | non | oui |
| Code open source | ? | ? | ? | ? | AGPL | MIT | AGPL | ? | ? | BSD-3 | ? |
| Adaptation automatique | oui | ? | ? | ? | non | ? | oui | oui | ? | ? | — |
| Seuil de maîtrise explicite | ? | ? | ? | ? | ? | oui | — | oui | ? | — | — |
| Révision espacée déclarée | ? | ? | oui | ? | ? | ? | ? | ? | ? | — | — |
| Série / streak | ? | ? | oui | ? | ? | ? | ? | ? | ? | ? | ? |
| Récompenses à collectionner | oui | oui | ? | oui | ? | ? | ? | ? | ? | ? | oui |
| Son d'erreur négatif | ? | ? | ? | ? | ? | ? | ? | oui | ? | — | — |
| Utilise le micro | oui | ? | ? | oui | ? | ? | ? | ? | ? | ? | ? |
| Utilise la caméra | ? | ? | ? | ? | ? | ? | ? | ? | ? | ? | oui |
| Français | ? | non | ? | oui | oui | ? | ? | ? | oui | non | ? |
| Malgache | ? | non | ? | ? | non | ? | ? | ? | ? | non | ? |
| Essai randomisé publié | ? | ? | ? | ? | ? | ? | — | oui | ? | ? | ? |

`—` = sans objet. Sources des cases : sections 1 à 8 ci-dessus.

---

## Opportunités de différenciation

Chaque point est relié à une observation sourcée (V) ou marqué supposé (S).

### Contenu
1. **Malgache natif**, pas une traduction après coup. V : absent de GCompris 26.1 [33], ABC anglais seul [10],
   ScratchJr anglais sur iOS [32] ; onebillion montre l'intérêt de la langue maternelle (chichewa) [7].
2. **Programme français GS → CM2** plutôt que Common Core. V : KAK et ABC s'alignent sur Common Core [2] ; aucun
   alignement cycles 1-3 trouvé (S pour les autres applis).
3. **Maîtrise + quiz cumulatif** comme onebillion, mais avec seuil réglable. V : seuil 100 % [7] ; Kolibri m sur n [28].
4. **Puzzles d'échecs pour enfants** filtrés depuis la base CC0 de Lichess. V : licence CC0, thèmes et cotes [20].
   S : assez de puzzles très faciles ; à vérifier.
5. **Écriture cursive française** incluse. V : Writing Wizard la vend à part [19].
6. **Algorithmique avec défis guidés** et but clair. S : ScratchJr est de la création libre (aucun exercice noté
   décrit [32]).
7. **Photo d'objets du quotidien malgache**, noms en FR et MG. V : Seek fonctionne hors ligne sur l'appareil [14].
   S : objets et jeu de données à constituer.

### Design
8. **Erreur sans punition** : indice → exemple → démonstration. V : onebillion utilise un son négatif [7] ; Simply
   Piano marque en rouge [16]. S : effet à tester avec des enfants.
9. **Fil rouge sans perte** au lieu d'une série. V : Duolingo reconnaît jouer sur l'aversion à la perte et a dû
   ajouter des gels [9] ; son article ne parle pas d'enfants [9]. S : meilleur pour 5–10 ans.
10. **Daltonisme** : jamais la couleur seule (forme + son + icône). V : Simply Piano code juste/faux/aidé par
    vert/rouge/jaune [16]. S : problème pour un enfant daltonien.
11. **Accessibilité déclarée** (contraste, cibles ≥ 48 dp, voix off, mode sombre). V : Writing Wizard ne déclare
    aucune fonction d'accessibilité [19]. S : les autres non vérifiées.
12. **Autonomie sans parent** : interface pictogrammes + voix pour 5–6 ans, aucun compte. V : KAK exige un compte
    parent avec e-mail [29] ; Kolibri est centré sur l'enseignant [12] ; Seek et onebillion n'exigent pas de
    login [14][23].
13. **Zéro donnée** quittant l'appareil. V : Simply Piano déclare du suivi entre applis [34] ; KAK, ABC, ScratchJr
    déclarent des analytics [2][10][11][32] ; Writing Wizard et onebillion déclarent ne rien collecter [19][23].
14. **Faible RAM / APK léger** pour la SM-X135G (3,7 Go). V : KAK pèse 210,6 Mo sur iOS [2], Writing Wizard 71,7 Mo
    [19], ScratchJr 53,5 Mo [32]. S : budget < 60 Mo atteignable seulement avec voix compressées ; à mesurer.
15. **Tout embarqué, aucun téléchargement au premier lancement.** S : GCompris proposerait le téléchargement des voix
    (manuel non lu) ; KAK télécharge livres et jeux pour le hors-ligne [2].
16. **Mode kiosque compatible Family Link.** V : GCompris a un mode kiosque [38]. S : sur Android, passer par
    l'épinglage d'écran sans toucher au profil supervisé (règle de `CLAUDE.md`).

---

## Reste à tester / non vérifié (récapitulatif)

Feedback sur l'erreur chez KAK, ABC, GCompris, Lichess, ScratchJr, Seek · algorithme d'adaptation de KAK · hors-ligne
de GCompris, Simply Piano, Lichess, Writing Wizard, ScratchJr · politique de confidentialité de GCompris (404) ·
langues de onebillion (malgache ?) et de Kolibri · neuf essais randomisés de onebillion et article UK 2018 ·
prix du gel de série · date de sortie Android de Duolingo ABC · progression par rang taxonomique de Seek et poids
de son modèle · critique NBC du chemin Duolingo.

---

## Sources

Toutes consultées le **2026-11-02**. « Lu » = page ouverte et lue ; « non lu » = échec ou seulement vue dans un
résultat de recherche (aucune affirmation « V » n'en dépend).

| # | URL | Statut |
| --- | --- | --- |
| 1 | https://apps.kde.org/gcompris/ | lu |
| 2 | https://apps.apple.com/US/app/id1378467217 (Khan Academy Kids) | lu |
| 3 | https://www.musicradar.com/reviews/simply-piano-review | non lu (contenu non chargé) |
| 4 | https://github.com/ornicar/lila | lu |
| 5 | https://www.nottingham.ac.uk/news/pressreleases/2017/june/addition-of-new-maths-app-equals-better-learning-for-children.aspx | lu |
| 6 | https://solve.mit.edu/solutions/4197 | lu |
| 7 | https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2015.00485/full | lu |
| 8 | https://lichess.org/blog/X-S6gRUAAGjNX4ki/new-puzzles-are-here | non lu (403) |
| 9 | https://blog.duolingo.com/how-duolingo-streak-builds-habit | lu |
| 10 | https://apps.apple.com/us/app/learn-to-read-duolingo-abc/id1440502568?l=en | lu |
| 11 | https://github.com/scratchfoundation/scratchjr | lu |
| 12 | https://learningequality.org/kolibri/ | lu |
| 13 | https://blog.duolingo.com/new-duolingo-home-screen-design | lu |
| 14 | https://help.inaturalist.org/en/support/solutions/articles/151000169914-what-is-the-difference-between-inaturalist-and-seek-by-inaturalist- | lu |
| 15 | https://www.commonsense.org/education/app/seek-by-inaturalist | non lu (page de connexion) |
| 16 | https://pianistscompass.org/?p=9588 | lu |
| 17 | https://static.inaturalist.org/wiki_page_attachments/SeekUserGuide2020.pdf | non lu (trop volumineux) |
| 18 | https://www.khanacademy.org/kids | non lu (erreur de chargement) |
| 19 | https://apps.apple.com/us/app/writing-wizard-handwriting/id1305242235 | lu |
| 20 | https://database.lichess.org/ | lu (partie puzzles) |
| 21 | https://gcompris.net/index-fr.html | lu |
| 22 | https://learn.khanacademy.org/khan-academy-kids/ | non lu (erreur de chargement) |
| 23 | https://onebillion.org/ | lu |
| 24 | https://play.google.com/store/apps/details?id=com.duolingo.literacy | non lu (contenu tronqué) |
| 25 | https://www.imagineworldwide.org/?p=98638 | lu |
| 26 | https://github.com/KDE/gcompris | lu |
| 27 | https://kolibri.readthedocs.io/en/latest/manage/resources.html | lu (rien sur la maîtrise) |
| 28 | https://ricecooker.readthedocs.io/en/latest/exercises.html | lu |
| 29 | https://www.commonsensemedia.org/app-reviews/khan-academy-kids | lu |
| 30 | https://www.media.mit.edu/projects/scratchjr/overview/ | non lu (certificat refusé) |
| 31 | https://www.scratchjr.org/about/info | non lu (page vide) |
| 32 | https://apps.apple.com/app/id895485086 (ScratchJr) | lu |
| 33 | https://planet.kde.org/gcompris-2026-03-10-release-gcompris-26-1/ | lu |
| 34 | https://apps.apple.com/app/id1019442026 (Simply Piano) | lu |
| 35 | https://github.com/learningequality/kolibri | lu |
| 36 | https://www.hellosimply.com/family/why-simply-works | lu |
| 37 | https://forum.inaturalist.org/t/seek-app-vs-inaturalist/16606 | lu |
| 38 | https://gcompris.net/docbook/stable6/en/user-interface.html | lu |
| 39 | https://www.simplypiano.com/ | non lu (connexion fermée) |
| 40 | https://gcompris.net/privacy-policy-fr.html | non lu (404) |
| 41 | https://invent.kde.org/education/gcompris/-/wikis/Developers-corner | non lu (page vide) |
| 42 | https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2019.02633/text | non lu (résultat de recherche) |
| 43 | https://www.burtonjoyce.notts.sch.uk/?p=1209 (article onebillion UK 2018) | non lu (résultat de recherche) |
| 44 | https://www.nbcnews.com/tech/tech-news/duolingos-update-redesign-luis-von-ahn-interview-rcna44655 | non lu (résultat de recherche) |
| 45 | https://learningequality.org/download/ | non lu (résultat de recherche) |
| 46 | https://design-system.learningequality.org/glossary | non lu (résultat de recherche) |
| 47 | https://gcompris.net/wiki/Manual | non lu (résultat de recherche) |
