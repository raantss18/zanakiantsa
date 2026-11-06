import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/deep_analysis.dart';
import 'package:zanakiantsa/core/engine.dart';
import 'package:zanakiantsa/core/game.dart';
import 'package:zanakiantsa/core/uci.dart';

// L'analyse fine avec Stockfish (ADR 0053), testée sans le moteur : le dialogue UCI et les règles de jugement.
void main() {
  group('notes UCI', () {
    test('centièmes de pion et mats, du point de vue du joueur', () {
      expect(parseScore('info depth 9 score cp 35 nodes 10 pv e2e4'), 35);
      expect(parseScore('info depth 9 score cp -120 lowerbound pv e2e4'), -120);
      expect(parseScore('info depth 3 score mate 2 pv d1d8'), mateScore - 2);
      expect(parseScore('info depth 3 score mate -3 pv d1d8'), -mateScore + 3);
      expect(parseScore('info depth 0 score mate 0'), -mateScore);
      expect(parseScore('info string NNUE'), isNull);
    });

    test('la recherche garde la dernière note et rend le coup', () async {
      final out = StreamController<String>.broadcast(sync: true);
      final sent = <String>[];
      final session = UciSession(out.stream, (l) {
        sent.add(l);
        if (l.startsWith('go ')) {
          out.add('info depth 1 score cp 10 pv e2e4');
          out.add('info depth 2 score cp 42 pv d2d4');
          out.add('bestmove d2d4 ponder d7d5');
        }
      });
      final r = await session.search(startFen, nodes: 500);
      expect(r.best, 'd2d4');
      expect(r.score, 42);
      expect(sent.last, 'go nodes 500');
    });

    test('plus de coup possible (mat, pat) : pas de coup, mais une note', () async {
      final out = StreamController<String>.broadcast(sync: true);
      final session = UciSession(out.stream, (l) {
        if (l.startsWith('go ')) {
          out.add('info depth 0 score mate 0');
          out.add('bestmove (none)');
        }
      });
      final r = await session.search(startFen);
      expect(r.best, isNull);
      expect(r.score, -mateScore);
    });
  });

  group('jugement d\'un coup', () {
    final p = Position.start();
    final e4 = Move.parse('e2e4');
    SearchResult s(int score, [String? best]) => (best: best, score: score);

    test('une vraie perte : on montre le meilleur coup', () {
      final n = judgeFine(p, e4, 0, s(50, 'd2d4'), s(150), null)!;
      expect(n.kind, 'fort');
      expect(n.better, 'd2d4');
      expect(n.text, contains('d4'));
    });

    test('petite perte, ou le meilleur coup joué : rien à dire', () {
      expect(judgeFine(p, e4, 0, s(50, 'd2d4'), s(-20), null), isNull);
      expect(judgeFine(p, e4, 0, s(50, 'e2e4'), s(150), null), isNull);
      expect(judgeFine(p, e4, 0, s(50, 'd2d4'), s(fineErrorLoss - 51), null), isNull);
    });

    test('partie déjà décidée : on ne fait pas de reproche', () {
      expect(judgeFine(p, e4, 0, s(900, 'd2d4'), s(-500), null), isNull, reason: 'encore 5 pions d\'avance');
      expect(judgeFine(p, e4, 0, s(-500, 'd2d4'), s(900), null), isNull, reason: 'déjà perdue');
    });

    test('fausse alerte de la petite recherche : retirée ; un bon coup reste salué', () {
      final gaffe = MoveNote(0, 'gaffe', 'pièce en prise');
      final bien = MoveNote(0, 'bien', 'très bien');
      expect(judgeFine(p, e4, 0, s(50, 'e2e4'), s(-50), gaffe), isNull);
      expect(judgeFine(p, e4, 0, s(50, 'e2e4'), s(-50), bien), same(bien));
    });

    test('une erreur déjà expliquée garde son explication', () {
      final gaffe = MoveNote(0, 'gaffe', 'pièce en prise');
      expect(judgeFine(p, e4, 0, s(50, 'd2d4'), s(400), gaffe), same(gaffe));
    });

    test('mat manqué proche, mat permis ; un mat lointain n\'est pas reproché', () {
      var n = judgeFine(p, e4, 0, s(mateScore - 2, 'd2d4'), s(-200), null)!;
      expect(n.text, contains('échec et mat en 2 coups'));
      n = judgeFine(p, e4, 0, s(20, 'd2d4'), s(mateScore - 1), null)!;
      expect(n.kind, 'mat_permis');
      expect(n.text, contains('échec et mat en 1 coup.'));
      expect(judgeFine(p, e4, 0, s(mateScore - 9, 'd2d4'), s(-600), null), isNull);
    });

    test('un mat permis remplace « fait perdre du matériel » (vu sur 1.f3 e5 2.g4 Dh4#)', () {
      final gaffe = MoveNote(0, 'gaffe', 'e4 fait perdre du matériel.');
      final n = judgeFine(p, e4, 0, s(-30, 'd2d4'), s(mateScore - 1), gaffe)!;
      expect(n.kind, 'mat_permis');
      expect(n.text, isNot(contains('matériel')));
    });

    test('déjà maté de toute façon : pas de reproche de mat permis', () {
      expect(judgeFine(p, e4, 0, s(-mateScore + 2, 'd2d4'), s(mateScore - 1), null), isNull);
    });

    test('un coup du moteur illégal ne s\'affiche jamais', () {
      expect(judgeFine(p, e4, 0, s(50, 'a1a8'), s(400), null), isNull);
    });
  });

  group('partie entière', () {
    test('seuls les coups de l\'enfant sont jugés ; le mat ne demande pas au moteur', () async {
      final asked = <String>[];
      final moves = ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'];
      final base = [for (final j in analyseGame((startFen, moves, true))) MoveNote.fromJson(j)];
      final done = <double>[];
      final n = await deepAnalyse(
        fen: startFen,
        moves: moves,
        white: true,
        base: base,
        search: (f) async {
          asked.add(f);
          return (best: null, score: 0);
        },
        onProgress: done.add,
      );
      expect(n.where((x) => x.kind == 'mat').length, 1);
      expect(asked.length, 6, reason: 'e4, Dh5, Fc4 : deux recherches chacun ; Dxf7# aucune');
      expect(done.last, 1.0);
    });

    test('page fermée : on s\'arrête et on rend les commentaires de base', () async {
      var asked = 0;
      final base = [MoveNote(0, 'bien', 'ok')];
      final n = await deepAnalyse(
        fen: startFen,
        moves: const ['e2e4', 'e7e5'],
        white: true,
        base: base,
        cancelled: () => true,
        search: (f) async {
          asked++;
          return (best: null, score: 0);
        },
      );
      expect(n, same(base));
      expect(asked, 0);
    });

    test('le moteur cale : l\'erreur remonte, l\'appelant garde la base', () {
      expect(
        deepAnalyse(fen: startFen, moves: const ['e2e4'], white: true, base: const [], search: (f) => Future.error(TimeoutException('muet'))),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  test('Stockfish 11 est livré, avec sa recette et sa licence', () {
    final so = File('android/app/src/main/jniLibs/arm64-v8a/libstockfish.so');
    expect(so.existsSync(), isTrue);
    expect(so.lengthSync(), lessThan(1500000), reason: 'budget de l\'APK');
    expect(File('../tool/build_stockfish.sh').readAsStringSync(), contains('c3483fa9a7d7c0ffa9fcc32b467ca844cfb63790'));
    expect(File('../docs/moteurs/stockfish-COPYING.txt').readAsStringSync(), contains('GNU GENERAL PUBLIC LICENSE'));
  });
}
