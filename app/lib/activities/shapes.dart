import 'dart:math';
import 'dart:ui';

/// Objets dessinés par code (aucune image à embarquer, net sur tablette).
void drawApple(Canvas c, Offset o, double r) {
  c.drawCircle(o, r * 0.85, Paint()..color = const Color(0xFFD6362B));
  c.drawOval(Rect.fromLTWH(o.dx, o.dy - r, r * 0.6, r * 0.35), Paint()..color = const Color(0xFF1D7A33));
}

void drawStar(Canvas c, Offset o, double r) {
  final path = Path();
  for (var k = 0; k < 10; k++) {
    final rr = k.isEven ? r : r * 0.45;
    final a = -pi / 2 + k * pi / 5;
    final p = o + Offset(cos(a) * rr, sin(a) * rr);
    k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path..close(), Paint()..color = const Color(0xFFE08A00));
}

void drawObject(String kind, Canvas c, Offset o, double r) => kind == 'etoile' ? drawStar(c, o, r) : drawApple(c, o, r);

/// Positions sans chevauchement dans un rectangle (grille mélangée + petit décalage).
List<Offset> scatter(int n, Size area, double r, Random rand) {
  final cols = max(3, (area.width / (r * 2.6)).floor());
  final rows = max(3, (area.height / (r * 2.6)).floor());
  final cells = [for (var i = 0; i < cols * rows; i++) i]..shuffle(rand);
  final cw = area.width / cols, ch = area.height / rows;
  return [
    for (final cell in cells.take(n))
      Offset(
        (cell % cols + 0.5) * cw + (rand.nextDouble() - 0.5) * (cw - 2 * r) * 0.5,
        (cell ~/ cols + 0.5) * ch + (rand.nextDouble() - 0.5) * (ch - 2 * r) * 0.5,
      ),
  ];
}
