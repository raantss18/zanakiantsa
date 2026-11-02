# 0012 — ML Kit accepté malgré sa licence non open source

- **Date** : 2026-11-02 · **Statut** : accepté (Antsa)
- **Contexte** : le SDK ML Kit est régi par les Google APIs Terms of Service, pas par une licence OSI
  (`docs/licences.md`), ce que l'ADR 0001 interdit sauf ADR.
- **Décision** : ML Kit est **autorisé** (encre numérique, étiquetage d'images) via les plugins MIT `google_mlkit_*`.
- **Raison** : l'app sert à la famille d'Antsa uniquement ; c'est la seule reconnaissance hors ligne vérifiée pour
  `fr` et `en`.
- **Vérifié** (https://developers.google.com/ml-kit/terms, 2026-11-02) : images, texte et résultats sont traités
  sur l'appareil et ne sont pas envoyés ; mais ML Kit « send metrics about the performance and utilization of the
  APIs » à Google (appareil, paquet, identifiant, latence, erreurs ; `docs/conformite.md`). Accepté en connaissance
  de cause ; le code de l'app reste Apache-2.0.
- **Si l'app est un jour diffusée plus largement** : réexaminer cette exception.
