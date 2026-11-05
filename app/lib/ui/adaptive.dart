/// Disposition adaptative (ADR 0052) : l'app choisit seule sa mise en page selon la place réellement disponible et la
/// taille de police du système, au lieu de supposer un téléphone en portrait. Des règles simples, sans magie, testées
/// sur beaucoup de tailles (`test/adaptive_test.dart`).
library;

import 'dart:math';
import 'dart:ui';

/// Paysage : au moins 15 % plus large que haut, et assez large pour deux colonnes. Sur une tablette (≥ 600 dp), Android
/// 16 ignore le verrou « portrait » du manifeste : l'app doit donc savoir tourner.
bool isLandscape(Size s) => s.width >= 560 && s.width > s.height * 1.15;

/// Largeur d'une colonne latérale (texte, boutons) à côté d'un grand élément (échiquier, cartes) : un peu plus d'un
/// tiers de la largeur, entre 300 et 420 dp.
double sidePanelWidth(double width) => (width * 0.36).clamp(300.0, 420.0);

/// Le plus grand carré qu'on peut poser dans [area] : c'est la taille d'un échiquier.
double squareSide(Size area) => min(area.width, area.height);

/// Plafond de la police du système (ADR 0052). Les écrans d'enfants ont des boutons et des cartes à taille fixe : une
/// police à 200 % les ferait déborder. Jamais en dessous de 100 % (lisibilité), et au plus 130 % — 115 % quand l'écran
/// est bas (paysage), où chaque ligne de texte prend la place du jeu.
double maxFontScale(Size screen) => screen.height < 500 ? 1.15 : 1.3;

/// La police réellement appliquée : celle du système, ramenée entre 100 % et le plafond.
double appliedFontScale(double system, Size screen) =>
    system.clamp(1.0, maxFontScale(screen));

/// Ce que prend le reste de l'accueil (en-tête, texte d'accueil, boutons du bas), en dp, avec une marge pour que
/// l'estimation soit toujours trop grande plutôt que trop petite : mieux vaut défiler un peu que serrer les cartes.
double homeChrome({required double fontScale, required bool dayFinished}) =>
    84 /* en-tête */ +
    (108 * fontScale +
        12) /* texte d'accueil, plus haut avec une grande police */ +
    (dayFinished ? 96 * fontScale : 0) /* bandeau « journée finie » */ +
    64 /* « Tout explorer » */ +
    84 /* rangée du bas */ +
    24 /* marges */;

/// Plus petite hauteur utile des trois cartes du jour, côte à côte (grandes cartes) ou l'une sous l'autre (lignes).
const homeCardsMinSideBySide = 270.0,
    homeCardMinRow = 104.0,
    homeCardGap = 12.0;
double homeCardsMinStacked() => 3 * homeCardMinRow + 2 * homeCardGap;

/// Comment ranger les cartes du jour en portrait, selon la place [cardsHeight] qui leur reste.
class HomeCards {
  const HomeCards({
    required this.sideBySide,
    required this.scrolls,
    required this.height,
  });

  /// Trois colonnes (tablette en portrait) plutôt que trois lignes (téléphone).
  final bool sideBySide;

  /// Pas assez de place : toute la page défile, les cartes gardent leur taille minimale.
  final bool scrolls;

  /// Hauteur d'une carte quand la page défile.
  final double height;
}

HomeCards homeCardsFor({required double width, required double cardsHeight}) {
  final sideBySide = width > cardsHeight * 1.1 || width >= 440;
  final min = sideBySide ? homeCardsMinSideBySide : homeCardsMinStacked();
  final stacked = !sideBySide;
  final scrolls =
      (stacked ? homeCardsMinStacked() : homeCardsMinSideBySide) > cardsHeight;
  return HomeCards(
    sideBySide: sideBySide,
    scrolls: scrolls,
    height: stacked ? homeCardMinRow : min,
  );
}

/// Hauteur d'une carte du jour en paysage : les trois se partagent la hauteur de la colonne de droite.
double landscapeCardHeight(double height) =>
    (height - 2 * homeCardGap - 24) / 3;

/// En dessous de cette hauteur, la carte passe en version compacte (disque et bouton plus petits).
const homeCardCompactBelow = 140.0;
