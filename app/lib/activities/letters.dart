import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';
import 'draw.dart' show Stroke;

/// Lire et écrire (ADR 0031) : compter les syllabes, reconnaître une lettre ou une syllabe, tracer une lettre.

/// Lettres faciles à confondre (programme de maternelle : b/d, c/e/o, p/q) : proposées ensemble exprès.
const confusable = {
  'b': 'dpq', 'd': 'bpq', 'p': 'qbd', 'q': 'pdb', 'm': 'nw', 'n': 'mu', 'u': 'nv', 'c': 'eo', 'e': 'co', 'o': 'ca',
  'a': 'oe', 'i': 'lj', 'l': 'it', 'f': 'tl', 't': 'fl', 'v': 'wy', 's': 'zc', 'z': 'sx', 'h': 'nk', 'g': 'qy', 'j': 'ig',
  'k': 'hx', 'r': 'nv', 'w': 'vm', 'x': 'kz', 'y': 'vg',
};

TextStyle letterStyle(String style, double size, {Color color = ink}) => style == 'cursive'
    ? TextStyle(fontFamily: 'PlaywriteFR', fontSize: size, color: color, height: 1.4)
    : TextStyle(fontFamily: 'Andika', fontWeight: FontWeight.w700, fontSize: size, color: color, height: 1.1);

/// Combien de syllabes : l'image du mot et le mot écrit, un bouton « mains » qui dit le mot en syllabes, 1 à 4.
class SyllablesActivity extends StatefulWidget {
  const SyllablesActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<SyllablesActivity> createState() => _SyllablesActivityState();
}

class _SyllablesActivityState extends State<SyllablesActivity> {
  Attempt get a => widget.attempt;
  late final item = a.skill.items[a.question.n];
  final tried = <int>{};
  int clap = -1;

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

  void _changed() {
    if (a.demonstrate && clap < 0) _claps();
    setState(() {});
  }

  /// Dit le mot syllabe par syllabe ; chaque main s'allume à son tour.
  Future<void> _claps() async {
    for (var i = 0; i < item.syllables.length; i++) {
      if (!mounted) return;
      setState(() => clap = i);
      await a.app.voice.say(item.syllables[i], force: true);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() => clap = item.syllables.length);
  }

  @override
  Widget build(BuildContext context) {
    final right = item.syllables.length;
    final shown = a.demonstrate || a.solved;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Column(children: [
            Art(item.image!, size: 120, label: item.text),
            const SizedBox(height: 8),
            // Le mot, découpé en syllabes une fois trouvé ou montré.
            Text(shown ? item.syllables.join(' · ') : item.text, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 8),
            // Les mains n'apparaissent qu'à l'écoute en syllabes : avant, leur nombre donnerait la réponse.
            SizedBox(
              height: 48,
              child: Wrap(spacing: 6, children: [
                for (var i = 0; i < right && clap >= i; i++) const Art('1f44f', size: 44),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // « Écoute en syllabes » est une aide : proposée après un premier essai, ou pendant la démonstration.
        if (a.misses > 0 || shown)
          OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 60), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 20, fontWeight: FontWeight.w700)),
          onPressed: () {
            setState(() => clap = -1);
            _claps();
          },
          icon: const Art('1f44f', size: 30),
          label: const Text('Écoute en syllabes'),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          for (var k = 1; k <= 4; k++)
            NumberButton(
              size: 84,
              value: k,
              highlight: shown && k == right,
              onPressed: a.busy || a.finished || tried.contains(k)
                  ? null
                  : () {
                      if (k != right) setState(() => tried.add(k));
                      a.submit(k == right,
                          why: k == right ? null : (k > right ? 'Il y a moins de morceaux : écoute-le en syllabes.' : 'Il y a plus de morceaux : écoute-le en syllabes.'));
                    },
            ),
        ]),
      ]),
    );
  }
}

/// Reconnaître : une lettre dite (nom), la minuscule d'une capitale (casse), la cursive d'une script (cursive), la
/// première lettre d'un mot illustré (initiale), une syllabe dite (syllabe). Trois réponses, dont des lettres qui se
/// ressemblent.
class LetterActivity extends StatefulWidget {
  const LetterActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<LetterActivity> createState() => _LetterActivityState();
}

class _LetterActivityState extends State<LetterActivity> {
  Attempt get a => widget.attempt;
  late final String mode = a.skill.params['mode'] as String;
  late final Random r = Random(a.question.a);
  late final String target = a.skill.letterOf(a.question);
  final tried = <String>{};

  /// Ce qu'on écrit sur les boutons, et la bonne réponse parmi eux.
  late final (List<String>, String) choices = () {
    final q = a.question;
    switch (mode) {
      case 'syllabe':
        final cons = List<String>.from(a.skill.params['consonnes'] as List), voy = List<String>.from(a.skill.params['voyelles'] as List);
        final c = cons[q.n], v = voy[q.b];
        final others = <String>{'$c${voy[(q.b + 1 + r.nextInt(voy.length - 1)) % voy.length]}', '${cons[(q.n + 1 + r.nextInt(cons.length - 1)) % cons.length]}$v', '$v$c'}
          ..remove(target);
        return ([target, ...others.take(2)]..shuffle(r), target);
      case 'initiale':
        final l = target.toLowerCase();
        final pool = (confusable[l] ?? 'aeiou').split('').map((x) => x.toUpperCase()).where((x) => x != target).toSet().toList()..shuffle(r);
        while (pool.length < 2) {
          final x = String.fromCharCode(65 + r.nextInt(26));
          if (x != target && !pool.contains(x)) pool.add(x);
        }
        return ([target, ...pool.take(2)]..shuffle(r), target);
      default:
        final l = target.toLowerCase();
        final pool = (confusable[l] ?? '').split('').where((x) => x != l).toSet().toList()..shuffle(r);
        while (pool.length < 2) {
          final x = String.fromCharCode(97 + r.nextInt(26));
          if (x != l && !pool.contains(x)) pool.add(x);
        }
        final out = [l, ...pool.take(2)]..shuffle(r);
        // nom : capitales ; casse : minuscules ; cursive : minuscules attachées.
        return (mode == 'nom' ? [for (final x in out) x.toUpperCase()] : out, mode == 'nom' ? l.toUpperCase() : l);
    }
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

  @override
  Widget build(BuildContext context) {
    final (options, right) = choices;
    final shown = a.demonstrate || a.solved;
    final u = a.app.universe;
    final model = switch (mode) {
      'casse' => Text(target, style: letterStyle('script', 110, color: u.night ? u.primary : u.onCard)),
      'cursive' => Text(target, style: letterStyle('script', 110, color: u.night ? u.primary : u.onCard)),
      'initiale' => Column(mainAxisSize: MainAxisSize.min, children: [
          Art(a.skill.items[a.question.n].image!, size: 130, label: a.skill.items[a.question.n].text),
          Text(a.skill.items[a.question.n].text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink)),
        ]),
      _ => null,
    };
    return LayoutBuilder(builder: (_, k) {
      final size = min((k.maxWidth - 32) / 3 - 16, 160.0).clamp(96.0, 160.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (model != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
              child: model,
            ),
          const SizedBox(height: 24),
          Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
            for (final o in options)
              PicButton(
                size: size,
                label: o,
                tried: tried.contains(o),
                highlight: shown && o == right,
                onPressed: a.busy || a.finished || tried.contains(o)
                    ? null
                    : () {
                        if (o != right) setState(() => tried.add(o));
                        a.submit(o == right, why: o == right ? null : _why(o, right));
                      },
                child: FittedBox(child: Text(o, style: letterStyle(mode == 'cursive' ? 'cursive' : 'script', size * 0.55))),
              ),
          ]),
        ]),
      );
    });
  }

  /// Ce que montre le choix (ADR 0029) : une lettre qui se ressemble, une syllabe à l'envers.
  String? _why(String chosen, String right) {
    if (mode == 'syllabe' && chosen.split('').reversed.join() == right) return '« $chosen » commence par la voyelle : on lit de gauche à droite.';
    final l = right.toLowerCase(), c = chosen.toLowerCase();
    if ((confusable[l] ?? '').contains(c)) return '« $chosen » ressemble à « $right », mais regarde bien : la boucle ou la barre n\'est pas du même côté.';
    return null;
  }
}

/// Tracer : la lettre en gris, l'enfant repasse dessus au doigt. Réussi si le tracé couvre l'essentiel de la lettre sans
/// trop en sortir (comparaison de deux images de 64 × 64 : aucune donnée envoyée, aucun modèle à télécharger).
class TraceActivity extends StatefulWidget {
  const TraceActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<TraceActivity> createState() => _TraceActivityState();
}

class _TraceActivityState extends State<TraceActivity> {
  Attempt get a => widget.attempt;
  late final String style = a.skill.params['style'] as String;
  late final String letter = a.skill.letterOf(a.question);
  final strokes = <Stroke>[];
  Size _box = Size.zero;

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

  TextPainter _guide(Size box) => TextPainter(
        // La cursive a des lettres basses (x-height) : on la dessine plus grande pour que le tracé reste ample.
        text: TextSpan(text: letter, style: letterStyle(style, box.height * (style == 'cursive' ? 0.95 : 0.78), color: const Color(0xFFCBD3CE))),
        textDirection: TextDirection.ltr,
      )..layout();

  Future<void> _check() async {
    if (strokes.isEmpty || a.busy || a.finished) return;
    const n = 64;
    final scale = n / max(_box.width, _box.height);
    Future<Uint8List> mask(void Function(Canvas) draw) async {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      draw(c);
      final img = await rec.endRecording().toImage(n, n);
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    }

    final tp = _guide(_box);
    final guide = await mask((c) => tp.paint(c, _box.center(Offset.zero) - Offset(tp.width / 2, tp.height / 2)));
    final ink = await mask((c) {
      for (final s in strokes) {
        c.drawPath(
          Path()..addPolygon(s.points, false),
          Paint()
            ..strokeWidth = s.width * 1.6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..color = Colors.black,
        );
      }
    });
    var g = 0, covered = 0, drawn = 0, outside = 0;
    bool near(int x, int y) {
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          final xx = x + dx, yy = y + dy;
          if (xx >= 0 && yy >= 0 && xx < n && yy < n && guide[(yy * n + xx) * 4 + 3] > 40) return true;
        }
      }
      return false;
    }

    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = (y * n + x) * 4 + 3;
        final isGuide = guide[i] > 40, isInk = ink[i] > 40;
        if (isGuide) {
          g++;
          if (isInk || _inkNear(ink, x, y, n)) covered++;
        }
        if (isInk) {
          drawn++;
          if (!near(x, y)) outside++;
        }
      }
    }
    final coverage = g == 0 ? 0 : covered / g, spill = drawn == 0 ? 1 : outside / drawn;
    final ok = coverage >= 0.6 && spill <= 0.35;
    a.submit(ok,
        why: ok
            ? null
            : coverage < 0.6
                ? "Il manque un morceau de la lettre : suis-la jusqu'au bout."
                : 'Ton tracé sort de la lettre : va plus doucement, sur le gris.');
    if (!ok && mounted) setState(strokes.clear);
  }

  bool _inkNear(Uint8List ink, int x, int y, int n) {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final xx = x + dx, yy = y + dy;
        if (xx >= 0 && yy >= 0 && xx < n && yy < n && ink[(yy * n + xx) * 4 + 3] > 40) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    final shown = a.demonstrate || a.solved;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow, border: Border.all(color: u.onCard, width: 4)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: LayoutBuilder(builder: (_, k) {
                    _box = Size(k.maxWidth, k.maxHeight);
                    return GestureDetector(
                      onPanStart: a.finished ? null : (d) => setState(() => strokes.add(Stroke(ink, 14)..points.add(d.localPosition))),
                      onPanUpdate: a.finished ? null : (d) => setState(() => strokes.last.points.add(d.localPosition)),
                      child: CustomPaint(size: Size.infinite, painter: _TracePainter(_guide(_box), strokes, shown ? (u.night ? u.primary : u.onCard) : null)),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(
            iconSize: 40,
            tooltip: 'Effacer',
            onPressed: a.finished || strokes.isEmpty ? null : () => setState(strokes.clear),
            icon: const Icon(Icons.delete_sweep_rounded),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 120,
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green, disabledBackgroundColor: const Color(0xFFBFC7C1)),
              onPressed: a.busy || a.finished || strokes.isEmpty ? null : _check,
              child: const Icon(Icons.check_rounded, size: 48, color: Colors.white, semanticLabel: "J'ai fini"),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.guide, this.strokes, this.reveal);
  final TextPainter guide;
  final List<Stroke> strokes;

  /// Démonstration ou réussite : la lettre se colore.
  final Color? reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final at = size.center(Offset.zero) - Offset(guide.width / 2, guide.height / 2);
    if (reveal != null) {
      (TextPainter(text: TextSpan(text: guide.text!.toPlainText(), style: guide.text!.style!.copyWith(color: reveal)), textDirection: TextDirection.ltr)..layout())
          .paint(canvas, at);
    } else {
      guide.paint(canvas, at);
    }
    for (final s in strokes) {
      canvas.drawPath(
        Path()..addPolygon(s.points, false),
        Paint()
          ..color = s.color
          ..strokeWidth = s.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}
