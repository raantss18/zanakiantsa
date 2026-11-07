import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/parent/gate.dart';

// Défaut trouvé le 2026-11-07 (versions 0.9.0 et 0.10.0) : le clavier réorganise l'accueil, le bouton disparaît de l'arbre, et la
// bonne réponse n'ouvrait plus l'espace parent, donc plus les mises à jour.
void main() {
  testWidgets('la bonne réponse ouvre l\'espace parent même si le bouton a disparu entre-temps', (t) async {
    final showButton = ValueNotifier(true);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: showButton,
          builder: (_, shown, _) => shown
              ? Builder(
                  builder: (context) => TextButton(
                    onPressed: () => openParentSpace(context, page: (_) => const Text('Espace ouvert')),
                    child: const Text('Cadenas'),
                  ),
                )
              : const SizedBox(),
        ),
      ),
    ));
    await t.tap(find.text('Cadenas'));
    await t.pumpAndSettle();

    final question = t.widget<Text>(find.textContaining('Combien font')).data!;
    final m = RegExp(r'(\d+) × (\d+)').firstMatch(question)!;
    await t.enterText(find.byType(TextField), '${int.parse(m[1]!) * int.parse(m[2]!)}');

    showButton.value = false; // ce que fait le clavier en réorganisant l'accueil
    await t.pump();
    await t.tap(find.text('Entrer'));
    await t.pumpAndSettle();
    expect(find.text('Espace ouvert'), findsOneWidget);
  });

  testWidgets('une mauvaise réponse n\'ouvre rien', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => openParentSpace(context, page: (_) => const Text('Espace ouvert')), child: const Text('Cadenas')),
        ),
      ),
    ));
    await t.tap(find.text('Cadenas'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '1');
    await t.tap(find.text('Entrer'));
    await t.pumpAndSettle();
    expect(find.text('Espace ouvert'), findsNothing);
  });

  // Défaut trouvé sur la SM-X135G en paysage (2026-11-07) : le clavier laisse ~360 px et la question disparaissait.
  testWidgets('en paysage, avec le clavier, la question, le champ et « Entrer » restent visibles', (t) async {
    t.view.physicalSize = const Size(1340, 800);
    t.view.devicePixelRatio = 1.75; // densité 280 de la SM-X135G : 766 × 457 dp
    t.view.viewInsets = const FakeViewPadding(bottom: 440);
    t.platformDispatcher.textScaleFactorTestValue = 1.5; // texte agrandi à 150 % sur la tablette de référence
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(onPressed: () => openParentSpace(context, page: (_) => const Text('Espace ouvert')), child: const Text('Cadenas')),
        ),
      ),
    ));
    await t.tap(find.text('Cadenas'));
    await t.pumpAndSettle();
    final visible = t.getRect(find.descendant(of: find.byType(Dialog), matching: find.byType(SingleChildScrollView))); // la fenêtre défile : ce qui dépasse est coupé
    for (final f in [find.textContaining('Combien font'), find.byType(TextField), find.text('Entrer')]) {
      final r = t.getRect(f);
      expect(r.top, greaterThanOrEqualTo(visible.top));
      expect(r.bottom, lessThanOrEqualTo(visible.bottom));
      expect(r.height, greaterThan(10));
      expect(r.bottom, lessThanOrEqualTo((800 - 440) / 1.75));
    }
    expect(t.takeException(), isNull);
  });
}
