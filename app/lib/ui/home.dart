import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../parent/gate.dart';
import 'session.dart';
import 'theme.dart';

/// Accueil enfant : le fil rouge (un chemin de pierres qui s'allument, jamais remis à zéro), un gros bouton
/// « Jouer », un haut-parleur pour réécouter. Aucun texte nécessaire pour un enfant qui ne lit pas.
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
  }

  void _welcome() {
    final s = AppScope.of(context);
    s.voice.say(s.common.text('bienvenue'), id: 'commun.bienvenue');
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(children: [
              const Icon(Icons.auto_awesome, color: gold, size: 32, semanticLabel: "Zanak'i Antsa"),
              const SizedBox(width: 8),
              Text("Zanak'i Antsa", style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(
                tooltip: 'Réécouter',
                iconSize: 40,
                onPressed: _welcome,
                icon: const Icon(Icons.volume_up_rounded, color: green),
              ),
              IconButton(
                tooltip: 'Espace parent',
                iconSize: 28,
                onPressed: () => openParentSpace(context),
                icon: const Icon(Icons.lock_outline, color: Colors.black38),
              ),
            ]),
          ),
          Expanded(
            child: split(
              sideSize: 220,
              main: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: PathPainter(done: s.sessionsDone, pulse: _pulse.value),
                ),
              ),
              side: (_) => Center(child: _play(s)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _play(AppState s) => SizedBox(
        width: 160,
        height: 160,
        child: FilledButton(
          style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: green),
          onPressed: () async {
            await s.voice.stop();
            if (!mounted) return;
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SessionPage()));
            await s.refresh();
          },
          child: const Icon(Icons.play_arrow_rounded, size: 110, color: Colors.white, semanticLabel: 'Jouer'),
        ),
      );
}

/// Le fil rouge : un chemin sinueux de pierres. Les pierres des séances finies portent une étoile ; la suivante pulse.
/// Il ne recule jamais (`docs/vision.md`).
class PathPainter extends CustomPainter {
  PathPainter({required this.done, required this.pulse});
  final int done;
  final double pulse;

  static const visible = 9;

  @override
  void paint(Canvas canvas, Size size) {
    // Fenêtre de pierres : on garde la pierre courante vers le bas de l'écran.
    final first = max(0, done - 2);
    final stones = <Offset>[];
    for (var i = 0; i < visible; i++) {
      final t = i / (visible - 1);
      final y = size.height * (0.92 - 0.84 * t);
      final x = size.width * (0.5 + 0.28 * sin((first + i) * 0.9));
      stones.add(Offset(x, y));
    }
    final road = Paint()
      ..color = const Color(0xFFE9DFC9)
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(stones.first.dx, stones.first.dy);
    for (var i = 1; i < stones.length; i++) {
      final a = stones[i - 1], b = stones[i];
      path.quadraticBezierTo(a.dx, (a.dy + b.dy) / 2, b.dx, b.dy);
    }
    canvas.drawPath(path, road);

    for (var i = 0; i < stones.length; i++) {
      final index = first + i;
      final c = stones[i];
      if (index < done) {
        canvas.drawCircle(c, 26, Paint()..color = green);
        _star(canvas, c, 14, Paint()..color = gold);
      } else if (index == done) {
        canvas.drawCircle(c, 30 + 6 * pulse, Paint()..color = red.withValues(alpha: 0.25));
        canvas.drawCircle(c, 26, Paint()..color = red);
        canvas.drawCircle(c, 10, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(c, 22, Paint()..color = const Color(0xFFCFC6B3));
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final rr = k.isEven ? r : r * 0.45;
      final a = -pi / 2 + k * pi / 5;
      final pt = c + Offset(cos(a) * rr, sin(a) * rr);
      k == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), p);
  }

  @override
  bool shouldRepaint(PathPainter old) => old.done != done || old.pulse != pulse;
}
