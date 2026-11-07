import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fractions.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Les fractions (ADR 0056) : lire, colorier, comparer, ajouter, placer sur une bande, écrire au-delà de 1, prendre une
/// fraction d'une quantité. Chaque réponse fausse dit ce qu'elle montre (`core/fractions.dart`).
class FractionActivity extends StatefulWidget {
  const FractionActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<FractionActivity> createState() => _FractionActivityState();
}

class _FractionActivityState extends State<FractionActivity> {
  Attempt get a => widget.attempt;
  String get mode => a.skill.params['mode'] as String;
  int get n => a.question.n;
  int get d => a.question.b;

  late final Random _r = Random(n * 1000 + a.question.a * 31 + d);
  late final _choices = _makeChoices();
  late final _numbers = mode == 'quantite' ? quantityChoices(n, a.question.a, d, _r) : const <int>[];

  /// Parts coloriées par l'enfant (mode colorier), graduations déjà essayées (mode placer), réponses déjà essayées.
  final filled = <int>{};
  final triedTicks = <int>{};
  final tried = <Object>{};
  int? mark;

  List<Frac> _makeChoices() => switch (mode) {
        'unitaire' => fracChoices(
            Frac(1, d),
            [for (final o in List<int>.from(a.skill.params['denominateurs'] as List)..shuffle(_r)) if (o != d) Frac(1, o)],
            _r,
            fill: (i) => Frac(1, d + i),
          ),
        'lire' => readChoices(n, d, _r),
        'additionner' => sumChoices(a.question.a, n - a.question.a, d, _r),
        'superieure' => wholeChoices(n, d, _r),
        _ => const [],
      };

  Frac get _right => switch (mode) {
        'superieure' => Frac(n % d, d, whole: n ~/ d),
        _ => Frac(n, d),
      };

  bool get _shown => a.demonstrate || a.solved;

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

  bool get _locked => a.busy || a.finished;

  void _pick(Frac f) {
    if (_locked || tried.contains(f)) return;
    final ok = f == _right;
    if (!ok) setState(() => tried.add(f));
    a.submit(ok, why: ok ? null : _why(f));
  }

  String? _why(Frac f) => switch (mode) {
        'lire' => readWhy(_right, f),
        'unitaire' => 'Compte toutes les parts de la figure : il y en a $d.',
        'additionner' => sumWhy(_right, f),
        'superieure' => wholeWhy(_right, f),
        _ => null,
      };

  void _check() {
    if (_locked) return;
    final ok = filled.length == n;
    a.submit(ok, why: ok ? null : colorWhy(filled.length, n, d));
  }

  void _tick(int i) {
    if (_locked || triedTicks.contains(i)) return;
    final ok = i == n;
    setState(() {
      mark = i;
      if (!ok) triedTicks.add(i);
    });
    a.submit(ok, why: ok ? null : placeWhy(i, n, d));
  }

  void _compare(bool first) {
    if (_locked || tried.contains(first)) return;
    final q = a.question;
    final ok = mode == 'comparer' ? (first ? q.n > q.a : q.a > q.n) : (first ? q.b < q.a : q.a < q.b);
    if (!ok) setState(() => tried.add(first));
    final why = mode == 'comparer' ? sameCompareWhy(max(q.n, q.a), min(q.n, q.a), d) : unitCompareWhy(min(q.a, q.b), max(q.a, q.b));
    a.submit(ok, why: ok ? null : why);
  }

  void _number(int v) {
    if (_locked || tried.contains(v)) return;
    final ok = v == n;
    if (!ok) setState(() => tried.add(v));
    a.submit(ok, why: ok ? null : quantityWhy(v, d));
  }

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    return LayoutBuilder(builder: (_, k) {
      final w = k.maxWidth - 32;
      final pick = (w / 3 - 16).clamp(88.0, 132.0);
      final color = u.night ? u.primary : u.onCard;
      Widget card(Widget child) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
            child: child,
          );
      Widget choices() => Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
            for (final f in _choices)
              PicButton(
                label: f.whole > 0 ? fracSumWords(f) : fracWords(f.n, f.d),
                size: pick,
                tried: tried.contains(f),
                highlight: _shown && f == _right,
                onPressed: _locked ? null : () => _pick(f),
                child: FracLabel(f, size: pick * 0.27, color: ink),
              ),
          ]);
      final figureW = min(w, 420.0);
      final body = switch (mode) {
        'colorier' => [
            card(_Figure(
              parts: d,
              filled: a.demonstrate ? {for (var i = 0; i < n; i++) i} : filled,
              disk: a.question.a == 1,
              size: figureW - 32,
              color: color,
              onPart: _locked ? null : (i) => setState(() => filled.contains(i) ? filled.remove(i) : filled.add(i)),
            )),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(220, 72), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 24, fontWeight: FontWeight.w700)),
              onPressed: _locked ? null : _check,
              icon: const Icon(Icons.check_rounded, size: 36),
              label: const Text('J\'ai fini'),
            ),
          ],
        'comparer' || 'comparer_unitaires' => [
            for (final first in [true, false]) ...[
              _CompareRow(
                frac: mode == 'comparer' ? Frac(first ? n : a.question.a, d) : Frac(1, first ? d : a.question.a),
                width: w,
                color: color,
                tried: tried.contains(first),
                highlight: _shown && (mode == 'comparer' ? (first ? n > a.question.a : a.question.a > n) : (first ? d < a.question.a : a.question.a < d)),
                onTap: _locked ? null : () => _compare(first),
              ),
              const SizedBox(height: 16),
            ],
          ],
        'placer' => [
            card(_Strip(parts: d, width: figureW - 32, color: color, mark: _shown ? n : mark, tried: triedTicks, onTick: _locked ? null : _tick)),
          ],
        'additionner' => [
            card(Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                FracLabel(Frac(a.question.a, d), size: 36, color: ink),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('+', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: ink))),
                FracLabel(Frac(n - a.question.a, d), size: 36, color: ink),
              ]),
              const SizedBox(height: 12),
              _Figure(parts: d, filled: {for (var i = 0; i < a.question.a; i++) i}, second: {for (var i = a.question.a; i < n; i++) i}, disk: false, size: figureW - 32, color: color),
            ])),
            const SizedBox(height: 20),
            choices(),
          ],
        'superieure' => [
            card(Column(mainAxisSize: MainAxisSize.min, children: [
              FracLabel(Frac(n, d), size: 36, color: ink),
              const SizedBox(height: 12),
              // Une bande par entier : celles qui sont pleines, puis la dernière, coloriée en partie.
              for (var b = 0; b < n ~/ d + 1; b++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Figure(
                    parts: d,
                    filled: {for (var i = 0; i < min(d, n - b * d); i++) i},
                    disk: false,
                    size: figureW - 32,
                    height: 48,
                    color: color,
                  ),
                ),
            ])),
            const SizedBox(height: 20),
            choices(),
          ],
        'quantite' => [
            card(_Objects(total: a.question.a, groups: _shown ? d : null, art: u.objects[a.skill.objectIndex], width: figureW - 32)),
            const SizedBox(height: 20),
            Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
              for (final v in _numbers)
                PicButton(
                  label: '$v',
                  size: pick,
                  tried: tried.contains(v),
                  highlight: _shown && v == n,
                  onPressed: _locked ? null : () => _number(v),
                  child: Text('$v', style: TextStyle(fontSize: pick * 0.38, fontWeight: FontWeight.w700, color: ink)),
                ),
            ]),
          ],
        _ => [
            card(_Figure(parts: d, filled: {for (var i = 0; i < n; i++) i}, disk: a.question.a == 1, size: min(figureW - 32, 260.0), color: color)),
            const SizedBox(height: 20),
            choices(),
          ],
      };
      return PlayScroll(padding: const EdgeInsets.all(16), child: Column(children: body));
    });
  }
}

/// Une fraction écrite comme à l'école : le numérateur sur le dénominateur, éventuellement avec l'entier devant.
class FracLabel extends StatelessWidget {
  const FracLabel(this.f, {super.key, this.size = 32, this.color = ink});
  final Frac f;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.1);
    final stacked = IntrinsicWidth(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${f.n}', textAlign: TextAlign.center, style: style),
        Container(height: max(2.0, size * 0.08), color: color, margin: const EdgeInsets.symmetric(vertical: 2)),
        Text('${f.d}', textAlign: TextAlign.center, style: style),
      ]),
    );
    if (f.whole == 0) return stacked;
    return Row(mainAxisSize: MainAxisSize.min, children: [Text('${f.whole} + ', style: style), stacked]);
  }
}

/// Quelle part d'une figure de [size] se trouve en [p] ; null en dehors. Bande : de gauche à droite ; disque : depuis midi,
/// dans le sens des aiguilles d'une montre.
int? partAt(Offset p, Size size, int parts, {required bool disk}) {
  if (!disk) {
    if (p.dx < 0 || p.dx >= size.width || p.dy < 0 || p.dy >= size.height) return null;
    return (p.dx / size.width * parts).floor().clamp(0, parts - 1);
  }
  final c = size.center(Offset.zero);
  final v = p - c;
  if (v.distance > size.shortestSide / 2) return null;
  var angle = atan2(v.dx, -v.dy); // 0 à midi, positif vers la droite
  if (angle < 0) angle += 2 * pi;
  return (angle / (2 * pi) * parts).floor().clamp(0, parts - 1);
}

class _Figure extends StatelessWidget {
  const _Figure({required this.parts, required this.filled, required this.disk, required this.size, required this.color, this.second = const {}, this.height, this.onPart});
  final int parts;
  final Set<int> filled, second;
  final bool disk;
  final double size;
  final double? height;
  final Color color;
  final ValueChanged<int>? onPart;

  @override
  Widget build(BuildContext context) {
    final s = disk ? Size.square(min(size, 260.0)) : Size(size, height ?? 96.0);
    return GestureDetector(
      onTapUp: onPart == null
          ? null
          : (e) {
              final i = partAt(e.localPosition, s, parts, disk: disk);
              if (i != null) onPart!(i);
            },
      child: CustomPaint(size: s, painter: _FigurePainter(parts, filled, second, disk, color)),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter(this.parts, this.filled, this.second, this.disk, this.color);
  final int parts;
  final Set<int> filled, second;
  final bool disk;
  final Color color;

  Path _part(Size s, int i) {
    if (!disk) return Path()..addRect(Rect.fromLTWH(s.width * i / parts, 0, s.width / parts, s.height));
    final c = s.center(Offset.zero);
    final r = s.shortestSide / 2;
    final start = -pi / 2 + 2 * pi * i / parts;
    return Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), start, 2 * pi / parts, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var i = 0; i < parts; i++) {
      final path = _part(size, i);
      final isFirst = filled.contains(i), isSecond = second.contains(i);
      if (isFirst || isSecond) {
        canvas.drawPath(path, Paint()..color = isSecond ? color.withValues(alpha: .45) : color.withValues(alpha: .8));
        // Des rayures en plus de la couleur : la couleur ne dit jamais seule ce qui est colorié (docs/design.md).
        canvas.save();
        canvas.clipPath(path);
        final hatch = Paint()
          ..color = Colors.white.withValues(alpha: .55)
          ..strokeWidth = 3;
        for (var x = -size.height; x < size.width; x += isSecond ? 22 : 14) {
          canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), hatch);
        }
        canvas.restore();
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) => true;
}

/// Une ligne à comparer : la fraction écrite et sa bande, sur un même tout ; toute la ligne se touche.
class _CompareRow extends StatelessWidget {
  const _CompareRow({required this.frac, required this.width, required this.color, required this.tried, required this.highlight, required this.onTap});
  final Frac frac;
  final double width;
  final Color color;
  final bool tried, highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: fracWords(frac.n, frac.d),
        excludeSemantics: true,
        child: Material(
          color: tried ? const Color(0xFFE3E7E4) : surface,
          elevation: tried ? 0 : 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: highlight ? gold : const Color(0xFFD5DBD7), width: highlight ? 6 : 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                FracLabel(frac, size: 32),
                const SizedBox(width: 16),
                _Figure(parts: frac.d, filled: {for (var i = 0; i < frac.n; i++) i}, disk: false, size: min(width - 110, 360.0), height: 64, color: color),
              ]),
            ),
          ),
        ),
      );
}

/// La bande-unité, graduée en [parts] : on touche la graduation (la plus proche du doigt).
class _Strip extends StatelessWidget {
  const _Strip({required this.parts, required this.width, required this.color, required this.mark, required this.tried, required this.onTick});
  final int parts;
  final double width;
  final Color color;
  final int? mark;
  final Set<int> tried;
  final ValueChanged<int>? onTick;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Bande graduée de zéro à un, en $parts parts',
        child: GestureDetector(
          onTapUp: onTick == null ? null : (e) => onTick!((e.localPosition.dx / width * parts).round().clamp(1, parts)),
          child: CustomPaint(size: Size(width, 140), painter: _StripPainter(parts, color, mark, tried)),
        ),
      );
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.parts, this.color, this.mark, this.tried);
  final int parts;
  final Color color;
  final int? mark;
  final Set<int> tried;

  void _text(Canvas c, String s, Offset at) {
    final t = TextPainter(text: TextSpan(text: s, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink)), textDirection: TextDirection.ltr)..layout();
    t.paint(c, at - Offset(t.width / 2, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 12.0, top = 40.0, h = 56.0;
    final w = size.width - 2 * inset;
    double x(int i) => inset + w * i / parts;
    final line = Paint()
      ..color = ink
      ..strokeWidth = 3;
    final filled = mark;
    if (filled != null) {
      canvas.drawRect(Rect.fromLTWH(inset, top, x(filled) - inset, h), Paint()..color = color.withValues(alpha: .6));
    }
    canvas.drawRect(
        Rect.fromLTWH(inset, top, w, h),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    for (var i = 1; i < parts; i++) {
      canvas.drawLine(Offset(x(i), top), Offset(x(i), top + h), line);
    }
    _text(canvas, '0', Offset(x(0), top + h + 6));
    _text(canvas, '1', Offset(x(parts), top + h + 6));
    // Les graduations déjà essayées portent une croix ; celle choisie, un triangle (la forme, pas seulement la couleur).
    for (final i in tried) {
      final o = Offset(x(i), top - 16);
      canvas.drawLine(o + const Offset(-7, -7), o + const Offset(7, 7), line);
      canvas.drawLine(o + const Offset(7, -7), o + const Offset(-7, 7), line);
    }
    if (filled != null && !tried.contains(filled)) {
      canvas.drawPath(
        Path()
          ..moveTo(x(filled), top - 2)
          ..lineTo(x(filled) - 12, top - 22)
          ..lineTo(x(filled) + 12, top - 22)
          ..close(),
        Paint()..color = gold,
      );
    }
  }

  @override
  bool shouldRepaint(_StripPainter old) => true;
}

/// Les objets dont on prend une fraction ; partagés en [groups] rangées quand la réponse est montrée.
class _Objects extends StatelessWidget {
  const _Objects({required this.total, required this.groups, required this.art, required this.width});
  final int total;
  final int? groups;
  final String art;
  final double width;

  @override
  Widget build(BuildContext context) {
    final g = groups;
    final size = (width / 10 - 6).clamp(24.0, 44.0);
    Widget item() => Padding(padding: const EdgeInsets.all(3), child: Art(art, size: size));
    if (g == null) {
      return SizedBox(width: width, child: Wrap(alignment: WrapAlignment.center, children: [for (var i = 0; i < total; i++) item()]));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < g; r++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(border: Border.all(color: gold, width: 3), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < total ~/ g; i++) item()]),
        ),
    ]);
  }
}
