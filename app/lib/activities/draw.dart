import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../content/content.dart';
import '../core/events.dart';
import '../ui/narrator.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Couleurs du dessin, chacune avec son nom (dit et lu par le lecteur d'écran : jamais la couleur seule). Huit : elles
/// tiennent sur une rangée en portrait (8 × 52 dp ≤ 457 dp de large sur la SM-X135G) avec des cibles de 48 dp.
const paints = [
  (Color(0xFF1B211D), 'noir'),
  (Color(0xFFD62828), 'rouge'),
  (Color(0xFFFCBF49), 'jaune'),
  (Color(0xFF2A9D3F), 'vert'),
  (Color(0xFF1D6FD6), 'bleu'),
  (Color(0xFF7B2CBF), 'violet'),
  (Color(0xFF8D5524), 'marron'),
  (Color(0xFFFF8FAB), 'rose'),
];

class Stroke {
  Stroke(this.color, this.width);
  final Color color;
  final double width;
  final points = <Offset>[];
}

/// Dossier des dessins de l'enfant (sur l'appareil seulement, CLAUDE.md règle 5).
Future<Directory> drawingsDir() async =>
    Directory('${(await getApplicationDocumentsDirectory()).path}/dessins')..createSync(recursive: true);

/// Atelier dessin (ADR 0019) : un sujet écrit et dit, une feuille, des couleurs, deux tailles, annuler. Pas de bonne
/// ou mauvaise réponse : « J'ai fini » range le dessin dans l'album et rapporte une étoile.
class DrawPage extends StatefulWidget {
  const DrawPage({super.key});
  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  late final AppState app = AppScope.of(context);
  late final Skill skill = app.topic('dessin').skills.first;
  late final Question q = skill.draw(Random());
  late final String prompt = skill.say('question', q, words: app.wordsFor(skill));
  final _started = DateTime.now();
  final strokes = <Stroke>[];
  Color color = paints.first.$1;
  double width = 10;
  Size _canvas = Size.zero;
  File? saved;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      app.voice.startMusic(app.universe.id);
      _listen(force: false);
    });
  }

  /// « Réécouter » ([force]) dit la phrase même voix coupée (ADR 0025).
  Future<void> _listen({bool force = true}) async {
    await app.voice.say(prompt, id: '${skill.voiceId('question')}.${q.n}', force: force);
    await app.voice.say(skill.phrases['consigne']!, id: skill.voiceId('consigne'), force: force);
  }

  @override
  void dispose() {
    app.voice.stop();
    app.voice.stopMusic();
    // Retour avant la fin : le temps passé compte quand même pour la journée, sans faire avancer l'histoire.
    if (!_logged && DateTime.now().difference(_started) > const Duration(seconds: 20)) {
      app.logSession(SessionLog(theme: 'dessin', started: _started, ended: DateTime.now(), complete: false));
    }
    super.dispose();
  }

  Future<void> _finish() async {
    if (strokes.isEmpty || saved != null) return;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Offset.zero & _canvas, Paint()..color = Colors.white);
    _Painter(strokes).paint(c, _canvas);
    final img = await rec.endRecording().toImage(_canvas.width.round(), _canvas.height.round());
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final f = File('${(await drawingsDir()).path}/${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(png);
    _logged = true;
    await app.record(Answer(
      skill: skill.id,
      attempts: 1,
      correct: true,
      demonstrated: false,
      millis: DateTime.now().difference(_started).inMilliseconds,
      at: DateTime.now(),
    ));
    await app.logSession(SessionLog(theme: 'dessin', started: _started, ended: DateTime.now()));
    if (!mounted) return;
    setState(() => saved = f);
    app.voice.fanfare();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await app.voice.say(skill.phrases['bravo']!, id: skill.voiceId('bravo'));
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    return MusicScope(
      resume: () => app.voice.startMusic(u.id),
      child: Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            SessionTopBar(onVoiceOn: _listen, progress: saved == null ? 0 : 1, stars: saved == null ? 0 : 1, universe: u, onBack: () => Navigator.of(context).maybePop()),
            Narrator(universe: u, text: prompt, cheer: saved == null ? 0 : 1, onListen: _listen),
            Expanded(
              child: saved != null
                  ? DayEnd(
                      theme: 'dessin',
                      again: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DrawPage())),
                      child: _Saved(saved!, skill.phrases['bravo']!),
                    )
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: split(
                        sideSize: 150,
                        main: Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow, border: Border.all(color: u.onCard, width: 4)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LayoutBuilder(builder: (_, k) {
                              _canvas = Size(k.maxWidth, k.maxHeight);
                              return GestureDetector(
                                onPanStart: (d) => setState(() => strokes.add(Stroke(color, width)..points.add(d.localPosition))),
                                onPanUpdate: (d) => setState(() => strokes.last.points.add(d.localPosition)),
                                child: CustomPaint(size: Size.infinite, painter: _Painter(strokes)),
                              );
                            }),
                          ),
                        ),
                        side: (axis) => _Tools(
                          axis: axis,
                          color: color,
                          width: width,
                          onColor: (c, name) {
                            setState(() => color = c);
                            app.voice.say(name);
                          },
                          onWidth: (w) => setState(() => width = w),
                          onUndo: strokes.isEmpty ? null : () => setState(strokes.removeLast),
                          onDone: strokes.isEmpty ? null : _finish,
                        ),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    ),
    );
  }
}

class _Painter extends CustomPainter {
  _Painter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final p = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.width / 2, p..style = PaintingStyle.fill);
      } else {
        canvas.drawPath(Path()..addPolygon(s.points, false), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.axis,
    required this.color,
    required this.width,
    required this.onColor,
    required this.onWidth,
    required this.onUndo,
    required this.onDone,
  });
  final Axis axis;
  final Color color;
  final double width;
  final void Function(Color, String) onColor;
  final ValueChanged<double> onWidth;
  final VoidCallback? onUndo, onDone;

  @override
  Widget build(BuildContext context) {
    Widget swatch(Color c, String name) => Semantics(
          button: true,
          selected: c == color,
          label: name,
          child: GestureDetector(
            onTap: () => onColor(c, name),
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: c == color ? ink : Colors.white, width: c == color ? 5 : 3),
                boxShadow: cardShadow,
              ),
              // La couleur choisie porte aussi une ✔ (pas seulement un contour).
              child: c == color ? const Icon(Icons.check_rounded, color: Colors.white, size: 30) : null,
            ),
          ),
        );
    Widget sizeButton(double w, double dot, String label) => IconButton.filledTonal(
          tooltip: label,
          isSelected: width == w,
          iconSize: 40,
          onPressed: () => onWidth(w),
          icon: Container(width: dot, height: dot, decoration: const BoxDecoration(color: ink, shape: BoxShape.circle)),
        );
    final colors = [for (final (c, name) in paints) swatch(c, name)];
    final actions = [
      sizeButton(6, 10, 'Trait fin'),
      sizeButton(18, 22, 'Trait épais'),
      IconButton.filledTonal(tooltip: 'Annuler le dernier trait', iconSize: 40, onPressed: onUndo, icon: const Icon(Icons.undo_rounded)),
    ];
    final done = SizedBox(
      width: 120,
      height: 64,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: green, foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFFBFC7C1)),
        onPressed: onDone,
        child: const Icon(Icons.check_rounded, size: 44, semanticLabel: "J'ai fini"),
      ),
    );
    // Portrait : deux rangées sous la feuille. Paysage : une colonne à droite.
    if (axis == Axis.horizontal) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: colors),
        const SizedBox(height: 6),
        Row(children: [...actions, const Spacer(), done]),
      ]);
    }
    return SingleChildScrollView(
      child: Column(children: [
        Wrap(alignment: WrapAlignment.center, children: colors),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 4, children: actions),
        const SizedBox(height: 8),
        done,
      ]),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved(this.file, this.text);
  final File file;
  final String text;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Art('2b50', size: 48),
          const SizedBox(width: 8),
          Text('× 1', style: Theme.of(context).textTheme.headlineMedium),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD5DBD7), width: 2), borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(file, height: 220, fit: BoxFit.contain, semanticLabel: 'Ton dessin'),
          ),
        ),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink)),
      ]);
}

/// « Mes dessins » : les dessins finis, du plus récent au plus ancien, avec leur date (le programme invite à dater les
/// dessins pour voir ses progrès).
class DrawingsPage extends StatelessWidget {
  const DrawingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Material(
                  color: surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Retour',
                    iconSize: 32,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Mes dessins', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: u.onBackground)),
              ]),
            ),
            Expanded(
              child: FutureBuilder<List<File>>(
                future: drawingsDir().then((d) => d.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
                  ..sort((a, b) => b.path.compareTo(a.path))),
                builder: (_, snap) {
                  final files = snap.data ?? const <File>[];
                  if (snap.hasData && files.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Art('1f3a8', size: 56),
                          SizedBox(width: 12),
                          Text('Pas encore de dessin.', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
                        ]),
                      ),
                    );
                  }
                  return GridView.extent(
                    maxCrossAxisExtent: 260,
                    padding: const EdgeInsets.all(16),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      for (final f in files)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
                          child: Column(children: [
                            Expanded(child: Image.file(f, fit: BoxFit.contain, cacheWidth: 400)),
                            const SizedBox(height: 4),
                            Text(_date(f), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                          ]),
                        ),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static String _date(File f) {
    final ms = int.tryParse(f.uri.pathSegments.last.split('.').first) ?? 0;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.day}/${d.month}/${d.year}';
  }
}
