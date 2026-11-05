# 0044 — La langue de la voix est réglée avant chaque phrase, jamais gardée en mémoire

- **Date** : 2026-11-05 · **Statut** : accepté (retour : « sur un autre appareil, le français est en anglais »)
- **Cause** (code Android de flutter_tts 4.2.5 lu, `FlutterTtsPlugin.kt`) : à chaque démarrage ou reconnexion du
  moteur (au lancement, après un `speak` refusé, après un changement de moteur), le plugin remet la langue à celle
  **du téléphone**, après avoir exécuté nos ordres en attente. L'app retenait « fr-FR déjà réglé » (ADR 0022) et ne le
  redisait plus : sur un téléphone réglé en anglais, le français était lu par la voix anglaise. Le bug « revenait »
  selon que le moteur avait redémarré ou non.
- **Décision** : `setLanguage` et la vitesse avant **chaque** phrase, sans mémoire. On vérifie la réponse : variantes
  acceptées (fr-FR, fr-CA, fr-BE, fr-CH ; en-GB, en-US, en-AU). Aucune voix de la langue : on se tait (le texte reste
  écrit) plutôt que de lire avec une voix d'une autre langue, et l'espace parent l'indique (« Tester la voix »).
- **Protégé par** `test/voice_language_test.dart` : faux moteur qui revient à en-US au redémarrage ; l'ancien code
  échoue (phrase française dite en en-US), le nouveau passe.
- **Vérifié sur l'émulateur réglé en en-US** : toutes les phrases demandées en fra-FRA. **Reste à tester** : à
  l'oreille, sur l'appareil qui montrait le bug.
