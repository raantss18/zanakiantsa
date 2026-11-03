/// Petit moteur d'échecs pour les leçons (FIDE Laws of Chess 2023, art. 3) : déplacements avec obstacles, prise,
/// échec et mat sur des positions simples (pièces blanches contre un roi noir), et générateurs de leçons.
library;

import 'dart:math';

typedef Square = (int, int); // (colonne, rangée), 0 à 7 ; rangée 0 = première rangée des Blancs

bool onBoard(Square s) => s.$1 >= 0 && s.$1 < 8 && s.$2 >= 0 && s.$2 < 8;

const _straight = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const _diagonal = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
const _knight = [(1, 2), (2, 1), (2, -1), (1, -2), (-1, -2), (-2, -1), (-2, 1), (-1, 2)];

/// Une pièce : [kind] r tour, b fou, q dame, k roi, n cavalier, p pion ; [white] sa couleur.
class Piece {
  const Piece(this.kind, {this.white = true});
  final String kind;
  final bool white;

  @override
  bool operator ==(Object other) => other is Piece && other.kind == kind && other.white == white;
  @override
  int get hashCode => Object.hash(kind, white);
}

typedef Board = Map<Square, Piece>;

/// Cases attaquées par [kind] depuis [from] : une pièce qui glisse s'arrête sur la première case occupée (art. 3.5).
/// Pour le pion, seulement ses deux prises en diagonale (art. 3.7.3).
Set<Square> attacks(String kind, Square from, Set<Square> occupied, {bool white = true}) {
  Iterable<Square> ray(List<(int, int)> dirs, int reach) sync* {
    for (final (dc, dr) in dirs) {
      for (var k = 1; k <= reach; k++) {
        final s = (from.$1 + dc * k, from.$2 + dr * k);
        if (!onBoard(s)) break;
        yield s;
        if (occupied.contains(s)) break;
      }
    }
  }

  final up = white ? 1 : -1;
  return switch (kind) {
    'r' => ray(_straight, 7),
    'b' => ray(_diagonal, 7),
    'q' => ray([..._straight, ..._diagonal], 7),
    'k' => ray([..._straight, ..._diagonal], 1),
    'n' => _knight.map((d) => (from.$1 + d.$1, from.$2 + d.$2)).where(onBoard),
    'p' => [(from.$1 - 1, from.$2 + up), (from.$1 + 1, from.$2 + up)].where(onBoard),
    _ => throw ArgumentError(kind),
  }
      .toSet();
}

/// Cases atteignables par [kind] seule sur un échiquier vide (leçons « étoiles »).
Set<Square> moves(String kind, Square from) => kind == 'p' ? pawnMoves(from, const {}, const {}) : attacks(kind, from, const {});

/// Pion blanc : une case en avant si elle est libre, deux depuis sa case de départ (art. 3.7.1–3.7.2), prise en
/// diagonale sur une pièce adverse (art. 3.7.3). Pas de prise en passant ni de promotion dans les leçons.
Set<Square> pawnMoves(Square from, Set<Square> occupied, Set<Square> enemies) {
  final out = <Square>{};
  final one = (from.$1, from.$2 + 1);
  if (onBoard(one) && !occupied.contains(one)) {
    out.add(one);
    final two = (from.$1, from.$2 + 2);
    if (from.$2 == 1 && !occupied.contains(two)) out.add(two);
  }
  out.addAll(attacks('p', from, occupied).where(enemies.contains));
  return out;
}

/// Coups d'une pièce blanche sur [board] : jamais sur une pièce blanche ; le roi noir ne se prend pas (on fait échec) ;
/// le roi blanc ne va pas à côté du roi noir.
Set<Square> legalMoves(Board board, Square from) {
  final p = board[from]!;
  final occupied = board.keys.toSet();
  final enemies = {for (final e in board.entries) if (!e.value.white && e.value.kind != 'k') e.key};
  final raw = p.kind == 'p' ? pawnMoves(from, occupied, enemies) : attacks(p.kind, from, occupied);
  final blackKing = kingOf(board, white: false);
  return raw.where((s) {
    final target = board[s];
    if (target != null && (target.white || target.kind == 'k')) return false;
    if (p.kind == 'k' && blackKing != null && _adjacent(s, blackKing)) return false;
    return true;
  }).toSet();
}

Square? kingOf(Board board, {required bool white}) =>
    board.entries.where((e) => e.value.kind == 'k' && e.value.white == white).map((e) => e.key).firstOrNull;

bool _adjacent(Square a, Square b) => a != b && (a.$1 - b.$1).abs() <= 1 && (a.$2 - b.$2).abs() <= 1;

Board play(Board board, Square from, Square to) => {...board}
  ..remove(from)
  ..[to] = board[from]!;

/// Cases attaquées par les Blancs. [ignore] : case retirée des obstacles (le roi noir ne se cache pas derrière lui-même).
Set<Square> whiteAttacks(Board board, {Square? ignore}) {
  final occupied = board.keys.toSet()..remove(ignore);
  return {
    for (final e in board.entries)
      if (e.value.white) ...attacks(e.value.kind, e.key, occupied),
  };
}

bool blackInCheck(Board board) {
  final k = kingOf(board, white: false);
  return k != null && whiteAttacks(board).contains(k);
}

/// Cases où le roi noir peut aller : à côté, pas attaquée (en le retirant des obstacles), prise d'une pièce blanche
/// non protégée comprise.
Set<Square> blackKingMoves(Board board) {
  final k = kingOf(board, white: false)!;
  final out = <Square>{};
  for (final s in attacks('k', k, const {})) {
    final target = board[s];
    if (target != null && !target.white) continue;
    final after = {...board}
      ..remove(k)
      ..[s] = const Piece('k', white: false);
    if (!whiteAttacks(after).contains(s)) out.add(s);
  }
  return out;
}

/// Échec et mat (art. 1.4.1) dans ces positions où les Noirs n'ont que leur roi : en échec et sans case où aller.
bool blackMated(Board board) => blackInCheck(board) && blackKingMoves(board).isEmpty;

/// Tous les coups blancs qui donnent [goal] (échec, ou mat).
List<(Square, Square)> solutions(Board board, bool Function(Board) goal) => [
      for (final e in board.entries.where((e) => e.value.white))
        for (final to in legalMoves(board, e.key))
          if (goal(play(board, e.key, to))) (e.key, to),
    ];

class StarPuzzle {
  const StarPuzzle(this.start, this.stars);
  final Square start;

  /// Dans l'ordre d'un chemin possible : chaque étoile est à un coup de la précédente (ou du départ).
  final List<Square> stars;
}

/// Un départ et [count] étoiles, chacune atteignable en un coup depuis la précédente : le parcours existe toujours.
/// Pion : départ sur sa 2e rangée, étoiles devant lui.
StarPuzzle starPuzzle(String piece, int count, Random r) {
  final start = piece == 'p' ? (r.nextInt(8), 1) : (r.nextInt(8), r.nextInt(8));
  final stars = <Square>[];
  var cur = start;
  for (var i = 0; i < count; i++) {
    final options = moves(piece, cur).where((s) => s != start && !stars.contains(s)).toList();
    final next = options[r.nextInt(options.length)];
    stars.add(next);
    cur = next;
  }
  return StarPuzzle(start, stars);
}

/// Leçon « prendre » : une pièce blanche et des pions noirs à prendre, chacun prenable depuis la case du précédent
/// en tenant compte des pions pas encore pris (qui barrent le passage).
(Board, List<Square>) capturePuzzle(String piece, int count, Random r) {
  while (true) {
    final start = (r.nextInt(8), r.nextInt(piece == 'p' ? 5 : 8));
    final targets = <Square>[];
    var cur = start;
    var ok = true;
    for (var i = 0; i < count && ok; i++) {
      // Pion : il ne prend qu'en diagonale vers l'avant.
      final options = (piece == 'p' ? attacks('p', cur, const {}) : moves(piece, cur))
          .where((s) => s != start && !targets.contains(s) && s.$2 < 7)
          .toList();
      if (options.isEmpty) {
        ok = false;
      } else {
        targets.add(options[r.nextInt(options.length)]);
        cur = targets.last;
      }
    }
    if (!ok) continue;
    // Vérifie le chemin avec les obstacles : prise i depuis la cible i-1, les cibles suivantes encore en place.
    var at = start;
    for (var i = 0; i < targets.length && ok; i++) {
      final board = <Square, Piece>{at: Piece(piece), for (final t in targets.skip(i)) t: const Piece('p', white: false)};
      ok = legalMoves(board, at).contains(targets[i]);
      at = targets[i];
    }
    if (ok) return ({start: Piece(piece), for (final t in targets) t: const Piece('p', white: false)}, targets);
  }
}

/// Leçon « faire échec » : une pièce blanche et le roi noir, pas encore en échec ; au moins un coup donne échec.
Board checkPuzzle(String piece, Random r) {
  while (true) {
    final w = (r.nextInt(8), r.nextInt(8));
    final k = (r.nextInt(8), r.nextInt(8));
    if (w == k) continue;
    final board = <Square, Piece>{w: Piece(piece), k: const Piece('k', white: false)};
    if (!blackInCheck(board) && solutions(board, blackInCheck).isNotEmpty) return board;
  }
}

/// Leçon « mat en un coup » : roi blanc + [piece] (tour ou dame) contre roi noir au bord. Position légale (rois pas
/// voisins, Noirs pas en échec, au moins une case pour le roi noir), au moins un coup blanc qui fait mat.
Board matePuzzle(String piece, Random r) {
  while (true) {
    final edge = r.nextInt(4);
    final along = r.nextInt(8);
    final bk = switch (edge) { 0 => (along, 7), 1 => (along, 0), 2 => (0, along), _ => (7, along) };
    final wk = (r.nextInt(8), r.nextInt(8));
    final wp = (r.nextInt(8), r.nextInt(8));
    if ({bk, wk, wp}.length < 3 || _adjacent(wk, bk)) continue;
    final board = <Square, Piece>{bk: const Piece('k', white: false), wk: const Piece('k'), wp: Piece(piece)};
    if (blackInCheck(board) || blackKingMoves(board).isEmpty) continue;
    if (solutions(board, blackMated).isNotEmpty) return board;
  }
}
