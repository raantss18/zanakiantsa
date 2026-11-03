/// Petite 3D maison (ADR 0024) : des solides en facettes, tournés au doigt, éclairés, triés par profondeur et dessinés
/// en triangles par `Canvas.drawVertices` (rasterisés par le GPU via Impeller/Vulkan, pas de moteur 3D à embarquer).
library;

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;
  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double k) => V3(x * k, y * k, z * k);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(dot(this));
  V3 get unit => this * (1 / length);

  /// Tourne de [yaw] autour de l'axe vertical, puis de [pitch] autour de l'axe horizontal.
  V3 rotate(double yaw, double pitch) {
    final x1 = x * cos(yaw) + z * sin(yaw), z1 = -x * sin(yaw) + z * cos(yaw);
    return V3(x1, y * cos(pitch) - z1 * sin(pitch), y * sin(pitch) + z1 * cos(pitch));
  }
}

/// Une face : ses sommets (dans l'ordre, vue de l'extérieur) et si son contour se dessine (arêtes vraies du solide).
class Face {
  const Face(this.points, {this.outline = true});
  final List<int> points;
  final bool outline;
}

class Mesh {
  const Mesh(this.vertices, this.faces);
  final List<V3> vertices;
  final List<Face> faces;
}

Mesh box(double w, double h, double d) {
  final v = [
    for (final x in [-w, w])
      for (final y in [-h, h])
        for (final z in [-d, d]) V3(x / 2, y / 2, z / 2),
  ];
  // Indices : x*4 + y*2 + z.
  return Mesh(v, const [
    Face([0, 1, 3, 2]), Face([4, 6, 7, 5]), Face([0, 4, 5, 1]),
    Face([2, 3, 7, 6]), Face([0, 2, 6, 4]), Face([1, 5, 7, 3]),
  ]);
}

/// Cylindre ([rTop] = [rBottom]) ou cône ([rTop] = 0, un seul sommet en haut), à [n] côtés : les côtés n'ont pas de
/// contour, ce sont des facettes d'une surface courbe ; les disques en ont un.
Mesh lathe({required double rTop, required double rBottom, required double h, int n = 32}) {
  final ring = [for (var i = 0; i < n; i++) V3(rBottom * cos(2 * pi * i / n), h / 2, rBottom * sin(2 * pi * i / n))];
  if (rTop == 0) {
    final apex = n;
    return Mesh([...ring, V3(0, -h / 2, 0)], [
      for (var i = 0; i < n; i++) Face([apex, i, (i + 1) % n], outline: false),
      Face([for (var i = 0; i < n; i++) i]),
    ]);
  }
  final top = [for (var i = 0; i < n; i++) V3(rTop * cos(2 * pi * i / n), -h / 2, rTop * sin(2 * pi * i / n))];
  return Mesh([...ring, ...top], [
    for (var i = 0; i < n; i++) Face([i, (i + 1) % n, n + (i + 1) % n, n + i], outline: false),
    Face([for (var i = 0; i < n; i++) i]),
    Face([for (var i = 0; i < n; i++) n + i]),
  ]);
}

Mesh sphere({double r = 1, int lat = 14, int lon = 24}) {
  final v = <V3>[];
  for (var i = 0; i <= lat; i++) {
    final a = pi * i / lat;
    for (var j = 0; j < lon; j++) {
      final b = 2 * pi * j / lon;
      v.add(V3(r * sin(a) * cos(b), -r * cos(a), r * sin(a) * sin(b)));
    }
  }
  return Mesh(v, [
    for (var i = 0; i < lat; i++)
      for (var j = 0; j < lon; j++)
        Face([i * lon + j, i * lon + (j + 1) % lon, (i + 1) * lon + (j + 1) % lon, (i + 1) * lon + j], outline: false),
  ]);
}

Mesh pyramid(double w, double h) {
  final v = [V3(-w / 2, h / 2, -w / 2), V3(w / 2, h / 2, -w / 2), V3(w / 2, h / 2, w / 2), V3(-w / 2, h / 2, w / 2), V3(0, -h / 2, 0)];
  return Mesh(v, const [Face([0, 1, 2, 3]), Face([4, 1, 0]), Face([4, 2, 1]), Face([4, 3, 2]), Face([4, 0, 3])]);
}

/// Les solides usuels du programme de cycle 2 (cube, pavé, boule, cylindre, cône) et la pyramide.
final solids = <String, Mesh>{
  'cube': box(1.3, 1.3, 1.3),
  'pave': box(1.9, 1.0, 1.1),
  'boule': sphere(r: 0.95),
  'cylindre': lathe(rTop: 0.7, rBottom: 0.7, h: 1.6),
  'cone': lathe(rTop: 0, rBottom: 0.8, h: 1.6),
  'pyramide': pyramid(1.5, 1.4),
};

/// Dessine [mesh] centré dans [size] : faces vues de face seulement, de la plus lointaine à la plus proche, ombrage
/// diffus (lumière en haut à gauche, devant).
void paintMesh(Canvas canvas, Size size, Mesh mesh, {required double yaw, required double pitch, required Color color, double scale = 1, Offset center = Offset.zero}) {
  final s = min(size.width, size.height) * 0.36 * scale;
  final c = size.center(center);
  final pts = [for (final p in mesh.vertices) p.rotate(yaw, pitch)];
  const light = V3(-0.5, -0.7, -0.6);
  final l = light.unit;
  final visible = <(double, Face, double)>[];
  for (final f in mesh.faces) {
    // Trois sommets distincts (aux pôles de la boule, deux sommets d'une facette sont confondus).
    final distinct = <V3>[];
    for (final i in f.points) {
      if (distinct.every((q) => (q - pts[i]).length > 1e-9)) distinct.add(pts[i]);
    }
    if (distinct.length < 3) continue;
    final a = distinct[0], b = distinct[1], d = distinct[2];
    final n = (b - a).cross(d - a);
    if (n.length == 0) continue;
    // Solides convexes centrés sur l'origine : la normale extérieure s'éloigne du centre (l'ordre des sommets n'importe
    // pas).
    final mid = f.points.map((i) => pts[i]).reduce((x, y) => x + y) * (1 / f.points.length);
    final nn = n.dot(mid) < 0 ? n.unit * -1 : n.unit;
    if (nn.z >= 0) continue; // tournée vers l'arrière (la caméra regarde vers +z)
    final depth = f.points.map((i) => pts[i].z).reduce((x, y) => x + y) / f.points.length;
    visible.add((depth, f, 0.38 + 0.62 * max(0.0, nn.dot(l))));
  }
  visible.sort((x, y) => y.$1.compareTo(x.$1));
  final positions = <double>[];
  final colors = <int>[];
  Offset proj(V3 p) => Offset(c.dx + p.x * s, c.dy + p.y * s);
  for (final (_, f, shade) in visible) {
    final col = Color.lerp(Colors.black, color, shade)!.toARGB32();
    for (var i = 1; i + 1 < f.points.length; i++) {
      for (final k in [f.points[0], f.points[i], f.points[i + 1]]) {
        final o = proj(pts[k]);
        positions
          ..add(o.dx)
          ..add(o.dy);
        colors.add(col);
      }
    }
  }
  canvas.drawVertices(
    ui.Vertices.raw(VertexMode.triangles, Float32List.fromList(positions), colors: Int32List.fromList(colors)),
    BlendMode.dst,
    Paint(),
  );
  final edge = Paint()
    ..color = const Color(0xCC1B211D)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round;
  for (final (_, f, _) in visible.where((v) => v.$2.outline)) {
    canvas.drawPath(Path()..addPolygon([for (final k in f.points) proj(pts[k])], true), edge);
  }
}

/// Un solide qu'on tourne au doigt ; il tourne doucement tout seul tant qu'on ne le touche pas (sauf si l'appareil
/// demande moins d'animations).
class SolidView extends StatefulWidget {
  const SolidView({super.key, required this.mesh, required this.color, this.label});
  final Mesh mesh;
  final Color color;
  final String? label;
  @override
  State<SolidView> createState() => _SolidViewState();
}

class _SolidViewState extends State<SolidView> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  double yaw = 0.6, pitch = 0.45;
  bool touched = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: widget.label,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          // Touché : il ne tourne plus tout seul, l'animation s'arrête (plus de dessin à chaque image, ADR 0028).
          if (!touched) _spin.stop();
          touched = true;
          yaw += d.delta.dx * 0.012;
          pitch = (pitch - d.delta.dy * 0.012).clamp(-1.4, 1.4);
        }),
        child: AnimatedBuilder(
          animation: _spin,
          builder: (_, _) => CustomPaint(
            size: Size.infinite,
            painter: _MeshPainter(widget.mesh, yaw + (touched || still ? 0 : _spin.value * 2 * pi), pitch, widget.color),
          ),
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter(this.mesh, this.yaw, this.pitch, this.color);
  final Mesh mesh;
  final double yaw, pitch;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => paintMesh(canvas, size, mesh, yaw: yaw, pitch: pitch, color: color);

  @override
  bool shouldRepaint(_MeshPainter old) => old.yaw != yaw || old.pitch != pitch || old.mesh != mesh;
}
