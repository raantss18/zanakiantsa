import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'theme.dart';
import 'universe.dart';

/// Bandeau narrateur (ADR 0016) : la mascotte de l'univers et une bulle avec l'énoncé **écrit** (dit aussi à voix
/// haute). Hauteur fixe [narratorHeight]. Une aide remplace l'énoncé dans la même bulle, avec une ampoule.
class Narrator extends StatefulWidget {
  const Narrator({super.key, required this.universe, required this.text, this.help = false, this.cheer = 0, this.onListen, this.height = narratorHeight});
  final Universe universe;
  final String text;
  final bool help;

  /// Change à chaque bonne réponse : la mascotte saute.
  final int cheer;
  final VoidCallback? onListen;

  /// Hauteur du bandeau : [narratorHeight], ou plus haute dans une colonne à côté d'un échiquier (ADR 0052).
  final double height;

  @override
  State<Narrator> createState() => _NarratorState();
}

class _NarratorState extends State<Narrator> with SingleTickerProviderStateMixin {
  late final _jump = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didUpdateWidget(Narrator old) {
    super.didUpdateWidget(old);
    if (widget.cheer != old.cheer && !MediaQuery.of(context).disableAnimations) _jump.forward(from: 0);
  }

  @override
  void dispose() {
    _jump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.universe;
    // La place de la bulle elle-même, pas celle de l'écran (vu en paysage le 2026-11-08 : dans la colonne de côté, le texte
    // n'avait plus que ≈ 80 dp, un mot par ligne). Étroite : mascotte plus petite ; étroite et haute : mascotte au-dessus.
    return LayoutBuilder(builder: (context, box) {
    final narrow = box.maxWidth < 600;
    final stacked = box.maxWidth < 380 && widget.height >= 200;
    final tight = box.maxWidth < 380;
    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Flex(direction: stacked ? Axis.vertical : Axis.horizontal, crossAxisAlignment: stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
          AnimatedBuilder(
            animation: _jump,
            builder: (_, child) {
              final t = _jump.value;
              final dy = -28 * (t < 0.5 ? Curves.easeOut.transform(t * 2) : Curves.bounceOut.transform(2 - t * 2));
              return Transform.translate(offset: Offset(0, t == 0 ? 0 : dy), child: child);
            },
            child: Art(u.mascot, size: stacked ? 44 : tight ? 38 : narrow ? 52 : 76),
          ),
          const SizedBox(width: 8, height: 6),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(tight ? 8 : narrow ? 12 : 16, 8, 0, 8),
              decoration: BoxDecoration(
                color: widget.help ? const Color(0xFFFFF4DE) : surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: cardShadow,
              ),
              child: Row(children: [
                if (widget.help) Padding(padding: EdgeInsets.only(right: tight ? 4 : 8), child: Art('1f4a1', size: tight ? 22 : 34, label: t('Aide'))),
                Expanded(
                  // Le texte passe à la ligne sur toute la largeur de la bulle, puis ne rétrécit que s'il dépasse
                  // en hauteur (jamais coupé ni débordant).
                  child: LayoutBuilder(
                    builder: (_, k) {
                      // Un texte long garde toute la largeur : on baisse la taille des lettres (jusqu'à 15) plutôt
                      // que de réduire le bloc entier, qui laissait une colonne étroite au milieu de la bulle.
                      final scaler = MediaQuery.textScalerOf(context);
                      var style = DefaultTextStyle.of(context).style.merge(const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink, height: 1.2));
                      while (style.fontSize! > 15) {
                        final tp = TextPainter(text: TextSpan(text: widget.text, style: style), textDirection: TextDirection.ltr, textScaler: scaler)
                          ..layout(maxWidth: k.maxWidth);
                        final fits = tp.height <= k.maxHeight;
                        tp.dispose();
                        if (fits) break;
                        style = style.copyWith(fontSize: style.fontSize! - 1);
                      }
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                        child: FittedBox(
                          key: ValueKey(widget.text),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(width: k.maxWidth, child: Text(widget.text, style: style)),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  tooltip: t('Réécouter'),
                  iconSize: tight ? 26 : narrow ? 30 : 36,
                  padding: tight ? EdgeInsets.zero : null,
                  constraints: tight ? const BoxConstraints(minWidth: 48, minHeight: 48) : null,
                  onPressed: widget.onListen,
                  icon: Icon(Icons.volume_up_rounded, color: u.onCard),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
    });
  }
}
