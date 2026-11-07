import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/day.dart';
import 'package:zanakiantsa/core/progress.dart';

// Sans âge maximum (ADR 0057) : la classe suit l'âge ou le choix du parent, les leçons s'adaptent, rien ne change pour les petits.
void main() {
  group('âge et classe', () {
    test('rien ne change jusqu\'à 10 ans : mêmes points de départ qu\'avant', () {
      expect([for (var a = 5; a <= 10; a++) startLevelForAge(a)], [0, 1, 2, 3, 4, 5]);
    });

    test('la classe suit l\'âge, sans plafond', () {
      expect(schoolLevels[classForAge(5)], 'GS');
      expect(schoolLevels[classForAge(7)], 'CE1');
      expect(schoolLevels[classForAge(11)], '6e');
      expect(schoolLevels[classForAge(14)], '3e');
      expect(schoolLevels[classForAge(17)], 'Terminale');
      expect(schoolLevels[classForAge(40)], 'Après le lycée');
    });

    test('les rangs des anciens niveaux n\'ont pas bougé', () {
      expect([for (final l in ['PS', 'MS', 'GS', 'CP', 'CE1', 'CE2', 'CM1', 'CM2']) levelRank(l)], [0, 0, 1, 2, 3, 4, 5, 6]);
      expect(levelRank('5e'), 8);
    });
  });

  group('un grand a toujours quelque chose à apprendre', () {
    const small = [SkillRef('a', [], level: 0), SkillRef('b', ['a'], level: 1)];
    test('le départ ne dépasse jamais le plus haut niveau du domaine', () {
      expect(startLevelIn(small, 9), 1);
      expect(startLevelIn(small, 0), 0);
      final p = Progress(small, const [], startLevel: startLevelIn(small, 9));
      expect(p.newSkill, 'b', reason: 'la compétence la plus avancée reste à apprendre');
    });
  });

  group('la journée d\'un grand', () {
    const tops = {'lire': 6, 'compter': 9, 'dessin': 2, 'sons': 1, 'code': 6};
    test('un domaine trop en dessous laisse la place au plus avancé', () {
      expect(adaptGroup(['lire', 'sons', 'dessin'], tops, 8), ['lire', 'compter', 'code']);
    });

    test('rien ne change pour un petit, ni de domaine en double', () {
      expect(adaptGroup(['lire', 'sons', 'dessin'], tops, 3), ['lire', 'sons', 'dessin']);
      final g = adaptGroup(['lire', 'sons', 'dessin'], tops, 14);
      expect(g.toSet().length, 3);
    });

    test('sans information, la journée habituelle', () {
      expect(DayPlan.of(DateTime(2026, 11, 7), const []).items.length, 3);
    });
  });

  test('questions écrites : toujours la bonne réponse et deux explications, justes', () {
    final t = Topic(jsonDecode(File('assets/content/compter.json').readAsStringSync()) as Map<String, dynamic>);
    final quiz = t.skills.where((s) => s.activity == 'quiz').toList();
    expect(quiz.map((s) => s.id).toSet(), containsAll(['pourcentages', 'relatifs-additionner', 'racine-carree']));
    final r = Random(1);
    for (final s in quiz) {
      expect(s.items.length, greaterThanOrEqualTo(8), reason: s.id);
      for (final i in s.items) {
        expect(i.name, isNotNull);
        expect(i.traps.length, greaterThanOrEqualTo(2));
        expect({i.name, for (final x in i.traps) x.text}.length, i.traps.length + 1, reason: i.text);
        expect(i.traps.every((x) => x.why.isNotEmpty), isTrue);
      }
      for (final k in s.phrases.keys) {
        expect(s.say(k, s.draw(r)), isNot(contains('{')), reason: '${s.id}.$k');
      }
    }
    // Quelques réponses recalculées ici, pour ne pas seulement relire le contenu.
    String answer(String id, String text) => t.skills.firstWhere((s) => s.id == id).items.firstWhere((i) => i.text == text).name!;
    expect(answer('pourcentages', 'Combien font 25 % de 80 ?'), '20');
    expect(answer('fraction-entier', 'Combien font 3/4 de 20 ?'), '15');
    expect(answer('relatifs-additionner', '(−5) + 3 = ?'), '−2');
    expect(answer('relatifs-multiplier', '(−7) × (−2) = ?'), '14');
    expect(answer('puissances-carre', 'Combien fait 7² ?'), '49');
    expect(answer('racine-carree', 'Quelle est la racine carrée de 144 ?'), '12');
    expect(answer('equation-premier-degre', 'Résous : 3x + 4 = 19'), 'x = 5');
    expect(answer('pythagore', 'Un triangle rectangle a des côtés de l’angle droit de 6 cm et 8 cm. Combien mesure l’hypoténuse ?'), '10 cm');
    expect(answer('fraction-irreductible', 'Rends irréductible la fraction 24/36.'), '2/3');
    expect(answer('notation-scientifique', 'Écris 45 000 en notation scientifique.'), '4,5 × 10⁴');
    expect(answer('identites-remarquables', 'Développe (x + 3)²'), 'x² + 6x + 9');
    expect(answer('equation-produit-nul', 'Résous : (x − 2)(x + 5) = 0'), 'x = 2 ou x = −5');
  });

  test('français : quelques formes vérifiées à la main (programme du cycle 3)', () {
    final t = Topic(jsonDecode(File('assets/content/lire.json').readAsStringSync()) as Map<String, dynamic>);
    String answer(String id, String text) => t.skills.firstWhere((s) => s.id == id).items.firstWhere((i) => i.text == text).name!;
    expect(answer('imparfait', 'Conjugue « faire » à l’imparfait, avec « nous ».'), 'nous faisions');
    expect(answer('futur', 'Conjugue « venir » au futur, avec « vous ».'), 'vous viendrez');
    expect(answer('conditionnel', 'Conjugue « vouloir » au conditionnel présent, avec « je ».'), 'je voudrais');
    expect(answer('passe-simple', 'Conjugue « faire » au passé simple, avec « ils ».'), 'ils firent');
    expect(answer('imperatif', 'Donne l’ordre avec « aller », à la personne « tu ».'), 'Va');
    expect(answer('participe-passe-etre', 'Accorde le participe passé : Paul et Léa sont (sorti).'), 'sortis');
    expect(answer('attribut-ou-cod', 'Dans « Le chat semble fatigué. », quelle est la fonction de « fatigué » ?'), 'attribut du sujet');
  });
}
