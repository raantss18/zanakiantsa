/// Dialogue avec un moteur d'échecs par le protocole UCI (ADR 0051), sans rien savoir d'où viennent les lignes : c'est
/// ce qui permet de le tester sans moteur. Protocole : « Universal Chess Interface », description publique de Stefan
/// Meyer-Kahlen (https://www.shredderchess.com/download/div/uci.zip, fichier engine-interface.txt) : `uci`, `isready` →
/// `readyok`, `position fen …`, `go nodes 1` → `bestmove e2e4`.
library;

import 'dart:async';

/// Niveaux 1 à 3 : le robot de l'app (core/engine.dart). À partir de 1000 : Maia, qui joue comme les humains de ce
/// classement (1100, 1500, 1900).
const maiaRatings = [1100, 1500, 1900];

bool isMaia(int level) => level >= 1000;

/// Le coup d'une ligne « bestmove e2e4 », « bestmove e7e8q ponder … » ; null pour toute autre ligne ou « (none) ».
String? parseBestMove(String line) =>
    RegExp(r'^\s*bestmove\s+([a-h][1-8][a-h][1-8][qrbn]?)(\s|$)').firstMatch(line)?[1];

bool isBestMoveLine(String line) => line.trimLeft().startsWith('bestmove');

/// Une conversation avec un moteur : [lines] (flux à plusieurs écoutes) arrive du moteur, [send] lui écrit.
class UciSession {
  UciSession(this._lines, this._send);
  final Stream<String> _lines;
  final void Function(String) _send;

  /// `uci` puis `isready` : le moteur charge son réseau et répond `readyok`.
  Future<void> ready({Duration timeout = const Duration(seconds: 30)}) {
    final done = _lines.firstWhere((l) => l.trim() == 'readyok');
    _send('uci');
    _send('isready');
    return done.timeout(timeout);
  }

  /// Le coup du moteur dans la position [fen], sans recherche : un seul nœud, le coup que jouerait un humain de ce
  /// niveau (« a nodes limit of 1 is what we use », README de Maia). Lève une TimeoutException si le moteur ne répond pas.
  Future<String?> bestMove(String fen, {Duration timeout = const Duration(seconds: 15)}) async {
    final reply = _lines.firstWhere(isBestMoveLine);
    _send('position fen $fen');
    _send('go nodes 1');
    return parseBestMove(await reply.timeout(timeout));
  }

  void quit() => _send('quit');
}
