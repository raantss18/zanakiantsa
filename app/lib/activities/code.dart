import 'dart:math';

import 'package:flutter/material.dart';

import '../core/robot.dart';
import '../l10n/l10n.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Programmer : on aligne des blocs (flèches, ou avancer / pivoter), puis ▶ fait rouler la mascotte case par case.
/// Arrivée sur l'objet = réussi ; choc ou arrêt ailleurs = essai manqué, la mascotte revient et le programme reste pour
/// être corrigé (ADR 0023). La démonstration écrit et joue un programme juste.
class CodeActivity extends StatefulWidget {
  const CodeActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<CodeActivity> createState() => _CodeActivityState();
}

class _CodeActivityState extends State<CodeActivity> {
  Attempt get a => widget.attempt;
  late final p = a.skill.params;
  late final bool arrowsMode = p['mode'] == 'fleches';
  late final (Maze, List<Op>) puzzle = mazePuzzle(
    Random(a.question.a),
    arrowsMode: arrowsMode,
    size: (p['grille'] as num).toInt(),
    min: (p['min'] as num).toInt(),
    max: (p['max'] as num).toInt(),
    rocks: (p['rochers'] as num?)?.toInt() ?? 0,
    maxTurns: (p['virages_max'] as num?)?.toInt() ?? 9,
  );
  Maze get maze => puzzle.$1;
  late final int slots = (p['max'] as num).toInt() + 1;
  final program = <Op>[];
  late RobotState robot = maze.start;
  int? running;
  bool bumped = false;

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

  void _changed() {
    if (a.demonstrate && running == null) {
      program
        ..clear()
        ..addAll(puzzle.$2);
      _run(demo: true);
    }
    setState(() {});
  }

  bool get locked => a.busy || a.finished || running != null;

  Future<void> _run({bool demo = false}) async {
    final states = maze.run(program);
    setState(() {
      running = 0;
      bumped = false;
    });
    for (var i = 1; i < states.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() {
        robot = states[i];
        running = i;
      });
    }
    final ok = maze.solves(program);
    if (!ok) {
      setState(() => bumped = states.length < program.length + 1);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted) return;
    // Ce que montre l'essai (ADR 0029) : un choc, ou un arrêt ailleurs que sur l'objet.
    final why = ok
        ? null
        : states.length < program.length + 1
            ? tf("Le robot s'est cogné au bloc {n} : regarde où il était juste avant.", {'n': states.length})
            : t("Le robot s'arrête ailleurs que sur l'objet : il manque un bloc, ou il y en a un de trop.");
    setState(() {
      running = null;
      if (!ok) robot = maze.start;
    });
    if (!demo) a.submit(ok, why: why);
  }

  IconData _icon(Op op) => switch (op) {
        Op.up => Icons.arrow_upward_rounded,
        Op.down => Icons.arrow_downward_rounded,
        Op.left => Icons.arrow_back_rounded,
        Op.right => Icons.arrow_forward_rounded,
        Op.forward => Icons.straight_rounded,
        Op.turnLeft => Icons.turn_left_rounded,
        Op.turnRight => Icons.turn_right_rounded,
      };

  String _name(Op op) => switch (op) {
        Op.up => t('en haut'),
        Op.down => t('en bas'),
        Op.left => t('à gauche'),
        Op.right => t('à droite'),
        Op.forward => t('avancer'),
        Op.turnLeft => t('pivoter à gauche'),
        Op.turnRight => t('pivoter à droite'),
      };

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    return LayoutBuilder(builder: (_, k) {
      final wide = k.maxWidth > k.maxHeight * 1.1;
      final gridSide = min(wide ? k.maxHeight - 24 : k.maxWidth - 48, wide ? k.maxWidth * 0.5 : k.maxHeight - 250);
      final grid = _grid(u, gridSide);
      final tools = _tools(u, wide ? k.maxWidth - gridSide - 64 : k.maxWidth - 32);
      return Padding(
        padding: const EdgeInsets.all(12),
        child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [grid, const SizedBox(width: 16), Expanded(child: tools)])
            : Column(children: [grid, const SizedBox(height: 12), Expanded(child: tools)]),
      );
    });
  }

  Widget _grid(Universe u, double side) {
    final cell = side / maze.size;
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), boxShadow: cardShadow, border: Border.all(color: u.onCard, width: 3)),
      child: Stack(children: [
        for (var r = 0; r < maze.size; r++)
          for (var c = 0; c < maze.size; c++)
            Positioned(
              left: c * cell,
              top: r * cell,
              child: Container(
                width: cell,
                height: cell,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD5DBD7))),
                alignment: Alignment.center,
                child: maze.rocks.contains((c, r))
                    ? Art('1faa8', size: cell * 0.7, label: 'rocher')
                    : (c, r) == maze.goal
                        ? Art(u.objects.first, size: cell * 0.7, label: 'objectif')
                        : null,
              ),
            ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          left: robot.cell.$1 * cell,
          top: robot.cell.$2 * cell,
          child: SizedBox(
            width: cell,
            height: cell,
            child: Stack(alignment: Alignment.center, children: [
              Transform.translate(offset: bumped ? const Offset(4, 0) : Offset.zero, child: Art(u.mascot, size: cell * 0.72)),
              // La flèche montre où la mascotte regarde (utile pour « avancer » et « pivoter »).
              if (!arrowsMode)
                Align(
                  alignment: [Alignment.topCenter, Alignment.centerRight, Alignment.bottomCenter, Alignment.centerLeft][robot.heading],
                  child: Transform.rotate(
                    angle: robot.heading * pi / 2,
                    child: Icon(Icons.navigation_rounded, size: cell * 0.32, color: u.night ? u.primary : u.onCard),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tools(Universe u, double width) {
    final ops = arrowsMode ? arrows : relative;
    final slot = min(64.0, (width - 8) / min(slots, 6) - 8);
    return SingleChildScrollView(
      child: Column(children: [
        // Le programme : des cases à remplir, numérotées ; celle en cours s'allume quand il tourne.
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
          child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (var i = 0; i < slots; i++)
              Container(
                width: slot,
                height: slot,
                decoration: BoxDecoration(
                  color: i < program.length ? u.primary : const Color(0xFFF1F3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: running == i + 1 ? gold : const Color(0xFFD5DBD7), width: running == i + 1 ? 4 : 2),
                ),
                child: i < program.length
                    ? Icon(_icon(program[i]), color: u.onPrimary, size: slot * 0.7, semanticLabel: _name(program[i]))
                    : Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 16, color: Color(0xFF8A948E)))),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        // Blocs, effacer et lancer sur une seule rangée : tout reste visible sans défiler.
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final op in ops)
            Tooltip(
              message: _name(op),
              child: SizedBox(
                width: 64,
                height: 72,
                child: FilledButton(
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  onPressed: locked || program.length >= slots
                      ? null
                      : () {
                          setState(() => program.add(op));
                          a.speech.say(_name(op));
                        },
                  child: Icon(_icon(op), size: 44, semanticLabel: _name(op)),
                ),
              ),
            ),
          IconButton.filledTonal(
            iconSize: 36,
            tooltip: t('Effacer le dernier bloc'),
            onPressed: locked || program.isEmpty ? null : () => setState(program.removeLast),
            icon: const Icon(Icons.backspace_rounded),
          ),
          SizedBox(
            width: 88,
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(padding: EdgeInsets.zero, backgroundColor: green, disabledBackgroundColor: const Color(0xFFBFC7C1)),
              onPressed: locked || program.isEmpty ? null : _run,
              child: Icon(Icons.play_arrow_rounded, size: 52, color: Colors.white, semanticLabel: t('Lancer le programme')),
            ),
          ),
        ]),
      ]),
    );
  }
}
