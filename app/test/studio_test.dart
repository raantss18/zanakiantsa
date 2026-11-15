import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/audio/sfx.dart';
import 'package:zanakiantsa/core/studio.dart';

StudioBlock b(StudioKind k, [int? n, List<StudioBlock>? body]) => StudioBlock(k, n: n, body: body);

void main() {
  test('un carré revient au départ, cap vers le haut, quatre traits', () {
    final r = runStudio([b(StudioKind.repeat, 4, [b(StudioKind.forward, 5), b(StudioKind.turnRight, 90)])]);
    expect(r.segments.length, 4);
    final end = r.frames.last.turtle;
    expect(end.x, closeTo(0, 1e-6));
    expect(end.y, closeTo(0, 1e-6));
    expect(end.heading, 0);
    expect(r.tooLong, isFalse);
  });

  test('l\'étoile à cinq branches se referme exactement', () {
    final star = studioIdeas.firstWhere((i) => i.title == 'Une étoile').build();
    final end = runStudio(star).frames.last.turtle;
    expect(end.x, closeTo(0, 1e-6));
    expect(end.y, closeTo(0, 1e-6));
  });

  test('crayon levé : le robot bouge sans tracer ; la couleur suit le bloc', () {
    final r = runStudio([
      b(StudioKind.penUp),
      b(StudioKind.forward, 2),
      b(StudioKind.penDown),
      b(StudioKind.colour, 4),
      b(StudioKind.forward, 1),
    ]);
    expect(r.segments.length, 1);
    expect(r.segments.single.colour, 4);
    expect(r.segments.single.y0, closeTo(-2, 1e-9));
  });

  test('tourner à gauche de 90° fait regarder à gauche (270°)', () {
    final r = runStudio([b(StudioKind.turnLeft, 90), b(StudioKind.forward, 3)]);
    expect(r.frames.last.turtle.heading, 270);
    expect(r.frames.last.turtle.x, closeTo(-3, 1e-9));
  });

  test('les notes sont des pas sans trait ; Frère Jacques en a 14', () {
    final song = studioIdeas.firstWhere((i) => i.title == 'Frère Jacques').build();
    final r = runStudio(song);
    expect(r.segments, isEmpty);
    expect(r.frames.where((f) => f.note != null).length, 14);
    expect(noteWav(0).length, greaterThan(44));
  });

  test('un programme trop long s\'arrête au plafond', () {
    final r = runStudio([
      b(StudioKind.repeat, 12, [
        b(StudioKind.repeat, 12, [
          b(StudioKind.repeat, 12, [b(StudioKind.forward, 1)]),
        ]),
      ]),
    ]);
    expect(r.tooLong, isTrue);
    expect(r.frames.length, studioMaxActions);
  });

  test('les valeurs suivent la liste : − et + s\'arrêtent aux bouts', () {
    final f = b(StudioKind.forward, 1);
    expect(f.shifted(-1), isNull);
    expect(f.shifted(1), 2);
    final turn = b(StudioKind.turnRight, 180);
    expect(turn.shifted(1), isNull);
    expect(turn.shifted(-1), 144);
    expect(b(StudioKind.penUp).hasValue, isFalse);
  });

  test('enregistrer puis relire rend le même programme ; données abîmées ignorées', () {
    final flower = studioIdeas.firstWhere((i) => i.title == 'Une fleur').build();
    final p = SavedProgram(7, 'Ma fleur', DateTime(2026, 11, 15), flower);
    final back = decodePrograms(encodePrograms([p]));
    expect(back.single.name, 'Ma fleur');
    expect(studioSize(back.single.blocks), studioSize(flower));
    expect(runStudio(back.single.blocks).segments.length, runStudio(flower).segments.length);
    expect(decodePrograms('pas du json'), isEmpty);
    expect(decodePrograms(null), isEmpty);
    // Bloc inconnu sauté, valeur hors liste remise par défaut.
    final odd = decodePrograms('[{"id":1,"nom":"x","date":0,"blocs":[{"k":"voler","n":3},{"k":"forward","n":99}]}]');
    expect(odd.single.blocks.single.kind, StudioKind.forward);
    expect(odd.single.blocks.single.n, 3);
  });

  test('chaque idée tient dans la place et finit sans être coupée', () {
    for (final i in studioIdeas) {
      final p = i.build();
      expect(studioSize(p), lessThanOrEqualTo(studioMaxBlocks), reason: i.title);
      expect(runStudio(p).tooLong, isFalse, reason: i.title);
    }
  });

  test('le cadre englobe tout le dessin', () {
    final r = runStudio([b(StudioKind.forward, 9), b(StudioKind.forward, 9), b(StudioKind.forward, 9)]);
    final (cx, cy, span) = r.view;
    expect(cx, 0);
    expect(cy, closeTo(-13.5, 1e-9));
    expect(span, greaterThanOrEqualTo(27));
  });

  test('chaque idée a son image dans les assets', () {
    for (final i in studioIdeas) {
      expect(File('assets/art/${i.art}.svg').existsSync(), isTrue, reason: i.title);
    }
  });
}
