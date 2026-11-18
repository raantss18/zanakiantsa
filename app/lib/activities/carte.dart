import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'figure.dart';

/// Figure `carte` (ADR 0079) : vraie carte dessinée à partir des contours Natural Earth (domaine public, convertis par
/// `tool/cartes.py` dans `assets/carte/`). Le monde est en projection Equal Earth, qui garde les surfaces : comparer la
/// taille des océans et des continents a un sens. Les zooms sont en projection plate corrigée de la latitude.
///
/// Champs : `vue` (monde, france, europe, caraibes, ocean-indien, suez, ormuz, asie-sud-est) ; `pays` [codes ADM0_A3]
/// mis en avant (orange hachuré, contour épais : jamais la couleur seule) ; `points` [{lon, lat, texte}] (point cerclé) ;
/// `textes` [{lon, lat, texte}] ; `fleuves` [noms] ; `equateur` (texte écrit sur la ligne). Aucune étiquette ne doit donner la réponse.
class MapFigure extends StatefulWidget {
  const MapFigure(this.spec, {super.key});
  final Map<String, dynamic> spec;

  static const views = {
    'monde': null,
    'france': [-5.6, 41.0, 10.2, 52.2],
    'europe': [-25.0, 33.0, 45.0, 71.0],
    'caraibes': [-86.0, 4.0, -50.0, 24.0],
    'ocean-indien': [25.0, -32.0, 80.0, 12.0],
    'suez': [22.0, 12.0, 46.0, 38.0],
    'ormuz': [44.0, 20.0, 64.0, 33.0],
    'asie-sud-est': [92.0, -8.0, 126.0, 26.0],
  };

  bool get world => spec['vue'] == null || spec['vue'] == 'monde';
  List<double>? get box => views[spec['vue']];

  double get aspect {
    final b = box;
    if (b == null) return _ee(pi, 0).dx / _ee(0, pi / 2).dy;
    final mid = (b[1] + b[3]) / 2 * pi / 180;
    return (b[2] - b[0]) * cos(mid) / (b[3] - b[1]);
  }

  @override
  State<MapFigure> createState() => _MapFigureState();
}

class _MapFigureState extends State<MapFigure> {
  MapData? data;

  @override
  void initState() {
    super.initState();
    final detail = !widget.world;
    data = MapData.cached(detail);
    if (data == null) {
      MapData.load(detail).then((d) {
        if (mounted) setState(() => data = d);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Carte de la question',
    // Jamais plus d'un tiers de l'écran en hauteur (vu sur l'émulateur : la France, plus haute que large, poussait la
    // question hors de l'écran).
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: min(360.0, MediaQuery.sizeOf(context).height * 0.32),
        ),
        child: AspectRatio(
          aspectRatio: widget.aspect,
          child: data == null
              ? const SizedBox.expand()
              : CustomPaint(
                  painter: MapPainter(
                    widget.spec,
                    MediaQuery.textScalerOf(context),
                    data!,
                  ),
                ),
        ),
      ),
    ),
  );
}

/// Contours chargés une seule fois : `monde.json` (1:110 M) ou `detail.json` (1:50 M, zones zoomées et fleuves).
class MapData {
  MapData._(this.countries, this.rivers);
  final Map<String, List<List<Offset>>> countries;
  final Map<String, List<List<Offset>>> rivers;

  static final _cache = <bool, MapData>{};
  static MapData? cached(bool detail) => _cache[detail];

  static Future<MapData> load(bool detail) async {
    final hit = _cache[detail];
    if (hit != null) return hit;
    final raw = jsonDecode(
      await rootBundle.loadString(
        'assets/carte/${detail ? 'detail' : 'monde'}.json',
      ),
    ) as Map;
    final scale = (raw['echelle'] as num).toDouble();
    Map<String, List<List<Offset>>> read(Map? m) => {
      for (final e in (m ?? const {}).entries)
        e.key as String: [
          for (final r in e.value as List)
            [
              for (var i = 0; i + 1 < (r as List).length; i += 2)
                Offset((r[i] as num) / scale, (r[i + 1] as num) / scale),
            ],
        ],
    };
    return _cache[detail] = MapData._(
      read(raw['pays'] as Map?),
      read(raw['fleuves'] as Map?),
    );
  }
}

/// Projection Equal Earth (Šavrič, Patterson, Jenny 2018), en radians ; y vers le nord.
Offset _ee(double lon, double lat) {
  const a1 = 1.340264, a2 = -0.081106, a3 = 0.000893, a4 = 0.003796;
  final t = asin(sqrt(3) / 2 * sin(lat));
  final t2 = t * t, t6 = t2 * t2 * t2;
  final x =
      2 *
      sqrt(3) *
      lon *
      cos(t) /
      (3 * (9 * a4 * t6 * t2 + 7 * a3 * t6 + 3 * a2 * t2 + a1));
  final y = t * (a4 * t6 * t2 + a3 * t6 + a2 * t2 + a1);
  return Offset(x, y);
}

class MapPainter extends FigurePainter {
  MapPainter(super.spec, super.scaler, this.data);
  final MapData data;

  static const sea = Color(0xFFCFE5F5),
      land = Color(0xFFF4ECD6),
      border = Color(0xFF8A8F86),
      focus = Color(0xFFF2A65A);
  static const river = Color(0xFF2F7DC4), dot = Color(0xFFD7263D);

  late Offset Function(Offset lonLat) project;

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    area = size;
    unit = min(size.width, size.height);
    final box = MapFigure.views[spec['vue']];
    if (box == null) {
      final w = _ee(pi, 0).dx, h = _ee(0, pi / 2).dy;
      project = (p) {
        final q = _ee(p.dx * pi / 180, p.dy * pi / 180);
        return Offset(
          (q.dx + w) / (2 * w) * size.width,
          (h - q.dy) / (2 * h) * size.height,
        );
      };
      // Le contour du monde : bords gauche et droit (méridien 180°) puis pôles.
      final edge = Path();
      for (var lat = -90.0; lat <= 90; lat += 3) {
        final p = project(Offset(-180, lat));
        lat == -90 ? edge.moveTo(p.dx, p.dy) : edge.lineTo(p.dx, p.dy);
      }
      for (var lat = 90.0; lat >= -90; lat -= 3) {
        final p = project(Offset(180, lat));
        edge.lineTo(p.dx, p.dy);
      }
      edge.close();
      c.drawPath(edge, Paint()..color = sea);
      c.drawPath(edge, stroke(1.5, border));
      c.save();
      c.clipPath(edge);
    } else {
      project = (p) => Offset(
        (p.dx - box[0]) / (box[2] - box[0]) * size.width,
        (box[3] - p.dy) / (box[3] - box[1]) * size.height,
      );
      final r = Offset.zero & size;
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(8)),
        Paint()..color = sea,
      );
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(8)));
    }
    final picked = {for (final p in list('pays')) '$p'};
    final thin = stroke(max(0.6, unit / 400), border);
    for (final e in data.countries.entries) {
      final path = _path(e.value, close: true);
      final on = picked.contains(e.key);
      c.drawPath(path, Paint()..color = on ? focus : land);
      if (on) _hatch(path);
      c.drawPath(
        path,
        on ? stroke(max(2.0, unit / 110), FigurePainter.line) : thin,
      );
    }
    for (final name in list('fleuves')) {
      c.drawPath(
        _path(data.rivers['$name'] ?? const [], close: false),
        stroke(max(2.0, unit / 120), river),
      );
    }
    if (spec['equateur'] != null) {
      final a = project(const Offset(-180, 0)),
          b = project(const Offset(180, 0));
      for (var x = a.dx; x < b.dx; x += 14) {
        c.drawLine(
          Offset(x, a.dy),
          Offset(min(x + 8, b.dx), a.dy),
          stroke(2.5, dot),
        );
      }
    }
    c.restore();
    final r = max(4.0, unit / 70);
    for (final p in list('points')) {
      final m = Map<String, dynamic>.from(p as Map);
      final at = project(
        Offset((m['lon'] as num).toDouble(), (m['lat'] as num).toDouble()),
      );
      c.drawCircle(at, r * 2.4, stroke(2.5, FigurePainter.line));
      c.drawCircle(at, r, Paint()..color = dot);
      c.drawCircle(at, r, stroke(2, Colors.white));
      final t = text(m['texte']);
      if (t.isNotEmpty) {
        label(
          t,
          at + Offset(0, -r * 2.4 - 4),
          align: Alignment.bottomCenter,
          size: 18,
        );
      }
    }
    for (final p in list('textes')) {
      final m = Map<String, dynamic>.from(p as Map);
      label(
        text(m['texte']),
        project(
          Offset((m['lon'] as num).toDouble(), (m['lat'] as num).toDouble()),
        ),
        size: 18,
      );
    }
    if (spec['equateur'] != null) {
      label(
        'équateur',
        project(const Offset(-150, 0)) + const Offset(0, -14),
        size: 16,
      );
    }
  }

  Path _path(List<List<Offset>> rings, {required bool close}) {
    final path = Path();
    for (final ring in rings) {
      for (var i = 0; i < ring.length; i++) {
        final p = project(ring[i]);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      if (close) path.close();
    }
    return path;
  }

  /// Hachures dans un pays mis en avant (le repère ne passe jamais par la couleur seule).
  void _hatch(Path path) {
    final b = path.getBounds();
    c.save();
    c.clipPath(path);
    final p = stroke(1.4, FigurePainter.line.withValues(alpha: 0.55));
    for (var x = b.left - b.height; x < b.right; x += 7) {
      c.drawLine(Offset(x, b.bottom), Offset(x + b.height, b.top), p);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant MapPainter old) =>
      old.spec != spec || old.data != data;
}
