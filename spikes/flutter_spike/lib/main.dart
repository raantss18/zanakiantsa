// Spike Flutter + Flame : « Compte les pommes » (voir ../README.md).
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Positions normalisées communes aux trois spikes, et suite des N.
const positions = [
  [0.20, 0.20], [0.50, 0.15], [0.80, 0.22], [0.30, 0.42],
  [0.70, 0.40], [0.15, 0.60], [0.55, 0.62],
];
const rounds = [5, 3, 7, 4, 6];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: SpikePage()));
}

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});
  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  final tts = FlutterTts();
  final player = AudioPlayer();
  late final ApplesGame game = ApplesGame(onCount: _onCount);
  int round = 0;
  bool asking = false;

  int get n => rounds[round % rounds.length];

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => print('SPIKE first_frame'));
    _start();
  }

  Future<void> _start() async {
    await tts.setLanguage('fr-FR');
    game.setRound(n);
    await tts.speak('Touche chaque pomme pour la compter.');
  }

  void _onCount(int count) {
    tts.speak('$count');
    if (count == n) {
      setState(() => asking = true);
      Future.delayed(const Duration(milliseconds: 700), () => tts.speak('Combien de pommes ?'));
    }
  }

  Future<void> _answer(int value) async {
    if (value != n) {
      await tts.speak('Compte encore.');
      return;
    }
    await player.play(AssetSource('ding.wav'));
    await tts.speak('Oui, il y a $n pommes. Bravo !');
    setState(() {
      asking = false;
      round++;
    });
    game.setRound(n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      body: SafeArea(
        child: Column(children: [
          Expanded(child: GameWidget(game: game)),
          SizedBox(
            height: 140,
            child: asking
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [for (final v in [n - 1, n, n + 1]) _NumberButton(v, () => _answer(v))],
                  )
                : null,
          ),
        ]),
      ),
    );
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton(this.value, this.onTap);
  final int value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        height: 96,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1D7A33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: onTap,
          child: Text('$value', style: const TextStyle(fontSize: 40, color: Colors.white)),
        ),
      );
}

class ApplesGame extends FlameGame {
  ApplesGame({required this.onCount});
  final void Function(int) onCount;
  int counted = 0;
  double _fpsWindow = 0;
  int _frames = 0;

  @override
  Color backgroundColor() => const Color(0xFFF7F8F6);

  void setRound(int n) {
    counted = 0;
    removeAll(children.whereType<Apple>());
    for (var i = 0; i < n; i++) {
      add(Apple(i, positions[i], _tap));
    }
  }

  void _tap(Apple a) {
    if (a.number != null) return;
    a.number = ++counted;
    onCount(counted);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _frames++;
    _fpsWindow += dt;
    if (_fpsWindow >= 5) {
      print('SPIKE fps ${(_frames / _fpsWindow).toStringAsFixed(1)}');
      _frames = 0;
      _fpsWindow = 0;
    }
  }
}

class Apple extends PositionComponent with TapCallbacks, HasGameReference<ApplesGame> {
  Apple(this.index, this.rel, this.onTapped) : super(size: Vector2.all(radius * 2), anchor: Anchor.center);
  static const radius = 40.0;
  final int index;
  final List<double> rel;
  final void Function(Apple) onTapped;
  int? number;
  double t = 0;

  static final _red = Paint()..color = const Color(0xFFD6362B);
  static final _leaf = Paint()..color = const Color(0xFF1D7A33);
  static final _ring = Paint()
    ..color = const Color(0xFF1D7A33)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  @override
  void update(double dt) {
    t += dt;
    final s = game.size;
    position = Vector2(rel[0] * s.x, rel[1] * s.y / 0.75 + sin(t * 2 + index) * 8);
  }

  @override
  void render(Canvas c) {
    const r = radius;
    c.drawCircle(const Offset(r, r), r * 0.85, _red);
    c.drawOval(Rect.fromLTWH(r, 0, r * 0.6, r * 0.35), _leaf);
    if (number != null) {
      c.drawCircle(const Offset(r, r), r, _ring);
      final tp = TextPainter(
        text: TextSpan(text: '$number', style: const TextStyle(fontSize: 34, color: Colors.white, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(r - tp.width / 2, r - tp.height / 2));
    }
  }

  @override
  void onTapDown(TapDownEvent event) => onTapped(this);
}
