import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/progress.dart';

// Test de départ (ADR 0045) : sauter ce que l'enfant sait déjà, dans chaque domaine.
final t0 = DateTime(2026, 11, 5);
Answer ans(String skill, {bool correct = true}) =>
    Answer(skill: skill, attempts: 1, correct: correct, demonstrated: false, millis: 1000, at: t0);

const skills = [
  SkillRef('a', []),
  SkillRef('b', ['a']),
  SkillRef('c', ['b']),
  SkillRef('d', ['c']),
];

void main() {
  test('deux questions par compétence pas acquise, dans l\'ordre, même les pas encore ouvertes', () {
    expect(Progress(skills, []).placementPlan(), ['a', 'a', 'b', 'b', 'c', 'c', 'd', 'd']);
  });

  test('au plus six compétences testées d\'un coup', () {
    final many = [for (var i = 0; i < 10; i++) SkillRef('s$i', i == 0 ? const [] : ['s${i - 1}'])];
    expect(Progress(many, []).placementPlan()!.toSet().length, placementSkills);
  });

  test('réussies au test : acquises, et la compétence nouvelle est la suivante', () {
    final p = Progress(skills, [ans('a'), ans('a'), ans('b'), ans('b')], placed: {'a', 'b'});
    expect(p.earned('a'), isTrue);
    expect(p.newSkill, 'c');
    expect(p.placementPlan(), ['c', 'c', 'd', 'd']);
  });

  test('plus que zéro ou une compétence à tester : pas de test', () {
    expect(Progress(skills, [], placed: {'a', 'b', 'c'}).placementPlan(), isNull);
  });

  test('ensuite, la règle habituelle reprend la main : un acquis du test oublié redevient à apprendre', () {
    final p = Progress(skills, [for (var i = 0; i < 5; i++) ans('a', correct: false)], placed: {'a'});
    expect(p.earned('a'), isFalse);
    expect(p.newSkill, 'a');
  });
}
