/// Déplacements des pièces (FIDE Laws of Chess, art. 3) sur un échiquier vide, et parcours d'étoiles à attraper.
library;

import 'dart:math';

typedef Square = (int, int); // (colonne, rangée), 0 à 7

bool onBoard(Square s) => s.$1 >= 0 && s.$1 < 8 && s.$2 >= 0 && s.$2 < 8;

const _straight = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const _diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
const _knight = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)];

/// Cases atteignables en un coup par [piece] (r tour, b fou, q dame, k roi, n cavalier), échiquier sans autre pièce.
Set<Square> moves(String piece, Square from) {
  Iterable<Square> ray(List<(int, int)> dirs, int reach) sync* {
    for (final (dc, dr) in dirs) {
      for (var k = 1; k <= reach; k++) {
        final s = (from.$1 + dc * k, from.$2 + dr * k);
        if (!onBoard(s)) break;
        yield s;
      }
    }
  }

  return switch (piece) {
    'r' => ray(_straight, 7),
    'b' => ray(_diagonal, 7),
    'q' => ray([..._straight, ..._diagonal], 7),
    'k' => ray([..._straight, ..._diagonal], 1),
    'n' => _knight.map((d) => (from.$1 + d.$1, from.$2 + d.$2)).where(onBoard),
    _ => throw ArgumentError(piece),
  }
      .toSet();
}

class StarPuzzle {
  const StarPuzzle(this.start, this.stars);
  final Square start;

  /// Dans l'ordre d'un chemin possible : chaque étoile est à un coup de la précédente (ou du départ).
  final List<Square> stars;
}

/// Un départ et [count] étoiles, chacune atteignable en un coup depuis la précédente : le parcours existe toujours.
StarPuzzle starPuzzle(String piece, int count, Random r) {
  final start = (r.nextInt(8), r.nextInt(8));
  final stars = <Square>[];
  var cur = start;
  for (var i = 0; i < count; i++) {
    final options = moves(piece, cur).where((s) => s != start && !stars.contains(s)).toList();
    final next = options[r.nextInt(options.length)];
    stars.add(next);
    cur = next;
  }
  return StarPuzzle(start, stars);
}
