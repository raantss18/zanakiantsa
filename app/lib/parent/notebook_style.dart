/// L'espace parent a le visuel du site (ADR 0059) : un cahier Seyès, la marge rouge, les titres dans l'écriture d'école
/// (Playwrite FR), l'encre violette, le texte en Andika. Les écrans des enfants gardent leurs mondes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../l10n/l10n.dart';

const papier = Color(0xFFFBFBFF);
const encre = Color(0xFF2B1458);
const texteCahier = Color(0xFF26213A);
const violet = Color(0xFF7B1FA2);
const violetFonce = Color(0xFF5A1578);
const marge = Color(0xFFD93A63);
const soleil = Color(0xFFFFC83D);
const trait = Color(0xFF768AD6);

/// Titre de section de l'espace parent : l'écriture d'école, comme les titres du site.
const notebookTitle = TextStyle(fontFamily: 'PlaywriteFR', fontSize: 24, height: 1.9, color: encre);

/// Le thème de l'espace parent, construit sur celui de l'app.
ThemeData notebookTheme(ThemeData base) {
  final scheme = base.colorScheme.copyWith(
    primary: violet,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFF1E4F8),
    onPrimaryContainer: encre,
    secondaryContainer: const Color(0xFFF1E4F8),
    onSecondaryContainer: encre,
    surface: papier,
    onSurface: texteCahier,
  );
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: papier,
    textTheme: base.textTheme.copyWith(
      titleLarge: const TextStyle(fontFamily: 'PlaywriteFR', fontSize: 24, height: 1.9, color: encre),
      bodyMedium: const TextStyle(fontFamily: 'Andika', fontSize: 17, height: 1.45, color: texteCahier),
      bodyLarge: const TextStyle(fontFamily: 'Andika', fontSize: 18, height: 1.45, color: texteCahier),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: papier,
      foregroundColor: encre,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontFamily: 'PlaywriteFR', fontSize: 24, color: encre),
    ),
    dividerTheme: DividerThemeData(color: trait.withValues(alpha: .45), thickness: 2),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 52),
        shape: pill,
        textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: StadiumBorder(side: BorderSide(color: encre.withValues(alpha: .6), width: 1.5)),
      backgroundColor: Colors.white,
      selectedColor: soleil,
      checkmarkColor: encre,
      labelStyle: const TextStyle(fontFamily: 'Andika', fontSize: 16, fontWeight: FontWeight.w700, color: encre),
    ),
    cardTheme: base.cardTheme.copyWith(color: Colors.white, surfaceTintColor: Colors.transparent),
  );
}

/// Le papier du cahier : interlignes, gros carreaux de 32 dp et marge rouge, comme sur le site.
class SeyesPaper extends StatelessWidget {
  const SeyesPaper({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SeyesPainter(), child: child);
}

class _SeyesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = papier);
    final fine = Paint()..color = trait.withValues(alpha: .10);
    final big = Paint()..color = trait.withValues(alpha: .28);
    final col = Paint()..color = trait.withValues(alpha: .12);
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), y % 32 == 0 ? big : fine);
    }
    for (var x = 0.0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), col);
    }
    final m = size.width < 640 ? 14.0 : 28.0;
    canvas.drawLine(
      Offset(m, 0),
      Offset(m, size.height),
      Paint()
        ..color = marge
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_SeyesPainter old) => false;
}

/// « À propos » : une fiche bordée d'encre, comme celle du téléchargement sur le site ; le code QR sur fond blanc, et
/// chaque moyen de contact sur sa ligne, avec son icône (le texte se sélectionne pour être copié).
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: violet, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontFamily: 'Andika', fontSize: 14, color: Color(0xFF4A4560)),
                ),
                SelectableText(
                  value,
                  style: const TextStyle(fontFamily: 'Andika', fontSize: 17, fontWeight: FontWeight.w700, color: encre),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final qr = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(blurRadius: 18, offset: Offset(0, 8), color: Color(0x332B1458))],
          ),
          child: SvgPicture.asset('assets/logo/qr-site.svg', width: 140, height: 140, semanticsLabel: t('Code QR du site de l’application')),
        ),
        const SizedBox(height: 8),
        Text(
          t('Le site : téléchargement,\nguide vidéo et nouvelles'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Andika', fontSize: 14, color: Color(0xFF4A4560)),
        ),
      ],
    );
    final contacts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('Une question ? Un souci ?'),
          style: const TextStyle(fontFamily: 'PlaywriteFR', fontSize: 20, height: 1.8, color: encre),
        ),
        const SizedBox(height: 6),
        row(Icons.person_rounded, t('Conçue par'), 'RANIRIAMANJAKA Antsa'),
        row(Icons.mail_rounded, t('E-mail'), 'antsa.raniriamanjaka@univ-antananarivo.mg'),
        row(Icons.phone_rounded, t('Téléphone et WhatsApp'), '+261 33 43 838 82'),
        row(Icons.language_rounded, t('Site'), 'raantss18.github.io/zanakiantsa'),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: encre, width: 2),
      ),
      child: LayoutBuilder(
        builder: (_, k) => k.maxWidth >= 520
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: contacts),
                  const SizedBox(width: 20),
                  qr,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  contacts,
                  const SizedBox(height: 8),
                  Center(child: qr),
                ],
              ),
      ),
    );
  }
}
