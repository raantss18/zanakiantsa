import 'package:flutter/material.dart';

/// Couleurs reprises de COMIMa/academik (`academik/DESIGN.md`), formes plus rondes et cibles plus grandes pour les
/// 5–7 ans. Jamais la couleur seule pour porter un sens : toujours une forme, un nombre ou une voix avec.
const green = Color(0xFF1D7A33);
const red = Color(0xFFD6362B);
const gold = Color(0xFFE08A00);
const bg = Color(0xFFF7F8F6);
const surface = Color(0xFFFFFFFF);
const ink = Color(0xFF1B211D);

/// Bande du haut laissée libre par chaque activité : la bulle d'aide y flotte sans rien cacher (`ui/session.dart`).
const helpBand = 150.0;

/// Cible tactile minimale pour l'enfant (≥ 48 dp exigé ; on vise large).
const kidTarget = 72.0;

/// Zone principale + bande de commandes : en dessous en portrait, à droite en paysage. Android 16 ignore l'orientation
/// imposée sur les écrans ≥ 600 dp (vérifié sur la 2e SM-X135G) : chaque écran doit s'adapter.
Widget split({required Widget main, required Widget Function(Axis) side, double sideSize = 150}) => LayoutBuilder(
      builder: (_, k) => k.maxWidth > k.maxHeight * 1.1
          ? Row(children: [Expanded(child: main), SizedBox(width: sideSize + 30, child: side(Axis.vertical))])
          : Column(children: [Expanded(child: main), SizedBox(height: sideSize, child: side(Axis.horizontal))]),
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: green, primary: green, secondary: red, surface: bg);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: ink),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 20, color: ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(kidTarget, kidTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        textStyle: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800),
      ),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent, scrolledUnderElevation: 0),
  );
}
