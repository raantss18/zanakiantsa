# 0052 — L'app choisit seule sa mise en page, selon l'écran et la police

- **Date** : 2026-11-05 · **Statut** : accepté (retours d'Antsa sur tablette : « l'accueil ne s'affiche pas bien, je ne
  vois pas les trois thèmes, la police est trop grande » ; « l'échiquier est trop petit à côté des écritures, en
  paysage »).
- **Cause** : toutes les pages étaient pensées en une colonne, portrait. L'accueil empilait des blocs de hauteur fixe
  (en-tête, texte, « Tout explorer », rangée du bas) et les trois cartes se partageaient le reste ; l'échiquier prenait
  ce qui restait en hauteur. En paysage, cela ne laisse presque rien (600 dp de haut, dont 340 pris), les boutons ▶ des
  cartes étaient coupés. Le manifeste verrouille le portrait, mais **Android 16 ignore ce verrou sur les écrans de
  600 dp et plus** : une tablette de cette taille tourne vraiment (`CLAUDE.md`, profil « tablette B »).
- **Décision** (règles pures dans `ui/adaptive.dart`, testées sur beaucoup de tailles : `test/adaptive_test.dart`) :
  - **Paysage** = au moins 15 % plus large que haut et 560 dp de large. Alors :
    - accueil : à gauche l'en-tête, le texte d'accueil et les boutons, à droite les trois cartes l'une sous l'autre ;
    - partie d'échecs et revue : l'échiquier prend toute la hauteur, texte et boutons dans une colonne à côté ;
    - leçons d'échecs : le narrateur passe dans une colonne à gauche, l'échiquier a toute la hauteur.
  - **Portrait** : comme avant tant que les cartes ont leur place. S'il manque de la place (écran bas, police grande,
    journée finie), toute la page défile et les cartes gardent leur taille : plus jamais de cartes écrasées.
  - **Police du système** suivie entre 100 % et 130 % (115 % si l'écran fait moins de 500 dp de haut), jamais au-delà :
    les boutons et cartes à taille fixe ne débordent plus. Jamais sous 100 %, par lisibilité.
- **Limite connue** : les autres écrans (activités de comptage, lecture, etc.) gardent leur disposition ; seuls
  l'accueil et les échecs ont une version paysage. À reprendre écran par écran si un retour le demande.
- **Vérifié** : `test/adaptive_test.dart` (11 tests sur de nombreuses tailles et polices). Sur l'émulateur : tablette de
  600 dp en paysage (accueil, partie contre Maia, revue, leçon avec exemple), police système à 200 % (ramenée à 130 %),
  tablette de 457 dp et téléphone de 1080 × 2400 en portrait (sans changement). Le profil de 457 dp (SM-X135G) ne peut
  pas passer en paysage : sous 600 dp, le manifeste garde le portrait. **Pas vérifié** : une vraie tablette ; les écrans
  autres que l'accueil et les échecs en paysage.
- **Aussi corrigé** : « 1 coups » dans la liste des parties.
