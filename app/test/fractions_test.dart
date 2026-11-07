import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/fractions.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/fractions.dart';

// Les fractions (ADR 0056) : les mots, les réponses proposées, l'explication de chaque erreur, le toucher sur la figure.
void main() {
  group('les mots', () {
    test('demi, tiers, quart et pluriels', () {
      expect(fracWords(1, 2), 'un demi');
      expect(fracWords(1, 3), 'un tiers');
      expect(fracWords(2, 3), 'deux tiers');
      expect(fracWords(3, 4), 'trois quarts');
      expect(fracWords(3, 8), 'trois huitièmes');
      expect(fracWords(7, 2), 'sept demis');
      expect(fracSumWords(const Frac(3, 4, whole: 1)), '1 plus trois quarts');
    });
  });

  group('les réponses proposées', () {
    test('toujours trois, dont la bonne, sans doublon', () {
      final r = Random(1);
      for (var d = 2; d <= 10; d++) {
        for (var n = 1; n < d; n++) {
          for (final c in [readChoices(n, d, r), sumChoices(1, n, d, r)]) {
            expect(c.toSet().length, 3, reason: '$n/$d : $c');
          }
          expect(readChoices(n, d, r), contains(Frac(n, d)));
          expect(sumChoices(1, n, d, r), contains(Frac(1 + n, d)));
        }
        for (var n = d + 1; n < 3 * d; n++) {
          if (n % d == 0) continue;
          final c = wholeChoices(n, d, r);
          expect(c.toSet().length, 3);
          expect(c, contains(Frac(n % d, d, whole: n ~/ d)));
        }
      }
    });

    test('quantité : la bonne réponse est là, et aucune réponse nulle', () {
      final r = Random(2);
      for (final d in [2, 3, 4, 5]) {
        for (var k = 2; k <= 6; k++) {
          final c = quantityChoices(k, k * d, d, r);
          expect(c.toSet().length, 3, reason: '$k de ${k * d} : $c');
          expect(c, contains(k));
          expect(c.every((x) => x > 0), isTrue);
        }
      }
    });
  });

  group('chaque erreur est expliquée', () {
    test('lire : parts blanches, fraction à l\'envers', () {
      expect(readWhy(const Frac(3, 8), const Frac(5, 8)), contains('parts blanches'));
      expect(readWhy(const Frac(3, 8), const Frac(8, 3)), contains('En bas'));
    });

    test('ajouter : on n\'ajoute pas les dénominateurs', () {
      expect(sumWhy(const Frac(3, 5), const Frac(3, 10)), contains('le dénominateur ne change pas'));
    });

    test('un cinquième est plus petit qu\'un tiers, malgré 3 < 5', () {
      expect(unitCompareWhy(3, 5), startsWith('Un cinquième, c\'est plus petit que un tiers'));
    });

    test('au-delà de 1 : l\'entier, puis le reste', () {
      expect(wholeWhy(const Frac(3, 4, whole: 1), const Frac(3, 4, whole: 2)), contains('bandes'));
      expect(wholeWhy(const Frac(3, 4, whole: 1), const Frac(1, 4, whole: 1)), contains('dernière bande'));
    });

    test('colorier : trop ou pas assez ; placer : le bout de la bande', () {
      expect(colorWhy(2, 3, 8), contains('Il en faut plus'));
      expect(colorWhy(5, 3, 8), contains('trop'));
      expect(placeWhy(4, 3, 4), contains('la bande entière'));
    });
  });

  group('le toucher sur la figure', () {
    const s = Size(300, 300);
    test('bande : de gauche à droite', () {
      expect(partAt(const Offset(10, 50), const Size(300, 96), 3, disk: false), 0);
      expect(partAt(const Offset(150, 50), const Size(300, 96), 3, disk: false), 1);
      expect(partAt(const Offset(299, 50), const Size(300, 96), 3, disk: false), 2);
      expect(partAt(const Offset(150, 200), const Size(300, 96), 3, disk: false), isNull);
    });

    test('disque : depuis midi, dans le sens des aiguilles d\'une montre', () {
      expect(partAt(const Offset(200, 50), s, 4, disk: true), 0);
      expect(partAt(const Offset(200, 250), s, 4, disk: true), 1);
      expect(partAt(const Offset(100, 250), s, 4, disk: true), 2);
      expect(partAt(const Offset(100, 50), s, 4, disk: true), 3);
      expect(partAt(const Offset(2, 2), s, 4, disk: true), isNull, reason: 'dans le coin, hors du disque');
    });
  });

  test('toutes les questions tirées sont justes, et jamais deux fractions égales à comparer', () {
    final j = jsonDecode(File('assets/content/compter.json').readAsStringSync()) as Map<String, dynamic>;
    final skills = [for (final s in j['competences'] as List) Skill(Map<String, dynamic>.from(s as Map))].where((s) => s.activity == 'fraction').toList();
    expect(skills.length, 9);
    final r = Random(3);
    for (final s in skills) {
      for (var i = 0; i < 300; i++) {
        final q = s.draw(r);
        final mode = s.params['mode'];
        expect(q.b, greaterThanOrEqualTo(2));
        switch (mode) {
          case 'comparer':
            expect(q.a != q.n, isTrue);
            expect(q.a < q.b && q.n < q.b, isTrue);
          case 'comparer_unitaires':
            expect(q.a != q.b, isTrue);
          case 'additionner':
            expect(q.n <= q.b && q.a >= 1 && q.n - q.a >= 1, isTrue, reason: '${q.a}+${q.n - q.a}/${q.b}');
          case 'superieure':
            expect(q.n > q.b && q.n % q.b != 0, isTrue);
          case 'quantite':
            expect(q.a, q.n * q.b);
            expect(q.a, lessThanOrEqualTo(30));
          default:
            expect(q.n >= 1 && q.n < q.b || q.n == 1, isTrue);
        }
        for (final k in ['question', 'consigne', 'indice', 'exemple', 'demonstration', 'bravo']) {
          expect(s.say(k, q), isNot(contains('{')), reason: '${s.id}/$k');
        }
      }
    }
  });
}
