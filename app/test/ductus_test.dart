import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/ductus.dart';

// Sens du tracé des lettres attachées (ADR 0049).
const box = Rect.fromLTWH(0, 0, 100, 100);

/// Un arc de cercle à l'écran (y vers le bas), de [from] à [to] degrés (0 = à droite, 90 = en bas).
List<Offset> arc(double from, double to, {int n = 40}) => [
      for (var i = 0; i <= n; i++)
        Offset(50 + 40 * cos((from + (to - from) * i / n) * pi / 180), 50 + 40 * sin((from + (to - from) * i / n) * pi / 180)),
    ];

void main() {
  // Départ « à 2 heures » : -45° (en haut à droite).
  test('o tracé vers la gauche depuis en haut à droite : juste', () {
    expect(ductusError('o', [arc(-45, -405)], box), isNull);
  });

  test('o tracé dans le sens des aiguilles : on le dit', () {
    expect(ductusError('o', [arc(-45, 315)], box), contains('tourne vers la gauche'));
  });

  test('c commencé en bas : on le dit', () {
    expect(ductusError('c', [arc(45, -45 - 270)], box), contains('commence en haut'));
  });

  test('l tracé de gauche à droite : juste ; à l\'envers : faux', () {
    final l = [const Offset(10, 70), const Offset(40, 20), const Offset(45, 5), const Offset(40, 80), const Offset(90, 75)];
    expect(ductusError('l', [l], box), isNull);
    expect(ductusError('l', [l.reversed.toList()], box), contains('de gauche à droite'));
  });

  test('lever le doigt : faux, sauf pour le point du i', () {
    final a = [const Offset(10, 70), const Offset(40, 40), const Offset(60, 80)];
    final b = [const Offset(40, 10), const Offset(41, 11), const Offset(42, 12)];
    expect(ductusError('u', [a, b], box), contains("d'un seul geste"));
    expect(ductusError('i', [a, b], box), isNull);
    expect(ductusError('i', [a, b, b], box), contains('le point vient à la fin'));
  });

  test('s finit à gauche dans le modèle : pas de règle gauche-droite', () {
    expect(ductusError('s', [[const Offset(80, 10), const Offset(30, 40), const Offset(70, 70), const Offset(15, 95)]], box), isNull);
  });

  test('un petit toucher par erreur ne compte pas comme un trait', () {
    final a = [const Offset(10, 70), const Offset(40, 40), const Offset(60, 80)];
    expect(ductusError('n', [a, [const Offset(5, 5)]], box), isNull);
  });
}
