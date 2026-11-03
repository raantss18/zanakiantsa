/// Règles complètes des échecs pour jouer de vraies parties (ADR 0040), d'après les FIDE Laws of Chess (2023) :
/// déplacements (art. 3), roque (3.8.2), prise en passant (3.7.4.1), promotion (3.7.5), échec et mat (5.1.1), pat
/// (5.2.1), nulle par matériel insuffisant (5.2.2), triple répétition (9.2) et 50 coups (9.3). Le petit moteur des
/// leçons (`chess.dart`) reste tel quel. Écrit pour l'app (aucun code repris).
library;

/// Une case : 0 = a1, 7 = h1, 56 = a8, 63 = h8.
String squareName(int s) => '${'abcdefgh'[s % 8]}${s ~/ 8 + 1}';
int squareOf(String name) => (name.codeUnitAt(1) - 49) * 8 + name.codeUnitAt(0) - 97;

/// Pièces : majuscule blanche, minuscule noire (P N B R Q K), comme la notation FEN.
bool isWhitePiece(String p) => p == p.toUpperCase();

class Move {
  const Move(this.from, this.to, {this.promo});
  final int from, to;

  /// Promotion : q, r, b ou n.
  final String? promo;

  String get uci => '${squareName(from)}${squareName(to)}${promo ?? ''}';

  static Move parse(String uci) =>
      Move(squareOf(uci.substring(0, 2)), squareOf(uci.substring(2, 4)), promo: uci.length > 4 ? uci[4] : null);

  @override
  bool operator ==(Object other) => other is Move && other.from == from && other.to == to && other.promo == promo;
  @override
  int get hashCode => Object.hash(from, to, promo);
  @override
  String toString() => uci;
}

const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _knight = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)];
const _king = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)];
const _rook = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const _bishop = [(1, 1), (1, -1), (-1, 1), (-1, -1)];

int? _step(int s, (int, int) d) {
  final f = s % 8 + d.$1, r = s ~/ 8 + d.$2;
  return f < 0 || f > 7 || r < 0 || r > 7 ? null : r * 8 + f;
}

/// Une position : pièces, trait, droits de roque, case de prise en passant, compteurs.
class Position {
  Position(this.board, {required this.whiteToMove, this.castling = '', this.ep, this.halfmove = 0, this.fullmove = 1});

  factory Position.start() => Position.fen(startFen);

  factory Position.fen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    final board = List<String?>.filled(64, null);
    final ranks = parts[0].split('/');
    for (var i = 0; i < 8; i++) {
      var f = 0;
      for (final ch in ranks[i].split('')) {
        final n = int.tryParse(ch);
        if (n != null) {
          f += n;
        } else {
          board[(7 - i) * 8 + f] = ch;
          f++;
        }
      }
    }
    return Position(
      board,
      whiteToMove: parts.length < 2 || parts[1] == 'w',
      castling: parts.length > 2 && parts[2] != '-' ? parts[2] : '',
      ep: parts.length > 3 && parts[3] != '-' ? squareOf(parts[3]) : null,
      halfmove: parts.length > 4 ? int.parse(parts[4]) : 0,
      fullmove: parts.length > 5 ? int.parse(parts[5]) : 1,
    );
  }

  final List<String?> board;
  final bool whiteToMove;
  final String castling;
  final int? ep;
  final int halfmove, fullmove;

  String get fen {
    final rows = <String>[];
    for (var r = 7; r >= 0; r--) {
      var row = '', empty = 0;
      for (var f = 0; f < 8; f++) {
        final p = board[r * 8 + f];
        if (p == null) {
          empty++;
        } else {
          if (empty > 0) row += '$empty';
          empty = 0;
          row += p;
        }
      }
      rows.add(empty > 0 ? '$row$empty' : row);
    }
    return '${rows.join('/')} ${whiteToMove ? 'w' : 'b'} ${castling.isEmpty ? '-' : castling} '
        '${ep == null ? '-' : squareName(ep!)} $halfmove $fullmove';
  }

  /// La position sans les compteurs : deux positions « identiques » au sens de la répétition (art. 9.2).
  String get key => fen.split(' ').take(4).join(' ');

  bool _mine(String? p, bool white) => p != null && isWhitePiece(p) == white;

  int? kingOf(bool white) {
    final k = white ? 'K' : 'k';
    for (var s = 0; s < 64; s++) {
      if (board[s] == k) return s;
    }
    return null;
  }

  /// La case [s] est-elle attaquée par le camp [byWhite] ?
  bool attacked(int s, {required bool byWhite}) {
    String up(String p) => byWhite ? p : p.toLowerCase();
    // Pions : un pion blanc attaque en montant, donc on regarde en dessous de la case.
    for (final df in [-1, 1]) {
      final from = _step(s, (df, byWhite ? -1 : 1));
      if (from != null && board[from] == up('P')) return true;
    }
    for (final d in _knight) {
      final t = _step(s, d);
      if (t != null && board[t] == up('N')) return true;
    }
    for (final d in _king) {
      final t = _step(s, d);
      if (t != null && board[t] == up('K')) return true;
    }
    bool slide(List<(int, int)> dirs, String a, String b) {
      for (final d in dirs) {
        var t = _step(s, d);
        while (t != null) {
          final p = board[t];
          if (p != null) {
            if (p == up(a) || p == up(b)) return true;
            break;
          }
          t = _step(t, d);
        }
      }
      return false;
    }

    return slide(_rook, 'R', 'Q') || slide(_bishop, 'B', 'Q');
  }

  bool get inCheck {
    final k = kingOf(whiteToMove);
    return k != null && attacked(k, byWhite: !whiteToMove);
  }

  /// Coups qui suivent la marche des pièces, sans vérifier que le roi reste hors d'échec.
  List<Move> _pseudo() {
    final out = <Move>[];
    final w = whiteToMove;
    for (var s = 0; s < 64; s++) {
      final p = board[s];
      if (!_mine(p, w)) continue;
      switch (p!.toUpperCase()) {
        case 'P':
          final dir = w ? 1 : -1, startRank = w ? 1 : 6, lastRank = w ? 7 : 0;
          void add(int to) {
            if (to ~/ 8 == lastRank) {
              for (final q in ['q', 'r', 'b', 'n']) {
                out.add(Move(s, to, promo: q));
              }
            } else {
              out.add(Move(s, to));
            }
          }
          final one = _step(s, (0, dir));
          if (one != null && board[one] == null) {
            add(one);
            final two = _step(one, (0, dir));
            if (s ~/ 8 == startRank && two != null && board[two] == null) out.add(Move(s, two));
          }
          for (final df in [-1, 1]) {
            final t = _step(s, (df, dir));
            if (t == null) continue;
            if ((board[t] != null && !_mine(board[t], w)) || t == ep) add(t);
          }
        case 'N':
          for (final d in _knight) {
            final t = _step(s, d);
            if (t != null && !_mine(board[t], w)) out.add(Move(s, t));
          }
        case 'K':
          for (final d in _king) {
            final t = _step(s, d);
            if (t != null && !_mine(board[t], w)) out.add(Move(s, t));
          }
          _castles(s, out);
        default:
          final dirs = switch (p.toUpperCase()) { 'R' => _rook, 'B' => _bishop, _ => [..._rook, ..._bishop] };
          for (final d in dirs) {
            var t = _step(s, d);
            while (t != null) {
              if (_mine(board[t], w)) break;
              out.add(Move(s, t));
              if (board[t] != null) break;
              t = _step(t, d);
            }
          }
      }
    }
    return out;
  }

  /// Roque (art. 3.8.2) : roi et tour jamais déplacés (droits), cases entre eux vides, le roi n'est pas en échec et ne
  /// traverse ni n'arrive sur une case attaquée.
  void _castles(int s, List<Move> out) {
    final w = whiteToMove;
    final home = w ? 4 : 60;
    if (s != home || attacked(home, byWhite: !w)) return;
    final (k, q) = w ? ('K', 'Q') : ('k', 'q');
    if (castling.contains(k) &&
        board[home + 3] == (w ? 'R' : 'r') &&
        board[home + 1] == null &&
        board[home + 2] == null &&
        !attacked(home + 1, byWhite: !w) &&
        !attacked(home + 2, byWhite: !w)) {
      out.add(Move(home, home + 2));
    }
    if (castling.contains(q) &&
        board[home - 4] == (w ? 'R' : 'r') &&
        board[home - 1] == null &&
        board[home - 2] == null &&
        board[home - 3] == null &&
        !attacked(home - 1, byWhite: !w) &&
        !attacked(home - 2, byWhite: !w)) {
      out.add(Move(home, home - 2));
    }
  }

  /// Coups légaux : ceux après lesquels son propre roi n'est pas en échec.
  List<Move> legalMoves() => [
        for (final m in _pseudo())
          if (!_leavesKingAttacked(m)) m,
      ];

  bool _leavesKingAttacked(Move m) {
    final next = play(m);
    final k = next.kingOf(whiteToMove);
    return k != null && next.attacked(k, byWhite: !whiteToMove);
  }

  bool isLegal(Move m) => legalMoves().contains(m);

  /// Le coup suit la marche de la pièce (sans regarder si le roi reste à l'abri) : sert à expliquer un refus.
  bool followsPieceRules(int from, int to) => _pseudo().any((m) => m.from == from && m.to == to);

  bool isCapture(Move m) => board[m.to] != null || (m.to == ep && board[m.from]?.toUpperCase() == 'P');

  /// Joue un coup (supposé permis) et rend la nouvelle position.
  Position play(Move m) {
    final b = List<String?>.of(board);
    final p = b[m.from]!;
    final kind = p.toUpperCase();
    final w = isWhitePiece(p);
    final capture = isCapture(m);
    b[m.to] = m.promo == null ? p : (w ? m.promo!.toUpperCase() : m.promo!);
    b[m.from] = null;
    if (kind == 'P' && m.to == ep) b[m.to + (w ? -8 : 8)] = null; // prise en passant
    if (kind == 'K' && (m.to - m.from).abs() == 2) {
      // Roque : la tour saute par-dessus le roi.
      final (rf, rt) = m.to > m.from ? (m.from + 3, m.from + 1) : (m.from - 4, m.from - 1);
      b[rt] = b[rf];
      b[rf] = null;
    }
    var rights = castling;
    void lose(String r) => rights = rights.replaceAll(r, '');
    if (kind == 'K') {
      for (final r in w ? ['K', 'Q'] : ['k', 'q']) {
        lose(r);
      }
    }
    for (final (sq, r) in [(0, 'Q'), (7, 'K'), (56, 'q'), (63, 'k')]) {
      if (m.from == sq || m.to == sq) lose(r);
    }
    final twoStep = kind == 'P' && (m.to - m.from).abs() == 16;
    return Position(
      b,
      whiteToMove: !w,
      castling: rights,
      ep: twoStep ? (m.from + m.to) ~/ 2 : null,
      halfmove: kind == 'P' || capture ? 0 : halfmove + 1,
      fullmove: w ? fullmove : fullmove + 1,
    );
  }

  /// Plus assez de pièces pour faire mat (art. 5.2.2, cas usuels) : rois seuls, ou un fou ou un cavalier en plus.
  bool get insufficientMaterial {
    final rest = [for (final p in board) if (p != null && p.toUpperCase() != 'K') p.toUpperCase()];
    return rest.isEmpty || (rest.length == 1 && (rest.single == 'B' || rest.single == 'N'));
  }

  /// Notation algébrique abrégée (« Cf3 » en français : R D T F C ; pions sans lettre ; « + » échec, « # » mat).
  String san(Move m) {
    final p = board[m.from]!.toUpperCase();
    final next = play(m);
    final suffix = next.legalMoves().isEmpty && next.inCheck ? '#' : (next.inCheck ? '+' : '');
    if (p == 'K' && (m.to - m.from).abs() == 2) return '${m.to > m.from ? 'O-O' : 'O-O-O'}$suffix';
    final cap = isCapture(m);
    final to = squareName(m.to);
    if (p == 'P') {
      final promo = m.promo == null ? '' : '=${frenchLetter[m.promo!.toUpperCase()]}';
      return '${cap ? '${squareName(m.from)[0]}x' : ''}$to$promo$suffix';
    }
    // Lever l'ambiguïté si une autre pièce pareille peut aller sur la même case.
    final others = [for (final o in legalMoves()) if (o.to == m.to && o.from != m.from && board[o.from]!.toUpperCase() == p) o];
    var dis = '';
    if (others.isNotEmpty) {
      final from = squareName(m.from);
      dis = others.any((o) => o.from % 8 == m.from % 8) ? (others.any((o) => o.from ~/ 8 == m.from ~/ 8) ? from : from[1]) : from[0];
    }
    return '${frenchLetter[p]}$dis${cap ? 'x' : ''}$to$suffix';
  }
}

/// Lettres françaises des pièces (Roi, Dame, Tour, Fou, Cavalier).
const frenchLetter = {'K': 'R', 'Q': 'D', 'R': 'T', 'B': 'F', 'N': 'C', 'P': ''};

/// Nom d'une pièce avec son article, pour les explications (« la tour », « le cavalier »).
String pieceName(String p) => const {
      'P': 'le pion',
      'N': 'le cavalier',
      'B': 'le fou',
      'R': 'la tour',
      'Q': 'la dame',
      'K': 'le roi',
    }[p.toUpperCase()]!;

/// Comment une partie s'arrête.
enum GameEnd { checkmate, stalemate, insufficient, fiftyMoves, repetition }

/// Une partie : la position de départ et les coups joués, avec l'état de fin.
class Game {
  Game({Position? start}) : positions = [start ?? Position.start()];

  final List<Position> positions;
  final moves = <Move>[];

  Position get position => positions.last;

  void play(Move m) {
    moves.add(m);
    positions.add(position.play(m));
  }

  /// Revenir d'un coup (contre le robot, l'enfant peut reprendre son coup).
  void undo() {
    if (moves.isEmpty) return;
    moves.removeLast();
    positions.removeLast();
  }

  GameEnd? get end {
    final p = position;
    if (p.legalMoves().isEmpty) return p.inCheck ? GameEnd.checkmate : GameEnd.stalemate;
    if (p.insufficientMaterial) return GameEnd.insufficient;
    if (p.halfmove >= 100) return GameEnd.fiftyMoves;
    final k = p.key;
    if (positions.where((x) => x.key == k).length >= 3) return GameEnd.repetition;
    return null;
  }

  /// « 1-0 », « 0-1 », « 1/2-1/2 » ou « * » (en cours).
  String get result => switch (end) {
        null => '*',
        GameEnd.checkmate => position.whiteToMove ? '0-1' : '1-0',
        _ => '1/2-1/2',
      };
}

/// Nombre de positions atteintes en [depth] demi-coups : sert à vérifier le générateur de coups (« perft »).
int perft(Position p, int depth) {
  if (depth == 0) return 1;
  final moves = p.legalMoves();
  if (depth == 1) return moves.length;
  var n = 0;
  for (final m in moves) {
    n += perft(p.play(m), depth - 1);
  }
  return n;
}
