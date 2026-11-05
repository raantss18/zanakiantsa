/// Maia, le robot qui joue comme les humains (ADR 0051) : le programme lc0 (GPL-3), livré comme bibliothèque native
/// `liblc0.so`, lancé comme un processus à part, avec les poids Maia-1 d'un niveau. Aucune bibliothèque n'est liée à
/// l'app : les deux ne se parlent que par le protocole UCI (voir docs/licences.md).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/uci.dart';

const _channel = MethodChannel('zanakiantsa/system');

class Maia {
  Maia._(this.rating, this._process, this._session);
  final int rating;
  final Process _process;
  final UciSession _session;

  /// Le programme est-il dans cette version de l'app ? Non sur les autres processeurs que arm64 : le robot de l'app joue
  /// alors à la place.
  static Future<bool> available() async {
    try {
      final dirs = await _channel.invokeMapMethod<String, String>('engineDirs');
      return dirs != null && await File('${dirs['lib']}/liblc0.so').exists();
    } catch (_) {
      return false;
    }
  }

  /// Lance lc0 avec les poids de [rating] ; null si quoi que ce soit échoue.
  static Future<Maia?> start(int rating) async {
    try {
      final dirs = await _channel.invokeMapMethod<String, String>('engineDirs');
      if (dirs == null) return null;
      final exe = File('${dirs['lib']}/liblc0.so');
      if (!await exe.exists()) return null;
      // Les poids sont dans l'app : on les pose sur le disque (lc0 lit un fichier), une fois.
      final asset = (await rootBundle.load('assets/echecs/maia-$rating.pb.gz'));
      final weights = File('${dirs['files']}/maia-$rating.pb.gz');
      if (!await weights.exists() || await weights.length() != asset.lengthInBytes) {
        await weights.writeAsBytes(asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes), flush: true);
      }
      // Un seul fil, un petit cache : une tablette de 4 Go ne doit pas ralentir l'app.
      final p = await Process.start(
        exe.path,
        ['--weights=${weights.path}', '--backend=eigen', '--threads=1', '--nncache=1000'],
        workingDirectory: dirs['files'],
      );
      final lines = p.stdout.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
      p.stderr.drain<void>();
      final session = UciSession(lines, p.stdin.writeln);
      try {
        await session.ready();
      } catch (_) {
        p.kill();
        rethrow;
      }
      return Maia._(rating, p, session);
    } catch (e) {
      debugPrint('Maia indisponible : $e');
      return null;
    }
  }

  /// Le coup de Maia (UCI) ; null s'il ne répond pas à temps.
  Future<String?> bestMove(String fen) async {
    try {
      return await _session.bestMove(fen);
    } catch (e) {
      debugPrint('Maia sans réponse : $e');
      return null;
    }
  }

  void dispose() {
    try {
      _session.quit();
    } catch (_) {}
    // S'il n'a pas quitté de lui-même, on l'arrête : aucun programme ne doit rester en vie quand la partie est finie.
    Timer(const Duration(seconds: 1), _process.kill);
  }
}
