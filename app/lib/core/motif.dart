/// Motifs organisés (programme de maternelle, « Se familiariser avec les motifs organisés ») : une suite d'images
/// avec un trou, et les images proposées pour le combler (ADR 0019).
library;

import 'dart:math';

class MotifPuzzle {
  const MotifPuzzle(this.sequence, this.hole, this.choices);

  /// Codes d'images de la suite complète ; [hole] est la place cachée.
  final List<String> sequence;
  final int hole;
  final List<String> choices;

  String get answer => sequence[hole];
}

/// Lettres du motif : AB, ABB, AAB, ABC répétés ; « AB+ » évolutif (A B AA BB AAA BBB).
List<int> motifLetters(String base) {
  if (base == 'AB+') return [for (var k = 1; k <= 3; k++) ...[...List.filled(k, 0), ...List.filled(k, 1)]];
  final unit = [for (final c in base.codeUnits) c - 'A'.codeUnitAt(0)];
  final cycles = unit.length == 2 ? 4 : 3;
  return [for (var i = 0; i < cycles; i++) ...unit];
}

/// [pool] : images de l'univers (au moins 4 différentes). Le trou est dans la seconde moitié : l'enfant a vu au moins
/// deux fois le motif avant de devoir le continuer.
MotifPuzzle motifPuzzle(String base, List<String> pool, Random r) {
  final arts = ([...pool.toSet()]..shuffle(r));
  final letters = motifLetters(base);
  final kinds = letters.reduce(max) + 1;
  final seq = [for (final l in letters) arts[l]];
  final hole = letters.length ~/ 2 + r.nextInt(letters.length - letters.length ~/ 2);
  final choices = [...arts.take(kinds), if (kinds < 3) ...arts.skip(kinds).take(3 - kinds)]..shuffle(r);
  return MotifPuzzle(seq, hole, choices);
}
