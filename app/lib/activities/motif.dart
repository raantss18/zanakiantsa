import 'dart:math';

import 'package:flutter/material.dart';

import '../core/motif.dart';
import '../l10n/l10n.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Motifs : une suite d'images de l'univers avec une case « ? » ; on choisit l'image qui la remplit (ADR 0019).
class MotifActivity extends StatefulWidget {
  const MotifActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<MotifActivity> createState() => _MotifActivityState();
}

class _MotifActivityState extends State<MotifActivity> {
  Attempt get a => widget.attempt;
  late final MotifPuzzle puzzle = motifPuzzle(
    a.skill.params['base'] as String,
    [...a.app.universe.objects, ...a.app.universe.stickers],
    Random(a.question.a),
  );
  final tried = <String>{};

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  void _tap(String art) {
    if (a.busy || a.finished || tried.contains(art)) return;
    final ok = art == puzzle.answer;
    if (!ok) setState(() => tried.add(art));
    a.submit(ok);
  }

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    final shown = a.demonstrate || a.solved;
    return LayoutBuilder(builder: (_, k) {
      final cell = ((k.maxWidth - 64) / 6.5).clamp(56.0, 96.0);
      // Les trois images proposées sur une seule rangée.
      final pick = ((k.maxWidth - 32) / 3 - 20).clamp(100.0, 160.0);
      return PlayScroll(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(children: [
          // La suite, sur une carte (jamais à même le décor), qui passe à la ligne si besoin.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, art) in puzzle.sequence.indexed)
                  Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: i == puzzle.hole ? const Color(0xFFF1F3F2) : null,
                      borderRadius: BorderRadius.circular(16),
                      border: i == puzzle.hole ? Border.all(color: shown ? gold : u.onCard, width: 4) : null,
                    ),
                    alignment: Alignment.center,
                    child: i != puzzle.hole
                        ? Art(art, size: cell * 0.8)
                        : shown
                            ? Art(art, size: cell * 0.8)
                            : Text('?', style: TextStyle(fontSize: cell * 0.6, fontWeight: FontWeight.w700, color: u.onCard)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: [
            for (final (i, art) in puzzle.choices.indexed)
              PicButton(
                // Les images n'ont pas de nom dans l'app : au moins une étiquette par réponse pour le lecteur d'écran.
                label: tf('Réponse {n}', {'n': i + 1}),
                size: pick,
                tried: tried.contains(art),
                highlight: shown && art == puzzle.answer,
                onPressed: a.busy || a.finished ? null : () => _tap(art),
                child: Art(art, size: pick * 0.66),
              ),
          ]),
        ]),
      );
    });
  }
}
