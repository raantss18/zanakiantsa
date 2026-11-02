import 'dart:math';
import 'dart:ui';

/// Placement de [n] objets sans chevauchement : une grille d'au moins [n] cases (mélangées), un objet par case,
/// légèrement décalé (±10 %) dans sa case. Positions en fraction (0–1) de la zone, avec la taille d'une case.
class Scatter {
  Scatter(int n, Random rand, {double aspect = 1}) {
    cols = max(2, sqrt(n * aspect).ceil());
    final r = max(2, (n / cols).ceil());
    // Une rangée de plus quand la grille est presque pleine : de l'air entre les objets.
    rows = cols * r < n + 2 ? r + 1 : r;
    final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(rand);
    spots = [
      for (final cell in cells.take(n))
        Offset(
          (cell % cols + 0.5 + (rand.nextDouble() - 0.5) * 0.2) / cols,
          (cell ~/ cols + 0.5 + (rand.nextDouble() - 0.5) * 0.2) / rows,
        ),
    ];
  }

  late final int cols, rows;
  late final List<Offset> spots;

  /// Rayon maximal d'un objet pour une zone donnée : 38 % de la plus petite dimension d'une case. Avec un décalage de
  /// ±10 %, deux voisins restent à ≥ 0,8 case l'un de l'autre > 2 × 0,38 : jamais de chevauchement (test).
  double radius(Size area) => min(area.width / cols, area.height / rows) * 0.38;
}
