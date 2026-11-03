import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/chess.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Échecs : une pièce seule sur l'échiquier, des étoiles à attraper en respectant sa marche (FIDE, art. 3 ; ADR 0019).
/// Un coup permis déplace la pièce ; un coup interdit compte comme un essai manqué et fait apparaître des points sur
/// les cases permises (l'indice). Toutes les étoiles attrapées = réussi.
class ChessActivity extends StatefulWidget {
  const ChessActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ChessActivity> createState() => _ChessActivityState();
}

class _ChessActivityState extends State<ChessActivity> {
  Attempt get a => widget.attempt;
  late final String piece = a.skill.params['piece'] as String;
  late final StarPuzzle puzzle = starPuzzle(piece, a.question.n, Random(a.question.a));
  late Square at = puzzle.start;
  late final Set<Square> stars = {...puzzle.stars};
  bool hints = false;
  Square? wrong;

  static const light = Color(0xFFF0D9B5), dark = Color(0xFFB58863);

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

  void _changed() => setState(() => hints = hints || a.helpText != null || a.demonstrate);

  void _tap(Square s) {
    if (a.busy || a.finished || s == at) return;
    if (moves(piece, at).contains(s)) {
      setState(() {
        at = s;
        wrong = null;
        stars.remove(s);
      });
      if (stars.isEmpty) {
        a.submit(true);
      } else if (puzzle.stars.contains(s)) {
        a.app.voice.success(a.app.universe.id);
      }
    } else {
      setState(() => wrong = s);
      a.submit(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    final legal = hints ? moves(piece, at) : const <Square>{};
    return LayoutBuilder(builder: (_, k) {
      final side = min(k.maxWidth, k.maxHeight) - 24;
      final cell = side / 8;
      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(boxShadow: cardShadow, border: Border.all(color: u.onCard, width: 4)),
          child: Column(children: [
            for (var row = 7; row >= 0; row--)
              Row(children: [
                for (var col = 0; col < 8; col++)
                  _square((col, row), cell - 1, legal),
              ]),
          ]),
        ),
      );
    });
  }

  Widget _square(Square s, double cell, Set<Square> legal) {
    final isDark = (s.$1 + s.$2).isEven;
    return GestureDetector(
      onTap: () => _tap(s),
      child: Container(
        width: cell,
        height: cell,
        color: isDark ? dark : light,
        child: Stack(alignment: Alignment.center, children: [
          if (s == wrong) Icon(Icons.close_rounded, size: cell * 0.7, color: const Color(0xAA5F1B1B)),
          if (stars.contains(s))
            Art('2b50', size: cell * 0.7, label: 'étoile')
          else if (legal.contains(s) && s != at)
            Container(width: cell * 0.28, height: cell * 0.28, decoration: const BoxDecoration(color: Color(0x991B211D), shape: BoxShape.circle)),
          if (s == at)
            AnimatedScale(
              scale: 1,
              duration: const Duration(milliseconds: 200),
              // Les SVG d'origine n'ont pas de viewBox (45 × 45) : FittedBox les met à l'échelle de la case.
              child: SizedBox(
                width: cell * 0.9,
                height: cell * 0.9,
                child: FittedBox(child: SvgPicture.asset('assets/echecs/$piece.svg', semanticsLabel: a.skill.title)),
              ),
            ),
        ]),
      ),
    );
  }
}
