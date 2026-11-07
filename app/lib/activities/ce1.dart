import 'dart:math';

import 'package:flutter/material.dart';

import '../content/content.dart';
import '../core/column.dart';
import '../l10n/l10n.dart';
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
    const c = 9.0;
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
      if (d == 0 && v == c * 10 + u) return t("Il n'y a pas de barre de dix : on écrit 0 au chiffre des dizaines.");
      if (v == d * 100 + c * 10 + u) return t('Tu as échangé les centaines et les dizaines : les plaques valent cent.');
      if ((v - right).abs() == 100) return t('Recompte les plaques : chacune vaut cent.');
      if ((v - right).abs() == 10) return t('Recompte les barres : chacune vaut dix.');
    case 'suite':
      final step = q.b, w = stepWords[step.abs()];
      if (step.abs() != 1 && v == right - step + step.sign) return tf('Tu as compté de un en un. Ici, on avance de {w} en {w}.', {'w': '$w'});
      if (v == right - 2 * step) {
        return step < 0 ? tf("Cette suite descend : chaque nombre a {w} de moins que celui d'avant.", {'w': '$w'}) : tf("Cette suite monte : chaque nombre a {w} de plus que celui d'avant.", {'w': '$w'});
      }
      if ((v - right).abs() == step.abs()) return t('Regarde le nombre juste avant le trou, et fais un seul pas.');
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
    return PlayScroll(
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

/// L'opération posée, effectuée chiffre par chiffre (ADR 0046) : l'enfant écrit chaque chiffre du résultat de droite à
/// gauche, la retenue, ou la dizaine cassée. La case à remplir a un cadre épais et une flèche (pas seulement une
/// couleur) ; ce qu'il faut faire est écrit sous l'opération et dit.
class _ColumnOpActivityState extends State<ColumnOpActivity> {
  Attempt get a => widget.attempt;
  late final bool sub = a.skill.params['op'] == '-';
  late final List<ColumnStep> steps = columnSteps(a.question.a, a.question.b, subtract: sub);
  int done = 0;

  ColumnStep? get step => done < steps.length ? steps[done] : null;

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne')).then((_) => _sayStep());
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _sayStep() async {
    final s = step;
    if (s != null && !a.finished) await a.speech.say(s.prompt);
  }

  void _press(int v) {
    final s = step;
    if (s == null || a.busy || a.finished) return;
    if (v != s.value) {
      a.submit(false, why: s.why);
      return;
    }
    setState(() => done++);
    if (step == null) {
      a.submit(true);
    } else {
      _sayStep();
    }
  }

  /// La valeur affichée d'une case : écrite si l'étape est faite (ou montrée à la fin).
  int? _shown(ColumnKind kind, int col) {
    for (final (i, s) in steps.indexed) {
      if (s.kind == kind && s.column == col && (i < done || a.demonstrate || a.solved)) return s.value;
    }
    return null;
  }

  bool _active(ColumnKind kind, int col) => !a.finished && step?.kind == kind && step?.column == col;

  bool _has(ColumnKind kind, int col) => steps.any((s) => s.kind == kind && s.column == col);

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final u = a.app.universe;
    const big = TextStyle(fontFamily: 'Andika', fontSize: 44, fontWeight: FontWeight.w700, color: ink, height: 1.05);
    const cell = 52.0;
    Widget box(ColumnKind kind, int col, {bool small = false}) {
      final v = _shown(kind, col);
      final active = _active(kind, col);
      final size = small ? 38.0 : cell;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        // La flèche montre la case à remplir (en plus du cadre épais).
        SizedBox(height: small ? 0 : 16, child: active && !small ? Icon(Icons.arrow_downward_rounded, size: 16, color: u.primary) : null),
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? u.primary.withValues(alpha: 0.08) : null,
            border: Border.all(color: active ? u.primary : const Color(0xFFB8C1BB), width: active ? 4 : 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(v == null ? (active && small ? '?' : '') : '$v',
              style: big.copyWith(fontSize: small ? 24 : 38, color: v != null && kind == ColumnKind.result ? green : ink)),
        ),
      ]);
    }

    // Le chiffre du haut d'une colonne : barré quand on y a cassé une dizaine (le nouveau chiffre est écrit au-dessus),
    // et précédé d'un petit 1 aux unités qui ont reçu la dizaine cassée.
    Widget top(int col) {
      if (q.a < [1, 10, 100][col] && col > 0) return const SizedBox(width: cell);
      final d = digit(q.a, col);
      final crossed = _shown(ColumnKind.borrow, col) != null;
      final gotTen = col + 1 < 3 && _shown(ColumnKind.borrow, col + 1) != null;
      return SizedBox(
        width: cell,
        child: Text.rich(
          TextSpan(children: [
            if (gotTen) TextSpan(text: '1', style: big.copyWith(fontSize: 24, color: u.primary)),
            TextSpan(text: '$d', style: crossed ? big.copyWith(decoration: TextDecoration.lineThrough, decorationThickness: 3, color: const Color(0xFF7A847E)) : big),
          ]),
          textAlign: TextAlign.center,
        ),
      );
    }

    Widget bottom(int col) => SizedBox(
        width: cell, child: Text(q.b < [1, 10, 100][col] && col > 0 ? '' : '${digit(q.b, col)}', textAlign: TextAlign.center, style: big));
    const cols = [2, 1, 0];
    final s = step;
    return PlayScroll(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 40),
              for (final c in cols)
                SizedBox(width: cell, child: Text((english ? 'hto' : 'cdu')[2 - c], textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63)))),
            ]),
            // Retenues (addition) ou dizaines cassées (soustraction), au-dessus des colonnes, seulement où il en faut.
            Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 40),
              for (final c in cols)
                SizedBox(
                  width: cell,
                  height: 40,
                  child: Center(
                    child: _has(sub ? ColumnKind.borrow : ColumnKind.carry, c) &&
                            (_shown(sub ? ColumnKind.borrow : ColumnKind.carry, c) != null || _active(sub ? ColumnKind.borrow : ColumnKind.carry, c))
                        ? box(sub ? ColumnKind.borrow : ColumnKind.carry, c, small: true)
                        : null,
                  ),
                ),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 40), for (final c in cols) top(c)]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 40, child: Text(sub ? '−' : '+', style: big.copyWith(color: u.night ? u.primary : u.onCard))),
              for (final c in cols) bottom(c),
            ]),
            Container(width: 40 + 3 * cell, height: 4, color: ink),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 40),
              for (final c in cols) SizedBox(width: cell, child: Center(child: _has(ColumnKind.result, c) || c == 0 ? box(ColumnKind.result, c) : const SizedBox(height: 68))),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        // Ce qu'il faut faire maintenant, écrit (la voix le dit aussi). Hauteur fixe de trois lignes : le clavier ne
        // bouge pas d'une étape à l'autre (sinon le doigt tombe sur une autre touche).
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(20) * 1.2 * 3 + 4,
          child: Center(
            child: s != null && !a.finished
                ? Text(s.prompt, textAlign: TextAlign.center, maxLines: 3, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink, height: 1.2))
                : null,
          ),
        ),
        const SizedBox(height: 8),
        _Keypad(enabled: s != null && !a.busy && !a.finished, onDigit: _press),
      ]),
    );
  }
}

/// Dix chiffres, deux rangées de cinq ; touches de 60 dp (≥ 48).
class _Keypad extends StatelessWidget {
  const _Keypad({required this.enabled, required this.onDigit});
  final bool enabled;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        for (final row in const [[1, 2, 3, 4, 5], [6, 7, 8, 9, 0]])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final d in row)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 32, fontWeight: FontWeight.w700),
                      ),
                      onPressed: enabled ? () => onDigit(d) : null,
                      child: Text('$d'),
                    ),
                  ),
                ),
            ]),
          ),
      ]);
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
    if (o.$2 == (q.n % 12) * 5) return t("Tu as lu les aiguilles à l'envers : la petite montre les heures, la grande les minutes.");
    if (o.$1 == q.n % 12 + 1 && o.$2 == q.b) return t("La petite aiguille n'a pas encore atteint ce nombre : regarde où elle est.");
    if (o.$1 == q.n && o.$2 != q.b) return t('Regarde bien la grande aiguille : elle montre les minutes.');
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final u = a.app.universe;
    final shown = a.demonstrate || a.solved;
    return LayoutBuilder(builder: (_, k) {
      final side = min(k.maxWidth - 64, k.maxHeight * 0.55).clamp(200.0, 360.0);
      return PlayScroll(
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
                  Text('${o.$1}${english ? ':' : ' h '}${o.$2.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ink)),
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

/// Une suite de nombres à compléter (ADR 0036) : cinq cases de [b] en [b], une vide. Après un essai manqué, ou dans la
/// démonstration, les pas « +2 » (ou « −1 ») s'écrivent entre les cases : la règle devient visible.
class SequenceActivity extends StatefulWidget {
  const SequenceActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<SequenceActivity> createState() => _SequenceActivityState();
}

class _SequenceActivityState extends State<SequenceActivity> {
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
    final u = a.app.universe;
    final shown = a.solved || a.demonstrate;
    final steps = a.helpText != null || shown;
    final label = q.b > 0 ? '+${q.b}' : '−${-q.b}';
    Widget tile(int v) {
      final hole = v == q.n;
      return Container(
        width: 112,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hole && !shown ? const Color(0xFFFFF4D6) : surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: cardShadow,
          // La case vide a un bord épais et pointillé à l'œil : pas seulement une autre couleur.
          border: hole ? Border.all(color: shown ? green : ink, width: 4) : null,
        ),
        child: Text(hole && !shown ? '?' : '$v',
            style: TextStyle(fontFamily: 'Andika', fontSize: 44, fontWeight: FontWeight.w700, color: hole && shown ? green : ink)),
      );
    }

    final values = [for (var i = 0; i < 5; i++) q.a + i * q.b];
    return PlayScroll(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, v) in values.indexed) ...[
              if (i > 0)
                SizedBox(
                  width: 52,
                  child: Column(children: [
                    Opacity(
                      opacity: steps ? 1 : 0,
                      child: Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: u.night ? u.primary : u.onCard)),
                    ),
                    Icon(Icons.arrow_forward_rounded, size: 32, color: u.night ? u.primary : u.onCard),
                    const SizedBox(height: 28),
                  ]),
                ),
              tile(v),
            ],
          ]),
        ),
        const SizedBox(height: 32),
        CE1Choices(attempt: a, right: q.n, near: [
          if (q.b.abs() != 1) q.n - q.b + q.b.sign,
          q.n - 2 * q.b,
          q.n + q.b,
        ].where((v) => v >= 0).toList()),
      ]),
    );
  }
}
