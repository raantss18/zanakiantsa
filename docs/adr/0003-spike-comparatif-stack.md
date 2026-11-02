# 0003 — Spike comparatif de la stack avant de trancher

- **Date** : 2026-11-02 · **Statut** : accepté (méthode) ; stack **non tranchée**
- **Décision** : construire la **même mini-activité** (dénombrer des objets qu'on touche + voix off + son) en
  **Flutter + Flame**, **Kotlin / Jetpack Compose** et **Godot**, puis mesurer sur la SM-X135G.
- **Critères chiffrés** : taille d'APK, pic de mémoire PSS (`dumpsys meminfo`), démarrage à froid
  (`am start -W`), images par seconde, accès ML Kit (encre numérique, étiquetage d'images), maintenabilité par un
  développeur seul.
- **Raison** : choix d'Antsa (comparatif complet plutôt que Flutter seul).
- **Sortie** : un ADR « stack retenue » avec le tableau des mesures.
