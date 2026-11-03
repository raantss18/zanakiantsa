import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/blocks.dart';
import 'package:zanakiantsa/core/robot.dart';

// Programmer avec des blocs (ADR 0041).
void main() {
  test('boucle : la solution marche, et sans « répéter » le trajet dépasse la limite de blocs', () {
    final r = Random(5);
    for (var i = 0; i < 200; i++) {
      final (maze, solution, limit) = loopPuzzle(r);
      expect(solves(maze, solution), isTrue);
      final unrolled = execute(maze, solution).states.length - 1;
      expect(unrolled, greaterThan(limit + 1), reason: 'sans boucle, il faudrait $unrolled blocs > $limit');
    }
  });

  test('condition : tourner du bon côté marche, l\'autre côté et « avancer seulement » échouent', () {
    final r = Random(6);
    for (var i = 0; i < 100; i++) {
      final (maze, solution, _) = conditionPuzzle(r);
      expect(solves(maze, solution), isTrue);
      // Sans boucle, le chemin déroulé dépasse la limite de blocs donnée à l'enfant (taille de la solution + 2).
      expect(execute(maze, solution).states.length - 1, greaterThan(programSize(solution) + 2));
      final turn = solution.single.body.first.body.single.kind;
      final other = turn == BlockKind.turnRight ? BlockKind.turnLeft : BlockKind.turnRight;
      expect(
          solves(maze, [
            Block(BlockKind.untilGoal, body: [Block(BlockKind.ifRock, body: [Block(other)]), Block(BlockKind.forward)])
          ]),
          isFalse);
    }
  });

  test('un programme qui tourne en rond s\'arrête ; un choc s\'arrête aussi', () {
    const maze = Maze(4, RobotState((0, 0), 1), (3, 3), {});
    expect(execute(maze, [Block(BlockKind.untilGoal, body: [Block(BlockKind.turnLeft)])]).tooLong, isTrue);
    expect(execute(maze, [Block(BlockKind.untilGoal, body: [Block(BlockKind.ifRock)])]).tooLong, isTrue);
    expect(execute(maze, [Block(BlockKind.repeat, count: 5, body: [Block(BlockKind.forward)])]).bumped, isTrue);
  });
}
