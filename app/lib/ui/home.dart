import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../parent/gate.dart';
import 'album.dart';
import 'session.dart';
import 'theme.dart';
import 'universe.dart';

/// Accueil enfant : le fil rouge de l'univers (un chemin qui s'allume, jamais remis à zéro), la mascotte qui
/// présente l'univers (écrit et dit), un gros bouton « Jouer ». Sans genre saisi, on demande un adulte (ADR 0014).
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  final Map<String, ui.Image> _images = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  void _welcome() {
    final s = AppScope.of(context);
    if (!s.ready) {
      s.voice.say(s.common.text('demande_adulte'), id: 'commun.demande_adulte');
    } else {
      final e = s.universeWords.episode(s.sessionsDone);
      e == null
          ? s.voice.say(s.universeWords.intro, id: 'univers.${s.universe.id}.intro')
          : s.voice.say(s.universeWords.story[e], id: 'univers.${s.universe.id}.histoire.$e');
    }
  }

  Future<ui.Image> _image(String code) async => _images[code] ??= await artImage(code, 96);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            _Header(onListen: _welcome),
            if (!s.ready)
              Expanded(child: _AskAdult(text: s.common.text('demande_adulte')))
            else ...[
              _Intro(words: s.universeWords, sessions: s.sessionsDone, universe: u),
              Expanded(
                child: split(
                  sideSize: 210,
                  main: FutureBuilder<List<ui.Image>>(
                    future: Future.wait([_image(u.objects.first), _image(u.mascot)]),
                    builder: (_, snap) => AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, _) => CustomPaint(
                        size: Size.infinite,
                        painter: PathPainter(
                          done: s.sessionsDone,
                          pulse: _pulse.value,
                          stone: snap.data?[0],
                          mascot: snap.data?[1],
                          road: u.night ? const Color(0x66FFFFFF) : u.onCard.withValues(alpha: 0.22),
                          current: u.night ? u.primary : u.onCard,
                        ),
                      ),
                    ),
                  ),
                  side: (axis) => Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _RoundButton(
                      size: 88,
                      color: surface,
                      tooltip: 'Mon album',
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlbumPage())),
                      child: const Icon(Icons.collections_bookmark_rounded, size: 46, color: ink),
                    ),
                    _RoundButton(
                      size: 150,
                      color: u.primary,
                      tooltip: 'Jouer',
                      onPressed: () async {
                        await s.voice.stop();
                        if (!context.mounted) return;
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionPage()));
                        await s.refresh();
                      },
                      child: Icon(Icons.play_arrow_rounded, size: 110, color: u.onPrimary),
                    ),
                    _RoundButton(
                      size: 88,
                      color: surface,
                      tooltip: 'Changer de monde',
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UniversePicker())),
                      child: Art(u.mascot, size: 52),
                    ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onListen});
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).universe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(children: [
        Text("Zanak'i Antsa", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: u.onBackground)),
        const Spacer(),
        _RoundButton(size: 56, color: surface, tooltip: 'Réécouter', onPressed: onListen, child: Icon(Icons.volume_up_rounded, color: u.onCard, size: 32)),
        const SizedBox(width: 8),
        _RoundButton(
          size: 48,
          color: surface,
          tooltip: 'Espace parent',
          onPressed: () => openParentSpace(context),
          child: const Icon(Icons.lock_outline, color: Color(0xFF5F6B63), size: 24),
        ),
      ]),
    );
  }
}

/// La mascotte se présente, puis raconte l'épisode gagné (ADR 0017) : texte écrit sur une carte (jamais directement
/// sur le décor).
class _Intro extends StatelessWidget {
  const _Intro({required this.words, required this.sessions, required this.universe});
  final UniverseWords words;
  final int sessions;
  final Universe universe;

  @override
  Widget build(BuildContext context) {
    final e = words.episode(sessions);
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
          child: Row(children: [
            Art(universe.mascot, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (e != null) EpisodeLabel(index: e, count: words.story.length),
                Text(e == null ? words.intro : words.story[e], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink, height: 1.2)),
              ]),
            ),
          ]),
        ),
      );
  }
}

class _AskAdult extends StatelessWidget {
  const _AskAdult({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.family_restroom_rounded, size: 96, color: ink),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 22)),
              onPressed: () => openParentSpace(context),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Espace parent'),
            ),
          ]),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.size, required this.color, required this.tooltip, required this.onPressed, required this.child});
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(width: size, height: size, child: Center(child: child)),
            ),
          ),
        ),
      );
}

/// Choix de l'univers : seulement ceux du genre de l'enfant (ADR 0014), nom écrit et dit.
class UniversePicker extends StatelessWidget {
  const UniversePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 8),
              _RoundButton(
                size: 56,
                color: surface,
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_rounded, color: ink, size: 32),
              ),
              const SizedBox(width: 12),
              Text(s.common.text('choisis_univers'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: u.onBackground)),
            ]),
            Expanded(
              child: LayoutBuilder(
                builder: (_, k) {
                  final wide = k.maxWidth > k.maxHeight;
                  final cards = [
                    for (final c in s.choices)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _UniverseCard(
                            universe: c,
                            name: s.words[c.id]!.name,
                            selected: c.id == u.id,
                            onTap: () async {
                              await s.setUniverse(c.id);
                              s.voice.say(s.words[c.id]!.name);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                  ];
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: wide ? Row(children: cards) : Column(children: cards),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _UniverseCard extends StatelessWidget {
  const _UniverseCard({required this.universe, required this.name, required this.selected, required this.onTap});
  final Universe universe;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: name,
        excludeSemantics: true,
        child: Material(
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [universe.bg1, universe.bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: selected ? Border.all(color: gold, width: 6) : null,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Stack(children: [
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Art(universe.mascot, size: 72),
                    const SizedBox(width: 12),
                    Art(universe.objects.first, size: 48),
                    Art(universe.objects.last, size: 48),
                  ]),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)),
                    child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink)),
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: CircleAvatar(radius: 18, backgroundColor: gold, child: Icon(Icons.check_rounded, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ),
      );
}

/// Le fil rouge : un chemin sinueux de pierres. Les pierres des séances finies portent l'objet de l'univers ; la
/// mascotte se tient sur la pierre courante. Il ne recule jamais (`docs/vision.md`).
class PathPainter extends CustomPainter {
  PathPainter({required this.done, required this.pulse, this.stone, this.mascot, required this.road, required this.current});
  final int done;
  final double pulse;
  final ui.Image? stone, mascot;
  final Color road, current;

  static const visible = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final first = max(0, done - 2);
    final stones = <Offset>[];
    for (var i = 0; i < visible; i++) {
      final t = i / (visible - 1);
      stones.add(Offset(size.width * (0.5 + 0.3 * sin((first + i) * 0.9)), size.height * (0.9 - 0.8 * t)));
    }
    final roadPaint = Paint()
      ..color = road
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(stones.first.dx, stones.first.dy);
    for (var i = 1; i < stones.length; i++) {
      final a = stones[i - 1], b = stones[i];
      path.quadraticBezierTo(a.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
    }
    canvas.drawPath(path, roadPaint);

    for (var i = 0; i < stones.length; i++) {
      final index = first + i;
      final c = stones[i];
      if (index < done) {
        canvas.drawCircle(c, 26, Paint()..color = Colors.white);
        canvas.drawCircle(c, 26, Paint()
          ..color = current
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
        _img(canvas, stone, c, 36);
      } else if (index == done) {
        canvas.drawCircle(c, 32 + 6 * pulse, Paint()..color = current.withValues(alpha: 0.25));
        canvas.drawCircle(c, 28, Paint()..color = current);
        _img(canvas, mascot, c - const Offset(0, 34), 60);
      } else {
        // Pierre à venir : blanche avec un contour, visible sur fond clair comme sombre.
        canvas.drawCircle(c, 20, Paint()..color = Colors.white);
        canvas.drawCircle(c, 20, Paint()
          ..color = current.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
      }
    }
  }

  void _img(Canvas canvas, ui.Image? img, Offset c, double s) {
    if (img == null) return;
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: c, width: s, height: s), Paint()..filterQuality = FilterQuality.medium);
  }

  @override
  bool shouldRepaint(PathPainter old) => old.done != done || old.pulse != pulse || old.stone != stone || old.mascot != mascot;
}
