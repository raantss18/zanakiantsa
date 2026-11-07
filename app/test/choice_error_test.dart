import 'dart:convert';
import 'dart:io';

import 'support/unfilled.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/choose.dart';
import 'package:zanakiantsa/content/content.dart';

// Réponses en images expliquées (ADR 0048) : une image fausse est nommée, et la compétence dit pourquoi si elle le peut.
Map<String, dynamic> json(String name) => jsonDecode(File('assets/content/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final skills = [
    for (final id in json('domaines')['ordre'] as List)
      for (final s in Topic(json(id as String)).skills)
        if (s.activity == 'choisir') s,
  ];

  test('chaque mauvaise image de chaque question donne une phrase complète, sans variable restée', () {
    expect(skills, isNotEmpty);
    for (final s in skills) {
      for (final (i, it) in s.items.indexed) {
        for (final p in it.others) {
          final q = Question(n: i);
          final why = choiceError(s, (k) => s.say(k, q), p);
          expect(why, isNot(contains(unfilled)), reason: '${s.id} : $why');
          expect(why, contains(p.name.replaceFirst(RegExp(r"^(le |la |les |l'|un |une )"), '')), reason: '${s.id} : $why');
          // L'explication ne nomme jamais la bonne réponse (le mot de la question, lui, peut revenir : « orange »).
          expect(why.replaceAll(it.text, '').contains(it.right!.name) && it.right!.name != p.name && !p.name.contains(it.right!.name), isFalse,
              reason: '${s.id} : $why');
        }
      }
    }
  });

  test('ce sont les bras, c\'est la tête', () {
    expect(thatIs('les bras'), 'Ça, ce sont les bras.');
    expect(thatIs('la tête'), 'Ça, c\'est la tête.');
  });

  test('rimes : on dit pourquoi le mot touché ne va pas', () {
    final rimes = skills.firstWhere((s) => s.id == 'rimes');
    final why = choiceError(rimes, (k) => rimes.say(k, const Question(n: 0)), rimes.items[0].others.first);
    expect(why, contains('ne finit pas comme « chat »'));
    expect(why, startsWith('« lapin »'));
  });
}
