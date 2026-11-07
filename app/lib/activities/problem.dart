import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/game.dart';
import '../l10n/l10n.dart';
import '../ui/chess_play.dart';
import '../ui/session.dart';

/// Problème d'échecs sur une vraie position (ADR 0040) : roque, promotion, prise en passant, pièce non protégée,
/// fourchette, mat du couloir. Les Blancs jouent ; on touche une pièce, puis sa case d'arrivée. Coup interdit : on dit
/// pourquoi. Coup permis mais pas le bon : il s'affiche un instant, puis la position revient. La démonstration encadre
/// d'or le bon coup.
class ProblemActivity extends StatefulWidget {
  const ProblemActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ProblemActivity> createState() => _ProblemActivityState();
}

class _ProblemActivityState extends State<ProblemActivity> {
  Attempt get a => widget.attempt;
  late final item = a.skill.items[a.question.n];
  late final Position start = Position.fen(item.fen!);
  late Position shown = start;
  int? selected;
  Move? played;

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => a.say('consigne'));
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _tap(int s) async {
    if (a.busy || a.finished) return;
    final p = start;
    final piece = p.board[s];
    if (piece != null && isWhitePiece(piece)) {
      setState(() => selected = s);
      return;
    }
    final from = selected;
    if (from == null) return;
    final candidates = [for (final m in p.legalMoves()) if (m.from == from && m.to == s) m];
    if (candidates.isEmpty) {
      final name = pieceName(p.board[from]!);
      a.submit(false,
          why: p.followsPieceRules(from, s)
              ? t('Interdit : ton roi serait en échec.')
              : tf('{piece} ne va pas là.', {'piece': '${name[0].toUpperCase()}${name.substring(1)}'}));
      return;
    }
    var move = candidates.first;
    if (candidates.length > 1) {
      final promo = await _choosePromotion();
      if (promo == null) return;
      move = candidates.firstWhere((m) => m.promo == promo);
    }
    final ok = item.moves.contains(move.uci);
    setState(() {
      shown = p.play(move);
      played = move;
      selected = null;
    });
    if (ok) {
      a.submit(true);
      return;
    }
    // Le coup s'affiche un instant, puis la position revient pour un nouvel essai.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      shown = start;
      played = null;
    });
    final promoWrong = move.promo != null && item.moves.any((m) => m.length > 4 && m.substring(0, 4) == move.uci.substring(0, 4));
    a.submit(false, why: promoWrong ? t('Choisis plutôt la dame : c\'est la pièce la plus forte.') : null);
  }

  Future<String?> _choosePromotion() => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('Ton pion devient…')),
          content: Wrap(spacing: 8, children: [
            for (final (k, name) in [('q', t('une dame')), ('r', t('une tour')), ('b', t('un fou')), ('n', t('un cavalier'))])
              Semantics(
                button: true,
                label: name,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, k),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 64, height: 64, child: FittedBox(child: SvgPicture.asset('assets/echecs/$k.svg'))),
                    Text(name),
                  ]),
                ),
              ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hints = a.helpText != null || a.demonstrate;
    final targets = hints && selected != null ? {for (final m in start.legalMoves()) if (m.from == selected) m.to} : <int>{};
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ChessBoardView(
        position: shown,
        selected: selected,
        targets: targets,
        last: played,
        advice: a.demonstrate && played == null ? Move.parse(item.moves.first) : null,
        onTap: _tap,
      ),
    );
  }
}
