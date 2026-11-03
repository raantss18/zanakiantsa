import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/numbers.dart';
import 'package:zanakiantsa/audio/sfx.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/chess.dart';
import 'package:zanakiantsa/core/day.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/motif.dart';

Map<String, dynamic> json(String name) => jsonDecode(File('assets/content/$name.json').readAsStringSync()) as Map<String, dynamic>;
List<Topic> topics() => [for (final id in json('domaines')['ordre'] as List) Topic(json(id as String))];

void main() {
  group('Journée en 3 activités (ADR 0018)', () {
    test('les deux journées alternent et couvrent tous les domaines, chacun une fois', () {
      final d = DateTime(2026, 11, 3, 9);
      expect(DayPlan.of(d, const []).items.map((i) => i.theme), isNot(DayPlan.of(d.add(const Duration(days: 1)), const []).items.map((i) => i.theme)));
      expect(DayPlan.of(d, const []).items.map((i) => i.theme), DayPlan.of(d.add(const Duration(days: 2)), const []).items.map((i) => i.theme));
      final all = dayGroups.expand((g) => g).toList();
      expect(all.toSet().length, all.length);
      expect(all.toSet(), (json('domaines')['ordre'] as List).toSet());
    });

    test('le jour change à minuit (date locale), pas 24 h après', () {
      expect(dayNumber(DateTime(2026, 11, 3, 23, 59)) + 1, dayNumber(DateTime(2026, 11, 4, 0, 1)));
    });

    test('temps compté : seulement aujourd\'hui et le bon domaine, séances interrompues comprises', () {
      final now = DateTime(2026, 11, 3, 18);
      final group = DayPlan.of(now, const []).items.map((i) => i.theme).toList();
      SessionLog s(String t, DateTime start, int min, {bool complete = true}) =>
          SessionLog(theme: t, started: start, ended: start.add(Duration(minutes: min)), complete: complete);
      final plan = DayPlan.of(now, [
        s(group[0], DateTime(2026, 11, 2, 10), 30), // hier
        s(group[0], DateTime(2026, 11, 3, 9), 20),
        s(group[0], DateTime(2026, 11, 3, 10), 12, complete: false),
        s(group[1], DateTime(2026, 11, 3, 11), 5),
      ], minutes: 90);
      expect(plan.items[0].done, const Duration(minutes: 32));
      expect(plan.items[0].target, const Duration(minutes: 30));
      expect(plan.items[0].finished, isTrue);
      expect(plan.next!.theme, group[1]);
      expect(plan.items[1].ratio, closeTo(5 / 30, 1e-9));
      expect(plan.finished, isFalse);
    });
  });

  group('Contenu des nouveaux domaines (ADR 0019)', () {
    test('chaque compétence de chaque domaine tire des questions et remplit toutes ses phrases', () {
      final r = Random(3);
      const w = Words(singular: 'fleur', plural: 'fleurs', feminine: true, container: 'le panier', firstName: 'Lila');
      for (final t in topics()) {
        expect(File('assets/art/${t.icon}.svg').existsSync(), isTrue, reason: t.id);
        for (final s in t.skills) {
          Question? last;
          for (var i = 0; i < 200; i++) {
            final q = s.draw(r, last: last);
            if (s.items.length > 1 && last != null) expect(q.n, isNot(last.n), reason: '${s.id} : même question deux fois');
            last = q;
            for (final k in s.phrases.keys) {
              expect(s.say(k, q, words: w), isNot(contains('{')), reason: '${s.id}.$k');
            }
          }
        }
      }
    });

    test('choisir : la bonne image et les autres existent, jamais deux fois la même', () {
      for (final s in topics().expand((t) => t.skills).where((s) => s.activity == 'choisir')) {
        for (final it in s.items) {
          final arts = [it.right!.art, ...it.others.map((p) => p.art)];
          expect(arts.toSet().length, arts.length, reason: it.text);
          for (final a in arts) {
            expect(File('assets/art/$a.svg').existsSync(), isTrue, reason: a);
          }
        }
      }
    });
  });

  group('Motifs', () {
    test('lettres des motifs, dont l\'évolutif ABAABBAAABBB du programme', () {
      expect(motifLetters('AB'), [0, 1, 0, 1, 0, 1, 0, 1]);
      expect(motifLetters('ABB'), [0, 1, 1, 0, 1, 1, 0, 1, 1]);
      expect(motifLetters('AB+').map((l) => 'AB'[l]).join(), 'ABAABBAAABBB');
    });
    test('le trou est dans la 2e moitié, la réponse est proposée, choix tous différents', () {
      final pool = ['a', 'b', 'c', 'd', 'e', 'f'];
      for (final base in ['AB', 'ABB', 'AAB', 'ABC', 'AB+']) {
        for (var i = 0; i < 300; i++) {
          final p = motifPuzzle(base, pool, Random(i));
          expect(p.hole, greaterThanOrEqualTo(p.sequence.length ~/ 2));
          expect(p.choices, contains(p.answer));
          expect(p.choices.toSet().length, p.choices.length);
          expect(p.choices.length, 3);
        }
      }
    });
  });

  group('Échecs (FIDE art. 3)', () {
    test('nombre de cases atteignables', () {
      expect(moves('r', (0, 0)).length, 14);
      expect(moves('r', (3, 4)).length, 14);
      expect(moves('b', (0, 0)).length, 7);
      expect(moves('b', (3, 3)).length, 13);
      expect(moves('q', (3, 3)).length, 27);
      expect(moves('k', (0, 0)).length, 3);
      expect(moves('k', (4, 4)).length, 8);
      expect(moves('n', (0, 0)), {(1, 2), (2, 1)});
      expect(moves('n', (4, 4)).length, 8);
    });
    test('le fou reste sur sa couleur ; le cavalier en change toujours', () {
      for (final to in moves('b', (2, 0))) {
        expect((to.$1 + to.$2).isEven, isTrue);
      }
      for (final to in moves('n', (2, 0))) {
        expect((to.$1 + to.$2).isOdd, isTrue);
      }
    });
    test('un parcours d\'étoiles existe toujours (chaque étoile à un coup de la précédente)', () {
      for (final piece in ['r', 'b', 'q', 'k', 'n']) {
        for (var i = 0; i < 300; i++) {
          final p = starPuzzle(piece, 3, Random(i));
          expect(p.stars.toSet().length, 3);
          expect(p.stars, isNot(contains(p.start)));
          var cur = p.start;
          for (final s in p.stars) {
            expect(moves(piece, cur), contains(s));
            cur = s;
          }
        }
      }
    });
  });

  group('Cours d\'échecs (ADR 0020)', () {
    test('le pion : une ou deux cases au départ, bloqué par une pièce, prise en diagonale avant seulement', () {
      expect(pawnMoves((3, 1), const {}, const {}), {(3, 2), (3, 3)});
      expect(pawnMoves((3, 2), const {}, const {}), {(3, 3)});
      expect(pawnMoves((3, 1), {(3, 2)}, const {}), isEmpty);
      expect(pawnMoves((3, 1), {(2, 2), (4, 0)}, {(2, 2), (4, 0)}), {(3, 2), (3, 3), (2, 2)});
    });
    test('une pièce qui glisse ne saute pas par-dessus une autre ; le cavalier si', () {
      expect(attacks('r', (0, 0), {(0, 3)}).contains((0, 4)), isFalse);
      expect(attacks('r', (0, 0), {(0, 3)}).contains((0, 3)), isTrue);
      expect(attacks('n', (0, 0), {(0, 1), (1, 0), (1, 1)}), {(1, 2), (2, 1)});
    });
    test('mat du couloir : tour en 8e rangée, roi noir en h8 gardé par le roi blanc en h6', () {
      final board = <Square, Piece>{(7, 7): const Piece('k', white: false), (7, 5): const Piece('k'), (0, 7): const Piece('r')};
      expect(blackInCheck(board), isTrue);
      expect(blackMated(board), isTrue);
      final escape = <Square, Piece>{(7, 7): const Piece('k', white: false), (0, 0): const Piece('k'), (0, 7): const Piece('r')};
      expect(blackMated(escape), isFalse, reason: 'le roi noir peut aller en g7 ou h7');
    });
    test('le roi noir peut prendre une tour non protégée qui le met en échec', () {
      final board = <Square, Piece>{(7, 7): const Piece('k', white: false), (0, 0): const Piece('k'), (6, 7): const Piece('r')};
      expect(blackInCheck(board), isTrue);
      expect(blackKingMoves(board), contains((6, 7)));
    });
    test('générateurs : chaque leçon a toujours une solution', () {
      for (var i = 0; i < 150; i++) {
        final r = Random(i);
        for (final p in ['p', 'r', 'n', 'b', 'q']) {
          final (board, targets) = capturePuzzle(p, 3, r);
          var cur = board;
          for (final t in targets) {
            final from = cur.entries.firstWhere((e) => e.value.white).key;
            expect(legalMoves(cur, from), contains(t), reason: '$p prise');
            cur = play(cur, from, t);
          }
        }
        for (final p in ['r', 'b', 'q', 'n']) {
          final b = checkPuzzle(p, r);
          expect(blackInCheck(b), isFalse);
          expect(solutions(b, blackInCheck), isNotEmpty);
        }
        for (final p in ['r', 'q']) {
          final b = matePuzzle(p, r);
          expect(blackInCheck(b), isFalse);
          expect(blackKingMoves(b), isNotEmpty, reason: 'pas de pat au départ');
          expect(solutions(b, blackMated), isNotEmpty);
        }
      }
    });
  });

  group('Calcul cycle 2 (ADR 0021)', () {
    test('trois réponses différentes, positives, dont la bonne', () {
      for (var n = 0; n <= 100; n++) {
        for (var seed = 0; seed < 5; seed++) {
          final c = numberChoices(n, seed, near: [n + 3, n]);
          expect(c, contains(n));
          expect(c.toSet().length, 3);
          expect(c.every((v) => v >= 0), isTrue);
        }
      }
    });
    test('dizaines et unités accordées au singulier', () {
      final s = topics().first.skills.firstWhere((s) => s.id == 'dizaines-lire');
      expect(s.say('bravo', const Question(n: 14, a: 1, b: 4)), 'Oui ! 1 dizaine et 4 unités, cela fait 14.');
      expect(s.say('bravo', const Question(n: 30, a: 3, b: 0)), 'Oui ! 3 dizaines et 0 unité, cela fait 30.');
    });
  });

  group('Sons à comparer', () {
    double peak(List<double> s) => s.map((v) => v.abs()).reduce(max);
    test('fort plus fort que doux, long plus long que court, sans saturation', () {
      final (fort, doux) = listenPair('intensite');
      expect(peak(fort), greaterThan(peak(doux) * 4));
      final (long, court) = listenPair('duree');
      expect(long.length, greaterThan(court.length * 4));
      for (final d in ['hauteur', 'intensite', 'duree', 'tempo']) {
        final (a, b) = listenPair(d);
        expect(max(peak(a), peak(b)), lessThanOrEqualTo(0.6 + 1e-9));
      }
    });
  });
}
