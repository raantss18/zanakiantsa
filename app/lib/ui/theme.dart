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

/// Hauteur du narrateur quand il est dans une colonne à gauche d'un échiquier, en paysage (ADR 0052).
const narratorSideHeight = 232.0;

/// Une seule ombre douce, pour les cartes posées sur un décor.
const cardShadow = [BoxShadow(blurRadius: 12, color: Color(0x2E000000), offset: Offset(0, 4))];

/// Zone principale + bande de commandes : en dessous en portrait, à droite en paysage. Android 16 ignore l'orientation
/// imposée sur les écrans ≥ 600 dp (ADR 0013) : chaque écran doit s'adapter.
Widget split({required Widget main, required Widget Function(Axis) side, double sideSize = 150}) => LayoutBuilder(
      builder: (_, k) => k.maxWidth > k.maxHeight * 1.1
          ? Row(children: [Expanded(child: main), SizedBox(width: sideSize + 30, child: side(Axis.vertical))])
          : Column(children: [Expanded(child: main), SizedBox(height: sideSize, child: side(Axis.horizontal))]),
    );

/// La hauteur que peut occuper une activité agrandie sur une grande tablette (ADR 0054), donnée par la séance. Pas de
/// `LayoutBuilder` ici : un `LayoutBuilder` autour de l'activité figeait l'écran en version publiée (ADR 0054).
class ActivityRoom extends InheritedWidget {
  const ActivityRoom({super.key, required this.height, required super.child});

  /// Null sur les petits écrans : l'activité reste en haut, comme toujours.
  final double? height;

  static double? heightOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ActivityRoom>()?.height;

  @override
  bool updateShouldNotify(ActivityRoom old) => old.height != height;
}

/// La zone de jeu d'une activité : elle défile si elle manque de place ; sur une grande tablette, elle se centre en hauteur
/// au lieu de laisser le bas de l'écran vide.
class PlayScroll extends StatelessWidget {
  const PlayScroll({super.key, this.padding = EdgeInsets.zero, required this.child});
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final room = ActivityRoom.heightOf(context);
    return SingleChildScrollView(
      padding: padding,
      child: room == null
          ? child
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: (room - padding.vertical).clamp(0.0, double.infinity)),
              child: Center(child: SizedBox(width: double.infinity, child: child)),
            ),
    );
  }
}

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
  const NumberButton({super.key, required this.value, required this.onPressed, this.highlight = false, this.size = 104});
  final int value;
  final VoidCallback? onPressed;
  final bool highlight;

  /// 104 dp par défaut ; 84 quand quatre boutons doivent tenir sur une rangée de téléphone (cible ≥ 48 dp).
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
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
    // Le libellé remplace le contenu pour le lecteur d'écran (sinon « h h » : libellé + texte du bouton).
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: label != null,
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

/// Identité visuelle (ADR 0027, docs/design.md § 7) : couleurs du logo. Les lettres de titre n'utilisent que les
/// teintes foncées (≥ 4,5:1 contre leur contour blanc) ; le jaune et le sarcelle clair restent des décors.
abstract final class Brand {
  static const pink = Color(0xFFD1246A), purple = Color(0xFF5B4BA6), teal = Color(0xFF15808C), maroon = Color(0xFF8C2F57);
  static const yellow = Color(0xFFF7B42C), tealLight = Color(0xFF1FA3B2), shadow = Color(0xFF2A1F5C);
  static const letters = [pink, purple, teal, maroon];
}

/// Titre « autocollant » des écrans de l'enfant : police Fredoka, lettres de couleurs alternées, contour blanc épais
/// et ombre, comme le logo. Lisible sur tous les fonds d'univers (le contour blanc porte le contraste).
class PlayfulTitle extends StatelessWidget {
  const PlayfulTitle(this.text, {super.key, this.size = 30, this.maxLines = 1});
  final String text;
  final double size;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    // Espaces élargis : sans eux, le contour blanc des lettres comble les blancs entre les mots (« Quijoue »).
    TextStyle base(Paint? fg) =>
        TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w700, fontSize: size, height: 1.1, letterSpacing: size * 0.02, wordSpacing: size * 0.35, foreground: fg);
    var n = 0;
    final colored = [
      for (final ch in text.characters)
        TextSpan(text: ch, style: TextStyle(color: ch.trim().isEmpty ? null : Brand.letters[n++ % Brand.letters.length])),
    ];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.22
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Stack(children: [
        // Ombre décalée, puis contour blanc, puis les lettres de couleur.
        Transform.translate(
          offset: Offset(size * 0.05, size * 0.07),
          child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: base(Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.22
            ..strokeJoin = StrokeJoin.round
            ..color = Brand.shadow)),
        ),
        Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: base(stroke)),
        Text.rich(TextSpan(children: colored), maxLines: maxLines, overflow: TextOverflow.ellipsis, style: base(null)),
      ]),
    );
  }
}
