/// Disposition adaptative (ADR 0052) : l'app choisit seule sa mise en page selon la place réellement disponible et la
/// taille de police du système, au lieu de supposer un téléphone en portrait. Des règles simples, sans magie, testées
/// sur beaucoup de tailles (`test/adaptive_test.dart`).
library;

import 'dart:math';
import 'package:flutter/widgets.dart';

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
double homeChrome({required double fontScale, required bool dayFinished, bool strip = false}) =>
    (strip ? homeStripHeight : 0) /* série, « À revoir », défi du jour (ADR 0071) */ +
    84 /* en-tête */ +
    (108 * fontScale +
        12) /* texte d'accueil, plus haut avec une grande police */ +
    (dayFinished ? 96 * fontScale : 0) /* bandeau « journée finie » */ +
    64 /* « Tout explorer » */ +
    84 /* rangée du bas */ +
    24 /* marges */;

/// La rangée « série de jours, À revoir, Défi du jour » de l'accueil, marge comprise.
const homeStripHeight = 72.0;

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

/// Taille à partir de laquelle une activité a de la place à revendre : elles sont dessinées pour un téléphone ou une petite
/// tablette (ADR 0054). En dessous, rien ne change. La hauteur est celle de la plus haute (opération posée et son clavier,
/// grille de 10 × 10 et ses réponses : mesurée à 475 dp).
const activityDesignSize = Size(460, 520);

/// Agrandissement le plus fort : au-delà, les boutons deviennent plus gros que la main d'un enfant.
const activityMaxScale = 1.6;

/// De combien agrandir une activité dans une zone [area] : tout (objets, textes, boutons, cibles tactiles) dans la même
/// proportion. Jamais moins de 1 : sur un petit écran, l'activité reste telle quelle.
double activityScale(Size area) => min(area.width / activityDesignSize.width, area.height / activityDesignSize.height).clamp(1.0, activityMaxScale);

/// Réduction la plus forte quand la place manque en hauteur : en dessous, les cibles tactiles passeraient sous 48 dp.
const activityMinScale = 0.72;

/// L'échelle d'une activité dans sa zone. Quand la hauteur manque (pendant l'exemple résolu, la place du bouton « J'ai
/// compris » est gardée), elle rétrécit pour tenir en entier au lieu d'être coupée en bas — vu sur la tablette le 2026-11-08 :
/// réponses à moitié cachées pendant l'exemple. Les quiz défilent (et montrent seuls la bonne réponse) : ils ne rétrécissent pas.
double activityScaleFor(Size area, String activity) {
  if (activitiesThatFill.contains(activity)) return 1;
  if (activity != 'quiz' && area.height < activityDesignSize.height) {
    return max(activityMinScale, area.height / activityDesignSize.height);
  }
  return activityScale(area);
}

/// Ces activités remplissent déjà leur zone (échiquier, grille, scène, zone de tracé) : les agrandir réduirait au contraire leur
/// élément principal, qui prendrait moins de place à côté de boutons plus gros.
const activitiesThatFill = {'echecs', 'probleme', 'programmer', 'blocs', 'planetes', 'corps', 'solide', 'tracer', 'denombrer', 'composer'};

/// Paysage : le texte passe-t-il dans une colonne à gauche de l'activité ? Oui s'il reste assez de largeur à côté.
bool activityBesideText(Size screen) => isLandscape(screen) && screen.width - sidePanelWidth(screen.width) >= 380;

/// Une activité agrandie de [scale] (voir [activityScale]) pour remplir sa zone sur une grande tablette (ADR 0054). Elle se
/// dessine à sa taille habituelle puis tout est mis à l'échelle : ses mises en page et ses touchers restent justes, sans rien
/// changer dans ses 25 écrans.
class ScaledActivity extends StatelessWidget {
  const ScaledActivity({super.key, required this.scale, required this.child});
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => scale == 1
      ? child
      : Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: FractionallySizedBox(alignment: Alignment.topLeft, widthFactor: 1 / scale, heightFactor: 1 / scale, child: child),
        );
}

/// Largeur d'une page de texte ou de listes (accueil de domaine, carnet, espace parent) : au-delà, les lignes courent sur toute
/// la tablette et deviennent pénibles à lire (ADR 0054).
const readableWidth = 760.0;

/// Marge à donner à une liste pour qu'elle reste dans [readableWidth], centrée ; [side] et [top]/[bottom] sont les marges
/// habituelles sur un petit écran.
EdgeInsets readablePadding(BuildContext context, {double side = 16, double top = 16, double bottom = 16}) {
  final extra = (MediaQuery.sizeOf(context).width - readableWidth) / 2;
  return EdgeInsets.fromLTRB(extra > side ? extra : side, top, extra > side ? extra : side, bottom);
}
