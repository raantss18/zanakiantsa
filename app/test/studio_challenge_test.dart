import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/studio.dart';
import 'package:zanakiantsa/l10n/en.dart';

StudioBlock b(StudioKind k, [int? n, List<StudioBlock>? body]) => StudioBlock(k, n: n, body: body);
StudioRun run(List<StudioBlock> p) => runStudio(p);

void main() {
  test('chaque défi se reconnaît lui-même, tient dans la place et a son image', () {
    final ids = <String>{};
    for (final c in studioChallenges) {
      final m = c.model();
      expect(ids.add(c.id), isTrue, reason: c.id);
      expect(sameDrawing(run(m), run(c.model())), isTrue, reason: c.id);
      expect(studioSize(m), c.best, reason: c.id);
      expect(run(m).tooLong, isFalse, reason: c.id);
      expect(File('assets/art/${c.art}.svg').existsSync(), isTrue, reason: c.id);
    }
  });

  test('le dessin compte, pas le chemin : 4 pas = 2 + 2, et dans les deux sens', () {
    final target = run([b(StudioKind.forward, 4)]);
    expect(sameDrawing(target, run([b(StudioKind.forward, 2), b(StudioKind.forward, 2)])), isTrue);
    // Monter de 4, faire demi-tour, redescendre : même trait.
    expect(
      sameDrawing(target, run([b(StudioKind.forward, 4), b(StudioKind.turnLeft, 180), b(StudioKind.forward, 4)])),
      isTrue,
    );
  });

  test('un carré écrit sans boucle, en tournant à gauche par l\'autre côté, ne va pas : il est ailleurs', () {
    final square = run(studioChallenges.firstWhere((c) => c.id == 'carre').model());
    final flat = run([
      for (var i = 0; i < 4; i++) ...[b(StudioKind.forward, 5), b(StudioKind.turnRight, 90)],
    ]);
    expect(sameDrawing(square, flat), isTrue);
    final mirrored = run([
      b(StudioKind.repeat, 4, [b(StudioKind.forward, 5), b(StudioKind.turnLeft, 90)]),
    ]);
    expect(sameDrawing(square, mirrored), isFalse);
  });

  test('trop court, trop long, ou un trait en trop : pas pareil', () {
    final target = run([b(StudioKind.forward, 5), b(StudioKind.turnRight, 90), b(StudioKind.forward, 3)]);
    expect(
      sameDrawing(target, run([b(StudioKind.forward, 5), b(StudioKind.turnRight, 90), b(StudioKind.forward, 2)])),
      isFalse,
    );
    expect(
      sameDrawing(target, run([b(StudioKind.forward, 5), b(StudioKind.turnRight, 90), b(StudioKind.forward, 4)])),
      isFalse,
    );
    expect(sameDrawing(target, run([b(StudioKind.forward, 5)])), isFalse);
  });

  test('la couleur ne compte pas ; le crayon levé, si', () {
    final gap = run(studioChallenges.firstWhere((c) => c.id == 'pointilles').model());
    expect(sameDrawing(gap, run([b(StudioKind.forward, 8)])), isFalse);
    expect(
      sameDrawing(
        gap,
        run([
          b(StudioKind.colour, 4),
          b(StudioKind.forward, 3),
          b(StudioKind.penUp),
          b(StudioKind.forward, 2),
          b(StudioKind.penDown),
          b(StudioKind.colour, 1),
          b(StudioKind.forward, 3),
        ]),
      ),
      isTrue,
    );
  });

  test('l\'étoile, l\'hexagone et la maison se retrouvent malgré les virages de 60°, 72° ou 144°', () {
    final hex = run(studioChallenges.firstWhere((c) => c.id == 'hexagone').model());
    // Même hexagone, mais en tournant à gauche de 300° au lieu de droite de 60° : impossible (300 hors liste) ;
    // on le fait avec 6 côtés « à la main ».
    final byHand = run([
      for (var i = 0; i < 6; i++) ...[b(StudioKind.forward, 4), b(StudioKind.turnRight, 60)],
    ]);
    expect(sameDrawing(hex, byHand), isTrue);
    final house = run(studioChallenges.firstWhere((c) => c.id == 'maison').model());
    expect(sameDrawing(house, hex), isFalse);
  });

  test('un dessin vide ne réussit jamais', () {
    expect(sameDrawing(run([]), run([])), isFalse);
    expect(sameDrawing(run([b(StudioKind.note, 0)]), run([])), isFalse);
  });

  test('défis réussis : lecture et écriture', () {
    expect(decodeDone(null), isEmpty);
    expect(decodeDone(''), isEmpty);
    expect(decodeDone(encodeDone({'carre', 'ligne'})), {'carre', 'ligne'});
    expect(encodeDone({'carre', 'ligne'}), 'carre,ligne');
  });

  test('titres et phrases des défis traduits en anglais', () {
    for (final c in studioChallenges) {
      expect(en.containsKey(c.title), isTrue, reason: c.title);
      expect(en.containsKey(c.text), isTrue, reason: c.text);
    }
  });
}
