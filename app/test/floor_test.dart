import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/day.dart';
import 'package:zanakiantsa/core/diagnostic.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/progress.dart';

// ADR 0065. Signalé par Antsa le 2026-11-08 : un enfant de 12 ans devait « compter 4 voitures » (diagnostic d'une notion
// de CM1 avec les jouets de son univers). À 12 ans, on ne compte plus les voitures ni les syllabes.
List<Topic> topics() => [
      for (final f in Directory('assets/content').listSync().whereType<File>())
        if (jsonDecode(f.readAsStringSync()) case final Map<String, dynamic> j when j['competences'] != null) Topic(j),
    ];

Progress progressFor(Topic t, int classe, [List<Answer> journal = const []]) {
  final refs = [for (final s in t.skills) s.ref];
  return Progress(refs, journal, startLevel: startLevelIn(refs, startLevelForClass(classe)), floor: t.ageless ? 0 : floorForClass(classe));
}

void main() {
  final all = topics();
  final classe = classForAge(12); // 5e
  final floor = floorForClass(classe); // CM2

  test('le plancher : deux classes sous la sienne', () {
    expect(schoolLevels[classe], '5e');
    expect(schoolLevels[floor], 'CM2');
    expect(floorForClass(classForAge(5)), 0);
  });

  // Les domaines proposés à 12 ans (les autres sont cachés, voir plus bas).
  for (final t in all.where((t) => !t.ageless && t.skills.any((s) => s.ref.level >= floor))) {
    test('${t.id} : à 12 ans, rien sous le CM2 dans les séances, le diagnostic ou le défi', () {
      final p = progressFor(t, classe);
      final level = {for (final s in t.skills) s.id: s.ref.level};
      final r = Random(3);
      for (var d = 0; d < 30; d++) {
        for (final id in p.plan(DateTime(2026, 11, 1 + d))) {
          expect(level[id]!, greaterThanOrEqualTo(floor), reason: id);
        }
      }
      for (final id in p.challengePlan(r) ?? const <String>[]) {
        expect(level[id]!, greaterThanOrEqualTo(floor), reason: id);
      }
      for (final s in t.skills.where((s) => !p.belowFloor(s.id))) {
        for (final pre in p.checkable(prerequisitesToCheck(s.ref, [for (final x in t.skills) x.ref]))) {
          expect(level[pre]!, greaterThanOrEqualTo(floor), reason: '${s.id} ← $pre');
        }
      }
    });
  }

  test('le cas signalé : les pourcentages ne vérifient plus « une fraction d\'une quantité » (CM1) à 12 ans', () {
    final compter = all.firstWhere((t) => t.id == 'compter');
    final p = progressFor(compter, classe);
    final s = compter.skill('pourcentages');
    expect(prerequisitesToCheck(s.ref, [for (final x in compter.skills) x.ref]), contains('fractions-quantite'));
    expect(p.checkable(prerequisitesToCheck(s.ref, [for (final x in compter.skills) x.ref])), isNot(contains('fractions-quantite')));
    // À 9 ans (CM1), la même vérification reste utile.
    expect(progressFor(compter, classForAge(9)).checkable(['fractions-quantite']), ['fractions-quantite']);
  });

  test('à 12 ans, la journée ne propose ni « Les sons » ni les suites de maternelle', () {
    final shown = [for (final t in all) if (t.ageless || t.skills.any((s) => s.ref.level >= floor)) t.id];
    expect(shown, isNot(contains('sons')));
    expect(shown, isNot(contains('motifs')));
    expect(shown, contains('dessin'), reason: 'le dessin libre est pour tous les âges');
    final tops = {for (final t in all) t.id: t.skills.map((s) => s.ref.level).reduce(max)};
    for (var d = 0; d < 14; d++) {
      final plan = DayPlan.of(DateTime(2026, 11, 1 + d), const [], tops: tops, classe: classe, visible: shown);
      expect(plan.items.map((i) => i.theme), everyElement(isIn(shown)));
    }
  });

  group('choisir sa leçon', () {
    final compter = all.firstWhere((t) => t.id == 'compter');

    test('jusqu\'à sa classe, oui ; sous le plancher, non ; au-dessus, quand sa classe est finie', () {
      final p = progressFor(compter, classe);
      final byLevel = {for (final s in compter.skills) s.level: s.id};
      expect(p.choosable(byLevel['CE1']!, classe), isFalse);
      expect(p.choosable(byLevel['6e']!, classe), isTrue);
      expect(p.choosable(byLevel['5e']!, classe), isTrue);
      expect(p.choosable(byLevel['4e']!, classe), isFalse, reason: 'les leçons de 6e et de 5e ne sont pas encore acquises');
      // Tout ce qui va jusqu'à la 5e acquis : la 4e s'ouvre.
      final now = DateTime(2026, 11, 8);
      final journal = [
        for (final s in compter.skills)
          if (s.ref.level <= classe)
            for (var i = 0; i < 10; i++) Answer(skill: s.id, attempts: 1, correct: true, demonstrated: false, millis: 3000, at: now.add(Duration(minutes: i))),
      ];
      expect(progressFor(compter, classe, journal).choosable(byLevel['4e']!, classe), isTrue);
    });

    test('la séance d\'une leçon choisie porte sur cette leçon', () {
      final p = progressFor(compter, classe);
      final plan = p.focusPlan('decimaux-multiplier', Random(1));
      expect(plan.length, questionsPerSession);
      expect(plan.first, 'decimaux-multiplier');
      expect(plan.where((id) => id == 'decimaux-multiplier').length, greaterThanOrEqualTo(questionsPerSession * 2 ~/ 3));
    });
  });

  test('les trois activités du jour : seulement des domaines où il reste à apprendre à son niveau', () {
    final shown = [for (final t in all) if (t.ageless || t.skills.any((s) => s.ref.level >= floor)) t.id];
    final tops = {for (final t in all) t.id: t.skills.map((s) => s.ref.level).reduce(max)};
    // Les échecs sont finis (plus rien à apprendre) : ils ne sont plus proposés tant que d'autres domaines ont à apprendre.
    final learning = {for (final t in all) if (!t.ageless && shown.contains(t.id) && t.id != 'echecs' && progressFor(t, classe).newSkill != null) t.id};
    final candidates = dayCandidates(shown, learning: learning, tops: tops);
    expect(candidates, isNot(contains('echecs')));
    expect(candidates, isNot(contains('dessin')));
    for (var d = 0; d < 14; d++) {
      final plan = DayPlan.of(DateTime(2026, 11, 1 + d), const [], tops: tops, classe: classe, visible: candidates);
      expect(plan.items.map((i) => i.theme), everyElement(isIn(learning)), reason: 'jour $d');
      expect(plan.items.map((i) => i.theme).toSet().length, 3);
    }
    // Moins de trois domaines à apprendre : on complète avec les autres domaines proposés.
    expect(dayCandidates(['a', 'b', 'c'], learning: {'a'}, tops: const {}), ['a', 'b', 'c']);
  });
}
