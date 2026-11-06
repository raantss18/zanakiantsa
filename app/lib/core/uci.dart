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

/// La valeur d'un mat, en centièmes de pion : plus grande que toute autre note.
const mateScore = 10000;

/// La note d'une ligne « info … score cp 35 … » ou « score mate -3 … », du point de vue de celui qui a le trait ; un mat
/// en n coups vaut mateScore - n, « mate 0 » veut dire qu'il est déjà mat. Null si la ligne n'a pas de note.
int? parseScore(String line) {
  final m = RegExp(r'\bscore\s+(cp|mate)\s+(-?\d+)').firstMatch(line);
  if (m == null) return null;
  final v = int.parse(m[2]!);
  if (m[1] == 'cp') return v;
  return v > 0 ? mateScore - v : -mateScore - v;
}

/// Ce qu'une recherche a trouvé : le meilleur coup (null s'il n'y en a plus) et la note de la position.
typedef SearchResult = ({String? best, int score});

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

  /// Une vraie recherche de [nodes] positions (Stockfish, ADR 0053) : le même jugement sur tous les appareils, seule la durée
  /// change. On garde la dernière note annoncée avant le coup.
  Future<SearchResult> search(String fen, {int nodes = 50000, Duration timeout = const Duration(seconds: 20)}) async {
    var score = 0;
    final done = Completer<String>();
    final sub = _lines.listen((l) {
      if (isBestMoveLine(l)) {
        if (!done.isCompleted) done.complete(l);
      } else {
        score = parseScore(l) ?? score;
      }
    });
    try {
      _send('position fen $fen');
      _send('go nodes $nodes');
      final line = await done.future.timeout(timeout);
      return (best: parseBestMove(line), score: score);
    } finally {
      await sub.cancel();
    }
  }

  void quit() => _send('quit');
}
