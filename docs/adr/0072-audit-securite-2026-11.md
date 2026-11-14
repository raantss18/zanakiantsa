# ADR 0072 — Audit de sécurité du 2026-11-14

- **Statut** : accepté. Audit à la lecture du code, plus OSV (https://osv.dev) sur les 93 paquets Dart de `pubspec.lock`
  et 36 artefacts Android relevés dans l'APK 1.1.0 : **aucune vulnérabilité connue dans ce qui est embarqué**.
- **Corrigé** :
  - Sauvegarde Google coupée (`allowBackup="false"`, `data_extraction_rules.xml`) : le journal, les prénoms et les dessins
    ne partent plus dans le nuage (règle 5). Le transfert direct d'appareil à appareil reste permis.
    https://developer.android.com/guide/topics/data/autobackup
  - Porte parentale : 32 questions au lieu de 10 réponses possibles ; après 3 erreurs, attente de 30 s qui double (5 min au plus).
  - Mise à jour : téléchargement seulement en HTTPS depuis github.com, taille signée imposée, délais, cache vidé.
  - Vidéos : identifiant validé (11 caractères YouTube) ; si le lecteur ne dit pas ce qui joue, la vidéo est arrêtée.
  - GitHub Actions épinglées par empreinte de commit ; `pyyaml` à version fixe ; notes de version sur plusieurs lignes.
- **Non corrigé, à décider par Antsa** :
  - Les APK sont signés avec la clé *debug* Android du poste (`~/.android/debug.keystore`). La changer obligerait à
    désinstaller l'app (journal perdu). À faire : **sauvegarder ce fichier hors du poste**, comme `ed25519.pem`.
  - Catalogue de vidéos non signé (il vient du site en HTTPS ; la liste blanche de chaînes reste dans le dépôt).
  - Kotlin Gradle Plugin 2.4.0, CVE-2026-53914 (https://osv.dev/vulnerability/GHSA-r937-wjx7-w2jp) : ne touche que la
    compilation, pas l'APK ; pas encore de version stable corrigée.
- **Reste à tester** : sur appareil, que la sauvegarde Google ne contient plus rien ; un code parent pour les plus de 10 ans.
