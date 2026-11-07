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
}
