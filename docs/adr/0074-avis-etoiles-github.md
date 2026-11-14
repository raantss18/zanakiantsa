# ADR 0074 — La note de l'app : les étoiles du dépôt GitHub

- **Statut** : accepté (2026-11-14, demande d'Antsa : « un système de notation de l'app lié à la notation du dépôt sur
  GitHub, sur le site ou dans l'app »).
- **Décision** : la note, ce sont les étoiles du dépôt (https://docs.github.com/fr/get-started/exploring-projects-on-github/saving-repositories-with-stars).
  - Le site les montre dans « Votre avis », avec « Donner une étoile » (page GitHub) et « Écrire un avis » (ticket
    étiqueté `avis`). Le flux du site se relance à chaque nouvelle étoile (`on: watch`,
    https://docs.github.com/actions/using-workflows/events-that-trigger-workflows#watch) et écrit `avis.json`.
  - L'espace parent montre le même nombre, lu dans `avis.json` sur le site (jamais chez GitHub), et ouvre les mêmes pages.
    Le canal natif `open` n'ouvre que les adresses `https://github.com/raantss18/zanakiantsa…`.
- **Pourquoi** : aucun compte ni serveur à nous ; la note ne peut pas être gonflée par l'app ; rien sur l'enfant ne part
  (règle 5). Ni le site ni l'app ne contactent GitHub depuis l'appareil de l'utilisateur.
- **Limite** : une étoile n'est pas une note sur 5, et il faut un compte GitHub. Les avis écrits passent par les tickets.
- **Reste à tester** : sur la SM-X135G avec Family Link (le navigateur peut être bloqué : l'adresse est alors affichée).
