import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/audio/voice.dart';

// Bug du 2026-11-03 (téléphone d'Antsa, voix coupée) : l'exercice d'écoute restait figé, un appel au lecteur ne
// répondant jamais. Aucun appel au son ne doit bloquer ni faire échouer un écran.
void main() {
  test('un son qui ne répond jamais rend la main après le budget', () async {
    final watch = Stopwatch()..start();
    await bounded(Completer<void>().future, const Duration(milliseconds: 200));
    expect(watch.elapsedMilliseconds, lessThan(1000));
  });

  test('un son qui échoue ne fait pas échouer l\'écran', () async {
    await expectLater(bounded(Future<void>.error(StateError('lecteur absent')), const Duration(seconds: 1)), completes);
  });
}
