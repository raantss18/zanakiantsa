import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/game.dart';
import 'package:zanakiantsa/core/uci.dart';

// Maia et lc0 dans l'app (ADR 0051) : le dialogue UCI, et ce qui est livré dans l'APK.
Future<String> sha256Of(String path) async =>
    (await Sha256().hash(Uint8List.fromList(File(path).readAsBytesSync()))).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Un faux moteur : il répond comme lc0 (UCI) à ce qu'on lui écrit.
class FakeEngine {
  final out = StreamController<String>.broadcast();
  final received = <String>[];
  String bestmove = 'bestmove e7e5';
  bool silent = false;

  void send(String line) {
    received.add(line);
    if (silent) return;
    if (line == 'isready') {
      out.add('Loading weights file from: maia-1100.pb.gz');
      out.add('readyok');
    }
    if (line.startsWith('go ')) {
      out.add('info depth 1 seldepth 1 time 119 nodes 1 score cp 149 pv e7e5');
      out.add(bestmove);
    }
  }
}

void main() {
  group('protocole UCI', () {
    test('on lit le coup, promotion comprise ; pas de coup, pas de réponse', () {
      expect(parseBestMove('bestmove e2e4'), 'e2e4');
      expect(parseBestMove('bestmove e7e8q ponder a1a2'), 'e7e8q');
      expect(parseBestMove('bestmove (none)'), isNull);
      expect(parseBestMove('info depth 1 nodes 1 pv e2e4'), isNull);
      expect(parseBestMove('bestmove e2e4junk'), isNull);
    });

    test('poignée de main, puis une position et un seul nœud', () async {
      final e = FakeEngine();
      final s = UciSession(e.out.stream, e.send);
      await s.ready();
      final move = await s.bestMove('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      expect(move, 'e7e5');
      expect(e.received, [
        'uci',
        'isready',
        'position fen rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
        'go nodes 1',
      ]);
    });

    test('un moteur muet ne bloque pas : on attend au plus le délai donné', () async {
      final e = FakeEngine()..silent = true;
      final s = UciSession(e.out.stream, e.send);
      await expectLater(s.ready(timeout: const Duration(milliseconds: 100)), throwsA(isA<TimeoutException>()));
      await expectLater(s.bestMove(Position.start().fen, timeout: const Duration(milliseconds: 100)), throwsA(isA<TimeoutException>()));
    });

    test('les niveaux : 1 à 3 pour le robot de l\'app, 1100 et plus pour Maia', () {
      expect([1, 2, 3].any(isMaia), isFalse);
      expect(maiaRatings.every(isMaia), isTrue);
    });
  });

  group('ce qui est livré', () {
    test('lc0 est une bibliothèque ELF arm64, et ses sources sont citées', () async {
      final so = File('android/app/src/main/jniLibs/arm64-v8a/liblc0.so').readAsBytesSync();
      expect(so.sublist(0, 4), [0x7f, 0x45, 0x4c, 0x46]); // ELF
      expect(so[4], 2); // 64 bits
      expect(so[18] | (so[19] << 8), 183); // EM_AARCH64
      expect(File('../tool/build_lc0.sh').readAsStringSync(), contains('fd71a2d921b689c5f479d3227c3806c8e272d9c5'));
      expect(File('../docs/moteurs/lc0-COPYING.txt').readAsStringSync(), contains('GNU GENERAL PUBLIC LICENSE'));
    });

    test('les poids Maia sont ceux de la version publiée v1.0 (sommes de contrôle)', () async {
      const expected = {
        1100: 'e1cf1cd0c96b8a4fa6a275f4b9fd54ed1ffebf9fe44641b9fceded310e9619c4',
        1500: '35ab6f20421d59e1df3b17c5a5016947af4c6761368ef84044a9a9c7619a9a00',
        1900: 'e2f565f42d7cd9f122557e6dc4eb84e5bbaedceda1d404dc485d3611c7c97a12',
      };
      expect(expected.keys, containsAll(maiaRatings));
      for (final e in expected.entries) {
        expect(await sha256Of('assets/echecs/maia-${e.key}.pb.gz'), e.value, reason: 'maia-${e.key}');
      }
    });

    test('le moteur est extrait sur le disque (sinon Android ne peut pas le lancer)', () {
      expect(File('android/app/build.gradle.kts').readAsStringSync(), contains('useLegacyPackaging = true'));
    });
  });
}
