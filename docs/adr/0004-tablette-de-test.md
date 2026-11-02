# 0004 — Tablette de test par adb

- **Date** : 2026-11-02 · **Statut** : accepté
- **Décision** : les versions de test s'installent et se désinstallent par `adb`, sans demande à chaque fois, sur
  **deux** Galaxy Tab A11 SM-X135G identiques (série `R8YYA0CZ5ZV` et `R8YL11BAJ7D`, toutes deux supervisées par
  Family Link). Utiliser `adb -s <série>`. La seconde tablette n'a pas été désencombrée (référence « d'usine »).
- **Limite** : seuls les paquets de Zanak'i Antsa (et des spikes) sont touchés. Jamais les réglages, Family Link,
  Knox Guard ni les autres applis.
- **Raison** : accord d'Antsa ; essais réels sur l'appareil cible.
