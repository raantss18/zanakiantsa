# Conformité — Zanak'i Antsa

> ⚠ **Ce document n'est pas un avis juridique.** Il a été rédigé par un assistant, pas par un juriste. Il résume des
> sources primaires lues le **2026-11-02** et en tire des règles de produit. En cas de doute (publication sur Google
> Play, partenariat avec une école), faire relire par un juriste.

Hypothèses du projet (`CLAUDE.md`, `docs/vision.md`) : enfants 5–10 ans, cœur 100 % hors ligne, aucun compte, aucune
pub, aucun achat, aucune télémétrie (journal local). Distribution : APK direct, puis peut-être Google Play.

## 1. YouTube API Services — Developer Policies [1]

- **Vérifié** : III.E.1 interdit de « download, import, backup, cache, or store copies of YouTube audiovisual
  content » sans accord écrit préalable (III.E.1.a) et de rendre un contenu disponible hors ligne (III.E.1.b).
  Le numéro **III.E.1** est confirmé.
- **Vérifié** : interdit de modifier ou bloquer le lecteur (III.I.6), de masquer ou modifier ses liens (III.I.4),
  de bloquer ses pubs (III.I.5), de séparer l'audio et la vidéo (III.I.7), de lire depuis un lecteur en arrière-plan
  (III.I.9).
- **Vérifié** : un client « Child-Directed » (III.J.1) doit respecter COPPA/RGPD, **le signaler à Google** par les outils
  prévus, ne faire aucune pub personnalisée, aucune action d'écriture (III.J.2). Pour chaque vidéo « Made For Kids »,
  vérifier son statut et **couper le suivi** (III.E.4.j). Une politique de confidentialité acceptée par l'utilisateur est
  exigée (III.A.2).
- **Règle** : aucun téléchargeur (Snaptube, yt-dlp…), aucun cache. Par défaut : **aucune vidéo YouTube**. Option
  future : liste blanche réglée dans l'espace parent, lecteur officiel non modifié, **en ligne seulement**, vidéos
  « Made For Kids » vérifiées — ce qui fait de l'app un client YouTube soumis à III.J (déclaration à Google, politique de
  confidentialité). Préférer des **vidéos propres** (CC BY-SA, embarquées dans l'APK ou téléchargées depuis nos serveurs).

## 2. CNIL — 8 recommandations pour les mineurs (1er juin 2021) [2–10]

| # | Recommandation (lue) | Pour Zanak'i Antsa (aucune donnée ne quitte l'appareil) |
| --- | --- | --- |
| 1 | Capacité d'agir des mineurs (≥ 15 ans, contrats) [3] | Ne s'applique pas : 5–10 ans, aucun contrat ni compte. |
| 2 | Exercice de leurs droits par les mineurs [4] | Effacement local simple : bouton « tout effacer » dans l'espace parent. |
| 3 | Accompagner les parents [5] | Écran parent qui explique, en clair, ce que l'app garde et où. |
| 4 | Consentement parental < 15 ans [6] | Seulement si un traitement repose sur le consentement. Sans collecte : rien à recueillir. Le jour où une donnée part (vidéo en ligne, ML Kit, cf. §6) : à réévaluer. |
| 5 | Contrôle parental respectueux [7] | Rapport parent local, proportionné, sans géolocalisation ; l'enfant sait ce que voit le parent. |
| 6 | Information et droits par le design [8] | Information adaptée à l'âge, options désactivées par défaut, **pas de dark patterns** (notifications qui retiennent) : déjà nos règles (fin de séance, pas de série perdue). |
| 7 | Vérifier l'âge sans atteinte à la vie privée [9] | L'âge saisi par le parent (ADR 0006) sert la pédagogie, pas un contrôle d'accès ; ne rien collecter de plus. |
| 8 | Garanties spécifiques [10] | Confidentialité renforcée par défaut, **aucun profilage**, aucune réutilisation commerciale. |

- **Vérifié** : la page CNIL reproduit l'article 45 de la loi Informatique et Libertés : sous 15 ans, les parents
  « doivent donner leur accord conjointement avec celui de leur enfant », pour les traitements fondés sur le
  consentement [6]. L'article 8.1 RGPD fixe 16 ans par défaut, abaissable jusqu'à 13 ans par un État membre [11].
- **Non vérifié** : texte de l'article 45 sur Légifrance (non lu directement) ; application du RGPD et du droit français
  à un auteur établi à Madagascar (art. 3 RGPD non lu). Recommandations CNIL = bonnes pratiques, pas obligations [10].

## 3. Madagascar — loi n° 2014-038 [12–14]

- **Vérifié** (texte de la loi, PDF hébergé par l'AFAPDP [12]) : **loi n° 2014-038 sur la protection des données à
  caractère personnel**, adoptée le 16 décembre 2014, décision HCC n° 02-HCC/D3 du 7 janvier 2015, promulguée le
  9 janvier 2015. Art. 4 : contrôle par une autorité indépendante, la **Commission Malagasy de l'Informatique et des
  Libertés (CMIL)**. Art. 5 : ne s'applique pas aux traitements « pour l'exercice d'activités exclusivement
  personnelles ». Art. 20 : transfert à l'étranger seulement vers un niveau de protection similaire (ou autorisation
  CMIL / exceptions). Art. 43 : régime de déclaration. **Aucun article spécifique aux mineurs** trouvé dans le texte.
- **Vérifié** (site de l'Assemblée nationale [13]) : **7 membres de la CMIL ont prêté serment le 4 août 2025**.
- **Contradictoire** : un tracker privé (lawlab.africa, mis à jour 2026-10-23) la marque « Operational: No » [14].
  **Non vérifié** : le décret d'application (n° 2023-1541 selon des sources secondaires), le site et le portail de
  déclaration de la CMIL, et si elle traite déjà des dossiers.
- **Règle** : rester hors du champ pratique de la loi en ne traitant **aucune** donnée hors de l'appareil. Si un jour
  l'app envoie des données (serveur, vidéo, ML Kit), vérifier auprès de la CMIL l'obligation de déclaration (art. 43) et
  l'art. 20 (serveurs hors de Madagascar).

## 4. Google Play — Families policy, Teacher Approved, Data safety [15–18]

- **Vérifié** (Families Policies [15]) : déclarer l'audience cible ; une app **seulement** pour enfants ne doit contenir
  **aucun SDK non approuvé** pour les services destinés aux enfants ; ne doit pas transmettre l'AAID, IMEI, IMSI, etc. ;
  ne pas demander la localisation ni la permission AD_ID (API ≥ 33) ; **déclarer** toute donnée sensible collectée, y
  compris par les SDK — la liste cite « microphone and camera sensor data » et « device data » ; **politique de
  confidentialité obligatoire** ; pubs seulement via SDK auto-certifiés Families. Le nom « Designed for Families » n'apparaît
  plus sur la page ; il ne reste que les Families Policies et Teacher Approved.
- **Vérifié** (Data safety [16]) : **toute** app publiée (sauf piste de test interne) remplit le formulaire, **même sans
  collecte**, et fournit une politique de confidentialité. Les données traitées **uniquement sur l'appareil** ne sont pas
  « collectées ». Les données des **SDK tiers** doivent être déclarées.
- **Vérifié** (Teacher Approved [17][18]) : apps pour enfants ou audience mixte incluant des enfants ; notées sur le
  design, l'enrichissement, l'âge, les pubs/achats/promotions croisées, la langue et l'audio. Pas de procédure
  d'inscription décrite sur les pages lues.
- **Règle** : audience « 5 ans et moins » + « 6–8 » + « 9–12 » seulement ; zéro SDK de pub/analytics/crash ; une page
  `docs/confidentialite.md` (publiée) même pour l'APK direct ; formulaire Data safety rempli à partir de l'inventaire
  réel des SDK (§6).

- **⚠ Conflit avec l'ADR 0011** (mises à jour par l'app) — **Vérifié** (Device and Network Abuse [23]) : une app Play
  « may not modify, replace, or update itself using any method other than Google Play's update mechanism » et ne
  télécharge pas de code exécutable hors Play. **Règle** : l'auto-mise à jour de l'APK n'existe que dans la version APK
  directe ; une version Play la retire (le contenu JSON/YAML signé n'est pas du code exécutable — ⚠ supposé).

## 5. Permissions micro et caméra [19][15]

- **Vérifié** (Android [19]) : demander **dans le contexte**, au moment où l'enfant lance l'activité ; expliquer avant
  (`shouldShowRequestPermissionRationale`) avec un bouton « non merci » ; en cas de refus, **dégrader sans bloquer** et ne
  pas harceler ; deux refus = refus définitif ; Android ≥ 11 propose « Seulement cette fois » ; Android ≥ 12 affiche un
  indicateur micro/caméra. Prendre une photo est possible **sans permission** via l'appli caméra du système [19].
- **Vérifié** (Play [15]) : micro et caméra sont des données sensibles à déclarer si elles sont collectées.
- **Règle** : `RECORD_AUDIO` et `CAMERA` demandés seulement au lancement de l'activité, avec une explication **pour le
  parent** (l'enfant de 5 ans ne lit pas) ; toute activité reste jouable sans (piano au toucher, choix d'image) ; aucun
  enregistrement audio ni photo conservé par défaut ; ni localisation, ni AD_ID, ni contacts.

## 6. ML Kit — ⚠ contredit « aucune donnée ne quitte l'appareil » [20][21]

- **Vérifié** (Terms, 14 mai 2025 [20]) : le traitement des images, textes, tracés est **entièrement sur l'appareil** et
  ML Kit n'envoie **ni les entrées ni les résultats** à Google. **Mais** les API contactent Google (correctifs, modèles,
  compatibilité) et **envoient des métriques de performance et d'utilisation à Google**. Le développeur doit **en
  informer ses utilisateurs**.
- **Vérifié** (data disclosure Android [21]) : toutes les fonctions collectent infos appareil (fabricant, modèle, OS),
  nom du paquet et version, **identifiant** (appareil pour les modèles « thin » via Play services ; par installation pour
  les modèles « bundled »), latence, configuration, tailles, version, événements (dont téléchargements de modèle), codes
  d'erreur ; Digital Ink ajoute les **langues configurées**. Chiffré (HTTPS), non transmis à des tiers.
- **Non vérifié** : aucun interrupteur documenté pour couper ces métriques ; statut « approuvé pour enfants » de ML Kit
  au sens Families ; nature exacte de l'identifiant (risque Families §4).
- **Règle** : ne plus écrire « aucune donnée ne quitte l'appareil » si ML Kit est inclus. Écrire : « ni images, ni voix,
  ni tracés ne quittent l'appareil ; ML Kit envoie à Google des statistiques techniques ». Préférer les modèles
  **bundled** (étiquetage d'images) ; Digital Ink exige un téléchargement (ADR 0009). Le déclarer dans la politique de
  confidentialité et le Data safety. Alternative à évaluer par ADR : modèles locaux sans SDK Google (TFLite seul).

## 7. Synthèse vocale [22]

- **Vérifié** (fiche Play de `com.google.android.tts`, « Speech Recognition & Synthesis » [22]) : le moteur Google
  déclare **collecter** activité, identifiants d'appareil, e-mail (facultatif), diagnostics, pour l'analytics. La fiche
  ne distingue pas reconnaissance et synthèse.
- **Vérifié** (`adb`, 2026-11-02) : les deux SM-X135G ont **Samsung TTS** (`com.samsung.SMT`) et Google TTS ; aucun moteur
  par défaut explicite (`tts_default_synth` vide / `null`) ; voix française Samsung installée sur `R8YYA0CZ5ZV` seulement.
- **Non vérifié** : ce que chaque moteur envoie lors d'une synthèse hors ligne.
- **Règle** : TTS = prototypage seulement (ADR 0002) ; la version testée avec des enfants utilise des **voix
  enregistrées** embarquées. Le moteur TTS est une app tierce choisie par l'appareil : le dire dans la politique.

## 8. Checklist par version

- [ ] Manifeste fusionné relu (`build/…/merged_manifests`) : liste exacte des permissions ; `INTERNET` justifiée ou absente
- [ ] Aucun SDK de pub, analytics, crash (Firebase Analytics/Crashlytics…) ; inventaire des SDK à jour
- [ ] Capture réseau (2 sessions, hors et en ligne) : aucune requête hors téléchargement de modèles / métriques ML Kit déclarées
- [ ] Micro/caméra : demandés au lancement de l'activité, explication parent, activité jouable si refus
- [ ] Ni localisation, ni AD_ID, ni identifiant matériel lu par notre code
- [ ] Aucune photo ni audio conservé (ou effacement documenté)
- [ ] Aucun lien sortant ni vidéo dans l'écran enfant ; YouTube absent (ou conforme §1)
- [ ] Bouton « tout effacer » dans l'espace parent fonctionnel
- [ ] `docs/confidentialite.md` à jour (ML Kit, TTS) et lien dans l'app
- [ ] Play : audience cible, Data safety, questionnaire de contenu cohérents avec la capture réseau
- [ ] Pas de notification, minuteur ni série qui pousse à revenir (CNIL rec. 6)

## Vérifié / Supposé / Reste à tester

- **Vérifié** : clauses YouTube III.E.1, III.E.4.j, III.I, III.J ; 8 recommandations CNIL ; art. 8 RGPD ; loi
  malgache n° 2014-038 (texte), serment CMIL 2025-08-04 ; Families policy, Data safety, Teacher Approved ; règles de
  permissions Android ; **métriques ML Kit envoyées à Google** ; collecte déclarée par Google TTS ; moteurs TTS présents.
- **Supposé** : sans collecte, la loi malgache et le consentement parental CNIL ne déclenchent rien ; le journal local
  n'est pas une « collecte » au sens Play [16] ; Samsung TTS est le moteur effectif.
- **Reste à tester** : capture réseau d'une session ML Kit (Digital Ink, étiquetage) ; permissions ajoutées par les
  plugins ML Kit ; trafic du moteur TTS hors ligne ; statut opérationnel de la CMIL et décret d'application ; art. 45 sur
  Légifrance ; ML Kit compatible Families (demande au support Play si publication).

## Sources (consultées le 2026-11-02)

1. https://developers.google.com/youtube/terms/developer-policies — lu
2. https://www.cnil.fr/la-cnil-publie-8-recommandations-pour-renforcer-la-protection-des-mineurs-en-ligne — lu
3. https://www.cnil.fr/recommandation-1-encadrer-la-capacite-dagir-des-mineurs-en-ligne — lu
4. https://www.cnil.fr/recommandation-2-encourager-les-mineurs-exercer-leurs-droits — lu
5. https://www.cnil.fr/recommandation-3-accompagner-les-parents-dans-leducation-au-numerique — lu
6. https://www.cnil.fr/recommandation-4-rechercher-le-consentement-dun-parent-pour-les-mineurs-de-moins-de-15-ans — lu
7. https://www.cnil.fr/recommandation-5-promouvoir-des-outils-de-controle-parental-respectueux-de-la-vie-privee-et-de — lu
8. https://www.cnil.fr/recommandation-6-renforcer-linformation-et-les-droits-des-mineurs-par-le-design — lu
9. https://www.cnil.fr/recommandation-7-verifier-lage-de-lenfant-et-laccord-des-parents-dans-le-respect-de-sa-vie-privee — lu
10. https://www.cnil.fr/recommandation-8-prevoir-des-garanties-specifiques-pour-proteger-linteret-de-lenfant — lu
11. https://www.cnil.fr/fr/reglement-europeen-protection-donnees/chapitre2 (RGPD art. 8) — lu
12. https://www.afapdp.org/wp-content/uploads/2018/05/Madagascar-L-2014-038-du-09-01-15-sur-la-protection-des-donnees-a-caractere-personnel.pdf — lu
13. https://assemblee-nationale.mg/prestation-de-serment-des-membres-de-la-commission-malagasy-de-linformatique-et-des-libertes-cmil/ — lu
14. https://research.lawlab.africa/madagascar/ (secondaire) — lu ; https://digital.gov.mg/2022/07/05/loi-n-2014-038-sur-la-protection-des-donnees-a-caractere-personnel/ — non lu (404)
15. https://support.google.com/googleplay/android-developer/answer/9893335 — lu
16. https://support.google.com/googleplay/android-developer/answer/10787469 — lu
17. https://support.google.com/googleplay/android-developer/answer/9867159 — lu
18. https://google.play/business/programs/teacherapproved/ — lu
19. https://developer.android.com/training/permissions/requesting — lu
20. https://developers.google.com/ml-kit/terms — lu
21. https://developers.google.com/ml-kit/android-data-disclosure — lu
22. https://play.google.com/store/apps/datasafety?id=com.google.android.tts&hl=fr — lu
23. https://support.google.com/googleplay/android-developer/answer/9888379 — lu
- Non lus : Légifrance art. 45 loi 78-17 ; https://developers.google.com/youtube/terms/required-minimum-functionality ;
  documentation Firebase data disclosure ; politique de Samsung TTS.

## 7. Vidéos YouTube (ADR 0068, 2026-11-08)

- **Ce qui part** : quand l'enfant regarde une vidéo, le lecteur officiel YouTube (domaine youtube-nocookie.com) reçoit
  l'adresse IP de la tablette, l'identifiant de la vidéo et des informations techniques ; Google peut afficher des
  publicités. La liste et la recherche, elles, se font sur l'appareil, dans un catalogue téléchargé depuis le site.
- **Choix d'Antsa** : actif sans réglage parent ; le parent en est informé dans l'espace parent (section « Vidéos »).
- **À vérifier** (non lu ici) : conditions YouTube API Services pour un public d'enfants (§ 1), statut « conçu pour les
  enfants » des vidéos intégrées, déclaration éventuelle à la CMIL (§ 3) puisque des données quittent désormais l'appareil.

