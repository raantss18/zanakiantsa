import 'dart:math';

import 'package:flutter/material.dart';

import 'universe.dart';

/// Scène de réussite propre au monde (docs/design.md) : le héros bouge selon le monde (la voiture passe la ligne, la
/// fusée décolle, la fée vole…) et des éclats jaillissent du centre. 1,4 s, par-dessus l'activité, transparente aux
/// touchers, coupée si l'appareil demande moins d'animations.
class Celebration extends StatefulWidget {
  const Celebration({super.key, required this.trigger, required this.scene});

  /// Change à chaque bonne réponse.
  final int trigger;
  final Scene scene;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  final _rand = Random();
  List<(double, double, String)> _burst = [];

  @override
  void didUpdateWidget(Celebration old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0 && !MediaQuery.of(context).disableAnimations) {
      _burst = [
        for (var i = 0; i < 10; i++)
          (i * 2 * pi / 10 + _rand.nextDouble() * 0.4, 0.7 + _rand.nextDouble() * 0.3, widget.scene.burst[i % widget.scene.burst.length]),
      ];
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Position (centre) et rotation du héros à l'instant [t] (0–1) dans une zone [w]×[h].
  (Offset, double, double) _hero(double t, double w, double h) {
    final e = Curves.easeInOut.transform(t);
    switch (widget.scene.motion) {
      case Motion.cross:
        return (Offset(-60 + e * (w + 120), h * 0.55), 0, 1);
      case Motion.rise:
        return (Offset(w / 2 + sin(t * 18) * 3, h + 60 - e * (h + 120)), 0, 1);
      case Motion.spin:
        return (Offset(w / 2, h / 2), e * 2 * pi, 0.4 + 0.8 * sin(t * pi));
      case Motion.fly:
        return (Offset(-60 + e * (w + 120), h * 0.5 + sin(t * 3 * pi) * h * 0.18), sin(t * 6 * pi) * 0.15, 1);
      case Motion.drop:
        final b = Curves.bounceOut.transform((t * 1.6).clamp(0.0, 1.0));
        return (Offset(w / 2, -60 + b * (h / 2 + 60)), 0, t < 0.8 ? 1.2 : 1.2 - (t - 0.8) * 1.5);
    }
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            if (!_c.isAnimating) return const SizedBox.expand();
            final t = _c.value;
            return LayoutBuilder(builder: (_, k) {
              final w = k.maxWidth, h = k.maxHeight;
              final (pos, angle, scale) = _hero(t, w, h);
              final fade = t < 0.85 ? 1.0 : (1 - t) / 0.15;
              final burstT = Curves.easeOut.transform(t);
              final reach = min(w, h) * 0.45;
              return Stack(children: [
                for (final (dir, speed, art) in _burst)
                  Positioned(
                    left: w / 2 + cos(dir) * reach * speed * burstT - 22,
                    top: h / 2 + sin(dir) * reach * speed * burstT - 22,
                    child: Opacity(opacity: fade * (t < 0.1 ? t / 0.1 : 1), child: Art(art, size: 44)),
                  ),
                Positioned(
                  left: pos.dx - 60,
                  top: pos.dy - 60,
                  child: Opacity(
                    opacity: fade,
                    child: Transform.rotate(angle: angle, child: Transform.scale(scale: scale, child: Art(widget.scene.hero, size: 120))),
                  ),
                ),
              ]);
            });
          },
        ),
      );
}
