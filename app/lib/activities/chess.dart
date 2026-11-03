import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/chess.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Leçons d'échecs (FIDE, art. 3 ; ADR 0019, 0020), selon le paramètre `mode` :
/// - `etoiles` : une pièce seule attrape des étoiles ;
/// - `prise` : la pièce prend des pions noirs (qui barrent le passage) ;
/// - `echec` : un coup qui met le roi noir en échec ;
/// - `mat` : avec le roi blanc et une tour ou une dame, un coup qui fait échec et mat.
/// On touche une pièce blanche (choisie d'office s'il n'y en a qu'une), puis sa case d'arrivée. Coup interdit, ou coup
/// qui ne répond pas à la question (échec, mat) : un essai manqué, la position revient, des points montrent les cases
/// permises. La démonstration montre un coup juste (cases entourées d'or).
class ChessActivity extends StatefulWidget {
  const ChessActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ChessActivity> createState() => _ChessActivityState();
}

class _ChessActivityState extends State<ChessActivity> {
  Attempt get a => widget.attempt;
  late final String piece = a.skill.params['piece'] as String;
  late final String mode = a.skill.params['mode'] as String? ?? 'etoiles';
  late final Random _r = Random(a.question.a);
  late Board board;
  late final Board start;
  final stars = <Square>{};
  Square? selected;
  Square? wrong;
  bool hints = false;

  static const light = Color(0xFFF0D9B5), dark = Color(0xFFB58863);

  @override
  void initState() {
    super.initState();
    switch (mode) {
      case 'prise':
        board = capturePuzzle(piece, a.question.n, _r).$1;
      case 'echec':
        board = checkPuzzle(piece, _r);
      case 'mat':
        board = matePuzzle(piece, _r);
      default:
        final p = starPuzzle(piece, a.question.n, _r);
        board = {p.start: Piece(piece)};
        stars.addAll(p.stars);
    }
    start = {...board};
    final whites = board.entries.where((e) => e.value.white).toList();
    if (whites.length == 1) selected = whites.single.key;
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() => hints = hints || a.helpText != null || a.demonstrate);

  bool get _blackPawnsLeft => board.values.any((p) => !p.white && p.kind == 'p');

  /// Un coup juste à montrer en démonstration.
  (Square, Square)? get _shown {
    if (!a.demonstrate) return null;
    final goal = switch (mode) { 'echec' => blackInCheck, 'mat' => blackMated, _ => null };
    if (goal != null) return solutions(start, goal).firstOrNull;
    final from = board.entries.firstWhere((e) => e.value.white).key;
    final targets = mode == 'prise' ? {for (final e in board.entries) if (!e.value.white) e.key} : stars;
    final to = legalMoves(board, from).where(targets.contains).firstOrNull;
    return to == null ? null : (from, to);
  }

  Future<void> _tap(Square s) async {
    if (a.busy || a.finished) return;
    final p = board[s];
    if (p != null && p.white) {
      setState(() => selected = s);
      return;
    }
    final from = selected;
    if (from == null) return;
    if (!legalMoves(board, from).contains(s)) {
      setState(() => wrong = s);
      a.submit(false);
      return;
    }
    setState(() {
      board = play(board, from, s);
      selected = board.entries.where((e) => e.value.white).length == 1 ? s : null;
      wrong = null;
      stars.remove(s);
    });
    switch (mode) {
      case 'etoiles':
        if (stars.isEmpty) a.submit(true);
      case 'prise':
        if (!_blackPawnsLeft) a.submit(true);
      default:
        final ok = mode == 'echec' ? blackInCheck(board) : blackMated(board);
        if (ok) {
          a.submit(true);
        } else {
          // Coup permis mais pas la réponse : on le laisse voir un instant, puis la position revient.
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          setState(() {
            board = {...start};
            final whites = start.entries.where((e) => e.value.white).toList();
            selected = whites.length == 1 ? whites.single.key : null;
          });
          a.submit(false);
        }
    }
  }

  String _file(Piece p) => p.white ? p.kind : 'b${p.kind}';

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    final legal = hints && selected != null && board[selected!]?.white == true ? legalMoves(board, selected!) : const <Square>{};
    final shown = _shown;
    return LayoutBuilder(builder: (_, k) {
      final side = min(k.maxWidth, k.maxHeight) - 24;
      final cell = side / 8;
      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(boxShadow: cardShadow, border: Border.all(color: u.onCard, width: 4)),
          child: Column(children: [
            for (var row = 7; row >= 0; row--)
              Row(children: [
                for (var col = 0; col < 8; col++) _square((col, row), cell - 1, legal, shown),
              ]),
          ]),
        ),
      );
    });
  }

  Widget _square(Square s, double cell, Set<Square> legal, (Square, Square)? shown) {
    final isDark = (s.$1 + s.$2).isEven;
    final p = board[s];
    final ring = shown != null && (shown.$1 == s || shown.$2 == s);
    return GestureDetector(
      onTap: () => _tap(s),
      child: Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: isDark ? dark : light,
          border: ring ? Border.all(color: gold, width: 5) : (s == selected && board.length > 1 ? Border.all(color: const Color(0xFF1D6FD6), width: 4) : null),
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (s == wrong) Icon(Icons.close_rounded, size: cell * 0.7, color: const Color(0xAA5F1B1B)),
          if (stars.contains(s)) Art('2b50', size: cell * 0.7, label: 'étoile'),
          if (p == null && legal.contains(s) && !stars.contains(s))
            Container(width: cell * 0.28, height: cell * 0.28, decoration: const BoxDecoration(color: Color(0x991B211D), shape: BoxShape.circle)),
          if (p != null)
            SizedBox(
              width: cell * 0.95,
              height: cell * 0.95,
              // Les SVG d'origine n'ont pas de viewBox (45 × 45) : FittedBox les met à l'échelle de la case.
              child: FittedBox(child: SvgPicture.asset('assets/echecs/${_file(p)}.svg')),
            ),
          // Une pièce noire qu'on peut prendre porte aussi un rond (pas seulement la couleur de la case).
          if (p != null && !p.white && legal.contains(s))
            Container(
              width: cell * 0.9,
              height: cell * 0.9,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x991B211D), width: 4)),
            ),
        ]),
      ),
    );
  }
}
