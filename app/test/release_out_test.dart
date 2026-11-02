import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/update/updater.dart';

/// Vérifie qu'une version préparée par `tool/release.sh` est acceptée par la clé publique de l'app (ADR 0011).
/// Ignoré tant que `../release-out/` n'existe pas (CI).
void main() {
  final json = File('../release-out/release.json'), sig = File('../release-out/release.json.sig');
  test('release.json signé par tool/release.sh accepté par l’app', () async {
    final r = await parseSigned(json.readAsBytesSync(), sig.readAsStringSync());
    expect(r, isNotNull);
    expect(r!.sha256.length, 64);
  }, skip: !json.existsSync() ? 'pas de ../release-out' : false);
}
