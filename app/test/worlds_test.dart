import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/ui/universe.dart';

// ADR 0066 (demande d'Antsa, 2026-11-08 : « adapte à la catégorie d'âge ») : à 12 ans, plus de poupées ni de Robi qui répare
// son atelier ; des mondes mixtes pour les 8–11 ans et pour les 12 ans et plus.
void main() {
  test('tranches d\'âge', () {
    expect([for (final a in [4, 5, 7, 8, 11, 12, 15, 40]) bandForAge(a)],
        [Band.petits, Band.petits, Band.petits, Band.moyens, Band.moyens, Band.grands, Band.grands, Band.grands]);
  });

  test('les petits : trois mondes de leur genre ; ensuite, trois mondes mixtes de leur âge', () {
    expect(worldsFor(6, true).map((u) => u.id), ['robots', 'voitures', 'espace']);
    expect(worldsFor(6, false).map((u) => u.id), ['fees', 'mode', 'princesses']);
    for (final boy in [true, false]) {
      expect(worldsFor(9, boy).map((u) => u.id), ['expedition', 'laboratoire', 'ocean']);
      expect(worldsFor(12, boy).map((u) => u.id), ['mars', 'studio', 'monde']);
      expect(worldsFor(16, boy).map((u) => u.id), ['mars', 'studio', 'monde']);
    }
  });

  test('chaque monde a ses mots en français et en anglais, et tous ses dessins', () {
    final words = (jsonDecode(File('assets/content/univers.json').readAsStringSync()) as Map)['univers'] as Map;
    for (final u in universes) {
      final w = words[u.id] as Map?;
      expect(w, isNotNull, reason: u.id);
      expect(w!['tranche'], u.band.name, reason: u.id);
      expect((w['en'] as Map)['histoire'], hasLength((w['histoire'] as List).length), reason: u.id);
      for (final code in [u.mascot, u.container, u.scene.hero, ...u.objects, ...u.stickers, ...u.decor, ...u.scene.burst]) {
        expect(File('assets/art/$code.svg').existsSync(), isTrue, reason: '${u.id} : $code');
      }
      expect(u.stickers, hasLength(12), reason: u.id);
    }
  });
}
