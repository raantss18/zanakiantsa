import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/ui/theme.dart';
import 'package:zanakiantsa/ui/universe.dart';

/// Lisibilité (WCAG 2.x, texte ≥ 4,5:1) : un texte sur fond jaune ne se lisait pas (Antsa, 2026-11-15). Ce test garde
/// toutes les couleurs de texte posées sur une couleur, et refuse le blanc sur les jaunes et l'or dans le code.
void main() {
  test('les fonds colorés de l\'app ont un texte lisible', () {
    final pairs = {
      'bulle d\'aide': (helpBubble, ink),
      'pastille Nouveau / Rappel': (Brand.yellow, textOn(Brand.yellow)),
      'bouton Reprendre': (green, Colors.white),
      'carte blanche': (surface, ink),
    };
    for (final MapEntry(key: name, value: (bg, fg)) in pairs.entries) {
      expect(contrastRatio(bg, fg), greaterThanOrEqualTo(4.5), reason: name);
    }
  });

  test('textOn choisit toujours un texte lisible sur les jaunes et l\'or', () {
    for (final bg in [Brand.yellow, gold, helpBubble, const Color(0xFFFFC83D), const Color(0xFFF7B42C)]) {
      expect(textOn(bg), ink, reason: bg.toString());
      expect(contrastRatio(bg, textOn(bg)), greaterThanOrEqualTo(4.5), reason: bg.toString());
    }
  });

  test('chaque monde : texte sur bouton, accent sur carte blanche', () {
    for (var age = 5; age <= 18; age++) {
      for (final boy in [true, false, null]) {
        for (final u in worldsFor(age, boy)) {
          expect(contrastRatio(u.primary, u.onPrimary), greaterThanOrEqualTo(4.5), reason: '${u.id} bouton');
          expect(contrastRatio(surface, u.onCard), greaterThanOrEqualTo(4.5), reason: '${u.id} carte');
        }
      }
    }
  });

  test('jamais de texte blanc juste après un fond jaune ou or dans le code', () {
    final yellow = RegExp(r'(Brand\.yellow|\bgold\b|helpBubble|soleil|0xFFFFC83D|0xFFF7B42C|0xFFFFF4DE)');
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (!yellow.hasMatch(l) || !RegExp(r'(backgroundColor:|color:)').hasMatch(l) || l.contains('Border')) continue;
        if (l.contains('Icon(')) continue;
        // Le texte posé sur ce fond, dans les lignes qui suivent.
        for (var j = i; j < (i + 6).clamp(0, lines.length); j++) {
          if (RegExp(r'Text\(|TextStyle\(').hasMatch(lines[j]) && lines[j].contains('Colors.white')) {
            bad.add('${f.path}:${j + 1}');
          }
        }
      }
    }
    expect(bad, isEmpty);
  });
}
