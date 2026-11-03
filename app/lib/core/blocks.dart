/// Programmer avec des blocs, comme dans Scratch (ADR 0041) : avancer, pivoter, « répéter n fois », « répéter jusqu'à
/// l'objet » et « si rocher devant ». Repère : la fiche éduscol « Programmer » (cycles 3 et 4) cite « séquence
/// d'instructions, boucle, instructions conditionnelles » (https://eduscol.education.fr/document/14773/download).
/// Idée des blocs emboîtés seulement (aucun code ni dessin de Scratch repris, CLAUDE.md règle 7).
library;

import 'dart:math';

import 'robot.dart';

enum BlockKind { forward, turnLeft, turnRight, repeat, untilGoal, ifRock }

/// Un bloc ; les blocs « répéter », « jusqu'à l'objet » et « si rocher devant » contiennent d'autres blocs.
class Block {
  Block(this.kind, {this.count = 2, List<Block>? body}) : body = body ?? [];
  final BlockKind kind;
  int count;
  final List<Block> body;

  bool get isContainer => kind == BlockKind.repeat || kind == BlockKind.untilGoal || kind == BlockKind.ifRock;

  /// Nombre de blocs, ceux du dedans compris (c'est ce que compte la limite).
  int get size => 1 + body.fold(0, (n, b) => n + b.size);

  Block copy() => Block(kind, count: count, body: [for (final b in body) b.copy()]);
}

int programSize(List<Block> p) => p.fold(0, (n, b) => n + b.size);

/// Au-delà, le programme « tourne en rond » : on l'arrête.
const maxSteps = 60;

/// Ce qu'a fait le programme : les états du robot (un par pas), et comment il s'est arrêté.
class Trace {
  Trace(this.states, this.bumped, this.tooLong);
  final List<RobotState> states;
  final bool bumped, tooLong;
}

/// Exécute un programme : un « pas » = avancer ou pivoter ; un choc arrête tout.
Trace execute(Maze maze, List<Block> program) {
  final states = [maze.start];
  var bumped = false, tooLong = false;

  bool rockAhead() {
    final s = states.last;
    const d = [(0, -1), (1, 0), (0, 1), (-1, 0)];
    final c = (s.cell.$1 + d[s.heading].$1, s.cell.$2 + d[s.heading].$2);
    return !maze.free(c);
  }

  // false : arrêter (choc, trop long, ou arrivé dans « jusqu'à l'objet »).
  bool run(List<Block> blocks) {
    for (final b in blocks) {
      switch (b.kind) {
        case BlockKind.forward || BlockKind.turnLeft || BlockKind.turnRight:
          if (states.length > maxSteps) {
            tooLong = true;
            return false;
          }
          final op = switch (b.kind) { BlockKind.forward => Op.forward, BlockKind.turnLeft => Op.turnLeft, _ => Op.turnRight };
          final next = maze.step(states.last, op);
          if (next == null) {
            bumped = true;
            return false;
          }
          states.add(next);
        case BlockKind.repeat:
          for (var i = 0; i < b.count; i++) {
            if (!run(b.body)) return false;
          }
        case BlockKind.untilGoal:
          while (states.last.cell != maze.goal) {
            final before = states.length;
            if (!run(b.body)) return false;
            if (states.length == before) {
              // Un tour de boucle qui ne fait rien : il tournerait sans fin.
              tooLong = true;
              return false;
            }
          }
        case BlockKind.ifRock:
          if (rockAhead() && !run(b.body)) return false;
      }
    }
    return true;
  }

  run(program);
  return Trace(states, bumped, tooLong);
}

bool solves(Maze maze, List<Block> program) {
  final t = execute(maze, program);
  return !t.bumped && !t.tooLong && t.states.last.cell == maze.goal;
}

/// Boucle : le trajet est un motif répété [count] fois ; la limite de blocs oblige à utiliser « répéter ».
/// Rend le parcours, la solution, et la limite de blocs.
(Maze, List<Block>, int) loopPuzzle(Random r, {int size = 7}) {
  // (motif, nombre de tours possibles) : du plus simple (avancer n fois) aux escaliers.
  final patterns = [
    ([BlockKind.forward], [4, 5, 6]),
    ([BlockKind.forward, BlockKind.forward, BlockKind.turnRight], [2, 3]),
    ([BlockKind.forward, BlockKind.forward, BlockKind.turnLeft], [2, 3]),
    ([BlockKind.forward, BlockKind.forward, BlockKind.forward, BlockKind.turnRight], [2, 3]),
    ([BlockKind.forward, BlockKind.turnRight, BlockKind.forward, BlockKind.turnLeft], [2, 3, 4]),
    ([BlockKind.forward, BlockKind.turnLeft, BlockKind.forward, BlockKind.turnRight], [2, 3, 4]),
  ];
  while (true) {
    final (pattern, counts) = patterns[r.nextInt(patterns.length)];
    final count = counts[r.nextInt(counts.length)];
    final solution = [Block(BlockKind.repeat, count: count, body: [for (final k in pattern) Block(k)])];
    final start = RobotState((r.nextInt(size), r.nextInt(size)), r.nextInt(4));
    final probe = Maze(size, start, (-1, -1), const {});
    final t = execute(probe, solution);
    if (t.bumped || t.tooLong) continue;
    final goal = t.states.last.cell;
    // L'objet n'est pas croisé avant la fin (un dernier virage sur place est permis), trajet d'au moins 4 cases.
    final first = t.states.indexWhere((s) => s.cell == goal);
    if (t.states.skip(first).any((s) => s.cell != goal)) continue;
    if ((goal.$1 - start.cell.$1).abs() + (goal.$2 - start.cell.$2).abs() < 3) continue;
    final maze = Maze(size, start, goal, const {});
    return (maze, solution, programSize(solution));
  }
}

/// Condition : « répéter jusqu'à l'objet [ si rocher devant : pivoter ; avancer ] ». Les rochers sont placés pour que
/// tourner toujours du même côté marche, et que l'autre côté (ou avancer sans regarder) échoue.
(Maze, List<Block>, int) conditionPuzzle(Random r, {int size = 7}) {
  while (true) {
    final right = r.nextBool();
    final turn = right ? BlockKind.turnRight : BlockKind.turnLeft;
    List<Block> program(BlockKind t) => [
          Block(BlockKind.untilGoal, body: [
            Block(BlockKind.ifRock, body: [Block(t)]),
            Block(BlockKind.forward),
          ]),
        ];
    final start = RobotState((r.nextInt(size), r.nextInt(size)), r.nextInt(4));
    final rocks = <(int, int)>{for (var i = 0; i < 4 + r.nextInt(4); i++) (r.nextInt(size), r.nextInt(size))}..remove(start.cell);
    // On fait rouler la bonne solution sans objet, puis on pose l'objet sur une case atteinte après au moins 2 virages.
    final probe = Maze(size, start, (-1, -1), rocks);
    final t = execute(probe, program(turn));
    var turns = 0;
    (int, int)? goal;
    for (var i = 1; i < t.states.length; i++) {
      if (t.states[i].heading != t.states[i - 1].heading) turns++;
      if (turns >= 2 && t.states[i].cell != start.cell && i >= 9) {
        goal = t.states[i].cell;
        break;
      }
    }
    if (goal == null || rocks.contains(goal)) continue;
    final maze = Maze(size, start, goal, rocks);
    final good = program(turn);
    if (!solves(maze, good)) continue;
    if (solves(maze, program(right ? BlockKind.turnLeft : BlockKind.turnRight))) continue;
    if (solves(maze, [Block(BlockKind.untilGoal, body: [Block(BlockKind.forward)])])) continue;
    return (maze, good, programSize(good));
  }
}
