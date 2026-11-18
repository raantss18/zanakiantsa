import 'dart:math';

import 'package:flutter/material.dart';

import '../core/game.dart';
import '../l10n/l10n.dart';
import '../ui/chess_play.dart';
import 'carte.dart';


/// Figures dessinées par l'app pour les questions écrites (ADR 0078) : une question qui parle d'un triangle, d'une droite
/// graduée, d'une carte de relief ou d'un schéma en barres montre ce dessin au-dessus de l'énoncé, au lieu de tout dire en
/// texte (demande d'Antsa, 2026-11-15). Écrites dans le contenu (`figure:` d'une question), dessinées ici : aucune image
/// reprise (CLAUDE.md règle 7). Les étiquettes sont des lettres, des nombres ou des mesures ; le « ? » marque ce qu'on
/// cherche (écrit, jamais la couleur seule). Figures schématiques : pas à l'échelle sauf la droite graduée et le repère.
///
/// Types (champ `type`) et leurs champs :
/// - `triangle` : `sommets` [A, B, C] ; `droit` (sommet de l'angle droit) ; `cotes` {AB: "8"} ; `angles` {A: "40°"}.
/// - `thales` : triangle ABC, M sur [AB], N sur [AC], (MN) parallèle à (BC) ; `cotes` {AM: "4", BC: "9", MN: "?"} ;
///   `sommets` [A, B, C, M, N] pour d'autres lettres.
/// - `rectangle` : `largeur`, `hauteur` (textes) ; `parts` [texte, texte] : coupé en deux dans la largeur.
/// - `cercle` : `rayon` ou `diametre` (texte) ; `demi` true pour un demi-disque.
/// - `droite` : droite graduée ; `debut`, `fin`, `pas` (nombres) ; `etiquettes` [nombres écrits sous la droite] ;
///   `points` {A: 0.6} ; `fleche` true (demi-droite).
/// - `angle` : `degres` (nombre) ; `etiquette` (texte, « ? » par défaut).
/// - `repere` : `xmin`, `xmax`, `ymin`, `ymax` ; `points` {A: [1, 3]} ; `droites` [[a, b]] pour y = ax + b ;
///   `segments` [[A, B]].
/// - `barres` : `barres` [{nom, parts, valeur}] : schéma en barres (une case par part) ; `total` : accolade sous la
///   première barre.
/// - `allumettes` : `carres` [1, 2, 3] : rangées de carrés en allumettes, une par étape.
/// - `relief` : carte de relief schématique (plaine, collines, montagnes) et sa légende ; `legende` [textes, du bas
///   vers le haut].
/// - `cases` : une rangée de `n` cases numérotées ; `robot` (case) ; `sens` 1 (vers la droite) ou -1.
/// - `grille` : quadrillage `colonnes` × `lignes`, `robot` [colonne, ligne] (0 en bas à gauche), `regard`, `but`.
/// - `tableau` : `cases`, lignes du tableau (titres en première ligne et colonne) ; « … » ou « ? » : la case cherchée.
/// - `bande` : bande unité de `parts` égales, `colorees` coloriées et hachurées.
/// - `carreaux` : `forme` (croix, cadre, escalier, l, rangee, rectangle) et `etapes`, une figure numérotée par étape.
/// - `allumettes` avec `forme: triangles` et `triangles` [1, 2, 3] : rangées de triangles en allumettes.
/// - `carreaux` accepte aussi `ronds` (rangée de ronds) et `tables` (tables carrées bout à bout, une place par côté libre).
/// - `perles` : `groupes` [[1, 1], [2, 2]] : rouges (rondes) puis bleues (carrées), groupe par groupe.
/// - `rectangles` : [{nom, l, h, largeur, hauteur}] côte à côte, à l'échelle (un carré : l = h).
/// - `echiquier` : `fen` (la position, notation FEN), `noirs` true pour voir l'échiquier du côté des Noirs.
/// - `carte` : vraie carte (monde ou zoom), voir `carte.dart`.
/// - `thales` accepte aussi `papillon: true` et `parallele: false` ; `repere`, `verticales` [x].
class QuizFigure extends StatelessWidget {
  const QuizFigure(this.spec, {super.key});
  final Map<String, dynamic> spec;

  static const types = {'triangle', 'thales', 'rectangle', 'rectangles', 'cercle', 'droite', 'angle', 'repere', 'barres', 'allumettes',
    'relief', 'cases', 'grille', 'tableau', 'bande', 'carreaux', 'echiquier', 'perles', 'carte'};

  /// Proportions de la zone de dessin (largeur / hauteur).
  double get aspect => switch (spec['type']) {
        'droite' || 'cases' => 3.2,
        'barres' => 2.2,
        'allumettes' => 2.6,
        'relief' => 1.7,
        'repere' => 1.25,
        'bande' => 4.0,
        'tableau' => _tableAspect,
        'carreaux' => 2.4,
        'perles' => 4.0,
        'grille' => ((spec['colonnes'] as num?) ?? 6) / ((spec['lignes'] as num?) ?? 4),
        'rectangles' => 1.9,
        _ => 1.6,
      };

  double get _tableAspect {
    final rows = spec['cases'] as List? ?? const [];
    final cols = rows.isEmpty ? 3 : (rows.first as List).length;
    return (cols / max(1, rows.length) * 1.9).clamp(1.2, 3.0).toDouble();
  }

  String get description => spec['type'] == 'relief' ? 'Carte de relief et sa légende' : 'Figure de la question';

  @override
  Widget build(BuildContext context) => spec['type'] == 'carte'
      ? MapFigure(spec)
      : spec['type'] == 'echiquier'
      // La position décrite en mots (« roi noir en h8… ») sur le vrai échiquier de l'app, sans rien à toucher.
      ? Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 360),
            child: AspectRatio(
              aspectRatio: 1,
              child: ChessBoardView(position: Position.fen(spec['fen'] as String), flipped: spec['noirs'] == true),
            ),
          ),
        )
      : Semantics(
        image: true,
        label: description,
        child: AspectRatio(
          aspectRatio: aspect,
          child: CustomPaint(painter: FigurePainter(spec, MediaQuery.textScalerOf(context))),
        ),
      );
}

class FigurePainter extends CustomPainter {
  FigurePainter(this.spec, this.scaler);
  final Map<String, dynamic> spec;
  final TextScaler scaler;

  static const line = Color(0xFF1B211D), soft = Color(0xFF5B6660), fill = Color(0xFFE8F1FB);

  late double unit;
  late Canvas c;
  late Size area;

  Paint stroke([double w = 3, Color col = line]) => Paint()
    ..color = col
    ..strokeWidth = w
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Écrit [s] centré sur [at] (ou à côté selon [align]) ; fond blanc derrière pour rester lisible sur les traits.
  void label(String s, Offset at, {Alignment align = Alignment.center, double size = 20, bool bold = true, Color color = line, bool box = true}) {
    if (s.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Andika', fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    var o = at - Offset(tp.width * (align.x + 1) / 2, tp.height * (align.y + 1) / 2);
    // Toujours en entier dans la figure (vu au rendu : graduations et noms de barres coupés au bord).
    o = Offset(o.dx.clamp(3.0, max(3.0, area.width - tp.width - 3)), o.dy.clamp(3.0, max(3.0, area.height - tp.height - 3)));
    if (box) {
      c.drawRRect(RRect.fromRectAndRadius((o & tp.size).inflate(3), const Radius.circular(6)), Paint()..color = const Color(0xE6FFFFFF));
    }
    tp.paint(c, o);
    tp.dispose();
  }

  String text(Object? v) => v == null ? '' : '$v';

  /// Largeur d'un texte écrit par [label].
  double widthOf(String s, {double size = 20}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontFamily: 'Andika', fontSize: size, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }
  Map<String, dynamic> map(String k) => Map<String, dynamic>.from(spec[k] as Map? ?? const {});
  List<dynamic> list(String k) => spec[k] as List? ?? const [];
  double num_(String k, double d) => (spec[k] as num?)?.toDouble() ?? d;

  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    area = size;
    unit = min(size.width, size.height);
    switch (spec['type']) {
      case 'triangle':
        _triangle(size);
      case 'thales':
        _thales(size);
      case 'rectangle':
        _rectangle(size);
      case 'cercle':
        _circle(size);
      case 'droite':
        _numberLine(size);
      case 'angle':
        _angle(size);
      case 'repere':
        _grid(size);
      case 'barres':
        _bars(size);
      case 'allumettes':
        _matches(size);
      case 'relief':
        _relief(size);
      case 'cases':
        _cells(size);
      case 'grille':
        _robotGrid(size);
      case 'tableau':
        _table(size);
      case 'bande':
        _strip(size);
      case 'carreaux':
        _tiles(size);
      case 'rectangles':
        _rects(size);
      case 'perles':
        _beads(size);
    }
  }

  /// Côté entre deux sommets : son étiquette au milieu, poussée vers l'extérieur.
  void side(Offset a, Offset b, String s, Offset centre) {
    if (s.isEmpty) return;
    final m = (a + b) / 2;
    var n = Offset(-(b - a).dy, (b - a).dx);
    n = n / n.distance;
    if ((m + n - centre).distance < (m - centre).distance) n = -n;
    label(s, m + n * 22);
  }

  void vertex(Offset p, String s, Offset centre) {
    final d = p - centre;
    label(s, p + d / d.distance * 20, box: false, size: 22);
  }

  void rightMark(Offset p, Offset a, Offset b) {
    final u = (a - p) / (a - p).distance * 16, v = (b - p) / (b - p).distance * 16;
    c.drawPath(Path()..moveTo(p.dx + u.dx, p.dy + u.dy)..lineTo(p.dx + u.dx + v.dx, p.dy + u.dy + v.dy)..lineTo(p.dx + v.dx, p.dy + v.dy), stroke(2));
  }

  void angleLabel(Offset p, Offset a, Offset b, String s) {
    final u = (a - p) / (a - p).distance, v = (b - p) / (b - p).distance;
    final start = atan2(u.dy, u.dx);
    var sweep = atan2(v.dy, v.dx) - start;
    while (sweep > pi) {
      sweep -= 2 * pi;
    }
    while (sweep < -pi) {
      sweep += 2 * pi;
    }
    c.drawArc(Rect.fromCircle(center: p, radius: 26), start, sweep, false, stroke(2));
    final mid = start + sweep / 2;
    label(s, p + Offset(cos(mid), sin(mid)) * 48, size: 18);
  }

  void _triangle(Size s) {
    final names = [for (final x in list('sommets')) text(x)];
    final n = names.length == 3 ? names : ['A', 'B', 'C'];
    final right = spec['droit'] as String?;
    final pad = 44.0;
    final w = s.width - 2 * pad, h = s.height - 2 * pad;
    // Sommets : sans angle droit, un triangle quelconque ; avec, l'angle droit en bas à gauche.
    final pts = right == null
        ? [Offset(pad + w * 0.18, pad + h), Offset(pad + w, pad + h), Offset(pad + w * 0.42, pad)]
        : [Offset(pad + w * 0.2, pad), Offset(pad + w * 0.2, pad + h), Offset(pad + w * 0.92, pad + h)];
    // L'angle droit tombe sur le sommet demandé : on fait tourner les noms.
    final order = [...n];
    if (right != null && n.contains(right)) {
      while (order[1] != right) {
        order.insert(0, order.removeLast());
      }
    }
    final at = {for (var i = 0; i < 3; i++) order[i]: pts[i]};
    final centre = (pts[0] + pts[1] + pts[2]) / 3;
    c.drawPath(Path()..addPolygon(pts, true), Paint()..color = fill);
    c.drawPath(Path()..addPolygon(pts, true), stroke());
    if (right != null) rightMark(pts[1], pts[0], pts[2]);
    for (final e in at.entries) {
      vertex(e.value, e.key, centre);
    }
    for (final e in map('cotes').entries) {
      if (e.key.length != 2) continue;
      final a = at[e.key[0]], b = at[e.key[1]];
      if (a != null && b != null) side(a, b, text(e.value), centre);
    }
    for (final e in map('angles').entries) {
      final p = at[e.key];
      if (p == null) continue;
      final others = [for (final x in at.values) if (x != p) x];
      angleLabel(p, others[0], others[1], text(e.value));
    }
  }

  void _thales(Size s) {
    final names = [for (final x in list('sommets')) text(x)];
    final n = names.length == 5 ? names : ['A', 'B', 'C', 'M', 'N'];
    final pad = 40.0;
    final w = s.width - 2 * pad, h = s.height - 2 * pad;
    // Papillon : A au milieu, (BM) et (CN) se croisent en A ; sinon M et N sont sur [AB] et [AC].
    final butterfly = spec['papillon'] == true;
    // `parallele: false` : N plus bas que M, (MN) n'est visiblement pas parallèle à (BC) (question « sont-elles parallèles ? »).
    final parallel = spec['parallele'] != false;
    final a = butterfly ? Offset(pad + w * 0.5, pad + h * 0.45) : Offset(pad + w * 0.5, pad);
    final b = Offset(pad + (butterfly ? w * 0.12 : 0), pad + h), cc = Offset(pad + w * (butterfly ? 0.88 : 1), pad + h);
    const k = 0.42;
    // Papillon : M en face de B, N en face de C, le petit triangle au-dessus (rapport 0,8).
    final m = butterfly ? a + (a - b) * 0.8 : a + (b - a) * k;
    final nn = butterfly ? a + (a - cc) * 0.8 : a + (cc - a) * (parallel ? k : 0.62);
    final at = {n[0]: a, n[1]: b, n[2]: cc, n[3]: m, n[4]: nn};
    final centre = butterfly ? a + const Offset(0, 1) : (a + b + cc) / 3;
    c.drawPath(Path()..addPolygon([a, b, cc], true), Paint()..color = fill);
    c.drawPath(Path()..addPolygon([a, b, cc], true), stroke());
    if (butterfly) {
      c.drawPath(Path()..addPolygon([a, m, nn], true), Paint()..color = fill);
      c.drawPath(Path()..addPolygon([a, m, nn], true), stroke());
    }
    c.drawLine(m, nn, stroke(3, const Color(0xFF1D4ED8)));
    for (final p in [m, nn]) {
      c.drawCircle(p, 4, Paint()..color = line);
    }
    for (final e in at.entries) {
      if (butterfly && e.value == a) {
        label(e.key, a + const Offset(30, 0), box: false, size: 22);
      } else if ((e.value == m || e.value == nn) && butterfly) {
        label(e.key, e.value + Offset(e.value.dx > a.dx ? 18 : -18, -18), box: false, size: 22);
      } else if (e.value == m || e.value == nn) {
        // M et N : à l'intérieur du triangle, juste sous le point (les longueurs s'écrivent dehors).
        label(e.key, e.value + Offset(e.value == m ? 18 : -18, 16), box: false, size: 20);
      } else {
        vertex(e.value, e.key, centre);
      }
    }
    for (final e in map('cotes').entries) {
      if (e.key.length != 2) continue;
      final p = at[e.key[0]], q = at[e.key[1]];
      if (p == null || q == null) continue;
      // [MN] : étiquette au-dessus du segment ; les autres, vers l'extérieur.
      if ({p, q}.containsAll([m, nn])) {
        label(text(e.value), (p + q) / 2 + const Offset(0, -16));
      } else if (!butterfly && (p == a && (q == b || q == cc) || q == a && (p == b || p == cc))) {
        // [AB] et [AC] entiers : l'étiquette entre M (ou N) et B (ou C), pour ne pas tomber sur M ou N.
        final far = p == a ? q : p;
        final along = a + (far - a) * 0.74;
        var n = Offset(-(far - a).dy, (far - a).dx);
        n = n / n.distance;
        if ((along + n - centre).distance < (along - centre).distance) n = -n;
        label(text(e.value), along + n * 24);
      } else if (butterfly) {
        // Côtés du petit triangle : poussés hors de AMN ; du grand : hors de ABC.
        final top = p.dy <= a.dy + 1 && q.dy <= a.dy + 1;
        side(p, q, text(e.value), top ? (a + m + nn) / 3 : (a + b + cc) / 3);
      } else {
        side(p, q, text(e.value), centre);
      }
    }
  }

  void _rectangle(Size s) {
    final pad = 40.0;
    final lw = min(s.width * 0.3, widthOf(text(spec['hauteur'])) + 16);
    final r = Rect.fromLTWH(max(pad, lw + 6), pad - 10, s.width - max(pad, lw + 6) - 16, s.height - 2 * pad);
    c.drawRect(r, Paint()..color = fill);
    c.drawRect(r, stroke());
    final parts = list('parts');
    if (parts.length == 2) {
      final x = r.left + r.width * 0.68;
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), stroke(2.5));
      label(text(parts[0]), Offset((r.left + x) / 2, r.bottom + 20));
      label(text(parts[1]), Offset((x + r.right) / 2, r.bottom + 20));
    } else {
      label(text(spec['largeur']), Offset(r.center.dx, r.bottom + 20));
    }
    label(text(spec['hauteur']), Offset(r.left - 6, r.center.dy), align: Alignment.centerRight);
  }

  void _circle(Size s) {
    final r = min(s.width, s.height) / 2 - 30;
    final o = Offset(s.width / 2, s.height / 2 + (spec['demi'] == true ? r / 2 : 0));
    if (spec['demi'] == true) {
      final path = Path()
        ..moveTo(o.dx - r, o.dy)
        ..arcTo(Rect.fromCircle(center: o, radius: r), pi, pi, false)
        ..close();
      c.drawPath(path, Paint()..color = fill);
      c.drawPath(path, stroke());
    } else {
      c.drawCircle(o, r, Paint()..color = fill);
      c.drawCircle(o, r, stroke());
    }
    c.drawCircle(o, 4, Paint()..color = line);
    if (spec['diametre'] != null) {
      c.drawLine(o - Offset(r, 0), o + Offset(r, 0), stroke(2.5, const Color(0xFF1D4ED8)));
      label(text(spec['diametre']), o + const Offset(0, -18));
    } else if (spec['rayon'] != null) {
      c.drawLine(o, o + Offset(r * cos(-pi / 5), r * sin(-pi / 5)), stroke(2.5, const Color(0xFF1D4ED8)));
      label(text(spec['rayon']), o + Offset(r * 0.5 * cos(-pi / 5), r * 0.5 * sin(-pi / 5)) + const Offset(0, -18));
    }
  }

  String _fmt(num v) {
    final r = (v * 1000).round() / 1000;
    // Écriture de la langue de l'app : 0,6 et 10 000 en français, 0.6 et 10,000 en anglais.
    var t = r == r.roundToDouble() ? r.toInt().toString() : (english ? r.toString() : r.toString().replaceAll('.', ','));
    if (r.abs() >= 10000 && r == r.roundToDouble()) {
      t = t.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => english ? ',' : ' ');
    }
    return t;
  }

  void _numberLine(Size s) {
    final a = num_('debut', 0), b = num_('fin', 10), step = num_('pas', 1);
    final y = s.height * 0.5;
    // Marge pour écrire les nombres des bouts en entier.
    final shown0 = list('etiquettes').isEmpty ? [a, b] : [for (final v in list('etiquettes')) (v as num).toDouble()];
    final edge = shown0.map((v) => widthOf(_fmt(v), size: 18)).fold(20.0, max) / 2 + 8;
    final x0 = edge, x1 = s.width - edge - (spec['fleche'] == true ? 20 : 0);
    double xOf(double v) => x0 + (v - a) / (b - a) * (x1 - x0);
    c.drawLine(Offset(x0 - 10, y), Offset(x1 + (spec['fleche'] == true ? 20 : 10), y), stroke(3));
    if (spec['fleche'] == true) {
      c.drawPath(Path()..moveTo(x1 + 20, y)..lineTo(x1 + 8, y - 8)..moveTo(x1 + 20, y)..lineTo(x1 + 8, y + 8), stroke(3));
    }
    final count = ((b - a) / step).round();
    for (var i = 0; i <= count && count <= 200; i++) {
      final x = xOf(a + i * step);
      c.drawLine(Offset(x, y - 10), Offset(x, y + 10), stroke(2));
    }
    final shown = list('etiquettes').isEmpty ? [a, b] : [for (final v in list('etiquettes')) (v as num).toDouble()];
    // Les deux bouts toujours ; un nombre du milieu seulement s'il a la place (sinon ils se chevauchaient).
    final sorted = [...shown]..sort();
    final placed = <(double, double)>[];
    bool free(double v) {
      final w = widthOf(_fmt(v), size: 18) / 2 + 6;
      return placed.every((p) => xOf(v) + w < p.$1 || xOf(v) - w > p.$2);
    }

    void put(double v) {
      final w = widthOf(_fmt(v), size: 18) / 2 + 6;
      placed.add((xOf(v) - w, xOf(v) + w));
      label(_fmt(v), Offset(xOf(v), y + 30), size: 18, box: false);
    }

    if (sorted.isNotEmpty) {
      put(sorted.first);
      if (sorted.length > 1) put(sorted.last);
      for (final v in sorted.skip(1).take(max(0, sorted.length - 2))) {
        if (free(v)) put(v);
      }
    }
    for (final e in map('points').entries) {
      final x = xOf((e.value as num).toDouble());
      c.drawCircle(Offset(x, y), 7, Paint()..color = const Color(0xFFDC2626));
      c.drawLine(Offset(x, y - 14), Offset(x, y - 28), stroke(2));
      label(e.key, Offset(x, y - 44), size: 22);
    }
  }

  void _angle(Size s) {
    final deg = num_('degres', 60);
    final o = Offset(s.width * (deg > 120 ? 0.5 : 0.25), s.height * 0.8);
    final len = min(s.width * 0.55, s.height * 0.75);
    final a = o + Offset(len, 0);
    final rad = -deg * pi / 180;
    final b = o + Offset(cos(rad), sin(rad)) * len;
    c.drawLine(o, a, stroke());
    c.drawLine(o, b, stroke());
    if (deg == 90) {
      rightMark(o, a, b);
      label(text(spec['etiquette'] ?? '?'), o + Offset(cos(rad / 2), sin(rad / 2)) * 48, size: 20);
    } else {
      angleLabel(o, a, b, text(spec['etiquette'] ?? '?'));
    }
  }

  void _grid(Size s) {
    final xa = num_('xmin', -1), xb = num_('xmax', 6), ya = num_('ymin', -1), yb = num_('ymax', 8);
    const pad = 24.0;
    final sx = (s.width - 2 * pad) / (xb - xa), sy = (s.height - 2 * pad) / (yb - ya);
    Offset at(double x, double y) => Offset(pad + (x - xa) * sx, s.height - pad - (y - ya) * sy);
    final g = stroke(1, const Color(0xFFD5DBD7));
    for (var x = xa.ceil(); x <= xb; x++) {
      c.drawLine(at(x.toDouble(), ya), at(x.toDouble(), yb), g);
    }
    for (var y = ya.ceil(); y <= yb; y++) {
      c.drawLine(at(xa, y.toDouble()), at(xb, y.toDouble()), g);
    }
    c.drawLine(at(xa, 0), at(xb, 0), stroke(2.5));
    c.drawLine(at(0, ya), at(0, yb), stroke(2.5));
    label('0', at(0, 0) + const Offset(-10, 12), size: 16, box: false);
    label('1', at(1, 0) + const Offset(0, 14), size: 16, box: false);
    label('1', at(0, 1) + const Offset(-12, 0), size: 16, box: false);
    c.save();
    c.clipRect(Rect.fromPoints(at(xa, ya), at(xb, yb)));
    for (final d in list('droites')) {
      final ab = d as List;
      final m = (ab[0] as num).toDouble(), p = (ab[1] as num).toDouble();
      c.drawLine(at(xa, m * xa + p), at(xb, m * xb + p), stroke(3, const Color(0xFF1D4ED8)));
    }
    // Droites verticales x = k (pas d'équation réduite y = mx + p).
    for (final v in list('verticales')) {
      final x = (v as num).toDouble();
      c.drawLine(at(x, ya), at(x, yb), stroke(3, const Color(0xFF1D4ED8)));
      label(_fmt(x), at(x, 0) + const Offset(12, 14), size: 16);
    }
    c.restore();
    final pts = {for (final e in map('points').entries) e.key: at(((e.value as List)[0] as num).toDouble(), ((e.value as List)[1] as num).toDouble())};
    for (final sg in list('segments')) {
      final ab = sg as List;
      final p = pts[ab[0]], q = pts[ab[1]];
      if (p != null && q != null) c.drawLine(p, q, stroke(3, const Color(0xFF1D4ED8)));
    }
    for (final e in pts.entries) {
      c.drawCircle(e.value, 6, Paint()..color = const Color(0xFFDC2626));
      label(e.key, e.value + const Offset(14, -14), size: 20);
    }
  }

  void _bars(Size s) {
    final bars = [for (final b in list('barres')) Map<String, dynamic>.from(b as Map)];
    if (bars.isEmpty) return;
    final maxParts = bars.map((b) => (b['parts'] as num? ?? 1).toInt()).reduce(max);
    final hasNames = bars.any((b) => text(b['nom']).isNotEmpty);
    final nameW = hasNames ? bars.map((b) => widthOf(text(b['nom']), size: 18)).reduce(max) : 0.0;
    final valueW = bars.map((b) => widthOf(text(b['valeur']))).fold(24.0, max);
    final left = hasNames ? min(s.width * 0.42, nameW + 18) : 16.0, right = s.width - valueW - 18;
    final cell = (right - left) / maxParts;
    final total = spec['total'];
    final rowH = min(56.0, (s.height - (total != null ? 50 : 16)) / bars.length - 12);
    for (final (i, b) in bars.indexed) {
      final top = 8 + i * (rowH + 14);
      final parts = (b['parts'] as num? ?? 1).toInt();
      for (var k = 0; k < parts; k++) {
        final r = Rect.fromLTWH(left + k * cell, top, cell, rowH);
        c.drawRect(r, Paint()..color = i.isEven ? fill : const Color(0xFFFDEBD3));
        c.drawRect(r, stroke(2));
      }
      if (hasNames) label(text(b['nom']), Offset(left - 10, top + rowH / 2), align: Alignment.centerRight, size: 18, box: false);
      label(text(b['valeur']), Offset(left + parts * cell + 10, top + rowH / 2), align: Alignment.centerLeft, size: 20, box: false);
    }
    if (total != null) {
      final parts = (bars.first['parts'] as num? ?? 1).toInt();
      final y = 8 + rowH + 8;
      final x0 = left, x1 = left + parts * cell;
      c.drawPath(Path()..moveTo(x0, y)..quadraticBezierTo(x0, y + 12, x0 + 12, y + 12)..lineTo((x0 + x1) / 2 - 10, y + 12)..lineTo((x0 + x1) / 2, y + 22)
        ..lineTo((x0 + x1) / 2 + 10, y + 12)..lineTo(x1 - 12, y + 12)..quadraticBezierTo(x1, y + 12, x1, y), stroke(2));
      if (bars.length == 1) label(text(total), Offset((x0 + x1) / 2, y + 40), size: 20, box: false);
    }
  }

  void _matches(Size s) {
    if (spec['forme'] == 'triangles') return _matchTriangles(s);
    final steps = [for (final v in list('carres')) (v as num).toInt()];
    if (steps.isEmpty) return;
    final totalSquares = steps.fold(0, (a, b) => a + b) + steps.length - 1;
    final side = min((s.width - 20) / max(1, totalSquares), s.height * 0.5);
    var x = 10.0;
    final y = s.height * 0.2;
    final m = Paint()
      ..color = const Color(0xFFB45309)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final (i, n) in steps.indexed) {
      for (var k = 0; k < n; k++) {
        final l = x + k * side;
        void stick(Offset a, Offset b) {
          final d = (b - a) * 0.08;
          c.drawLine(a + d, b - d, m);
          c.drawCircle(b - d, 4, Paint()..color = const Color(0xFFDC2626));
        }

        stick(Offset(l, y), Offset(l + side, y));
        stick(Offset(l, y + side), Offset(l + side, y + side));
        if (k == 0) stick(Offset(l, y + side), Offset(l, y));
        stick(Offset(l + side, y + side), Offset(l + side, y));
      }
      label('${i + 1}', Offset(x + n * side / 2, y + side + 26), size: 20);
      x += (n + 1) * side;
    }
  }

  /// Rangées de triangles en allumettes (pointe en haut, puis en bas, côtés partagés), une par étape : `triangles` [1, 2, 3].
  void _matchTriangles(Size s) {
    final steps = [for (final v in list('triangles')) (v as num).toInt()];
    if (steps.isEmpty) return;
    final halfUnits = steps.fold(0, (a, n) => a + n + 1) + steps.length - 1;
    final side = min((s.width - 20) / max(1, halfUnits) * 2, s.height * 0.55);
    final h = side * sqrt(3) / 2;
    final y = s.height * 0.15;
    final m = Paint()
      ..color = const Color(0xFFB45309)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    void stick(Offset a, Offset b) {
      final d = (b - a) * 0.08;
      c.drawLine(a + d, b - d, m);
      c.drawCircle(b - d, 4, Paint()..color = const Color(0xFFDC2626));
    }

    var x = 10.0;
    for (final (i, n) in steps.indexed) {
      // Triangle k : pointe en haut si k pair, en bas sinon ; ils se touchent par un côté.
      for (var k = 0; k < n; k++) {
        final l = x + k * side / 2;
        final up = k.isEven;
        final a = up ? Offset(l, y + h) : Offset(l, y);
        final b = up ? Offset(l + side, y + h) : Offset(l + side, y);
        final apex = up ? Offset(l + side / 2, y) : Offset(l + side / 2, y + h);
        if (k == 0) stick(a, apex);
        stick(apex, b);
        stick(a, b);
      }
      final w = (n + 1) * side / 2;
      label('${i + 1}', Offset(x + w / 2, y + h + 26), size: 20);
      x += w + side / 2;
    }
  }

  /// Collier : groupes de perles (`groupes` [[2, 2], …] : nombre de rouges puis de bleues). Rouge = rond, bleu = carré :
  /// la forme dit la couleur, jamais la couleur seule.
  void _beads(Size s) {
    final groups = [for (final g in list('groupes')) [for (final v in g as List) (v as num).toInt()]];
    if (groups.isEmpty) return;
    final total = groups.fold(0, (a, g) => a + g.fold(0, (x, y) => x + y)) + groups.length - 1;
    final r = min((s.width - 20) / max(1, total) / 2.3, s.height * 0.22);
    final y = s.height * 0.42;
    c.drawLine(Offset(6, y), Offset(s.width - 6, y), stroke(2, soft));
    var x = 10 + r;
    for (final (gi, g) in groups.indexed) {
      for (final (ci, n) in g.indexed) {
        for (var k = 0; k < n; k++) {
          final o = Offset(x, y);
          if (ci == 0) {
            c.drawCircle(o, r, Paint()..color = const Color(0xFFDC2626));
            c.drawCircle(o, r, stroke(2));
          } else {
            final q = Rect.fromCenter(center: o, width: r * 1.8, height: r * 1.8);
            c.drawRect(q, Paint()..color = const Color(0xFF1D4ED8));
            c.drawRect(q, stroke(2));
          }
          x += r * 2.3;
        }
      }
      if (gi < groups.length - 1) x += r * 2.3;
    }
  }

  void _relief(Size s) {
    final legendW = s.width * 0.3;
    final map = Rect.fromLTWH(8, 8, s.width - legendW - 24, s.height - 16);
    const colours = [Color(0xFF2E7D32), Color(0xFF9CCC65), Color(0xFFF2D16B), Color(0xFFC77D3A), Color(0xFF7B4A1E)];
    c.drawRRect(RRect.fromRectAndRadius(map, const Radius.circular(10)), Paint()..color = colours[0]);
    // Courbes de niveau emboîtées : plus on monte, plus c'est marron (montagnes au nord-est de la carte).
    final peak = Offset(map.left + map.width * 0.68, map.top + map.height * 0.34);
    for (var i = 1; i < colours.length; i++) {
      final k = 1 - i / colours.length;
      final r = Rect.fromCenter(center: peak + Offset(-map.width * 0.1 * k, map.height * 0.08 * k), width: map.width * 0.95 * k, height: map.height * 0.9 * k);
      c.save();
      c.clipRRect(RRect.fromRectAndRadius(map, const Radius.circular(10)));
      c.drawOval(r, Paint()..color = colours[i]);
      c.restore();
    }
    // Une rivière dans la plaine.
    c.drawPath(
        Path()
          ..moveTo(map.left, map.bottom - map.height * 0.2)
          ..quadraticBezierTo(map.left + map.width * 0.3, map.bottom - map.height * 0.35, map.left + map.width * 0.45, map.bottom),
        stroke(5, const Color(0xFF1D6FD6)));
    c.drawRRect(RRect.fromRectAndRadius(map, const Radius.circular(10)), stroke(2));
    // Légende : du bas (vert foncé) vers le haut (marron), avec les altitudes écrites.
    final labels = [for (final x in list('legende')) text(x)];
    final lx = map.right + 14, boxH = (s.height - 16) / colours.length;
    for (var i = 0; i < colours.length; i++) {
      final top = s.height - 8 - (i + 1) * boxH;
      final r = Rect.fromLTWH(lx, top + 3, 28, boxH - 6);
      c.drawRect(r, Paint()..color = colours[i]);
      c.drawRect(r, stroke(1.5));
      if (i < labels.length) label(labels[i], Offset(lx + 36, top + boxH / 2), align: Alignment.centerLeft, size: 15, box: false);
    }
  }

  void _cells(Size s) {
    final n = (spec['n'] as num? ?? 10).toInt().clamp(2, 20);
    final w = (s.width - 16) / n, h = min(w, s.height * 0.55);
    final y = (s.height - h) / 2 + 10;
    for (var i = 0; i < n; i++) {
      final r = Rect.fromLTWH(8 + i * w, y, w, h);
      c.drawRect(r, Paint()..color = fill);
      c.drawRect(r, stroke(2));
      label('${i + 1}', r.center + Offset(0, h * 0.28), size: min(18, w * 0.45), box: false, color: soft);
    }
    final robot = (spec['robot'] as num?)?.toInt();
    if (robot != null && robot >= 1 && robot <= n) {
      final r = Rect.fromLTWH(8 + (robot - 1) * w, y, w, h);
      c.drawCircle(r.center - Offset(0, h * 0.12), min(w, h) * 0.26, Paint()..color = const Color(0xFF1F5F8B));
      final dir = (spec['sens'] as num? ?? 1).toDouble();
      final tip = r.center - Offset(0, h * 0.12) + Offset(dir * min(w, h) * 0.42, 0);
      c.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(tip.dx - dir * 10, tip.dy - 8)..lineTo(tip.dx - dir * 10, tip.dy + 8)..close(), Paint()..color = const Color(0xFF1F5F8B));
    }
  }

  /// Robot sur un quadrillage : `colonnes`, `lignes`, `robot` [colonne, ligne] (0 en bas à gauche), `regard` (haut, bas,
  /// gauche, droite), `but` [colonne, ligne] facultatif (une étoile) ; jamais le chemin (ce serait la réponse).
  void _robotGrid(Size s) {
    final cols = (spec['colonnes'] as num? ?? 6).toInt().clamp(2, 12), rows = (spec['lignes'] as num? ?? 4).toInt().clamp(2, 10);
    final cell = min((s.width - 16) / cols, (s.height - 16) / rows);
    final ox = (s.width - cell * cols) / 2, oy = (s.height - cell * rows) / 2;
    Rect at(int cx, int cy) => Rect.fromLTWH(ox + cx * cell, oy + (rows - 1 - cy) * cell, cell, cell);
    for (var x = 0; x < cols; x++) {
      for (var y = 0; y < rows; y++) {
        c.drawRect(at(x, y), Paint()..color = fill);
        c.drawRect(at(x, y), stroke(1.5, const Color(0xFF9AA6A0)));
      }
    }
    final goal = spec['but'] as List?;
    if (goal != null) {
      final r = at((goal[0] as num).toInt(), (goal[1] as num).toInt());
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final rad = (i.isEven ? 0.38 : 0.16) * cell, ang = -pi / 2 + i * pi / 5;
        final p = r.center + Offset(cos(ang), sin(ang)) * rad;
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      c.drawPath(path..close(), Paint()..color = const Color(0xFFE08A00));
      c.drawPath(path, stroke(1.5));
    }
    final rob = spec['robot'] as List?;
    if (rob != null) {
      final r = at((rob[0] as num).toInt(), (rob[1] as num).toInt());
      c.drawCircle(r.center, cell * 0.3, Paint()..color = const Color(0xFF1F5F8B));
      final dir = switch (spec['regard']) { 'bas' => const Offset(0, 1), 'gauche' => const Offset(-1, 0), 'droite' => const Offset(1, 0), _ => const Offset(0, -1) };
      final tip = r.center + dir * cell * 0.46, side = Offset(-dir.dy, dir.dx) * cell * 0.14, base = r.center + dir * cell * 0.26;
      c.drawPath(Path()..moveTo(tip.dx, tip.dy)..lineTo(base.dx + side.dx, base.dy + side.dy)..lineTo(base.dx - side.dx, base.dy - side.dy)..close(),
          Paint()..color = const Color(0xFF1F5F8B));
    }
  }

  /// Tableau : `cases`, liste de lignes ; la première ligne et la première colonne sont des titres (en gras, fond pâle).
  /// « … » ou « ? » marque la case cherchée (encadrée).
  void _table(Size s) {
    final rows = [for (final r in list('cases')) [for (final v in r as List) text(v)]];
    if (rows.isEmpty) return;
    final ncol = rows.map((r) => r.length).reduce(max);
    final colW = List<double>.filled(ncol, 40);
    for (final r in rows) {
      for (var j = 0; j < r.length; j++) {
        colW[j] = max(colW[j], widthOf(r[j], size: 20) + 20);
      }
    }
    final total = colW.reduce((a, b) => a + b);
    final scale = min(1.0, (s.width - 8) / total);
    final rowH = min(52.0, (s.height - 8) / rows.length);
    final x0 = (s.width - total * scale) / 2, y0 = (s.height - rowH * rows.length) / 2;
    var y = y0;
    for (var i = 0; i < rows.length; i++) {
      var x = x0;
      for (var j = 0; j < ncol; j++) {
        final w = colW[j] * scale;
        final r = Rect.fromLTWH(x, y, w, rowH);
        final head = i == 0 || j == 0;
        final v = j < rows[i].length ? rows[i][j] : '';
        final unknown = v == '…' || v == '?';
        if (!(i == 0 && j == 0 && v.isEmpty)) {
          c.drawRect(r, Paint()..color = head ? const Color(0xFFE8F1FB) : Colors.white);
          c.drawRect(r, stroke(unknown ? 4 : 1.5, unknown ? const Color(0xFF7A1FA2) : line));
        }
        label(unknown ? '?' : v, r.center, size: 20 * scale.clamp(0.7, 1.0), bold: head || unknown, box: false);
        x += w;
      }
      y += rowH;
    }
  }

  /// Bande unité : `parts` égales, `colorees` parts coloriées et hachurées (la couleur n'est jamais seule), `etiquette`.
  void _strip(Size s) {
    final n = (spec['parts'] as num? ?? 10).toInt().clamp(1, 20), k = (spec['colorees'] as num? ?? 0).toInt().clamp(0, n);
    final r = Rect.fromLTWH(16, s.height * 0.22, s.width - 32, s.height * 0.5);
    final w = r.width / n;
    for (var i = 0; i < n; i++) {
      final cell = Rect.fromLTWH(r.left + i * w, r.top, w, r.height);
      if (i < k) {
        c.drawRect(cell, Paint()..color = const Color(0xFFFDE68A));
        c.save();
        c.clipRect(cell);
        for (var d = -r.height; d < w; d += 8) {
          c.drawLine(Offset(cell.left + d, cell.bottom), Offset(cell.left + d + r.height, cell.top), stroke(1.2, const Color(0xFFB45309)));
        }
        c.restore();
      } else {
        c.drawRect(cell, Paint()..color = Colors.white);
      }
      c.drawRect(cell, stroke(2));
    }
    c.drawRect(r, stroke(3));
    if (spec['etiquette'] != null) label(text(spec['etiquette']), Offset(r.center.dx, r.bottom + 22), size: 20, box: false);
  }

  /// Motifs de carreaux, une figure par étape (`etapes`, des nombres ; pour `rectangle`, des [lignes, colonnes]) :
  /// `forme` croix (bras de n), cadre (tour d'un carré de n + 2), escalier (marches de 1 à n), l (deux bras de n + 1),
  /// rangee (n carreaux), rectangle (lignes × colonnes). Chaque étape est numérotée dessous.
  void _tiles(Size s) {
    final steps = list('etapes');
    if (steps.isEmpty) return;
    List<(int, int)> cells(Object st) {
      final n = st is List ? 0 : (st as num).toInt();
      return switch (spec['forme']) {
        'croix' => [(0, 0), for (var i = 1; i <= n; i++) ...[(i, 0), (-i, 0), (0, i), (0, -i)]],
        'cadre' => [for (var x = 0; x < n + 2; x++) for (var y = 0; y < n + 2; y++) if (x == 0 || y == 0 || x == n + 1 || y == n + 1) (x, y)],
        'escalier' => [for (var x = 0; x < n; x++) for (var y = 0; y <= x; y++) (x, y)],
        'l' => [for (var i = 0; i <= n; i++) (0, i), for (var i = 1; i <= n; i++) (i, 0)],
        'tables' => [for (var i = 0; i < n; i++) (i, 0)],
        'ronds' => [for (var i = 0; i < n; i++) (i, 0)],
        'rectangle' => [
            for (var y = 0; y < ((st as List)[0] as num).toInt(); y++) for (var x = 0; x < (st[1] as num).toInt(); x++) (x, y)
          ],
        _ => [for (var i = 0; i < n; i++) (i, 0)],
      };
    }

    final shapes = [for (final st in steps) cells(st as Object)];
    final spans = [
      for (final sh in shapes)
        (sh.map((e) => e.$1).reduce(min), sh.map((e) => e.$1).reduce(max), sh.map((e) => e.$2).reduce(min), sh.map((e) => e.$2).reduce(max))
    ];
    // Tables : de la place autour pour les sièges (bouts de rangée, haut et bas), et le numéro plus bas.
    final tables = spec['forme'] == 'tables';
    final totalW = spans.fold(0, (a, sp) => a + sp.$2 - sp.$1 + 1) + shapes.length - 1 + (tables ? 1 : 0);
    final maxH = spans.map((sp) => sp.$4 - sp.$3 + 1).reduce(max);
    final room = maxH + (tables ? 1 : 0);
    final cell = min((s.width - 16) / totalW, (s.height - 40) / room);
    var x = (s.width - cell * totalW) / 2 + (tables ? cell * 0.5 : 0);
    final top = (s.height - 34 - cell * room) / 2 + (tables ? cell * 0.5 : 0);
    final showNumbers = shapes.length > 1;
    for (final (i, sh) in shapes.indexed) {
      final sp = spans[i];
      for (final (cx, cy) in sh) {
        final r = Rect.fromLTWH(x + (cx - sp.$1) * cell, top + (maxH - 1 - (cy - sp.$3)) * cell, cell, cell);
        if (spec['forme'] == 'ronds') {
          c.drawCircle(r.center, cell * 0.38, Paint()..color = const Color(0xFFFDE68A));
          c.drawCircle(r.center, cell * 0.38, stroke(1.5));
          continue;
        }
        c.drawRect(r.deflate(1), Paint()..color = const Color(0xFFFDE68A));
        c.drawRect(r.deflate(1), stroke(1.5));
        if (spec['forme'] == 'tables') {
          // Une place (petit rond) de chaque côté libre de la table : en haut, en bas, et aux deux bouts de la rangée.
          final seat = Paint()..color = const Color(0xFF1D4ED8);
          final rr = cell * 0.13;
          c.drawCircle(Offset(r.center.dx, r.top - rr * 1.6), rr, seat);
          c.drawCircle(Offset(r.center.dx, r.bottom + rr * 1.6), rr, seat);
          if (cx == sp.$1) c.drawCircle(Offset(r.left - rr * 1.6, r.center.dy), rr, seat);
          if (cx == sp.$2) c.drawCircle(Offset(r.right + rr * 1.6, r.center.dy), rr, seat);
        }
      }
      final w = (sp.$2 - sp.$1 + 1) * cell;
      if (showNumbers) label('${i + 1}', Offset(x + w / 2, top + maxH * cell + (tables ? cell * 0.5 : 0) + 20), size: 20);
      x += w + cell;
    }
  }

  /// Rectangles à l'échelle, côte à côte : `rectangles` [{nom, l, h, largeur, hauteur}] (l et h : nombres, pour les
  /// proportions ; largeur et hauteur : les textes écrits). Un carré est un rectangle de l = h.
  void _rects(Size s) {
    final rs = [for (final r in list('rectangles')) Map<String, dynamic>.from(r as Map)];
    if (rs.isEmpty) return;
    double nv(Map m, String k) => (m[k] as num? ?? 1).toDouble();
    final sumL = rs.fold(0.0, (a, r) => a + nv(r, 'l'));
    final maxH = rs.map((r) => nv(r, 'h')).reduce(max);
    final gap = 70.0, padX = 50.0;
    final unitPx = min((s.width - 2 * padX - gap * (rs.length - 1)) / sumL, (s.height - 90) / maxH);
    var x = padX + ((s.width - 2 * padX - gap * (rs.length - 1)) - sumL * unitPx) / 2;
    final base = s.height - 44;
    for (final r in rs) {
      final w = nv(r, 'l') * unitPx, h = nv(r, 'h') * unitPx;
      final rect = Rect.fromLTWH(x, base - h, w, h);
      c.drawRect(rect, Paint()..color = fill);
      c.drawRect(rect, stroke());
      label(text(r['nom']), rect.center, size: 24);
      label(text(r['largeur']), Offset(rect.center.dx, base + 20), size: 18, box: false);
      label(text(r['hauteur']), Offset(rect.left - 6, rect.center.dy), align: Alignment.centerRight, size: 18, box: false);
      x += w + gap;
    }
  }

  @override
  bool shouldRepaint(FigurePainter old) => old.spec != spec;
}
