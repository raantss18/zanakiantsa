# 0047 — Stockfish et Maia dans l'app (proposé, à valider par Antsa)

- **Date** : 2026-11-05 · **Statut** : proposé, puis tranché par l'ADR 0051 (Maia) et l'ADR 0053 (Stockfish 11) (demande d'Antsa : « intégrer Maia et Stockfish et les outils
  nécessaires », priorité basse)
- **Faits mesurés** (GitHub, 2026-11-05) :
  - **Stockfish 19** : GPL-3, son README demande de joindre la licence et les sources. Le paquet Android arm64 pèse
    80,2 Mo. Son réseau `nn-1a298aa575a0.nnue` pèse à lui seul 78,9 Mo
    (https://github.com/official-stockfish/Stockfish, `src/evaluate.h`, tag `sf_19`).
  - **Maia-1** (CSSLab/maia-chess) : GPL-3. Neuf niveaux, de 1100 à 1900, de 1,2 à 1,3 Mo chacun. Il faut le moteur
    **lc0** (GPL-3, sans version Android en ligne de commande publiée), avec `go nodes 1`.
  - **Maia-2** : MIT, mais 280 Mo (modèle PyTorch). **Maia-3** : AGPL-3, exclu (CLAUDE.md règle 7).
- **Licences** : la FSF admet qu'un programme GPL soit livré avec d'autres, même non libres (ML Kit), s'il reste un
  programme séparé qui communique par tuyaux ou en ligne de commande, comme UCI
  (https://www.gnu.org/licenses/gpl-faq.html#MereAggregation). Ce qui est **interdit** : charger Stockfish ou Maia dans
  le même processus que l'app. ⚠ Lecture de la FAQ, pas un avis juridique.
- **Android** : depuis Android 10, l'app ne peut plus exécuter un fichier téléchargé : il doit être livré dans l'APK
  (https://developer.android.com/about/versions/10/behavior-changes-10#execute-permission).
- **Proposition** :
  1. **Stockfish** : le programme, sans réseau intégré, livré dans l'APK (⚠ taille non mesurée, à mesurer). Son réseau
     de 79 Mo est téléchargé une fois depuis l'espace parent, comme les modèles ML Kit. Usage : analyse fine des
     parties et explication du meilleur coup. Licence GPL et lien vers les sources dans l'espace parent.
  2. **Maia-1** : compiler lc0 pour Android comme programme séparé (⚠ faisabilité et taille à vérifier). Joindre
     maia-1100 et maia-1500 (2,6 Mo). Usage : des robots « qui jouent comme des humains », pour les grands et les
     parents. 1100 reste trop fort pour un débutant de 5 ans : les niveaux 1 à 3 de l'app restent pour les petits.
- **Autres domaines** : « les outils nécessaires » sont à préciser par Antsa (exemple : reconnaissance de la parole
  hors ligne pour lire à voix haute). Aucun outil n'est choisi sans sa licence et sa taille vérifiées.
