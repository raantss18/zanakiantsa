import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/progress.dart';
import 'package:zanakiantsa/l10n/en.dart';

/// Écrans traduits (ADR 0064) : chaque texte passé à t() ou tf() doit avoir sa traduction anglaise.
const translatedFiles = [
  'lib/parent/parent.dart',
  'lib/parent/dashboard.dart',
  'lib/parent/notebook_style.dart',
  'lib/parent/gate.dart',
  'lib/ui/home.dart',
  'lib/ui/session.dart',
  'lib/ui/topic_hub.dart',
  'lib/ui/all_topics.dart',
  'lib/ui/album.dart',
  'lib/ui/topic_intro.dart',
  'lib/ui/library.dart',
  'lib/ui/theme.dart',
  'lib/ui/narrator.dart',
];

const _literal = r'''(?:'(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")''';

/// Les clés de t('…') et tf('…', …) d'un source Dart : littéraux simples ou doubles, éventuellement juxtaposés sur
/// plusieurs lignes ('a' 'b'), échappements résolus.
List<String> keysIn(String source) {
  final call = RegExp(r'(?<![\w$.])tf?\(\s*((?:' + _literal + r'\s*)+)');
  final part = RegExp(_literal);
  return [
    for (final m in call.allMatches(source))
      [
        for (final p in part.allMatches(m.group(1)!))
          p
              .group(0)!
              .substring(1, p.group(0)!.length - 1)
              .replaceAllMapped(
                RegExp(r'\\(.)'),
                (e) => switch (e.group(1)!) {
                  'n' => '\n',
                  't' => '\t',
                  final c => c,
                },
              ),
      ].join(),
  ];
}

Set<String> placeholders(String s) => {
  for (final m in RegExp(r'\{(\w+)\}').allMatches(s)) m.group(1)!,
};

void main() {
  test('chaque texte des écrans traduits a sa traduction anglaise', () {
    final missing = <String>[];
    var found = 0;
    for (final f in translatedFiles) {
      for (final k in keysIn(File(f).readAsStringSync())) {
        found++;
        if (!en.containsKey(k)) {
          missing.add('$f : ${k.replaceAll('\n', r'\n')}');
        }
      }
    }
    expect(
      found,
      greaterThan(100),
      reason: 'l’extraction des clés ne trouve presque rien : l’expression est cassée',
    );
    expect(
      missing,
      isEmpty,
      reason: 'Clés absentes de lib/l10n/en.dart :\n${missing.join('\n')}',
    );
  });

  test('les classes affichées dans l’espace parent sont traduites', () {
    expect([
      for (final c in schoolLevels)
        if (!en.containsKey(c)) c,
    ], isEmpty);
  });

  test('chaque traduction garde les mêmes {valeurs} que sa clé', () {
    final wrong = [
      for (final e in en.entries)
        if (!_sameSet(placeholders(e.key), placeholders(e.value)))
          '${e.key} → ${e.value}',
    ];
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('l’extraction lit les deux sortes de guillemets et les textes sur plusieurs lignes', () {
    expect(keysIn('''t('a\\'b') + tf("c'd {x}", {}) + t('e '\n   'f')'''), [
      "a'b",
      "c'd {x}",
      'e f',
    ]);
  });
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
