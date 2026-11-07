import 'dart:io';

import 'package:flutter_test/flutter_test.dart' hide paints;
import 'package:zanakiantsa/activities/draw.dart';
import 'package:zanakiantsa/activities/explore.dart';
import 'package:zanakiantsa/core/column.dart';
import 'package:zanakiantsa/core/ductus.dart';
import 'package:zanakiantsa/core/fractions.dart';
import 'package:zanakiantsa/core/game.dart';
import 'package:zanakiantsa/l10n/en_activites.dart';
import 'package:zanakiantsa/l10n/l10n.dart';

// Phrases écrites par le code des activités (ADR 0064) : chaque `t('…')` / `tf('…', …)` a sa traduction dans
// `enActivites`, avec les mêmes valeurs {variables}.

/// Les fichiers dont les phrases sont traduites dans `enActivites`.
List<File> get _files => [
      ...Directory('lib/activities').listSync().whereType<File>().where((f) => f.path.endsWith('.dart')),
      for (final n in ['fractions', 'column', 'ductus', 'blocks', 'engine', 'deep_analysis', 'robot', 'chess', 'game', 'motif']) File('lib/core/$n.dart'),
      for (final n in ['chess_play', 'three', 'celebrate', 'universe']) File('lib/ui/$n.dart'),
    ];

const _lit = r"'(?:[^'\\\n]|\\.)*'|" r'"(?:[^"\\\n]|\\.)*"';

/// Le texte d'une chaîne Dart (une ou plusieurs chaînes collées), sans les guillemets ni les échappements.
String _value(String literals) => [
      for (final m in RegExp(_lit).allMatches(literals)) m[0]!.substring(1, m[0]!.length - 1).replaceAllMapped(RegExp(r'\\(.)'), (x) => x[1]!),
    ].join();

/// Les clés écrites directement dans un appel `t(` ou `tf(`.
Set<String> keysIn(String source) => {
      for (final m in RegExp('(?<![A-Za-z0-9_.])tf?\\(\\s*((?:$_lit)(?:\\s*(?:$_lit))*)\\s*[,)]').allMatches(source)) _value(m[1]!),
    };

Set<String> placeholders(String s) => {for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m[1]!};

/// Les clés passées à `t()` par une variable : listes et tables du code, formes au pluriel.
Set<String> get indirectKeys => {
      ...drawingNames.values,
      ...bodyParts.values,
      for (final p in planets) p.name,
      ...columnNames,
      ...secondGesture.values,
      for (final (_, name) in paints) name,
      'le pion', 'le cavalier', 'le fou', 'la tour', 'la dame', 'le roi',
      'blanc', 'blanche', 'noir', 'noire',
      'Facile : le robot se trompe souvent.', 'Moyen.', 'Fort : le robot ne laisse rien en prise.',
      '{n} bon coup', '{n} bons coups', '{n} mat manqué', '{n} mats manqués', '{n} mat permis', '{n} mats permis',
      '{n} matériel perdu', '{n} matériels perdus', '{n} prise manquée', '{n} prises manquées',
      '{n} coup plus fort à voir', '{n} coups plus forts à voir',
    };

void main() {
  tearDown(() => appLang = 'fr');

  test('chaque phrase des activités a sa traduction anglaise, avec les mêmes variables', () {
    final keys = {for (final f in _files) ...keysIn(f.readAsStringSync()), ...indirectKeys};
    expect(keys.length, greaterThan(300));
    final missing = [for (final k in keys) if (!enActivites.containsKey(k)) k];
    expect(missing, isEmpty, reason: 'Sans traduction dans enActivites :\n${missing.join('\n')}');
    for (final k in keys) {
      expect(placeholders(enActivites[k]!), placeholders(k), reason: k);
    }
  });

  test('la lecture des clés comprend les échappements et les chaînes collées', () {
    expect(keysIn("t('C\\'est fait') tf(\"A {x}\" 'b', {})"), {"C'est fait", 'A {x}b'});
    expect(keysIn("print('x') at('y') _t('z')"), isEmpty);
  });

  test('en anglais, les explications sont en anglais, sans variable restée ; en français, rien ne change', () {
    expect(readWhy(const Frac(3, 8), const Frac(5, 8)), contains('parts blanches'));
    appLang = 'en';
    expect(readWhy(const Frac(3, 8), const Frac(5, 8)), 'Those are the white parts. We count the coloured parts.');
    expect(colorWhy(1, 3, 8), 'You have coloured 1 part out of 8. We need more.');
    expect(colorWhy(0, 3, 8), 'You have coloured 0 parts out of 8. We need more.');
    expect(unitCompareWhy(3, 5), startsWith('One fifth is smaller than one third'));
    for (final s in additionSteps(78, 65)) {
      expect('${s.prompt} ${s.why}', isNot(contains('{')));
      expect(s.prompt, isNot(contains('Écris')));
    }
    expect(pieceName('n'), 'the knight');
  });
}
