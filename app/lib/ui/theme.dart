import 'package:flutter/material.dart';

import 'universe.dart';

/// Jetons de docs/design.md. Les couleurs viennent de l'univers (ADR 0014) ; jamais la couleur seule pour porter un
/// sens : toujours une forme, un nombre, un texte ou une voix avec.
const ink = Color(0xFF1B211D);
const surface = Color(0xFFFFFFFF);
const gold = Color(0xFFE08A00);
const green = Color(0xFF1D7A33);

/// Cible tactile minimale pour l'enfant (≥ 48 dp exigé ; on vise large).
const kidTarget = 72.0;

/// Hauteur fixe du bandeau narrateur : il ne change jamais la taille de la zone de jeu (ADR 0016).
const narratorHeight = 132.0;

/// Une seule ombre douce, pour les cartes posées sur un décor.
const cardShadow = [BoxShadow(blurRadius: 12, color: Color(0x2E000000), offset: Offset(0, 4))];

/// Zone principale + bande de commandes : en dessous en portrait, à droite en paysage. Android 16 ignore l'orientation
/// imposée sur les écrans ≥ 600 dp (ADR 0013) : chaque écran doit s'adapter.
Widget split({required Widget main, required Widget Function(Axis) side, double sideSize = 150}) => LayoutBuilder(
      builder: (_, k) => k.maxWidth > k.maxHeight * 1.1
          ? Row(children: [Expanded(child: main), SizedBox(width: sideSize + 30, child: side(Axis.vertical))])
          : Column(children: [Expanded(child: main), SizedBox(height: sideSize, child: side(Axis.horizontal))]),
    );

ThemeData buildTheme(Universe u) {
  final scheme = ColorScheme.fromSeed(
    seedColor: u.primary,
    primary: u.primary,
    onPrimary: u.onPrimary,
    surface: surface,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Andika',
    colorScheme: scheme,
    scaffoldBackgroundColor: u.bg1,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 64, fontWeight: FontWeight.w700, color: ink, height: 1.1),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 22, color: ink, height: 1.25),
      bodyMedium: TextStyle(fontSize: 18, color: ink, height: 1.25),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: u.primary,
        foregroundColor: u.onPrimary,
        // Inactif : gris clair visible sur fond clair comme sur le fond de nuit.
        disabledBackgroundColor: const Color(0xFFBFC7C1),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size(kidTarget, kidTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 44, fontWeight: FontWeight.w700),
      ),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, surfaceTintColor: Colors.transparent, elevation: 0),
  );
}

/// Bouton-nombre de 104 dp. Pendant une démonstration, la bonne réponse porte un contour et une ✔ (forme + couleur).
class NumberButton extends StatelessWidget {
  const NumberButton({super.key, required this.value, required this.onPressed, this.highlight = false});
  final int value;
  final VoidCallback? onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: FilledButton(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              disabledBackgroundColor: highlight ? cs.primary : const Color(0xFFBFC7C1),
              disabledForegroundColor: highlight ? cs.onPrimary : Colors.white,
              side: highlight ? const BorderSide(color: gold, width: 6) : null,
            ),
            onPressed: onPressed,
            child: Text('$value'),
          ),
        ),
        if (highlight)
          const Positioned(
            right: -8,
            top: -8,
            child: CircleAvatar(radius: 18, backgroundColor: gold, child: Icon(Icons.check_rounded, color: Colors.white)),
          ),
      ]),
    );
  }
}

/// « Épisode 3 » + une pastille par épisode (pleine = gagné) : le numéro est écrit, la couleur n'est jamais seule.
class EpisodeLabel extends StatelessWidget {
  const EpisodeLabel({super.key, required this.index, required this.count});
  final int index, count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Semantics(
          label: 'Épisode ${index + 1} sur $count',
          excludeSemantics: true,
          child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Épisode ${index + 1}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63))),
            const SizedBox(width: 4),
            for (var i = 0; i < count; i++)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= index ? green : null,
                  border: Border.all(color: i <= index ? green : const Color(0xFF8A948E), width: 1.5),
                ),
              ),
          ]),
        ),
      );
}

/// Grande carte-image à toucher (≥ 120 dp). [highlight] : bonne réponse montrée (contour or + ✔, forme et couleur) ;
/// [tried] : déjà essayée, grisée et barrée (jamais la couleur seule).
class PicButton extends StatelessWidget {
  const PicButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.label,
    this.size = 132,
    this.highlight = false,
    this.tried = false,
    this.selected = false,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final String? label;
  final double size;
  final bool highlight, tried, selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Material(
              color: tried ? const Color(0xFFE3E7E4) : surface,
              elevation: tried ? 0 : 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: highlight ? gold : (selected ? cs.primary : const Color(0xFFD5DBD7)),
                  width: highlight || selected ? 6 : 2,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Opacity(opacity: tried ? 0.35 : 1, child: Center(child: child)),
                ),
              ),
            ),
          ),
          if (tried) const Center(child: Icon(Icons.close_rounded, size: 56, color: Color(0xFF5F6B63))),
          if (highlight)
            const Positioned(
              right: -8,
              top: -8,
              child: CircleAvatar(radius: 18, backgroundColor: gold, child: Icon(Icons.check_rounded, color: Colors.white)),
            ),
        ]),
      ),
    );
  }
}
