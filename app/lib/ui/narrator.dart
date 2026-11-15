import 'dart:math';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'theme.dart';
import 'universe.dart';

/// Bandeau narrateur (ADR 0016) : la mascotte de l'univers et une bulle avec l'énoncé **écrit** (dit aussi à voix
/// haute). Hauteur [narratorHeight] au moins ; un texte long fait grandir la bulle jusqu'à [maxHeight], puis défile.
/// Les lettres ne descendent jamais sous 19 (téléphone) ou 21 (tablette) : avant, un long rappel rétrécissait jusqu'à
/// devenir illisible sur téléphone (capture d'Antsa, 2026-11-15). Une aide remplace l'énoncé dans la même bulle, avec une
/// ampoule.
class Narrator extends StatefulWidget {
  const Narrator({super.key, required this.universe, required this.text, this.help = false, this.cheer = 0, this.onListen, this.height = narratorHeight, this.maxHeight});
  final Universe universe;
  final String text;
  final bool help;

  /// Change à chaque bonne réponse : la mascotte saute.
  final int cheer;
  final VoidCallback? onListen;

  /// Hauteur du bandeau : [narratorHeight], ou plus haute dans une colonne à côté d'un échiquier (ADR 0052).
  final double height;

  /// Hauteur jusqu'où la bulle peut grandir pour un texte long (par défaut : [height], le texte défile).
  final double? maxHeight;

  /// Taille des lettres la plus petite permise : lisible à bout de bras sur un téléphone comme sur une tablette.
  static double minFont(double width) => width < 600 ? 19 : 21;

  /// Taille des lettres et hauteur de bulle pour [text] dans une bulle de [width] : la plus grande taille (24 au plus) qui
  /// tient dans [height] ; sinon la taille minimale, et la bulle grandit (jusqu'à [maxHeight]).
  static (double font, double height) fit(String text, double width, double height, double maxHeight, TextStyle base, TextScaler scaler,
      {required double reserved, double chrome = 28}) {
    final w = (width - reserved).clamp(40.0, double.infinity);
    double measure(double f) {
      final tp = TextPainter(text: TextSpan(text: text, style: base.copyWith(fontSize: f)), textDirection: TextDirection.ltr, textScaler: scaler)
        ..layout(maxWidth: w);
      final h = tp.height;
      tp.dispose();
      return h;
    }

    final low = minFont(width);
    for (var f = 24.0; f >= low; f--) {
      if (measure(f) + chrome <= height) return (f, height);
    }
    return (low, (measure(low) + chrome).clamp(height, max(height, maxHeight)));
  }

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
    final mascot = stacked ? 44.0 : tight ? 38.0 : narrow ? 52.0 : 76.0;
    final helpIcon = widget.help ? (tight ? 26.0 : 42.0) : 0.0;
    final base = DefaultTextStyle.of(context).style.merge(const TextStyle(fontWeight: FontWeight.w700, color: ink, height: 1.2));
    // Ce qui n'est pas du texte sur la largeur : marges, mascotte (à côté), ampoule, bouton « Réécouter ».
    final reserved = 24 + (stacked ? 0 : mascot + 8) + (tight ? 8 : narrow ? 12 : 16) + helpIcon + 52;
    final (font, height) = Narrator.fit(widget.text, box.maxWidth, widget.height - (stacked ? mascot + 6 : 0), (widget.maxHeight ?? widget.height) - (stacked ? mascot + 6 : 0),
        base, MediaQuery.textScalerOf(context), reserved: reserved);
    final style = base.copyWith(fontSize: font);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height + (stacked ? mascot + 6 : 0),
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
            child: Art(u.mascot, size: mascot),
          ),
          const SizedBox(width: 8, height: 6),
          Expanded(
            child: Container(
              padding: EdgeInsets.fromLTRB(tight ? 8 : narrow ? 12 : 16, 8, 0, 8),
              decoration: BoxDecoration(
                color: widget.help ? helpBubble : surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: cardShadow,
              ),
              child: Row(children: [
                if (widget.help) Padding(padding: EdgeInsets.only(right: tight ? 4 : 8), child: Art('1f4a1', size: tight ? 22 : 34, label: t('Aide'))),
                Expanded(
                  // Le texte passe à la ligne sur toute la largeur de la bulle, à une taille lisible ; s'il dépasse encore la
                  // hauteur permise, il défile (barre de défilement visible) au lieu de rétrécir.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                    child: _ScrollText(key: ValueKey(widget.text), text: widget.text, style: style),
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

/// Le texte de la bulle, centré en hauteur s'il tient, qui défile (barre visible) s'il ne tient pas.
class _ScrollText extends StatefulWidget {
  const _ScrollText({super.key, required this.text, required this.style});
  final String text;
  final TextStyle style;
  @override
  State<_ScrollText> createState() => _ScrollTextState();
}

class _ScrollTextState extends State<_ScrollText> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, k) => Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(right: 6),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: k.maxHeight),
              child: Align(alignment: Alignment.centerLeft, child: Text(widget.text, style: widget.style)),
            ),
          ),
        ),
      );
}
