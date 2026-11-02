# 0009 — Packs ML Kit d'écriture : un téléchargement unique

- **Date** : 2026-11-02 · **Statut** : accepté
- **Décision** : les modèles ML Kit Digital Ink (`fr`, puis `en`) sont **téléchargés une seule fois**, depuis l'espace
  parent ; ensuite, la reconnaissance fonctionne **hors ligne**. Sans modèle, l'activité d'écriture reste jouable
  (tracé guidé) sans reconnaissance.
- **Raison** : choix d'Antsa. ML Kit liste `fr` et `en` et fonctionne hors ligne sur Android
  (https://developers.google.com/ml-kit/vision/digital-ink-recognition/base-models, vérifié le 2026-11-02).
- **Reste à tester sur la SM-X135G** : taille des packs, mémoire, précision sur écriture d'enfant, téléchargement
  autorisé sous Family Link.
