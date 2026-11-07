import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

import '../l10n/l10n.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Langue du modèle d'écriture ML Kit (ADR 0009, 0012). Les chiffres sont reconnus par le modèle français.
const inkLanguage = 'fr';

/// Calcul : « a + b = ? » ou « a + ? = n ». L'enfant écrit la réponse au doigt (ML Kit, sur l'appareil) ; sans
/// modèle téléchargé, il choisit parmi trois nombres.
class CalcActivity extends StatefulWidget {
  const CalcActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<CalcActivity> createState() => _CalcActivityState();
}

class _CalcActivityState extends State<CalcActivity> {
  Attempt get a => widget.attempt;
  late final bool complement = a.skill.params['forme'] == 'complement';
  late final int expected = a.skill.expected(a.question);
  bool? inkReady;
  final _strokes = <List<Offset>>[];
  final _times = <List<int>>[];
  mlkit.DigitalInkRecognizer? _recognizer;
  late final List<int> choices = ([max(0, expected - 1), max(0, expected - 1) + 1, max(0, expected - 1) + 2]..shuffle());

  @override
  void initState() {
    super.initState();
    a.addListener(_refresh);
    _checkModel();
    a.show('question').then((_) => a.say('consigne'));
  }

  Future<void> _checkModel() async {
    var ok = false;
    try {
      ok = await mlkit.DigitalInkRecognizerModelManager().isModelDownloaded(inkLanguage);
    } catch (_) {}
    if (ok) _recognizer = mlkit.DigitalInkRecognizer(languageCode: inkLanguage);
    if (mounted) setState(() => inkReady = ok);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    a.removeListener(_refresh);
    _recognizer?.close();
    super.dispose();
  }

  bool get locked => a.busy || a.finished;

  Future<void> _validate() async {
    if (locked || _strokes.isEmpty || _recognizer == null) return;
    final ink = mlkit.Ink();
    for (final (i, s) in _strokes.indexed) {
      final st = mlkit.Stroke();
      for (final (j, p) in s.indexed) {
        st.points.add(mlkit.StrokePoint(x: p.dx, y: p.dy, t: _times[i][j]));
      }
      ink.strokes.add(st);
    }
    int? value;
    try {
      final candidates = await _recognizer!.recognize(ink);
      for (final c in candidates) {
        value = int.tryParse(_digits(c.text));
        if (value != null) break;
      }
    } catch (_) {}
    setState(() {
      _strokes.clear();
      _times.clear();
    });
    if (value == null) {
      // Pas lu : ce n'est pas un essai manqué.
      await a.speech.say(a.app.common.text('pas_compris'), id: 'commun.pas_compris');
      return;
    }
    await a.submit(value == expected);
  }

  /// Confusions courantes d'un chiffre tracé avec une lettre (⚠ à vérifier sur l'écriture d'enfants).
  String _digits(String s) => s
      .trim()
      .replaceAll(RegExp('[oO]'), '0')
      .replaceAll(RegExp('[lI|]'), '1')
      .replaceAll(' ', '');

  @override
  Widget build(BuildContext context) {
    final q = a.question;
    final big = Theme.of(context).textTheme.displayLarge!;
    final answerShown = a.demonstrate || a.solved ? '$expected' : '?';
    final u = a.app.universe;
    final art = a.app.objectArt(a.skill);
    // La réponse attendue : « ? » dans une case ; pendant la démonstration, le nombre lui-même apparaît.
    final answer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(border: Border.all(color: u.onCard, width: 4), borderRadius: BorderRadius.circular(16)),
      child: Text(answerShown, style: big.copyWith(color: u.onCard)),
    );
    final equation = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
      child: FittedBox(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Num(q.a, big, art),
          Text(' + ', style: big),
          complement ? answer : _Num(q.b, big, art),
          Text(' = ', style: big),
          complement ? _Num(q.n, big, art) : answer,
        ]),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: switch (inkReady) {
        null => const SizedBox(),
        false => Column(children: [equation, Expanded(child: _choices())]),
        true => split(
            sideSize: 130,
            main: LayoutBuilder(
              builder: (_, k) => k.maxWidth > k.maxHeight * 1.1
                  ? Row(children: [Expanded(child: equation), const SizedBox(width: 16), Expanded(child: _pad())])
                  : Column(children: [equation, const SizedBox(height: 12), Expanded(child: _pad())]),
            ),
            side: (axis) => Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              SizedBox(
                width: 104,
                height: 104,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A938C), padding: EdgeInsets.zero),
                  onPressed: locked ? null : () => setState(() {
                    _strokes.clear();
                    _times.clear();
                  }),
                  child: Icon(Icons.backspace_rounded, size: 56, color: Colors.white, semanticLabel: t('Effacer')),
                ),
              ),
              SizedBox(
                width: 104,
                height: 104,
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: locked ? null : _validate,
                  child: Icon(Icons.check_rounded, size: 72, semanticLabel: t('Valider')),
                ),
              ),
            ]),
          ),
      },
    );
  }

  /// La zone où l'enfant écrit au doigt (un repère « écris ici » tant qu'elle est vide).
  Widget _pad() => Container(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: GestureDetector(
            onPanStart: locked
                ? null
                : (d) => setState(() {
                      _strokes.add([d.localPosition]);
                      _times.add([DateTime.now().millisecondsSinceEpoch]);
                    }),
            onPanUpdate: locked
                ? null
                : (d) => setState(() {
                      _strokes.last.add(d.localPosition);
                      _times.last.add(DateTime.now().millisecondsSinceEpoch);
                    }),
            child: Stack(children: [
              if (_strokes.isEmpty)
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.draw_rounded, size: 40, color: Color(0xFF9AA49D)),
                    const SizedBox(width: 8),
                    Text(t('Écris ici'), style: const TextStyle(fontSize: 26, color: Color(0xFF5F6B63))),
                  ]),
                ),
              CustomPaint(painter: _InkPainter(_strokes), size: Size.infinite),
            ]),
          ),
        ),
      );

  Widget _choices() => Center(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final v in choices)
            NumberButton(
              value: v,
              highlight: a.demonstrate && v == expected,
              onPressed: locked ? null : () => a.submit(v == expected),
            ),
        ]),
      );
}

/// Un nombre avec ses points en dessous (aide au dénombrement, pas seulement le chiffre).
class _Num extends StatelessWidget {
  const _Num(this.v, this.style, this.art);
  final int v;
  final TextStyle style;

  /// Objet de l'univers dessiné sous le nombre (autant d'objets que le nombre).
  final String art;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$v', style: style),
        SizedBox(
          width: 140,
          child: Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
            for (var i = 0; i < v; i++)
              Art(art, size: v > 5 ? 22 : 28),
          ]),
        ),
      ]);
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = ink
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.length == 1) canvas.drawCircle(s.first, 7, Paint()..color = ink);
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (final o in s.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => true;
}
