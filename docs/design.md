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
| **Scène de réussite** | bonne réponse | propre au monde (1,4 s) : l'engrenage tourne, la voiture passe la ligne, la fusée décolle, la fée vole, la robe virevolte, la couronne tombe ; éclats d'objets du monde ; mascotte qui saute ; bruitage du monde (bip-bip, moteur, décollage, clochettes, « ta-da », harpe) ; aucun son négatif nulle part |
| **Fil d'histoire** | fin de séance, accueil | épisode gagné écrit + dit, mascotte à gauche, « Épisode n » + pastilles (numéro écrit, la couleur n'est pas seule) ; ADR 0017 |
| **Album** | autocollants gagnés | grille 3 × 4 ; non gagnés = silhouette grise + cadenas (forme, pas seulement couleur) |
| **Fil rouge** | progression | pierres = icône de l'univers ; mascotte posée sur la pierre courante |

## 4. Règles anti-défauts (revue de chaque écran)

1. Aucun texte posé sur le décor sans carte de fond (lisibilité).
2. Aucun élément ne change la taille de la zone de jeu (bug de la bulle du 2026-11-02).
3. Aucun objet à compter sous le bandeau ni sous les boutons ; espacement ≥ 0,3 × rayon entre objets.
4. Portrait et paysage vérifiés sur les deux SM-X135G (ADR 0013), capture à l'appui.
5. Couleur jamais seule : forme, icône, texte ou voix avec.

## 5. Composant : interrupteurs « Voix » et « Musique » (ADR 0025)

**Problème.** Certains enfants (ou parents) veulent lire sans la voix, ou jouer sans musique ; la trame sonore ne doit
jamais gêner l'écoute. Le bouton « Réécouter » existant dit la phrase, il ne règle rien.

| Composant voisin | Point commun | Pourquoi il ne suffit pas |
| --- | --- | --- |
| Bouton « Réécouter » (bandeau) | icône haut-parleur | action ponctuelle, pas un état |
| Réglages de l'espace parent | état mémorisé | caché derrière une multiplication : pas visible pendant la leçon |

**Conception.** Deux interrupteurs ronds de 48 dp dans la barre du haut de **chaque** leçon et exercice (séances et
dessin), entre ← et la barre de progression.

| Propriété | Valeur |
| --- | --- |
| `SoundToggle(kind: voice / music, on, onChanged)` | état global mémorisé (`voix`, `musique` dans les réglages) |
| Activé | fond blanc, icône `record_voice_over` / `music_note` couleur `onCard` de l'univers |
| Coupé | fond gris `#BFC7C1`, icône barrée `voice_over_off` / `music_off` encre, contour pointillé : **la forme de l'icône change**, pas seulement la couleur |
| Lecteur d'écran | « Voix, activée » / « Voix, coupée » (bouton à bascule) |
| Retour | voix réactivée → la consigne est redite ; musique réactivée → la trame reprend en fondu |

**Règles.** Voix coupée : tout reste écrit (bandeau narrateur), « Réécouter » dit quand même la phrase (demande
explicite). Musique coupée : ni trame, ni bruitages. Trame sonore : volume 0,15, baissée à 0,04 pendant que la voix
parle, **arrêtée** pendant les exercices d'écoute (« Les sons ») et absente de l'accueil.

## 6. Bibliothèque et liseuse (ADR 0026)

**Bibliothèque** (bouton « Mes livres » de l'accueil, le plus grand de la rangée du bas) : en-tête ← + « Ma
bibliothèque » + nombre de livres lus ; **étagères** en puces (Tout, Compter et apprendre, Animaux et nature, Ma vie,
Contes et fables) avec icône et nom écrits ; **couvertures** en grille (≥ 160 dp), titre écrit dessous sur 2 lignes,
« Niveau 1–3 » écrit + pastilles, ✔ « Lu » sur les livres finis (forme + texte, pas seulement la couleur).

**Liseuse** : l'image en haut (jamais rognée), le texte dessous sur une carte blanche en Andika 28 sp (lisible à
bout de bras), « 3 / 10 » écrit ; ◀ ▶ de 72 dp en bas et glisser du doigt ; bouton « Lis-moi » (lecture à voix
haute de la page, puis page suivante tout seul, jusqu'à la fin ou un nouveau toucher) qui fonctionne même voix coupée
(c'est une demande). Dernière page : « Fin », une étoile la première fois, et les **crédits du livre** (auteurs,
illustrateurs, traducteurs, licence CC BY 4.0, source) — exigés par la licence, toujours visibles.
