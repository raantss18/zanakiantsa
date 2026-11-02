import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;

import '../ui/session.dart';
import '../ui/theme.dart';

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
    a.say('question').then((_) => a.say('consigne'));
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
      await a.app.voice.say(a.app.common.text('pas_compris'), id: 'commun.pas_compris');
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
    final answerShown = a.demonstrate ? '$expected' : '?';
    final equation = FittedBox(
      child: Row(children: [
        _Num(q.a, big),
        Text(' + ', style: big),
        complement ? Text(answerShown, style: big.copyWith(color: a.demonstrate ? gold : red)) : _Num(q.b, big),
        Text(' = ', style: big),
        complement ? _Num(q.n, big) : Text(answerShown, style: big.copyWith(color: a.demonstrate ? gold : red)),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, helpBand, 16, 8),
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
                  child: const Icon(Icons.backspace_rounded, size: 56, color: Colors.white, semanticLabel: 'Effacer'),
                ),
              ),
              SizedBox(
                width: 104,
                height: 104,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: green, padding: EdgeInsets.zero),
                  onPressed: locked ? null : _validate,
                  child: const Icon(Icons.check_rounded, size: 72, color: Colors.white, semanticLabel: 'Valider'),
                ),
              ),
            ]),
          ),
      },
    );
  }

  /// La zone où l'enfant écrit au doigt.
  Widget _pad() => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: surface,
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
            child: CustomPaint(painter: _InkPainter(_strokes), size: Size.infinite),
          ),
        ),
      );

  Widget _choices() => Center(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (final v in choices)
            SizedBox(
              width: 104,
              height: 104,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: a.demonstrate && v == expected ? gold : green,
                  disabledBackgroundColor: a.demonstrate && v == expected ? gold : const Color(0xFFBFC7C1),
                  padding: EdgeInsets.zero,
                ),
                onPressed: locked ? null : () => a.submit(v == expected),
                child: Text('$v', style: const TextStyle(fontSize: 48, color: Colors.white)),
              ),
            ),
        ]),
      );
}

/// Un nombre avec ses points en dessous (aide au dénombrement, pas seulement le chiffre).
class _Num extends StatelessWidget {
  const _Num(this.v, this.style);
  final int v;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$v', style: style),
        SizedBox(
          width: 90,
          child: Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: [
            for (var i = 0; i < v; i++)
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: green, shape: BoxShape.circle)),
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
