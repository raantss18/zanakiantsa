import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un LayoutBuilder imbriqué dans celui de la page de séance restait bloqué dans la version publiée (pas en mode debug) :
/// après « J'ai compris », la page ne passait plus à la question (1.1.7, émulateur, 2026-11-16). La page n'en garde qu'un.
void main() {
  test('la page de séance n\'a qu\'un seul LayoutBuilder', () {
    final src = File('lib/ui/session.dart').readAsStringSync();
    expect(RegExp(r'\bLayoutBuilder\(').allMatches(src).length, 1);
  });
}
