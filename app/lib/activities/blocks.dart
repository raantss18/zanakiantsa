import 'dart:math';

import 'package:flutter/material.dart';

import '../core/blocks.dart';
import '../core/robot.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Programmer avec des blocs emboîtés, comme dans Scratch (ADR 0041). Mode `boucle` : peu de place, il faut
/// « répéter ». Mode `condition` : « répéter jusqu'à l'objet » et « si rocher devant » pour contourner les rochers.
/// Mode `compteur` (ADR 0050) : une variable. Le robot compte les gemmes ; le programme est essayé sur trois parcours.
/// Un bloc « répéter » ou « si » s'ouvre : les blocs suivants vont dedans, jusqu'à « Fermer le bloc ».
class BlocksActivity extends StatefulWidget {
  const BlocksActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<BlocksActivity> createState() => _BlocksActivityState();
}

class _BlocksActivityState extends State<BlocksActivity> {
  Attempt get a => widget.attempt;
  late final String mode = a.skill.params['mode'] as String;
  late final bool loopMode = mode == 'boucle', counterMode = mode == 'compteur';

  /// Les parcours (un seul, sauf en mode compteur : trois), la solution, sa taille.
  late final (List<Maze>, List<Block>, int) puzzle = switch (mode) {
    'boucle' => _single(loopPuzzle(Random(a.question.a))),
    'compteur' => counterPuzzle(Random(a.question.a)),
    _ => _single(conditionPuzzle(Random(a.question.a))),
  };

  static (List<Maze>, List<Block>, int) _single((Maze, List<Block>, int) p) => ([p.$1], p.$2, p.$3);

  List<Maze> get mazes => puzzle.$1;
  int mazeIndex = 0;
  Maze get maze => mazes[mazeIndex];

  /// Valeur du compteur affichée pendant l'essai.
  int counter = 0;

  /// Place disponible : la solution plus un peu de marge, moins que le chemin bloc par bloc (il faut une boucle).
  late final int limit = puzzle.$3 + (loopMode ? 1 : 2);
  final program = <Block>[];

  /// Blocs ouverts (les nouveaux blocs vont dans le dernier) et ordre d'ajout (pour « effacer le dernier »).
  final open = <Block>[];
  final added = <(List<Block>, Block)>[];
  late RobotState robot = maze.start;
  bool running = false, bumped = false;

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
    if (a.demonstrate && !running) {
      program
        ..clear()
        ..addAll([for (final b in puzzle.$2) b.copy()]);
      open.clear();
      _run(demo: true);
    }
    setState(() {});
  }

  bool get locked => a.busy || a.finished || running;
  List<Block> get _target => open.isEmpty ? program : open.last.body;

  void _add(BlockKind k) {
    if (programSize(program) >= limit) {
      a.speech.say(counterMode ? 'Plus de place ! Fais compter le robot.' : 'Plus de place ! Utilise un bloc qui répète.', force: true);
      return;
    }
    final b = Block(k, count: 3);
    setState(() {
      final list = _target;
      list.add(b);
      added.add((list, b));
      if (b.isContainer) open.add(b);
    });
    a.speech.say(_name(b));
  }

  void _undo() {
    if (added.isEmpty) return;
    setState(() {
      final (list, b) = added.removeLast();
      list.remove(b);
      open.remove(b);
      // Les blocs qui étaient dedans partent avec lui.
      added.removeWhere((e) => _inside(b, e.$2));
    });
  }

  bool _inside(Block container, Block b) => container.body.any((x) => identical(x, b) || _inside(x, b));

  Future<void> _run({bool demo = false}) async {
    setState(() {
      running = true;
      bumped = false;
      open.clear();
    });
    // En mode compteur, le même programme est essayé sur chaque parcours, l'un après l'autre.
    var ok = true;
    late Trace t;
    for (var i = 0; i < mazes.length && ok; i++) {
      setState(() {
        mazeIndex = i;
        robot = maze.start;
        counter = 0;
      });
      if (i > 0) await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      t = execute(maze, program);
      for (final (j, s) in t.states.indexed.skip(1)) {
        await Future<void>.delayed(const Duration(milliseconds: 380));
        if (!mounted) return;
        setState(() {
          robot = s;
          counter = t.counts[j];
        });
      }
      ok = solves(maze, program);
      if (ok && i < mazes.length - 1) await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!ok) {
      setState(() => bumped = t.bumped);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (!mounted) return;
    // Ce que montre l'essai (ADR 0029, 0050).
    final String? why;
    if (ok) {
      why = null;
    } else if (t.bumped) {
      why = counterMode
          ? "Le robot est arrivé au mur sans s'arrêter : le compteur n'a pas atteint le bon nombre."
          : "Le robot s'est cogné : regarde où il était juste avant le choc.";
    } else if (t.tooLong) {
      why = counterMode
          ? "Le compteur n'arrive jamais au bon nombre. Quand faut-il ajouter 1 au compteur ?"
          : 'Le programme tourne en rond : il ne s\'arrête jamais. Que fait le robot à chaque tour ?';
    } else if (counterMode) {
      why = mazeIndex > 0
          ? "Ça marchait sur le parcours d'avant, mais pas sur celui-ci : les gemmes ne sont pas aux mêmes endroits. "
              "Ne dis pas au robot combien de pas : fais-lui compter les gemmes."
          : "Le robot s'arrête ailleurs que sur le drapeau. Combien de gemmes faut-il compter ?";
    } else {
      why = "Le robot s'arrête ailleurs que sur l'objet : change le nombre de tours, ou les blocs de la boucle.";
    }
    setState(() {
      running = false;
      if (!ok) {
        mazeIndex = 0;
        robot = maze.start;
        counter = 0;
      }
    });
    if (!demo) a.submit(ok, why: why);
  }

  String _name(Block b) => switch (b.kind) {
    BlockKind.forward => 'avancer',
    BlockKind.turnLeft => 'pivoter à gauche',
    BlockKind.turnRight => 'pivoter à droite',
    BlockKind.repeat => 'répéter ${b.count} fois',
    BlockKind.untilGoal => "répéter jusqu'à l'objet",
    BlockKind.ifRock => 'si rocher devant',
    BlockKind.addCounter => 'ajouter 1 au compteur',
    BlockKind.untilCounter => "répéter jusqu'à compteur = ${b.count}",
    BlockKind.ifGem => 'si gemme ici',
  };

  IconData _icon(BlockKind k) => switch (k) {
    BlockKind.forward => Icons.straight_rounded,
    BlockKind.turnLeft => Icons.turn_left_rounded,
    BlockKind.turnRight => Icons.turn_right_rounded,
    BlockKind.repeat => Icons.repeat_rounded,
    BlockKind.untilGoal => Icons.flag_rounded,
    BlockKind.ifRock || BlockKind.ifGem => Icons.help_outline_rounded,
    BlockKind.addCounter => Icons.exposure_plus_1_rounded,
    BlockKind.untilCounter => Icons.repeat_on_rounded,
  };

  /// Couleur d'un bloc : mouvement, boucle, condition (toujours avec son nom écrit, jamais la couleur seule).
  Color _colour(BlockKind k) => switch (k) {
    BlockKind.repeat || BlockKind.untilGoal || BlockKind.untilCounter => const Color(0xFFB45309),
    BlockKind.ifRock || BlockKind.ifGem => const Color(0xFF1D4ED8),
    BlockKind.addCounter => const Color(0xFF7E22CE),
    _ => const Color(0xFF15803D),
  };

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    return LayoutBuilder(
      builder: (_, k) {
        final Widget body;
        if (counterMode) {
          // Une seule rangée de gemmes : une bande en haut, et toute la hauteur au programme (tous formats).
          body = Column(
            children: [
              _grid(u, min(k.maxWidth - 24, 7 * 64.0)),
              const SizedBox(height: 8),
              Expanded(child: _programPanel()),
              const SizedBox(height: 8),
              _palette(),
            ],
          );
        } else if (k.maxWidth > k.maxHeight * 1.4) {
          // Paysage : la grille à gauche, le programme et les blocs à droite.
          final side = min(k.maxHeight - 24, k.maxWidth * 0.45);
          body = Row(
            children: [
              _grid(u, side),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _programPanel()),
                    const SizedBox(height: 8),
                    _palette(),
                  ],
                ),
              ),
            ],
          );
        } else if (k.maxWidth >= 600) {
          // Tablette en portrait : grille et programme côte à côte, les blocs dessous (tout se lit sans défiler).
          final side = max(160.0, min(k.maxWidth * 0.5, k.maxHeight - 240));
          body = Column(
            children: [
              SizedBox(
                height: side,
                child: Row(
                  children: [
                    _grid(u, side),
                    const SizedBox(width: 12),
                    Expanded(child: _programPanel()),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _palette(),
            ],
          );
        } else {
          // Téléphone : une colonne qui défile.
          body = SingleChildScrollView(
            child: Column(
              children: [
                _grid(u, min(k.maxWidth - 24, k.maxHeight * 0.3)),
                const SizedBox(height: 8),
                SizedBox(height: (k.maxHeight * 0.32).clamp(150.0, 280.0), child: _programPanel()),
                const SizedBox(height: 8),
                _palette(),
              ],
            ),
          );
        }
        return Padding(padding: const EdgeInsets.all(12), child: body);
      },
    );
  }

  Widget _grid(Universe u, double side) {
    final cell = side / maze.size;
    // En mode compteur, seule la rangée du robot est dessinée : une bande.
    final firstRow = counterMode ? maze.start.cell.$2 : 0;
    final rows = counterMode ? 1 : maze.size;
    return Container(
      width: side,
      height: cell * rows + (counterMode ? 6 : 0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
        border: Border.all(color: u.onCard, width: 3),
      ),
      child: Stack(
        children: [
          for (var r = firstRow; r < firstRow + rows; r++)
            for (var c = 0; c < maze.size; c++)
              Positioned(
                left: c * cell,
                top: (r - firstRow) * cell,
                child: Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD5DBD7))),
                  alignment: Alignment.center,
                  child: maze.rocks.contains((c, r))
                      ? Art('1faa8', size: cell * 0.7, label: 'rocher')
                      : (c, r) == maze.goal
                      ? (counterMode ? _flaggedGem(cell) : Art(u.objects.first, size: cell * 0.7, label: 'objectif'))
                      : maze.gems.contains((c, r))
                      ? Art('1f48e', size: cell * 0.7, label: 'gemme')
                      : null,
                ),
              ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: robot.cell.$1 * cell,
            top: (robot.cell.$2 - firstRow) * cell,
            child: SizedBox(
              width: cell,
              height: cell,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: bumped ? const Offset(4, 0) : Offset.zero,
                    child: Art(u.mascot, size: cell * 0.72),
                  ),
                  Align(
                    alignment: [
                      Alignment.topCenter,
                      Alignment.centerRight,
                      Alignment.bottomCenter,
                      Alignment.centerLeft,
                    ][robot.heading],
                    child: Transform.rotate(
                      angle: robot.heading * pi / 2,
                      child: Icon(Icons.navigation_rounded, size: cell * 0.34, color: u.night ? u.primary : u.onCard),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// La gemme où il faut s'arrêter : la gemme et un drapeau (la forme, pas seulement la couleur).
  Widget _flaggedGem(double cell) => Stack(
    alignment: Alignment.center,
    children: [
      Art('1f48e', size: cell * 0.7, label: 'gemme du drapeau'),
      Positioned(top: 0, right: 0, child: Icon(Icons.flag_rounded, size: cell * 0.42, color: const Color(0xFFB91C1C))),
    ],
  );

  /// Le programme : chaque bloc sur sa ligne ; ce qui est dans une boucle ou un « si » est décalé à droite, dans une
  /// bande de la couleur du bloc, fermée par « fin ».
  List<Widget> _lines(List<Block> blocks, int depth) => [
    for (final b in blocks) ...[
      Padding(
        padding: EdgeInsets.only(left: depth * 22.0, bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _colour(b.kind),
            borderRadius: BorderRadius.circular(12),
            border: open.contains(b) ? Border.all(color: gold, width: 4) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(b.kind), color: Colors.white, size: 26),
              const SizedBox(width: 6),
              Text(
                _name(b),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if ((b.kind == BlockKind.repeat || b.kind == BlockKind.untilCounter) && !locked) ...[
                const SizedBox(width: 4),
                _countButton(
                  Icons.remove_rounded,
                  b.kind == BlockKind.repeat ? 'Un tour de moins' : 'Un de moins',
                  b.count > (b.kind == BlockKind.repeat ? 2 : 1) ? () => setState(() => b.count--) : null,
                ),
                _countButton(
                  Icons.add_rounded,
                  b.kind == BlockKind.repeat ? 'Un tour de plus' : 'Un de plus',
                  b.count < 9 ? () => setState(() => b.count++) : null,
                ),
              ],
            ],
          ),
        ),
      ),
      if (b.isContainer) ...[
        ..._lines(b.body, depth + 1),
        if (open.contains(b))
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 22.0, bottom: 4),
            child: const Text(
              '… les blocs suivants vont ici',
              style: TextStyle(fontSize: 16, color: Color(0xFF4A554E)),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(left: depth * 22.0, bottom: 6),
          child: Text(
            'fin de « ${_name(b)} »',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _colour(b.kind)),
          ),
        ),
      ],
    ],
  ];

  Widget _countButton(IconData icon, String label, VoidCallback? onTap) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 26),
      style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF)),
    ),
  );

  Widget _programPanel() {
    final used = programSize(program);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // La place qui reste, écrite (pas seulement montrée) ; effacer et lancer toujours visibles.
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blocs : $used sur $limit',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
                    ),
                    // Le compteur, écrit pendant l'essai ; le parcours en cours (ADR 0050).
                    if (counterMode)
                      Text(
                        'Compteur : $counter · Parcours ${mazeIndex + 1} sur ${mazes.length}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF7E22CE)),
                      ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                iconSize: 32,
                tooltip: 'Effacer le dernier bloc',
                onPressed: locked || added.isEmpty ? null : _undo,
                icon: const Icon(Icons.backspace_rounded),
              ),
              SizedBox(
                width: 88,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: green,
                    disabledBackgroundColor: const Color(0xFFBFC7C1),
                  ),
                  onPressed: locked || program.isEmpty ? null : _run,
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 44,
                    color: Colors.white,
                    semanticLabel: 'Lancer le programme',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (program.isEmpty)
                    const Text('Touche les blocs en dessous pour écrire le programme.', style: TextStyle(fontSize: 17)),
                  ..._lines(program, 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _palette() {
    final kinds = loopMode
        ? [BlockKind.forward, BlockKind.turnLeft, BlockKind.turnRight, BlockKind.repeat]
        : counterMode
        ? [BlockKind.forward, BlockKind.untilCounter, BlockKind.ifGem, BlockKind.addCounter]
        : [BlockKind.forward, BlockKind.turnLeft, BlockKind.turnRight, BlockKind.untilGoal, BlockKind.ifRock];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final k in kinds)
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _colour(k),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              onPressed: locked ? null : () => _add(k),
              icon: Icon(_icon(k), size: 26),
              label: Text(_name(Block(k, count: 3)).replaceAll(' 3 fois', '…').replaceAll('= 3', '= …')),
            ),
          ),
        // Toujours là (grisé quand aucun bloc n'est ouvert) : en apparaissant, il faisait sauter les autres boutons et
        // l'enfant touchait à côté.
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            onPressed: locked || open.isEmpty ? null : () => setState(open.removeLast),
            icon: const Icon(Icons.keyboard_return_rounded),
            label: const Text('Fermer le bloc'),
          ),
        ),
      ],
    );
  }
}
