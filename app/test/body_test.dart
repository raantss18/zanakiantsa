import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/explore.dart';

// Le corps humain sur la SM-X135G (zone ≈ 430 × 420 dp) : les petites parties se touchent même un peu à côté.
void main() {
  const size = Size(430, 420);
  final paths = bodyPaths(size);

  test('chaque partie se touche en son centre', () {
    for (final k in bodyParts.keys) {
      final c = paths[k]!.getBounds().center;
      // Le centre des bras et des jambes tombe sur la partie elle-même (deux rectangles : on prend le premier).
      final at = k == 'bras' || k == 'jambes' || k == 'mains' || k == 'pieds' ? paths[k]!.getBounds().topLeft + const Offset(8, 12) : c;
      expect(bodyHit(size, at), k, reason: k);
    }
  });

  test('un doigt juste à côté du cou ou d\'une main compte encore', () {
    final cou = paths['cou']!.getBounds();
    expect(bodyHit(size, Offset(cou.right + 6, cou.center.dy)), 'cou');
    final main = paths['mains']!.getBounds();
    expect(bodyHit(size, Offset(main.left - 5, main.center.dy)), 'mains');
  });

  test('loin du corps : rien', () => expect(bodyHit(size, const Offset(5, 5)), isNull));
}
