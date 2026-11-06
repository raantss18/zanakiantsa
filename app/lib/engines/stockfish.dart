/// Stockfish 11 (ADR 0053), pour l'analyse fine des parties : programme séparé livré comme `libstockfish.so`, lancé comme un
/// processus à part. Il ne parle avec l'app que par le protocole UCI (voir docs/licences.md).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/uci.dart';

const _channel = MethodChannel('zanakiantsa/system');

class Stockfish {
  Stockfish._(this._process, this._session);
  final Process _process;
  final UciSession _session;

  /// Lance le moteur ; null s'il n'est pas dans cette version (autres processeurs que arm64) ou ne répond pas.
  static Future<Stockfish?> start() async {
    try {
      final dirs = await _channel.invokeMapMethod<String, String>('engineDirs');
      if (dirs == null) return null;
      final exe = File('${dirs['lib']}/libstockfish.so');
      if (!await exe.exists()) return null;
      final p = await Process.start(exe.path, const [], workingDirectory: dirs['files']);
      final lines = p.stdout.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
      p.stderr.drain<void>();
      final session = UciSession(lines, p.stdin.writeln);
      try {
        await session.ready();
      } catch (_) {
        p.kill();
        rethrow;
      }
      // Un seul fil et un petit cache : l'app reste fluide et la mémoire basse pendant l'analyse.
      p.stdin.writeln('setoption name Threads value 1');
      p.stdin.writeln('setoption name Hash value 16');
      return Stockfish._(p, session);
    } catch (e) {
      debugPrint('Stockfish indisponible : $e');
      return null;
    }
  }

  Future<SearchResult> search(String fen) => _session.search(fen);

  void dispose() {
    try {
      _session.quit();
    } catch (_) {}
    // Aucun programme ne doit rester en vie une fois la page fermée.
    Timer(const Duration(seconds: 1), _process.kill);
  }
}
