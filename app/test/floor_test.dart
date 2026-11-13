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

/// Comme l'app (app_state.progressOf) : plancher et départ du domaine selon la classe et la tranche d'âge.
Progress progressFor(Topic t, int classe, [List<Answer> journal = const []]) {
  final refs = [for (final s in t.skills) s.ref];
  final l = t.levelsFor(classe);
  return Progress(refs, journal, startLevel: l.start, floor: l.floor, ceiling: l.ceiling);
}

void main() {
  topicBand = 'grands'; // 12 ans (ADR 0066) : l'entrée des domaines hors école en dépend
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

  test('à 12 ans, la journée ne propose ni les sons ni les suites de maternelle', () {
    final shown = [for (final t in all) if (t.ageless || t.skills.any((s) => s.ref.level >= floor)) t.id];
    // « Les sons » va jusqu'au CM2 (éducation musicale) : proposé à 12 ans, mais sans ses leçons de maternelle (voir plus
    // haut, rien sous le CM2) ; à 13 ans, plus du tout.
    expect(shown, contains('sons'));
    expect(all.firstWhere((t) => t.id == 'sons').skills.any((s) => s.ref.level >= floorForClass(classForAge(13))), isFalse);
    // « Les suites » va jusqu'à la 6e (programme du cycle 3) : proposé à 12 ans, sans ses leçons de maternelle ; à 14 ans,
    // plus du tout.
    expect(shown, contains('motifs'));
    expect(all.firstWhere((t) => t.id == 'motifs').skills.any((s) => s.ref.level >= floorForClass(classForAge(14))), isFalse);
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

  // ADR 0069. Signalé par Antsa le 2026-11-08 : en informatique, à 12 ans, « la première question demande un code que
  // l'enfant n'a jamais vu ». Le code et les échecs ne s'apprennent pas forcément à l'école : on part du début de sa tranche
  // d'âge, le cours d'abord, sans diagnostic sur une notion jamais apprise.
  group('domaines hors école', () {
    final code = all.firstWhere((t) => t.id == 'code');
    final echecs = all.firstWhere((t) => t.id == 'echecs');

    test('code, 12 ans débutant : les programmes écrits de 6e, sans diagnostic sur le robot de CM2', () {
      final p = progressFor(code, classe);
      final first = code.skill(p.newSkill!);
      expect(first.id, 'sequence-instructions');
      expect(first.level, '6e');
      expect(p.checkable(prerequisitesToCheck(first.ref, [for (final s in code.skills) s.ref])), isEmpty);
      expect(code.levelsFor(classe), (floor: levelRank('6e'), start: levelRank('6e'), ceiling: levelRank('3e')));
    });

    test('code, 15 ans débutant : aussi le début des programmes écrits, pas la 3e', () {
      expect(code.skill(progressFor(code, classForAge(15)).newSkill!).id, 'sequence-instructions');
    });

    test('code, 9 ans débutant : le robot depuis le début', () {
      topicBand = 'moyens';
      addTearDown(() => topicBand = 'grands');
      expect(code.skill(progressFor(code, classForAge(9)).newSkill!).level, 'GS');
    });

    test('échecs, 12 ans débutant : la marche des pièces d\'abord, pas la règle du carré', () {
      final p = progressFor(echecs, classe);
      final first = echecs.skill(p.newSkill!);
      expect(first.ref.level, echecs.skills.map((s) => s.ref.level).reduce(min));
      expect(p.checkable(prerequisitesToCheck(first.ref, [for (final s in echecs.skills) s.ref])), isEmpty);
    });

    test('après une leçon apprise, le diagnostic vérifie ce qui a vraiment été appris', () {
      final now = DateTime(2026, 11, 8);
      final journal = [
        for (var i = 0; i < 10; i++)
          Answer(skill: 'sequence-instructions', attempts: 1, correct: true, demonstrated: false, millis: 3000, at: now.add(Duration(minutes: i))),
      ];
      final p = progressFor(code, classe, journal);
      final next = code.skill(p.newSkill!);
      final checked = p.checkable(prerequisitesToCheck(next.ref, [for (final s in code.skills) s.ref]));
      expect(checked.every((id) => !p.belowFloor(id)), isTrue);
    });
  });

  // Éducation musicale du CP au CM2 (programmes des cycles 2 et 3) : un enfant de CM2 n'a plus les sons de maternelle, et
  // sa journée (horaires du CM) fait une place à la musique.
  test('sons, 10 ans (CM2) : rien sous le CE2, des leçons à apprendre, et la musique dans la journée', () {
    final sons = all.firstWhere((t) => t.id == 'sons');
    final cm2 = classForAge(10);
    expect(schoolLevels[cm2], 'CM2');
    final p = progressFor(sons, cm2);
    final level = {for (final s in sons.skills) s.id: s.ref.level};
    for (var d = 0; d < 30; d++) {
      for (final id in p.plan(DateTime(2026, 11, 1 + d))) {
        expect(level[id]!, greaterThanOrEqualTo(floorForClass(cm2)), reason: id);
      }
    }
    expect(p.belowFloor('aigu-grave'), isTrue);
    expect(level[p.newSkill!]!, greaterThanOrEqualTo(levelRank('CM1')));
    final candidates = ['lire', 'compter', 'anglais', 'nature', 'explorer', 'dessin', 'sons'];
    final themes = [
      for (var d = 0; d < 60; d++)
        ...DayPlan.of(DateTime(2026, 9, 1).add(Duration(days: d)), const [], classe: cm2, visible: candidates).items.map((i) => i.theme),
    ];
    expect(themes, contains('sons'));
  });

  // Suites et tableaux jusqu'à la 6e (programmes de maths des cycles 2 et 3) : un enfant de 6e n'a plus les suites de
  // maternelle, et sa journée (horaires du CM et de la 6e) leur fait une place.
  test('suites, 11 ans (6e) : rien sous le CM1, des leçons à apprendre, et les suites dans la journée du CM et de la 6e', () {
    final motifs = all.firstWhere((t) => t.id == 'motifs');
    final sixieme = classForAge(11);
    expect(schoolLevels[sixieme], '6e');
    final p = progressFor(motifs, sixieme);
    final level = {for (final s in motifs.skills) s.id: s.ref.level};
    for (var d = 0; d < 30; d++) {
      for (final id in p.plan(DateTime(2026, 11, 1 + d))) {
        expect(level[id]!, greaterThanOrEqualTo(floorForClass(sixieme)), reason: id);
      }
    }
    expect(p.belowFloor('motif-ab'), isTrue);
    expect(level[p.newSkill!]!, greaterThanOrEqualTo(levelRank('CM1')));
    const candidates = ['lire', 'compter', 'anglais', 'nature', 'explorer', 'dessin', 'motifs'];
    for (final classe in [classForAge(10), sixieme]) {
      final themes = [
        for (var d = 0; d < 60; d++)
          ...DayPlan.of(DateTime(2026, 9, 1).add(Duration(days: d)), const [], classe: classe, visible: candidates).items.map((i) => i.theme),
      ];
      expect(themes, contains('motifs'), reason: schoolLevels[classe]);
    }
  });

  // Demande d'Antsa du 2026-11-12 : « si l'enfant est en 6e, les cours qu'il doit pouvoir voir sont CM1 à 4e ».
  group('la fenêtre de sa classe : deux en dessous, deux au-dessus', () {
    final sixieme = levelRank('6e');
    test('en 6e : du CM1 à la 4e', () {
      expect(schoolLevels[floorForClass(sixieme)], 'CM1');
      expect(schoolLevels[ceilingForClass(sixieme)], '4e');
    });
    for (final t in all.where((t) => !t.ageless)) {
      test('${t.id} : en 6e, rien après la 4e, même quand tout le reste est acquis', () {
        final l = t.levelsFor(sixieme);
        final level = {for (final s in t.skills) s.id: s.ref.level};
        // Tout ce qui est sous le plafond est réussi au test de départ : il ne reste rien à apprendre dans la fenêtre.
        final placed = {for (final s in t.skills) if (s.ref.level <= l.ceiling) s.id};
        final p = Progress([for (final s in t.skills) s.ref], const [],
            startLevel: l.start, floor: l.floor, ceiling: l.ceiling, placed: placed);
        expect(p.newSkill, isNull);
        for (var d = 0; d < 20; d++) {
          for (final id in p.plan(DateTime(2026, 11, 1 + d))) {
            expect(level[id]!, lessThanOrEqualTo(l.ceiling), reason: id);
          }
        }
        for (final s in t.skills.where((s) => s.ref.level > l.ceiling)) {
          expect(p.inRange(s.id), isFalse, reason: s.id);
          expect(p.choosable(s.id, sixieme), isFalse, reason: s.id);
        }
        // Sans rien d'acquis non plus : la leçon à apprendre n'est jamais au-dessus du plafond.
        final fresh = Progress([for (final s in t.skills) s.ref], const [], startLevel: l.start, floor: l.floor, ceiling: l.ceiling);
        if (fresh.newSkill case final id?) expect(level[id]!, lessThanOrEqualTo(l.ceiling), reason: id);
      });
    }
  });

  test('le carnet de 12 ans ne montre plus « Compter jusqu\'à 10 »', () {
    final compter = all.firstWhere((t) => t.id == 'compter');
    final p = progressFor(compter, classe);
    expect(p.belowFloor('denombrer-10'), isTrue);
    expect(compter.skill('denombrer-10').title, 'Compter jusqu\'à 10');
  });

  // ADR 0069 : à partir du CM1, la journée suit les horaires officiels de la classe.
  group('journée selon les horaires officiels', () {
    List<List<String>> days(int classe, List<String> candidates, int n) => [
          for (var d = 0; d < n; d++)
            DayPlan.of(DateTime(2026, 9, 1).add(Duration(days: d)), const [], classe: classe, visible: candidates)
                .items
                .map((i) => i.theme)
                .toList(),
        ];
    const domains = ['lire', 'compter', 'anglais', 'nature', 'explorer', 'code', 'echecs', 'dessin'];

    test('5e : chaque matière en proportion de ses heures, jamais deux fois le même jour', () {
      final plan = days(classForAge(12), domains, 130);
      final w = dayWeights['cycle4']!;
      final total = w.values.reduce((a, b) => a + b);
      final count = <String, int>{};
      for (final d in plan) {
        expect(d.toSet().length, 3);
        for (final t in d) {
          count[t] = (count[t] ?? 0) + 1;
        }
      }
      for (final e in w.entries) {
        expect(count[e.key]! / (130 * 3), closeTo(e.value / total, 0.02), reason: e.key);
      }
      expect(count['dessin'], isNull, reason: 'pas dans la grille du collège');
      // Le français et les maths ne sont plus là tous les jours comme en GS-CP.
      expect(plan.where((d) => d.contains('lire')).length, lessThan(130 * 0.8));
    });

    test('lycée : plus de sciences, le code (SNT) présent', () {
      final plan = days(classForAge(15), domains, 60).expand((d) => d).toList();
      expect(plan.where((t) => t == 'nature').length, greaterThan(plan.where((t) => t == 'anglais').length));
      expect(plan, contains('code'));
    });

    test('GS-CP : le tour de 4 jours ne change pas', () {
      final plan = days(classForAge(6), domains, 4);
      expect(plan.where((d) => d.contains('lire')).length, 3);
    });

    test('un domaine sans leçon à son niveau n\'est pas proposé', () {
      final plan = days(classForAge(12), ['lire', 'compter', 'anglais', 'nature'], 20).expand((d) => d);
      expect(plan.toSet(), {'lire', 'compter', 'anglais', 'nature'});
    });
  });
}
