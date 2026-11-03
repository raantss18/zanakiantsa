/// Programmer un robot sur un quadrillage (maternelle : « coder à l'aide de flèches », « 3 à 5 instructions simples
/// (avancer, tourner) » ; CP : « avancer d'une case, pivoter d'un quart de tour », au plus dix instructions dont deux
/// virages). Générateur de parcours et exécution d'un programme (ADR 0023).
library;

import 'dart:collection';
import 'dart:math';

typedef Cell = (int, int); // (colonne, rangée), rangée 0 en haut

/// Instructions : flèches absolues (haut, bas, gauche, droite) ou relatives (avancer, pivoter à gauche, à droite).
enum Op { up, down, left, right, forward, turnLeft, turnRight }

const arrows = [Op.up, Op.right, Op.down, Op.left];
const relative = [Op.forward, Op.turnLeft, Op.turnRight];

/// Orientation : 0 haut, 1 droite, 2 bas, 3 gauche.
const _dir = [(0, -1), (1, 0), (0, 1), (-1, 0)];

class RobotState {
  const RobotState(this.cell, this.heading);
  final Cell cell;
  final int heading;

  @override
  bool operator ==(Object other) => other is RobotState && other.cell == cell && other.heading == heading;
  @override
  int get hashCode => Object.hash(cell, heading);
}

class Maze {
  const Maze(this.size, this.start, this.goal, this.rocks);
  final int size;
  final RobotState start;
  final Cell goal;
  final Set<Cell> rocks;

  bool free(Cell c) => c.$1 >= 0 && c.$1 < size && c.$2 >= 0 && c.$2 < size && !rocks.contains(c);

  /// Un pas. null : le robot se cogne (bord ou rocher) et s'arrête.
  RobotState? step(RobotState s, Op op) {
    switch (op) {
      case Op.turnLeft:
        return RobotState(s.cell, (s.heading + 3) % 4);
      case Op.turnRight:
        return RobotState(s.cell, (s.heading + 1) % 4);
      default:
        final h = op == Op.forward ? s.heading : arrows.indexOf(op);
        final c = (s.cell.$1 + _dir[h].$1, s.cell.$2 + _dir[h].$2);
        return free(c) ? RobotState(c, h) : null;
    }
  }

  /// Les états successifs d'un programme ; s'arrête au premier choc.
  List<RobotState> run(List<Op> program) {
    final out = [start];
    for (final op in program) {
      final next = step(out.last, op);
      if (next == null) break;
      out.add(next);
    }
    return out;
  }

  bool solves(List<Op> program) {
    final states = run(program);
    return states.length == program.length + 1 && states.last.cell == goal;
  }

  /// Le plus court programme (largeur d'abord).
  List<Op>? shortest(List<Op> ops) {
    final prev = <RobotState, (RobotState, Op)>{};
    final queue = Queue.of([start]);
    final seen = {start};
    while (queue.isNotEmpty) {
      final s = queue.removeFirst();
      if (s.cell == goal) {
        final path = <Op>[];
        for (var cur = s; cur != start; cur = prev[cur]!.$1) {
          path.insert(0, prev[cur]!.$2);
        }
        return path;
      }
      for (final op in ops) {
        final n = step(s, op);
        if (n != null && seen.add(n)) {
          prev[n] = (s, op);
          queue.add(n);
        }
      }
    }
    return null;
  }
}

int turns(List<Op> p) => p.where((o) => o == Op.turnLeft || o == Op.turnRight).length;

/// Un parcours dont le plus court programme a entre [min] et [max] instructions et au plus [maxTurns] virages.
(Maze, List<Op>) mazePuzzle(Random r, {required bool arrowsMode, required int size, required int min, required int max, int rocks = 0, int maxTurns = 9}) {
  final ops = arrowsMode ? arrows : relative;
  while (true) {
    Cell cell() => (r.nextInt(size), r.nextInt(size));
    final start = RobotState(cell(), arrowsMode ? 0 : r.nextInt(4));
    final goal = cell();
    final rockSet = <Cell>{for (var i = 0; i < rocks; i++) cell()}..removeAll([start.cell, goal]);
    final maze = Maze(size, start, goal, rockSet);
    final p = maze.shortest(ops);
    if (p != null && p.length >= min && p.length <= max && turns(p) <= maxTurns) return (maze, p);
  }
}
