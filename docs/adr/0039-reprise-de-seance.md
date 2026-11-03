# 0039 — Reprendre une séance où l'enfant s'est arrêté

- **Date** : 2026-11-03 · **Statut** : accepté (demande d'Antsa : sortir d'un domaine ne doit pas faire recommencer)
- **Décision** : après chaque question, le point de reprise (plan de la séance, rang de la question, étoiles) est
  gardé par enfant et par domaine (`reprise_<domaine>` dans les réglages de l'enfant). Rouvrir le domaine — depuis
  l'accueil, « Tout explorer », après un autre domaine ou un redémarrage — reprend au même rang, avec les mêmes
  étoiles ; la question est tirée à nouveau dans la même compétence (ADR 0030). Fin de séance : la reprise est effacée.
- Une reprise dont une compétence n'existe plus (contenu mis à jour) est ignorée : nouvelle séance.
- **Vérifié sur l'émulateur** : 2 questions, sortie, autre domaine, app fermée, retour → 3ᵉ question, 2 étoiles.
