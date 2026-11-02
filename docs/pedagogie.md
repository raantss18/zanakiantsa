# Pédagogie — règles de conception de Zanak'i Antsa

> Public : enfants de **5 à 10 ans**, seuls devant une tablette, séance ≈ 10–15 min ⚠ (hypothèse). Chaque ligne
> distingue **Vérifié** (source lue le 2026-11-02, § 4) et **Supposé** (choix de produit, à mesurer). Le public des
> études est indiqué : beaucoup portent sur des adultes ou des enfants plus âgés, et ne se transposent pas d'office.

## 1. Ce que dit la recherche, et ce qu'on en fait

| Technique | Vérifié : ce que dit la source (public étudié) | Supposé : règle dans Zanak'i Antsa | Src |
| --- | --- | --- | --- |
| 4 piliers | Cadre **conceptuel** (pas un instrument validé) : implication active (réfléchir, pas seulement toucher), engagement sans distracteurs, sens (lien au vécu ; ex. chercher des triangles chez soi), interaction sociale (personnages réactifs, échange avec un adulte). Toutes les applis n'ont pas les 4 ; celles qui les ont « ont plus de chances » de faire apprendre (enfants, surtout jeunes ; âge non précisé). | Chaque activité vise un objectif d'apprentissage nommé et coche ≥ 3 piliers ; « sens » : photo d'objets réels (thème 6) ; « social » : personnage qui réagit à la réponse + invitation **facultative** à montrer à un adulte. | [1] |
| Rappel actif | Faible enjeu (« high challenge, low risk »), difficulté calibrée, correction rapide des erreurs ; test + retour > test seul. Méta-analyse sous-jacente avec effets en primaire (Adesope et al. 2017, non lue directement). | Presque chaque écran demande de **produire** une réponse ; jamais de note affichée ; la bonne forme est donnée vite après l'aide (§ erreur). | [2] |
| Espacement chez l'enfant | **Mitigé.** Pour : 3–4 ans, rappel à intervalles croissants ≈ double le rappel de noms de jouets, d = 1,9 vs étude massée [3] ; classe, leçons de lecture distribuées > groupées (âges non précisés dans le résumé) [4]. Contre : CE1–6e (NL), vocabulaire en classe, **aucun** gain de l'espacement long ni du rappel [5]. | Révisions espacées courtes en début de séance ; planificateur **simple** (boîtes de Leitner / intervalles croissants) ; on mesure localement si ça aide. | [3–5] |
| Planificateur FSRS | Paquet Dart `fsrs` 2.0.1 (MIT, portage de py-fsrs, « unverified uploader ») ; aucune mention d'enfants. | **Pas affirmé adapté** : à comparer à Leitner hors ligne (rétention J+7) avant tout choix. | [6] |
| Maîtrise avant progression | 108 évaluations : effet positif sur les examens au collège/lycée/université et dans les **grandes classes du primaire** (pas GS/CP) ; plus de temps d'enseignement ; seuil usuel ≈ 80 % (synthèse secondaire). | Graphe de compétences avec prérequis ; seuil de déblocage ⚠ à fixer ; un prérequis raté ramène doucement à une révision, sans message d'« échec ». | [7, 8] |
| Récompenses | 128 études : récompenses **tangibles attendues** sapent la motivation intrinsèque (libre choix, d = −0,40 à −0,28 selon le type), **plus chez les enfants** ; retour positif verbal l'augmente chez les étudiants (d = 0,43) mais **pas significativement chez les enfants** (d = 0,11, 7 études). Débat ouvert (Cameron & Pierce). | Pas de monnaie, pub, achat ni minuteur ; récompense = suite du monde/histoire liée au contenu ; retour **informatif** (« tu as compté jusqu'à 7 ») plutôt que louange générique. | [9] |
| Séries (« streaks ») | Non vérifié. Un essai au Pérou (CM1–6e, ≈ 60 000 élèves) est signalé, mais je n'ai pas pu lire le texte ni ses effets sur l'apprentissage ; rien de lu sur l'aversion à la perte chez les 5–10 ans. | « Fil rouge » qui avance et ne recule jamais : **choix de design**, pas un résultat. | — |
| Écriture manuscrite | 3–5 ans (2 × 38) : copier des lettres à la main → meilleure reconnaissance des lettres que les taper, **chez les plus âgés seulement** [10]. EEG : écrire (stylet sur écran tactile) > taper en connectivité cérébrale, mais **36 étudiants**, pas d'effet d'apprentissage mesuré [11]. | Tracer au doigt/stylet les lettres et chiffres (thème 3) plutôt que les choisir sur un clavier ; ne pas promettre d'effet chez les 7–10 ans. | [10, 11] |
| Reconnaissance hors ligne | ML Kit Digital Ink : « fully offline » sur Android, 300+ langues ; `fr` (et `fr-002` Afrique) et **`mg` (malgache)** listés. Packs **téléchargés à la demande** : taille non indiquée. | Packs `fr` puis `en` téléchargés une fois (ADR 0009) ; spike : mesurer taille/RAM/précision sur écriture d'enfant. | [12] |
| Aide graduée | Échafaudage (tuteur adulte, jeunes enfants) : Wood, Bruner & Ross 1976 — notice lue, **contenu non vérifié**. | 3 niveaux : indice → exemple voisin → démonstration (⚠ décision § 3). | [13] |
| Langue | UNESCO : enseigner dans une langue que l'enfant comprend ; ≥ 6 ans de langue maternelle pour réduire les écarts (exemples Mali, Éthiopie ; Madagascar non cité). Madagascar parmi les plus faibles au PASEC2019 (< 1 élève sur 3 au seuil en fin de primaire). Étude qualitative (Toliara) : acteurs favorables au malgache d'abord — **perceptions**, pas un effet mesuré. | **Décidé (ADR 0005)** : interface en français seulement ; l'anglais est un thème d'apprentissage. ⚠ Les sources ci-contre plaident pour la langue maternelle : à garder en tête si l'app sert à des enfants malgachophones. | [14–16] |
| Sans parent, pré-lecteurs | Non vérifié (aucune étude lue). | Écran enfant 100 % pictogrammes + voix off, zéro texte obligatoire pour 5–6 ans ; espace parent derrière un petit calcul. | — |

## 2. Checklist de revue d'une activité (à cocher, observable sur l'écran)

**Objectif et sens**
- [ ] L'objectif est écrit dans le fichier de contenu (compétence du graphe, cycle, niveau GS→CM2).
- [ ] L'enfant doit **produire ou choisir en réfléchissant** ; aucune étape où toucher n'importe où fait avancer.
- [ ] Au moins un élément relie au quotidien (objet, lieu, situation connue) ; si photo : traitée sur l'appareil.
- [ ] ≥ 3 des 4 piliers cochés ; lequel manque est noté.

**Engagement sans distracteurs**
- [ ] Aucune animation, son ou bouton qui ne sert pas l'objectif pendant la tâche.
- [ ] Aucun minuteur, compte à rebours, monnaie, publicité, achat, classement.

**Sans lecture, sans parent**
- [ ] Une enfant de 5 ans peut finir l'activité **sans lire** : consigne vocale, rejouable par un bouton haut-parleur.
- [ ] Tout bouton a un pictogramme ; cibles ≥ 48 dp ; ← retour ≠ Accueil.
- [ ] Rien n'exige un adulte ; l'invitation à « montrer à quelqu'un » est facultative et se ferme d'un geste.
- [ ] Texte et voix en français relus (thème anglais : prononciation anglaise vérifiée).

**Rappel, espacement, maîtrise**
- [ ] L'activité déclare ses prérequis et son seuil de maîtrise (valeur ⚠ produit).
- [ ] Ses items peuvent revenir en révision espacée (identifiant stable, plusieurs variantes).
- [ ] Un prérequis raté mène à une révision courte, sans écran « perdu ».

**Erreur = information**
- [ ] Aucune croix rouge, buzzer, vie perdue, mot « faux »/« échec » affiché ou dit.
- [ ] 3 essais avec aide croissante ; après le 3e : démonstration (< 6 ans) ou indice seul (≥ 6 ans) — ADR 0006.
- [ ] Le retour dit **quoi** (« il en manque 2 », « tu as compté jusqu'à 7 »), puis un encouragement court (ADR 0008).
- [ ] Le journal local enregistre : réponse, niveau d'aide utilisé, durée — sur l'appareil seulement.

**Boucle quotidienne**
- [ ] L'activité tient dans le défi du jour (durée mesurée ⚠ ≤ 5 min) et se termine par un écran de fin clair.
- [ ] La progression ne recule jamais (pas de série à perdre).

## 3. Décisions d'Antsa (2026-11-02)

1. **Après 3 essais manqués** : démonstration pour les moins de 6 ans, indice seul pour les 6 ans et plus — ADR 0006.
   Aucune étude lue ne compare les deux chez 5–7 ans : à observer à l'essai.
2. **Maîtrise** : 80 %, 3 essais — ADR 0007 (calcul exact à préciser).
3. **Révisions** : boîtes de Leitner (choix délégué à Claude), FSRS réévalué plus tard — ADR 0007.
4. **Langue** : français seulement ; anglais comme thème — ADR 0005.
5. **Retour positif** : descriptif + encouragement — ADR 0008.
6. **Packs ML Kit** : téléchargement unique — ADR 0009.

## 4. Sources (consultées le 2026-11-02)

« Lu » = page ou résumé lu par moi ; « non lu » = notice/extraits de recherche seulement.

1. Hirsh-Pasek, Zosh, Golinkoff, Gray, Robb & Kaufman (2015), *PSPI* 16(1), 3–34, doi:10.1177/1529100615569721 —
   https://www.psychologicalscience.org/publications/educational-apps.html (lu : page de présentation, pas l'article).
2. AERO (2021), *Spacing and retrieval practice guide* —
   https://www.edresearch.edu.au/guides-resources/practice-guides/spacing-and-retrieval-practice-guide-full-publication (lu).
3. Fritz, Morris, Nolan & Singleton (2007), *Q. J. Exp. Psychol.* 60(7), 991–1004 — https://eprints.lancs.ac.uk/id/eprint/3671/ (lu : résumé).
4. Seabrook, Brown & Solity (2005), *Appl. Cogn. Psychol.* 19(1), 107–122, doi:10.1002/acp.1066 — https://wrap.warwick.ac.uk/7472/ (lu : résumé).
5. Goossens et al. (2016), *Appl. Cogn. Psychol.* 30(5), 700–712, doi:10.1002/acp.3245 —
   https://pure.eur.nl/en/publications/distributed-practice-and-retrieval-practice-in-primary-school-voc/ (lu : résumé) ;
   contexte : https://www.learningscientists.org/blog/2018/9/8-1 (lu). Sobel, Cepeda & Kapler (2011), doi:10.1002/acp.1747 (non lu).
6. https://pub.dev/packages/fsrs (lu).
7. Kulik, Kulik & Bangert-Drowns (1990), *RER* 60(2), 265–299, doi:10.3102/00346543060002265 (non lu : résumé via recherche).
8. Evidence for Learning, *Mastery learning* —
   https://www.evidenceforlearning.org.au/the-toolkits/the-teaching-and-learning-toolkit/australasian-research-summaries/mastery-learning (lu, synthèse secondaire).
9. Deci, Koestner & Ryan (1999), *Psychol. Bull.* 125(6), 627–668 —
   https://depts.washington.edu/techdocs/papers/deciExtrinsicRewardsAndIntrinsicMotivation99.pdf (lu : résumé + analyses par âge).
10. Longcamp, Zerbato-Poudou & Velay (2005), *Acta Psychol.* 119(1), 67–79, doi:10.1016/j.actpsy.2004.10.019 — https://pubmed.ncbi.nlm.nih.gov/15823243 (lu : résumé).
11. Van der Weel & Van der Meer (2024), *Front. Psychol.* 14:1219945 — https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1219945 (lu).
12. https://developers.google.com/ml-kit/vision/digital-ink-recognition et `/base-models` (lus).
13. Wood, Bruner & Ross (1976), *J. Child Psychol. Psychiatry* 17(2), 89–100 — https://pubmed.ncbi.nlm.nih.gov/932126/ (non lu).
14. UNESCO GEM, *Policy Paper 24* (2016) —
    https://www.allinschool.org/media/1986/file/%20Paper-OOSCI-if%20you-dont-understand-how-can-you-learn-2016-en.pdf (lu, partiel).
15. Le Nestour (2021), CGD — https://www.cgdev.org/blog/new-pasec-results-show-modest-improvements-student-learning-francophone-africa (lu).
16. Soameva et al. (2025), *J. Pendidikan Tambusai* 9(3) — https://jptam.org/index.php/jptam/article/view/33717 (lu : résumé).
