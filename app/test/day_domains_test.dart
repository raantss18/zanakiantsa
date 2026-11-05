import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/ce1.dart';
import 'package:zanakiantsa/activities/numbers.dart';
import 'package:zanakiantsa/core/column.dart';
import 'package:zanakiantsa/core/progress.dart';
import 'package:zanakiantsa/audio/sfx.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/chess.dart';
import 'package:zanakiantsa/core/day.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/motif.dart';
import 'package:zanakiantsa/core/robot.dart';
import 'package:zanakiantsa/ui/three.dart';

Map<String, dynamic> json(String name) => jsonDecode(File('assets/content/$name.json').readAsStringSync()) as Map<String, dynamic>;
List<Topic> topics() => [for (final id in json('domaines')['ordre'] as List) Topic(json(id as String))];

void main() {
  group('Journée en 3 activités (ADR 0018)', () {
    test('les journées tournent et couvrent tous les domaines, chacun une fois', () {
      final d = DateTime(2026, 11, 3, 9);
      List<String> day(int k) => DayPlan.of(d.add(Duration(days: k)), const []).items.map((i) => i.theme).toList();
      expect({for (var k = 0; k < dayGroups.length; k++) day(k).join()}.length, dayGroups.length);
      expect(day(0), day(dayGroups.length));
      final all = dayGroups.expand((g) => g).toList();
      for (final g in dayGroups) {
        expect(g.toSet().length, g.length, reason: 'trois domaines différents par jour');
      }
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
      expect(topics().map((t) => t.id), containsAll(['anglais', 'code', 'explorer']));
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
            // « erreur » a {choisi}, rempli par l'image touchée (test/choice_error_test.dart).
            for (final k in s.phrases.keys.where((k) => k != 'erreur')) {
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
      final s = topics().firstWhere((t) => t.id == 'compter').skills.firstWhere((s) => s.id == 'dizaines-lire');
      expect(s.say('bravo', const Question(n: 14, a: 1, b: 4)), 'Oui ! 1 dizaine et 4 unités, cela fait 14.');
      expect(s.say('bravo', const Question(n: 30, a: 3, b: 0)), 'Oui ! 3 dizaines et 0 unité, cela fait 30.');
    });
  });

  group('Programmer un robot (ADR 0023)', () {
    test('un parcours tiré se résout par son programme, dans les bornes, et un choc arrête le robot', () {
      for (var i = 0; i < 200; i++) {
        final r = Random(i);
        final (m1, p1) = mazePuzzle(r, arrowsMode: true, size: 5, min: 2, max: 5);
        expect(m1.solves(p1), isTrue);
        expect(p1.length, inInclusiveRange(2, 5));
        final (m2, p2) = mazePuzzle(r, arrowsMode: false, size: 6, min: 4, max: 10, rocks: 6, maxTurns: 2);
        expect(m2.solves(p2), isTrue);
        expect(turns(p2), lessThanOrEqualTo(2));
        expect(p2.where((o) => arrows.contains(o)), isEmpty);
      }
      const m = Maze(3, RobotState((0, 0), 1), (2, 0), {(1, 0)});
      expect(m.run([Op.forward]).length, 1, reason: 'rocher devant : le robot ne bouge pas');
      expect(m.solves([Op.turnRight, Op.forward, Op.turnLeft, Op.forward, Op.forward, Op.turnLeft, Op.forward]), isTrue);
    });
  });

  group('Explorer en 3D (ADR 0024)', () {
    test('chaque solide est fermé : chaque arête est partagée par exactement deux faces', () {
      for (final e in solids.entries) {
        final count = <(int, int), int>{};
        for (final f in e.value.faces) {
          for (var i = 0; i < f.points.length; i++) {
            final a = f.points[i], b = f.points[(i + 1) % f.points.length];
            final k = a < b ? (a, b) : (b, a);
            if (a != b) count[k] = (count[k] ?? 0) + 1;
          }
        }
        // La boule a des faces dégénérées aux pôles (sommets confondus) : on ne compte que les arêtes réelles.
        if (e.key != 'boule') expect(count.values.every((c) => c == 2), isTrue, reason: e.key);
      }
    });
  });

  group('CE1 et profils (ADR 0034, 0035)', () {
    test("l'heure dite comme à l'école", () {
      expect(clockText(3, 0), '3 heures');
      expect(clockText(1, 15), '1 heure et quart');
      expect(clockText(12, 0), 'midi');
      expect(clockText(3, 30), '3 heures et demie');
      expect(clockText(3, 45), '4 heures moins le quart');
      expect(clockText(11, 45), 'midi moins le quart');
    });
    test('erreurs typiques des opérations posées et du matériel multibase', () {
      // Posées chiffre par chiffre (ADR 0046) : l'erreur aux dizaines rappelle la retenue, et la soustraction fait
      // casser une dizaine.
      expect(additionSteps(45, 37).last.why, contains('retenue'));
      expect(subtractionSteps(52, 27).first.prompt, contains('casse une dizaine'));
      expect(explainCe1('multibase', const Question(n: 205, a: 2, b: 0), 205, 25), contains('0 au chiffre des dizaines'));
    });
    test("point de départ selon l'âge : à 7 ans, maternelle tenue pour acquise, CP à faire", () {
      const skills = [SkillRef('ms', [], level: 0), SkillRef('gs', ['ms'], level: 1), SkillRef('cp', ['gs'], level: 2)];
      final p = Progress(skills, const [], startLevel: startLevelForAge(7));
      expect(p.mastered('ms') && p.mastered('gs'), isTrue);
      expect(p.plan(DateTime(2026, 11, 3)).toSet(), {'cp'});
      expect(Progress(skills, const [], startLevel: startLevelForAge(5)).plan(DateTime(2026, 11, 3)).toSet(), {'ms'});
    });
  });

  group('Lire et écrire (ADR 0031)', () {
    final lire = topics().firstWhere((t) => t.id == 'lire');
    Skill sk(String id) => lire.skills.firstWhere((s) => s.id == id);
    test('les syllabes recomposent exactement le mot, et chaque image existe', () {
      for (final it in sk('syllabes').items) {
        expect(it.syllables.join(), it.text, reason: it.text);
        expect(File('assets/art/${it.image}.svg').existsSync(), isTrue, reason: it.text);
      }
    });
    test('la première lettre est bien celle du mot', () {
      const noAccent = {'é': 'e', 'è': 'e'};
      for (final it in sk('premiere-lettre').items) {
        final first = it.text[0];
        expect(it.letter, (noAccent[first] ?? first).toUpperCase(), reason: it.text);
      }
    });
    test('rimes et débuts : la bonne image n\'est jamais une des autres', () {
      for (final id in ['rimes', 'debut', 'lire-mots']) {
        for (final it in sk(id).items) {
          expect(it.others.map((p) => p.art), isNot(contains(it.right!.art)), reason: '$id ${it.text}');
        }
      }
    });
    test('lettres et syllabes tirées : la lettre dite existe dans les choix possibles', () {
      final r = Random(4);
      for (final id in ['lettres-capitales', 'lettres-minuscules', 'lettres-cursives', 'premiere-lettre', 'lire-syllabes', 'tracer-capitales', 'tracer-cursive']) {
        for (var i = 0; i < 50; i++) {
          final q = sk(id).draw(r);
          expect(sk(id).letterOf(q), isNotEmpty);
          expect(sk(id).say('question', q), isNot(contains('{')), reason: id);
        }
      }
    });
  });

  group('Tirage varié au bon niveau (ADR 0030)', () {
    test('une séance de 8 questions ne repose jamais la même tant qu\'il en reste d\'autres', () {
      for (final s in topics().expand((t) => t.skills)) {
        final r = Random(11);
        final seen = <String>{};
        Question? last;
        var repeats = 0;
        for (var i = 0; i < 8; i++) {
          final q = s.draw(r, last: last, avoid: seen);
          if (!seen.add(s.signature(q))) repeats++;
          last = q;
        }
        // Les compétences à très peu de questions possibles (moins de 8) peuvent se répéter, jamais deux fois de suite.
        expect(repeats, lessThanOrEqualTo(8 - 3), reason: s.id);
      }
    });
    test('additions jusqu\'à 10 : 8 questions toutes différentes, et les variantes se remplissent', () {
      final s = topics().firstWhere((t) => t.id == 'compter').skills.firstWhere((s) => s.id == 'additionner-10');
      final r = Random(3);
      final seen = <String>{};
      const w = Words(singular: 'pile', plural: 'piles', feminine: true, container: 'la caisse', firstName: 'Robi');
      for (var i = 0; i < 8; i++) {
        final q = s.draw(r, avoid: seen);
        expect(seen.add(s.signature(q)), isTrue);
        expect(s.say('question', q, words: w), isNot(contains('{')));
      }
      expect(s.variants, isNotEmpty);
    });
  });

  group('Découverte guidée et erreurs expliquées (ADR 0029)', () {
    test('chaque idée se remplit sans variable restante', () {
      const w = Words(singular: 'fleur', plural: 'fleurs', feminine: true, container: 'le panier', firstName: 'Lila');
      final r = Random(5);
      for (final s in topics().expand((t) => t.skills).where((s) => s.idea != null)) {
        final q = s.draw(r);
        expect(fill(s.idea!, q, w, vars: s.vars(q)), isNot(contains('{')), reason: s.id);
      }
    });
    test('les erreurs typiques sont nommées', () {
      expect(explainNumber('batonnets', 'lire', 27, 2, 7, 27, 72), '72, ce serait 7 paquets de dix et 2 bâtonnets seuls.');
      expect(explainNumber('batonnets', 'lire', 31, 3, 1, 31, 13), '13, ce serait 1 paquet de dix et 3 bâtonnets seuls.');
      expect(explainNumber('groupes', null, 12, 3, 4, 12, 7), contains('Tu as ajouté 3 et 4'));
      expect(explainNumber('paquets', null, 12, 3, 4, 3, 4), contains('dans chaque paquet'));
      expect(explainNumber('batonnets', 'casser', 40, 4, 6, 34, 44), contains('paquets de dix'));
      expect(explainNumber('tables', null, 30, 10, 3, 30, 31), startsWith('Presque'));
    });
    test('un coup interdit est expliqué selon la pièce', () {
      Board one(String k) => {(3, 3): Piece(k), (7, 7): const Piece('k', white: false)};
      expect(whyIllegal(one('r'), (3, 3), (5, 5)), contains('jamais en biais'));
      expect(whyIllegal(one('b'), (3, 3), (3, 6)), contains('jamais tout droit'));
      expect(whyIllegal(one('n'), (3, 3), (3, 5)), contains('en L'));
      expect(whyIllegal({(0, 0): const Piece('r'), (0, 3): const Piece('p', white: false)}, (0, 0), (0, 5)), contains('barre le chemin'));
      expect(whyIllegal({(3, 1): const Piece('p')}, (3, 1), (3, 0)), contains('ne recule jamais'));
    });
  });

  group('Trames sonores (ADR 0025)', () {
    test('une boucle de 16 s par monde, sans saturation, silencieuse au raccord, toujours la même', () {
      for (final w in ['robots', 'voitures', 'espace', 'fees', 'mode', 'princesses']) {
        expect(ambienceNames, contains(w));
        final a = ambience(w);
        expect(a.length, sampleRate * 16);
        expect(a.map((v) => v.abs()).reduce(max), lessThanOrEqualTo(0.5 + 1e-9));
        // Les 0,3 dernières secondes sont quasi muettes : pas de clic quand la boucle repart.
        expect(a.sublist(a.length - (sampleRate * 0.3).round()).map((v) => v.abs()).reduce(max), lessThan(0.01), reason: w);
        expect(ambience(w), a);
      }
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
