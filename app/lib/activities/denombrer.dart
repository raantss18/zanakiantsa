import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';
import 'shapes.dart';

/// Dénombrer : toucher chaque objet de l'univers (il reçoit son numéro, la voix le dit), puis choisir le nombre.
class CountActivity extends StatefulWidget {
  const CountActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<CountActivity> createState() => _CountActivityState();
}

class _CountActivityState extends State<CountActivity> {
  Attempt get a => widget.attempt;
  late final int n = a.question.n;
  late final CountGame game;
  late final List<int> choices = _choices();
  int counted = 0;
  bool _demoStarted = false;
  int _lastMisses = 0;

  List<int> _choices() {
    final lo = max(1, n - 1);
    return ([lo, lo + 1, lo + 2]..shuffle(Random()));
  }

  @override
  void initState() {
    super.initState();
    final u = a.app.universe;
    game = CountGame(n, a.app.objectArt(a.skill), u.onCard, _counted);
    a.addListener(_onAttempt);
    a.show('consigne');
  }

  @override
  void dispose() {
    a.removeListener(_onAttempt);
    super.dispose();
  }

  void _onAttempt() {
    if (a.demonstrate && !_demoStarted) {
      _demoStarted = true;
      game.demonstrate();
    } else if (a.misses != _lastMisses && !a.finished) {
      // Après une erreur, on recompte depuis le début.
      _lastMisses = a.misses;
      game.reset();
      setState(() => counted = 0);
    } else {
      setState(() {});
    }
  }

  void _counted(int k) {
    if (!mounted) return;
    setState(() => counted = k);
    if (a.demonstrate) return;
    a.speech.say('$k');
    if (k == n) {
      Future.delayed(const Duration(milliseconds: 700), () {
        // Pas si l'enfant a déjà répondu entre-temps : la question effaçait l'aide et coupait sa voix.
        if (mounted && !a.busy && !a.finished) a.show('question');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showChoices = counted == n || a.demonstrate;
    return split(
      main: GameWidget(game: game),
      side: (axis) => showChoices
          ? Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final v in choices)
                NumberButton(
                  value: v,
                  highlight: a.demonstrate && v == n,
                  onPressed: a.busy || a.finished ? null : () => a.submit(v == n),
                ),
            ])
          : const SizedBox(),
    );
  }
}

class CountGame extends FlameGame {
  CountGame(this.n, this.art, this.badge, this.onCount);
  final int n;
  final String art;

  /// Couleur de la pastille du numéro (lisible sur carte, docs/design.md).
  final Color badge;
  final void Function(int) onCount;
  int counted = 0;
  final _rand = Random();
  ui.Image? _image;

  @override
  Color backgroundColor() => const Color(0x00000000);

  /// Positions en fraction de la zone : elles survivent à une rotation de l'écran.
  late final Scatter _scatter = Scatter(n, _rand);
  List<Thing> _things = [];

  void _layout() {
    final numbers = [for (final t in _things) t.number];
    removeAll(_things);
    // Rayon : jamais plus que la case (pas de chevauchement), plafonné pour garder de l'air.
    const margin = 8.0;
    final area = Size(size.x - 2 * margin, size.y - 2 * margin);
    final r = min(_scatter.radius(area), 64.0);
    _things = [
      for (final (i, p) in _scatter.spots.indexed)
        Thing(_image!, badge, r, i)
          ..number = i < numbers.length ? numbers[i] : null
          ..position = Vector2(margin + p.dx * area.width, margin + p.dy * area.height),
    ];
    addAll(_things);
  }

  @override
  Future<void> onLoad() async {
    _image = await artImage(art, 160);
    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded && _image != null) _layout();
  }

  bool demonstrating = false;

  void tap(Thing t) {
    if (demonstrating || t.number != null || counted >= n) return;
    t.number = ++counted;
    onCount(counted);
  }

  void reset() {
    counted = 0;
    for (final t in _things) {
      t.number = null;
    }
  }

  /// Montre la bonne façon : compte chaque objet, un par un.
  Future<void> demonstrate() async {
    reset();
    demonstrating = true;
    for (final t in _things) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (t.number != null) continue;
      t.number = ++counted;
      onCount(counted);
    }
  }
}

class Thing extends PositionComponent with TapCallbacks {
  Thing(this.image, this.badge, this.r, this.index) : super(size: Vector2.all(r * 2), anchor: Anchor.center);
  final ui.Image image;
  final Color badge;
  final double r;
  final int index;
  int? number;
  double t = 0;
  double? _baseY;

  @override
  void update(double dt) {
    t += dt;
    _baseY ??= position.y;
    position.y = _baseY! + sin(t * 2 + index) * 4;
  }

  @override
  void render(Canvas canvas) {
    final box = Rect.fromLTWH(0, 0, r * 2, r * 2);
    if (number != null) {
      // Objet compté : halo + pastille numérotée (forme et nombre, pas seulement la couleur).
      canvas.drawCircle(box.center, r, Paint()..color = const Color(0xCCFFFFFF));
      canvas.drawCircle(box.center, r, Paint()
        ..color = badge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5);
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      box.deflate(r * 0.18),
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (number != null) {
      final c = Offset(r * 1.65, r * 0.35);
      canvas.drawCircle(c, r * 0.42, Paint()..color = badge);
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(fontFamily: 'Andika', fontSize: r * 0.55, color: Colors.white, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  void onTapDown(TapDownEvent event) => (findGame() as CountGame).tap(this);
}
