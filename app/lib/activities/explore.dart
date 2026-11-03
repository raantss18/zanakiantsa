import 'dart:math';

import 'package:flutter/material.dart';

import '../content/content.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/three.dart';
import '../ui/universe.dart';

/// Explorer (ADR 0024) : des scènes qu'on tourne et qu'on touche — un solide en 3D à nommer, le système solaire, le
/// corps humain. Une question écrite et dite ; toucher la bonne chose = réussi.

/// Solide : il tourne (au doigt ou tout seul), on touche son nom parmi trois.
class SolidActivity extends StatefulWidget {
  const SolidActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<SolidActivity> createState() => _SolidActivityState();
}

class _SolidActivityState extends State<SolidActivity> {
  Attempt get a => widget.attempt;
  late final List<String> ids = List<String>.from(a.skill.params['solides'] as List);
  late final String right = ids[a.question.n];
  late final List<String> choices = () {
    final r = Random(a.question.a);
    return [right, ...(ids.where((i) => i != right).toList()..shuffle(r)).take(2)]..shuffle(r);
  }();
  final tried = <String>{};

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    final shown = a.demonstrate || a.solved;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
            child: Stack(children: [
              Positioned.fill(child: SolidView(mesh: solids[right]!, color: u.night ? u.primary : u.onCard, label: 'Un solide qui tourne')),
              const Positioned(right: 12, bottom: 8, child: Icon(Icons.threesixty_rounded, size: 36, color: Color(0xFF8A948E), semanticLabel: 'Tourne-le avec ton doigt')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          for (final id in choices)
            PicButton(
              size: 132,
              tried: tried.contains(id),
              highlight: shown && id == right,
              onPressed: a.busy || a.finished || tried.contains(id)
                  ? null
                  : () {
                      if (id != right) setState(() => tried.add(id));
                      a.submit(id == right);
                    },
              child: Text(solidNames[id]!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
            ),
        ]),
      ]),
    );
  }
}

/// Une planète : ordre depuis le Soleil (NASA), nom, couleur et taille dessinée (ordre des tailles respecté, pas
/// l'échelle).
class Planet {
  const Planet(this.id, this.name, this.color, this.radius, {this.ring = false});
  final String id, name;
  final Color color;
  final double radius;
  final bool ring;
}

const planets = [
  Planet('mercure', 'Mercure', Color(0xFF9E9E9E), 7),
  Planet('venus', 'Vénus', Color(0xFFE6C17A), 10),
  Planet('terre', 'la Terre', Color(0xFF2E7DD7), 10.5),
  Planet('mars', 'Mars', Color(0xFFC1440E), 8),
  Planet('jupiter', 'Jupiter', Color(0xFFD9A066), 22),
  Planet('saturne', 'Saturne', Color(0xFFE3C98D), 18, ring: true),
  Planet('uranus', 'Uranus', Color(0xFF8FD3DE), 13),
  Planet('neptune', 'Neptune', Color(0xFF3F5FD9), 13),
];

/// Système solaire en 3D : orbites inclinées qu'on tourne au doigt ; on touche la planète demandée.
class PlanetsActivity extends StatefulWidget {
  const PlanetsActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<PlanetsActivity> createState() => _PlanetsActivityState();
}

class _PlanetsActivityState extends State<PlanetsActivity> with SingleTickerProviderStateMixin {
  Attempt get a => widget.attempt;
  late final Item item = a.skill.items[a.question.n];
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final List<double> angles = () {
    final r = Random(a.question.a);
    return [for (var i = 0; i < planets.length; i++) r.nextDouble() * 2 * pi];
  }();
  double yaw = 0, pitch = 0.95;
  final tried = <String>{};
  List<(Planet, Offset, double)> _drawn = [];

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    _spin.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _tap(Offset p) {
    if (a.busy || a.finished) return;
    // La planète la plus proche du doigt, dans un rayon d'au moins 26 dp (cible tactile suffisante pour les petites).
    (Planet, double)? best;
    for (final (pl, c, r) in _drawn) {
      final d = (p - c).distance;
      if (d <= max(r, 26) && (best == null || d < best.$2)) best = (pl, d);
    }
    if (best == null || tried.contains(best.$1.id)) return;
    final ok = best.$1.id == item.target;
    if (!ok) setState(() => tried.add(best!.$1.id));
    a.submit(ok);
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0B1630), borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onPanUpdate: (d) => setState(() {
            yaw += d.delta.dx * 0.01;
            pitch = (pitch + d.delta.dy * 0.01).clamp(0.2, 1.5);
          }),
          onTapUp: (d) => _tap(d.localPosition),
          child: AnimatedBuilder(
            animation: _spin,
            builder: (_, _) => CustomPaint(
              size: Size.infinite,
              painter: _SolarPainter(
                yaw: yaw + (still ? 0 : _spin.value * 2 * pi),
                pitch: pitch,
                angles: angles,
                tried: tried,
                target: (a.demonstrate || a.solved) ? item.target : null,
                onDrawn: (d) => _drawn = d,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SolarPainter extends CustomPainter {
  _SolarPainter({required this.yaw, required this.pitch, required this.angles, required this.tried, required this.target, required this.onDrawn});
  final double yaw, pitch;
  final List<double> angles;
  final Set<String> tried;
  final String? target;
  final void Function(List<(Planet, Offset, double)>) onDrawn;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = min(size.width, size.height) * 0.46 / (planets.length + 1);
    Offset proj(V3 p) => Offset(c.dx + p.x, c.dy + p.y);
    // Étoiles du fond, toujours au même endroit.
    final stars = Random(7);
    final dot = Paint()..color = const Color(0x66FFFFFF);
    for (var i = 0; i < 80; i++) {
      canvas.drawCircle(Offset(stars.nextDouble() * size.width, stars.nextDouble() * size.height), stars.nextDouble() * 1.4 + 0.3, dot);
    }
    final orbit = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < planets.length; i++) {
      final r = unit * (i + 1.6);
      canvas.drawPath(
        Path()..addPolygon([for (var k = 0; k <= 64; k++) proj(V3(r * cos(2 * pi * k / 64), 0, r * sin(2 * pi * k / 64)).rotate(yaw, pitch))], false),
        orbit,
      );
    }
    final bodies = <(double, Planet?, Offset, double)>[(0, null, c, unit * 0.9)];
    for (final (i, pl) in planets.indexed) {
      final r = unit * (i + 1.6);
      final p = V3(r * cos(angles[i]), 0, r * sin(angles[i])).rotate(yaw, pitch);
      bodies.add((p.z, pl, proj(p), pl.radius * (unit / 22).clamp(0.8, 1.6)));
    }
    bodies.sort((x, y) => y.$1.compareTo(x.$1));
    final drawn = <(Planet, Offset, double)>[];
    for (final (_, pl, o, rad) in bodies) {
      final color = pl?.color ?? const Color(0xFFFFC83D);
      if (pl == null) {
        canvas.drawCircle(o, rad * 1.6, Paint()..color = const Color(0x33FFC83D));
      }
      if (pl?.ring ?? false) {
        canvas.drawOval(Rect.fromCenter(center: o, width: rad * 4, height: rad * 4 * sin(pitch).abs().clamp(0.25, 1)),
            Paint()
              ..color = const Color(0xCCE8D7A8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = rad * 0.35);
      }
      canvas.drawCircle(
        o,
        rad,
        Paint()
          ..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.45)!])
              .createShader(Rect.fromCircle(center: o, radius: rad)),
      );
      if (pl == null) continue;
      drawn.add((pl, o, rad));
      if (tried.contains(pl.id)) {
        canvas.drawCircle(o, rad + 4, Paint()
          ..color = const Color(0xFF8A948E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      }
      if (pl.id == target) {
        canvas.drawCircle(o, rad + 7, Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
        final tp = TextPainter(
          text: TextSpan(text: pl.name, style: const TextStyle(fontFamily: 'Andika', fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o + Offset(-tp.width / 2, rad + 10));
      }
    }
    onDrawn(drawn);
  }

  @override
  bool shouldRepaint(_SolarPainter old) => true;
}

/// Les parties du corps (programme de maternelle : bras, mains, jambes, tête, cou, tronc… ; pieds ajoutés) dessinées
/// en formes simples, chacune touchable.
const bodyParts = {
  'tete': 'la tête', 'cou': 'le cou', 'tronc': 'le tronc', 'bras': 'les bras', 'mains': 'les mains', 'jambes': 'les jambes', 'pieds': 'les pieds',
};

Map<String, Path> bodyPaths(Size s) {
  final w = s.width, h = s.height;
  final cx = w / 2, u = min(w / 6, h / 10);
  Path rr(double l, double t, double ww, double hh, double r) => Path()..addRRect(RRect.fromLTRBR(l, t, l + ww, t + hh, Radius.circular(r)));
  final top = (h - 9.4 * u) / 2;
  return {
    'tete': Path()..addOval(Rect.fromCenter(center: Offset(cx, top + u), width: 1.9 * u, height: 2 * u)),
    'cou': rr(cx - 0.35 * u, top + 1.9 * u, 0.7 * u, 0.6 * u, 0.2 * u),
    'tronc': rr(cx - 1.2 * u, top + 2.45 * u, 2.4 * u, 3.3 * u, 0.6 * u),
    'bras': rr(cx - 2.1 * u, top + 2.6 * u, 0.75 * u, 2.9 * u, 0.35 * u)..addPath(rr(cx + 1.35 * u, top + 2.6 * u, 0.75 * u, 2.9 * u, 0.35 * u), Offset.zero),
    'mains': (Path()..addOval(Rect.fromCenter(center: Offset(cx - 1.72 * u, top + 5.85 * u), width: 0.9 * u, height: 0.8 * u)))
      ..addOval(Rect.fromCenter(center: Offset(cx + 1.72 * u, top + 5.85 * u), width: 0.9 * u, height: 0.8 * u)),
    'jambes': rr(cx - 1.05 * u, top + 5.7 * u, 0.9 * u, 3.1 * u, 0.4 * u)..addPath(rr(cx + 0.15 * u, top + 5.7 * u, 0.9 * u, 3.1 * u, 0.4 * u), Offset.zero),
    'pieds': rr(cx - 1.5 * u, top + 8.75 * u, 1.35 * u, 0.6 * u, 0.3 * u)..addPath(rr(cx + 0.15 * u, top + 8.75 * u, 1.35 * u, 0.6 * u, 0.3 * u), Offset.zero),
  };
}

class BodyActivity extends StatefulWidget {
  const BodyActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<BodyActivity> createState() => _BodyActivityState();
}

class _BodyActivityState extends State<BodyActivity> {
  Attempt get a => widget.attempt;
  late final Item item = a.skill.items[a.question.n];
  final tried = <String>{};
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _tap(Offset p) {
    if (a.busy || a.finished) return;
    // Les petites parties (mains, cou) d'abord : elles sont posées au bord des grandes.
    final paths = bodyPaths(_size);
    final hit = ['mains', 'cou', 'pieds', 'tete', 'bras', 'jambes', 'tronc'].where((k) => paths[k]!.contains(p)).firstOrNull;
    if (hit == null || tried.contains(hit)) return;
    final ok = hit == item.target;
    if (!ok) setState(() => tried.add(hit));
    a.submit(ok);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: LayoutBuilder(builder: (_, k) {
            _size = Size(k.maxWidth, k.maxHeight);
            return GestureDetector(
              onTapUp: (d) => _tap(d.localPosition),
              child: CustomPaint(
                size: Size.infinite,
                painter: _BodyPainter(tried, (a.demonstrate || a.solved) ? item.target : null, a.app.universe),
              ),
            );
          }),
        ),
      );
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.tried, this.target, this.universe);
  final Set<String> tried;
  final String? target;
  final Universe universe;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = bodyPaths(size);
    const skin = Color(0xFFF2C29B), clothes = Color(0xFF4F86C6);
    final colors = {'tronc': clothes, 'jambes': const Color(0xFF3A5A8C), 'pieds': const Color(0xFF6B4226), 'bras': clothes};
    final outline = Paint()
      ..color = const Color(0xFF5F4632)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final k in ['bras', 'jambes', 'pieds', 'tronc', 'cou', 'tete', 'mains']) {
      final p = paths[k]!;
      final base = tried.contains(k) ? const Color(0xFFBFC7C1) : (colors[k] ?? skin);
      final b = p.getBounds();
      canvas
        ..drawPath(p, Paint()..shader = LinearGradient(colors: [Color.lerp(base, Colors.white, 0.25)!, base, Color.lerp(base, Colors.black, 0.2)!]).createShader(b))
        ..drawPath(p, outline);
      if (k == target) {
        canvas.drawPath(p, Paint()
          ..color = gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7);
      }
    }
    // Un visage souriant, pour que ce soit un enfant et pas une silhouette.
    final head = paths['tete']!.getBounds();
    final eye = Paint()..color = const Color(0xFF1B211D);
    canvas
      ..drawCircle(head.center + Offset(-head.width * 0.18, -head.height * 0.05), head.width * 0.06, eye)
      ..drawCircle(head.center + Offset(head.width * 0.18, -head.height * 0.05), head.width * 0.06, eye)
      ..drawArc(Rect.fromCenter(center: head.center + Offset(0, head.height * 0.12), width: head.width * 0.4, height: head.height * 0.25), 0.2, pi - 0.4, false,
          Paint()
            ..color = const Color(0xFF8C2F39)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_BodyPainter old) => true;
}
