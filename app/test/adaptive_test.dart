import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/ui/adaptive.dart';

// L'app s'adapte seule à la taille de l'écran et de la police (ADR 0052).
void main() {
  group('portrait ou paysage', () {
    test('les écrans réels du projet', () {
      expect(isLandscape(const Size(457, 766)), isFalse, reason: 'SM-X135G en portrait (800 × 1340, 280 dpi)');
      expect(isLandscape(const Size(766, 457)), isTrue, reason: 'SM-X135G en paysage');
      expect(isLandscape(const Size(1005, 600)), isTrue, reason: 'tablette B en paysage');
      expect(isLandscape(const Size(600, 1005)), isFalse, reason: 'tablette B en portrait');
      expect(isLandscape(const Size(360, 780)), isFalse, reason: 'téléphone en portrait');
      expect(isLandscape(const Size(780, 360)), isTrue, reason: 'téléphone en paysage');
    });

    test('un écran presque carré reste en une colonne', () {
      expect(isLandscape(const Size(600, 560)), isFalse);
      expect(isLandscape(const Size(500, 400)), isFalse, reason: 'trop étroit pour deux colonnes');
    });

    test('la colonne latérale tient entre 300 et 420 dp et laisse la place au reste', () {
      for (var w = 560.0; w <= 2000; w += 40) {
        final side = sidePanelWidth(w);
        expect(side, inInclusiveRange(300, 420));
        expect(w - side, greaterThanOrEqualTo(250), reason: 'largeur $w : il reste de la place pour l\'échiquier ou les cartes');
      }
    });
  });

  group('police du système', () {
    test('suivie entre 100 % et 130 %, jamais au-delà, jamais en dessous', () {
      const tall = Size(457, 766);
      expect(appliedFontScale(0.8, tall), 1.0);
      expect(appliedFontScale(1.0, tall), 1.0);
      expect(appliedFontScale(1.15, tall), 1.15);
      expect(appliedFontScale(1.3, tall), 1.3);
      expect(appliedFontScale(2.0, tall), 1.3);
    });

    test('écran bas (paysage) : plafond plus bas, chaque ligne de texte prend la place du jeu', () {
      expect(maxFontScale(const Size(766, 457)), 1.15);
      expect(appliedFontScale(2.0, const Size(766, 457)), 1.15);
      expect(maxFontScale(const Size(1005, 600)), 1.3);
    });
  });

  group('accueil, portrait', () {
    const sizes = [Size(320, 568), Size(360, 640), Size(360, 780), Size(411, 891), Size(457, 766), Size(600, 1005), Size(800, 1280)];
    const scales = [1.0, 1.15, 1.3];

    test('les cartes ne sont jamais écrasées : soit elles ont leur place, soit la page défile', () {
      for (final size in sizes) {
        for (final scale in scales) {
          for (final finished in [false, true]) {
            final h = size.height - 48; // barres du système
            final chrome = homeChrome(fontScale: scale, dayFinished: finished);
            final layout = homeCardsFor(width: size.width - 32, cardsHeight: h - chrome);
            final reason = '$size police $scale ${finished ? 'journée finie' : ''}';
            if (layout.scrolls) {
              expect(layout.height, greaterThanOrEqualTo(homeCardMinRow), reason: reason);
            } else {
              final need = layout.sideBySide ? homeCardsMinSideBySide : homeCardsMinStacked();
              expect(h - chrome, greaterThanOrEqualTo(need), reason: reason);
            }
          }
        }
      }
    });

    test('un grand téléphone avec la police normale garde ses trois lignes sans défiler', () {
      final layout = homeCardsFor(width: 411 - 32, cardsHeight: 891 - 48 - homeChrome(fontScale: 1, dayFinished: false));
      expect(layout.scrolls, isFalse);
    });

    test('plus la police est grande, plus la place prise par le reste est grande', () {
      for (final finished in [false, true]) {
        expect(homeChrome(fontScale: 1.3, dayFinished: finished), greaterThan(homeChrome(fontScale: 1.0, dayFinished: finished)));
      }
      expect(homeChrome(fontScale: 1.0, dayFinished: true), greaterThan(homeChrome(fontScale: 1.0, dayFinished: false)));
    });
  });

  group('accueil, paysage', () {
    test('trois cartes lisibles : de la hauteur, ou la version compacte', () {
      for (final h in <double>[320, 360, 411, 457, 500, 540, 600, 700, 800]) {
        final usable = h - 48;
        final cardH = landscapeCardHeight(usable);
        expect(cardH * 3 + 2 * homeCardGap + 24, closeTo(usable, 0.001));
        final shown = cardH < homeCardMinRow ? homeCardMinRow : cardH;
        expect(shown, greaterThanOrEqualTo(homeCardMinRow));
        final compact = shown < homeCardCompactBelow;
        // Une carte compacte tient dans sa hauteur : disque de 72 + marges de 12.
        if (compact) expect(shown, greaterThanOrEqualTo(72 + 24));
      }
    });

    test('la tablette de 600 dp en paysage a la place des cartes de taille normale', () {
      expect(landscapeCardHeight(600 - 48), greaterThanOrEqualTo(homeCardCompactBelow));
    });
  });

  test('le plus grand carré d\'un échiquier', () {
    expect(squareSide(const Size(700, 450)), 450);
    expect(squareSide(const Size(300, 450)), 300);
  });
}
