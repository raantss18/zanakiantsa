import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../ui/session.dart';
import '../ui/theme.dart';
import 'shapes.dart';

/// Dénombrer : toucher chaque objet (il reçoit son numéro, la voix le dit), puis choisir le nombre.
class CountActivity extends StatefulWidget {
  const CountActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<CountActivity> createState() => _CountActivityState();
}

class _CountActivityState extends State<CountActivity> {
  Attempt get a => widget.attempt;
  late final int n = a.question.n;
  late final CountGame game = CountGame(n, a.skill.params['objet'] as String, _counted);
  late final List<int> choices = _choices();
  int counted = 0;

  List<int> _choices() {
    final lo = max(1, n - 1);
    return ([lo, lo + 1, lo + 2]..shuffle(Random()));
  }

  @override
  void initState() {
    super.initState();
    a.addListener(_onAttempt);
    a.say('consigne');
  }

  @override
  void dispose() {
    a.removeListener(_onAttempt);
    super.dispose();
  }

  bool _demoStarted = false;
  int _lastMisses = 0;

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
    setState(() => counted = k);
    if (!a.demonstrate) a.app.voice.say('$k');
    if (k == n && !a.demonstrate) Future.delayed(const Duration(milliseconds: 700), () => a.say('question'));
  }

  @override
  Widget build(BuildContext context) {
    final showChoices = counted == n || a.demonstrate;
    return split(
      main: GameWidget(game: game),
      side: (axis) => showChoices
            ? Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                for (final v in choices)
                  SizedBox(
                    width: 104,
                    height: 104,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: a.demonstrate && v == n ? gold : green,
                        // Pendant la démonstration, la bonne réponse reste visible en couleur (bouton inactif).
                        disabledBackgroundColor: a.demonstrate && v == n ? gold : const Color(0xFFBFC7C1),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: a.busy || a.finished ? null : () => a.submit(v == n),
                      child: Text('$v', style: const TextStyle(fontSize: 48, color: Colors.white)),
                    ),
                  ),
              ])
            : const SizedBox(),
    );
  }
}

class CountGame extends FlameGame {
  CountGame(this.n, this.kind, this.onCount);
  final int n;
  final String kind;
  final void Function(int) onCount;
  int counted = 0;
  final _rand = Random();

  @override
  Color backgroundColor() => bg;

  /// Positions en fraction de la zone libre : elles survivent à une rotation de l'écran.
  late final List<Offset> _spots = [
    for (final p in scatter(n, const Size(1000, 1000), 1000 / 9, _rand)) Offset(p.dx / 1000, p.dy / 1000),
  ];
  List<Thing> _things = [];

  void _layout() {
    final numbers = [for (final t in _things) t.number];
    removeAll(_things);
    final r = min(size.x, max(size.y - helpBand, size.y * 0.5)) / 8;
    final area = Size(size.x - 2 * r, max(size.y - helpBand, r * 6) - 2 * r);
    _things = [
      for (final (i, p) in _spots.indexed)
        Thing(kind, r, i)
          ..number = i < numbers.length ? numbers[i] : null
          ..position = Vector2(r + p.dx * area.width, size.y - area.height - r + p.dy * area.height),
    ];
    addAll(_things);
  }

  @override
  Future<void> onLoad() async => _layout();

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  void tap(Thing t) {
    if (t.number != null || counted >= n) return;
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
    for (final t in _things) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
      t.number = ++counted;
      onCount(counted);
    }
  }
}

class Thing extends PositionComponent with TapCallbacks, HasGameReference<CountGame> {
  Thing(this.kind, this.r, this.index) : super(size: Vector2.all(r * 2), anchor: Anchor.center);
  final String kind;
  final double r;
  final int index;
  int? number;
  double t = 0;
  late final double _baseY = position.y;

  static final _ring = Paint()
    ..color = green
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  @override
  void update(double dt) {
    t += dt;
    position.y = _baseY + sin(t * 2 + index) * 4;
  }

  @override
  void render(Canvas canvas) {
    final o = Offset(r, r);
    drawObject(kind, canvas, o, r);
    if (number != null) {
      canvas.drawCircle(o, r, _ring);
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(fontSize: r * 0.8, color: Colors.white, fontWeight: FontWeight.w800, shadows: const [
            Shadow(blurRadius: 3, color: Colors.black54),
          ]),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  void onTapDown(TapDownEvent event) => game.tap(this);
}
