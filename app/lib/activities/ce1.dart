import 'dart:math';

import 'package:flutter/material.dart';

import '../content/content.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import 'numbers.dart';

/// Activités du CE1 (ADR 0035) : nombres jusqu'à 1000 avec le matériel multibase, additions et soustractions posées,
/// lecture de l'heure. Les réponses fausses proposées sont les erreurs typiques, et chacune est expliquée (ADR 0029).

/// Une plaque de cent (10 × 10), une barre de dix, ou un cube.
class Block extends StatelessWidget {
  const Block.plate({super.key}) : kind = 100;
  const Block.bar({super.key}) : kind = 10;
  const Block.cube({super.key}) : kind = 1;
  final int kind;

  @override
  Widget build(BuildContext context) {
    const c = 7.0;
    final (w, h) = switch (kind) { 100 => (10, 10), 10 => (1, 10), _ => (1, 1) };
    return CustomPaint(size: Size(w * c, h * c), painter: _BlockPainter(w, h, c));
  }
}

class _BlockPainter extends CustomPainter {
  _BlockPainter(this.w, this.h, this.c);
  final int w, h;
  final double c;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFF7B42C);
    final line = Paint()
      ..color = const Color(0xFF8A5A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRect(Offset.zero & size, fill);
    for (var x = 0; x <= w; x++) {
      canvas.drawLine(Offset(x * c, 0), Offset(x * c, h * c), line);
    }
    for (var y = 0; y <= h; y++) {
      canvas.drawLine(Offset(0, y * c), Offset(w * c, y * c), line);
    }
  }

  @override
  bool shouldRepaint(_BlockPainter old) => false;
}

/// Ce que montre une réponse fausse au CE1.
String? explainCe1(String activity, Question q, int right, int v) {
  switch (activity) {
    case 'multibase':
      final c = q.a, d = q.b, u = q.n % 10;
      if (d == 0 && v == c * 10 + u) return "Il n'y a pas de barre de dix : on écrit 0 au chiffre des dizaines.";
      if (v == d * 100 + c * 10 + u) return 'Tu as échangé les centaines et les dizaines : les plaques valent cent.';
      if ((v - right).abs() == 100) return 'Recompte les plaques : chacune vaut cent.';
      if ((v - right).abs() == 10) return 'Recompte les barres : chacune vaut dix.';
    case 'posee':
      if (v == right - 10 && q.a + q.b == right) return "N'oublie pas la retenue : 1 dizaine de plus.";
      if (q.a - q.b == right) {
        final wrong = ((q.a ~/ 10) - (q.b ~/ 10)) * 10 + ((q.a % 10) - (q.b % 10)).abs();
        if (v == wrong) return "Aux unités, on ne peut pas enlever ${q.b % 10} de ${q.a % 10} : on casse une dizaine.";
        if (v == q.a + q.b) return 'Tu as ajouté. Ici, on enlève.';
      } else if (v == (q.a - q.b).abs()) {
        return 'Tu as enlevé. Ici, on ajoute.';
      }
  }
  return null;
}

/// Lire un nombre jusqu'à 1000 représenté par des plaques de cent, des barres de dix et des cubes.
class MultibaseActivity extends StatefulWidget {
  const MultibaseActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<MultibaseActivity> createState() => _MultibaseActivityState();
}

class _MultibaseActivityState extends State<MultibaseActivity> {
  Attempt get a => widget.attempt;

  @override
  void initState() {
    super.initState();
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final c = q.a, d = q.b, u = q.n % 10;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < c; i++) const Block.plate(),
            if (c > 0) const SizedBox(width: 12),
            for (var i = 0; i < d; i++) const Block.bar(),
            if (d > 0) const SizedBox(width: 12),
            for (var i = 0; i < u; i++) const Block.cube(),
          ]),
        ),
        const SizedBox(height: 24),
        CE1Choices(attempt: a, right: q.n, near: [if (d == 0) c * 10 + u, if (d != c) d * 100 + c * 10 + u, q.n + 100]),
      ]),
    );
  }
}

/// Trois réponses-nombres dont les erreurs typiques, chacune expliquée si choisie.
class CE1Choices extends StatefulWidget {
  const CE1Choices({super.key, required this.attempt, required this.right, required this.near});
  final Attempt attempt;
  final int right;
  final List<int> near;
  @override
  State<CE1Choices> createState() => _CE1ChoicesState();
}

class _CE1ChoicesState extends State<CE1Choices> {
  final tried = <int>{};
  late final values = numberChoices(widget.right, widget.right * 31 + widget.attempt.question.a, near: widget.near);

  @override
  Widget build(BuildContext context) {
    final a = widget.attempt;
    return ListenableBuilder(
      listenable: a,
      builder: (_, _) => Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
        for (final v in values)
          NumberButton(
            value: v,
            highlight: (a.demonstrate || a.solved) && v == widget.right,
            onPressed: a.busy || a.finished || tried.contains(v)
                ? null
                : () {
                    if (v != widget.right) setState(() => tried.add(v));
                    a.submit(v == widget.right, why: v == widget.right ? null : explainCe1(a.skill.activity, a.question, widget.right, v));
                  },
          ),
      ]),
    );
  }
}

/// Addition ou soustraction posée en colonnes : unités sous les unités, dizaines sous les dizaines.
class ColumnOpActivity extends StatefulWidget {
  const ColumnOpActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ColumnOpActivity> createState() => _ColumnOpActivityState();
}

class _ColumnOpActivityState extends State<ColumnOpActivity> {
  Attempt get a => widget.attempt;

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
    final q = a.question;
    final sub = a.skill.params['op'] == '-';
    const style = TextStyle(fontFamily: 'Andika', fontSize: 56, fontWeight: FontWeight.w700, color: ink, height: 1.15);
    final u = a.app.universe;
    String two(int x) => x.toString().padLeft(3);
    // Colonnes fixes : chaque chiffre dans sa case (centaines, dizaines, unités).
    Widget row(String sign, String digits, {Color? color}) => Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 48, child: Text(sign, style: style.copyWith(color: u.night ? u.primary : u.onCard))),
          for (final ch in digits.split('')) SizedBox(width: 44, child: Text(ch, textAlign: TextAlign.center, style: style.copyWith(color: color))),
        ]);
    final wrongNoCarry = sub ? ((q.a ~/ 10) - (q.b ~/ 10)) * 10 + ((q.a % 10) - (q.b % 10)).abs() : q.n - 10;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // Les têtes de colonnes, écrites.
            Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 48),
              for (final h in ['c', 'd', 'u']) SizedBox(width: 44, child: Text(h, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63)))),
            ]),
            row('', two(q.a)),
            row(sub ? '−' : '+', two(q.b)),
            Container(width: 48 + 3 * 44, height: 4, color: ink),
            row('', (a.solved || a.demonstrate) ? two(q.n) : '  ?', color: (a.solved || a.demonstrate) ? green : null),
          ]),
        ),
        const SizedBox(height: 24),
        CE1Choices(attempt: a, right: q.n, near: [wrongNoCarry, if (sub) q.a + q.b else (q.a - q.b).abs()]),
      ]),
    );
  }
}

/// Lire l'heure sur une horloge à aiguilles : trois heures écrites, dont celle des aiguilles inversées.
class ClockActivity extends StatefulWidget {
  const ClockActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ClockActivity> createState() => _ClockActivityState();
}

class _ClockActivityState extends State<ClockActivity> {
  Attempt get a => widget.attempt;
  final tried = <(int, int)>{};

  late final List<(int, int)> options = () {
    final q = a.question;
    final r = Random(q.a);
    final right = (q.n, q.b);
    final cands = <(int, int)>{
      // Aiguilles lues à l'envers : la petite prise pour la grande.
      if (q.b != 0) ((q.b ~/ 5 == 0 ? 12 : q.b ~/ 5), (q.n % 12) * 5),
      (q.n % 12 + 1, q.b),
      ((q.n + 10) % 12 + 1, q.b),
      (q.n, (q.b + 30) % 60),
    }..remove(right);
    return [right, ...(cands.toList()..shuffle(r)).take(2)]..shuffle(r);
  }();

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

  String? _why((int, int) o) {
    final q = a.question;
    if (o.$2 == (q.n % 12) * 5) return "Tu as lu les aiguilles à l'envers : la petite montre les heures, la grande les minutes.";
    if (o.$1 == q.n % 12 + 1 && o.$2 == q.b) return "La petite aiguille n'a pas encore atteint ce nombre : regarde où elle est.";
    if (o.$1 == q.n && o.$2 != q.b) return 'Regarde bien la grande aiguille : elle montre les minutes.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final u = a.app.universe;
    final shown = a.demonstrate || a.solved;
    return LayoutBuilder(builder: (_, k) {
      final side = min(k.maxWidth - 64, k.maxHeight * 0.55).clamp(200.0, 360.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          SizedBox(width: side, height: side, child: CustomPaint(painter: _ClockPainter(q.n, q.b, u.night ? u.primary : u.onCard))),
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            for (final o in options)
              PicButton(
                size: 132,
                label: clockText(o.$1, o.$2),
                tried: tried.contains(o),
                highlight: shown && o == (q.n, q.b),
                onPressed: a.busy || a.finished || tried.contains(o)
                    ? null
                    : () {
                        final ok = o == (q.n, q.b);
                        if (!ok) setState(() => tried.add(o));
                        a.submit(ok, why: ok ? null : _why(o));
                      },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${o.$1} h ${o.$2.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink)),
                  Text(clockText(o.$1, o.$2), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF5F6B63))),
                ]),
              ),
          ]),
        ]),
      );
    });
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.h, this.m, this.accent);
  final int h, m;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    canvas
      ..drawCircle(c, r, Paint()..color = surface)
      ..drawCircle(c, r, Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8);
    for (var i = 1; i <= 12; i++) {
      final ang = -pi / 2 + i * pi / 6;
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: TextStyle(fontFamily: 'Andika', fontSize: r * 0.17, fontWeight: FontWeight.w700, color: ink)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(cos(ang), sin(ang)) * (r * 0.8) - Offset(tp.width / 2, tp.height / 2));
    }
    for (var i = 0; i < 60; i++) {
      final ang = -pi / 2 + i * pi / 30;
      final inner = i % 5 == 0 ? r * 0.92 : r * 0.96;
      canvas.drawLine(c + Offset(cos(ang), sin(ang)) * inner, c + Offset(cos(ang), sin(ang)) * r, Paint()
        ..color = ink
        ..strokeWidth = i % 5 == 0 ? 3 : 1.2);
    }
    // Petite aiguille (heures, elle avance avec les minutes) et grande aiguille (minutes) : longueur et épaisseur
    // différentes, pas seulement la couleur.
    final ha = -pi / 2 + ((h % 12) + m / 60) * pi / 6, ma = -pi / 2 + m * pi / 30;
    final hand = Paint()
      ..strokeCap = StrokeCap.round
      ..color = ink;
    canvas
      ..drawLine(c, c + Offset(cos(ha), sin(ha)) * (r * 0.5), hand..strokeWidth = 12)
      ..drawLine(c, c + Offset(cos(ma), sin(ma)) * (r * 0.78), Paint()
        ..strokeCap = StrokeCap.round
        ..color = accent
        ..strokeWidth = 6)
      ..drawCircle(c, 10, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.h != h || old.m != m;
}
