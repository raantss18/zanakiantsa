import 'dart:math';

import 'package:flutter/material.dart';

import 'universe.dart';

/// Célébration d'une bonne réponse : une pluie de 12 objets de l'univers pendant 1,2 s, par-dessus l'activité et
/// transparente aux touchers. Rien ne s'affiche si l'appareil demande moins d'animations.
class Celebration extends StatefulWidget {
  const Celebration({super.key, required this.trigger, required this.arts});

  /// Change à chaque bonne réponse.
  final int trigger;
  final List<String> arts;

  @override
  State<Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<Celebration> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  final _rand = Random();
  List<(double, double, double, String)> _drops = [];

  @override
  void didUpdateWidget(Celebration old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0 && !MediaQuery.of(context).disableAnimations) {
      _drops = [
        for (var i = 0; i < 12; i++)
          (_rand.nextDouble(), _rand.nextDouble() * 0.35, (_rand.nextDouble() - 0.5) * 2, widget.arts[i % widget.arts.length]),
      ];
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            if (!_c.isAnimating) return const SizedBox.expand();
            return LayoutBuilder(
              builder: (_, k) => Stack(children: [
                for (final (x, delay, spin, art) in _drops)
                  () {
                    final t = ((_c.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                    return Positioned(
                      left: x * (k.maxWidth - 48),
                      top: -48 + t * (k.maxHeight + 48),
                      child: Opacity(
                        opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
                        child: Transform.rotate(angle: spin * t * pi, child: Art(art, size: 44)),
                      ),
                    );
                  }(),
              ]),
            );
          },
        ),
      );
}
