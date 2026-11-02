# Design system — Zanak'i Antsa

> Méthode : skill `design:design-system` (jetons → composants → motifs). Contrastes calculés (WCAG 2.x) par
> `app/tool/contrast.py` : tous ≥ 4,5:1 pour le texte, ≥ 3:1 pour les éléments graphiques. Rien n'est copié d'une marque :
> illustrations **Twemoji v17.0.3** (CC BY 4.0, https://github.com/jdecked/twemoji), police **Andika 7.000**
> (SIL OFL, « literacy font », https://software.sil.org/andika/).

## 1. Univers (ADR 0014)

Choisi **strictement selon le genre** saisi par le parent ; l'enfant choisit parmi les 3 univers de son genre.

| Univers | Genre | Mascotte | Objets à compter (s./pl.) | Contenant (composer) | Fond (dégradé) | Primaire / texte |
| --- | --- | --- | --- | --- | --- | --- |
| Robots | garçon | 🤖 | engrenage(s) ⚙️, pile(s) 🔋 | la caisse à outils 🧰 | #E3F0FA → #C9DFF0 | #1F5F8B / blanc (6,8) |
| Voitures | garçon | 🏎️ | voiture(s) 🚗, camion(s) 🚚 | le garage 🏠 | #FFF3E0 → #FFE0B2 | #B71C1C / blanc (6,6) |
| Espace | garçon | 🧑‍🚀 | planète(s) 🪐, satellite(s) 🛰️ | la fusée 🚀 | #1A1F4A → #2D1E5C (nuit) | #FFC83D / encre (10,6) ; sur carte : accent #5E35B1 (8,0) |
| Fées | fille | 🧚‍♀️ | papillon(s) 🦋, fleur(s) 🌸 | le panier 🧺 | #F6E8F8 → #E3F4FB | #7B1FA2 / blanc (8,2) |
| Poupées & mode | fille | 💃 | robe(s) 👗, nœud(s) 🎀 | la valise 🧳 | #FDE7EF → #FFF6E0 | #AD1457 / blanc (7,0) |
| Princesses & château | fille | 👸 | couronne(s) 👑, diamant(s) 💎 | le coffret 🎁 | #EEE8F8 → #FFF7CC | #5E2A8C / blanc (9,6) |

Chaque univers a aussi : un décor (6 éléments en filigrane, opacité ≤ 12 %, jamais derrière un texte), des pierres du
fil rouge à son image, 12 autocollants à collectionner.

## 2. Jetons

- **Typographie** : Andika. Énoncé 24 sp gras (réduit seulement s'il dépasse 3 lignes ; consignes ≤ 60 caractères),
  réponses 44 sp, nombres de l'énoncé 64 sp, titres 28 sp. Interligne 1,2–1,25.
- **Espacements** : 8 · 12 · 16 · 24 · 32. Marges d'écran 16 (portrait), 24 (paysage).
- **Rayons** : cartes 28, boutons 24, pastilles 999.
- **Ombres** : une seule, douce (`blur 12, alpha .18`) pour les cartes posées sur un décor.
- **Mouvement** : 200 ms (retours), 450 ms (entrées), rebond `Curves.elasticOut` pour la mascotte ; décor animé lent
  (≥ 6 s par cycle). Tout est coupé si l'appareil demande moins d'animations.
- **Cibles** : ≥ 72 dp côté enfant (≥ 48 exigé).

## 3. Composants

| Composant | Rôle | Règles |
| --- | --- | --- |
| **Bandeau narrateur** | mascotte + bulle avec l'**énoncé écrit** (ADR 0016) | hauteur fixe (la zone de jeu ne change jamais de taille) ; texte ajusté sur 3 lignes max ; l'aide remplace l'énoncé dans la même bulle, avec une ampoule 💡 ; haut-parleur pour réécouter |
| **Bouton-réponse** | nombre à choisir | 104 dp, primaire de l'univers ; pendant une démonstration la bonne réponse porte en plus un contour épais et une ✔ (pas seulement la couleur) |
| **Compteur d'étoiles** | étoiles gagnées dans la séance | en haut à droite, nombre écrit à côté de ⭐ |
| **Scène de réussite** | bonne réponse | propre au monde (1,4 s) : l'engrenage tourne, la voiture passe la ligne, la fusée décolle, la fée vole, la robe virevolte, la couronne tombe ; éclats d'objets du monde ; mascotte qui saute ; aucun son négatif nulle part |
| **Album** | autocollants gagnés | grille 3 × 4 ; non gagnés = silhouette grise + cadenas (forme, pas seulement couleur) |
| **Fil rouge** | progression | pierres = icône de l'univers ; mascotte posée sur la pierre courante |

## 4. Règles anti-défauts (revue de chaque écran)

1. Aucun texte posé sur le décor sans carte de fond (lisibilité).
2. Aucun élément ne change la taille de la zone de jeu (bug de la bulle du 2026-11-02).
3. Aucun objet à compter sous le bandeau ni sous les boutons ; espacement ≥ 0,3 × rayon entre objets.
4. Portrait et paysage vérifiés sur les deux SM-X135G (ADR 0013), capture à l'appui.
5. Couleur jamais seule : forme, icône, texte ou voix avec.
