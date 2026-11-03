import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/content/content.dart';

Topic load(String id) => Topic(jsonDecode(File('assets/content/$id.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  test('suites de nombres (ADR 0036) : cinq nombres dans les bornes, le trou jamais en premier', () {
    final r = Random(3);
    for (final s in load('motifs').skills.where((s) => s.activity == 'suite')) {
      final lo = s.params['min'] as int? ?? 0;
      for (var i = 0; i < 2000; i++) {
        final q = s.draw(r);
        expect((s.params['pas'] as List), contains(q.b), reason: s.id);
        final values = [for (var k = 0; k < 5; k++) q.a + k * q.b];
        expect(values.every((v) => v >= lo && v <= s.p('max')), isTrue, reason: '${s.id} $values');
        expect(values.skip(1), contains(q.n), reason: s.id);
        expect(s.expected(q), q.n);
      }
      for (final k in s.phrases.keys) {
        expect(s.say(k, s.draw(r)), isNot(contains('{')), reason: '${s.id}.$k');
      }
    }
  });

  test('états de l\'eau : chaque question a une bonne image et deux autres', () {
    for (final id in ['etats-eau', 'fondre-geler']) {
      final s = load('nature').skills.firstWhere((s) => s.id == id);
      expect(s.items.length, greaterThanOrEqualTo(6));
      for (final it in s.items) {
        expect(it.right, isNotNull);
        expect(it.others.length, 2);
        expect(File('assets/art/${it.right!.art}.svg').existsSync(), isTrue, reason: it.right!.art);
        for (final o in it.others) {
          expect(File('assets/art/${o.art}.svg').existsSync(), isTrue, reason: o.art);
        }
      }
    }
  });
}
