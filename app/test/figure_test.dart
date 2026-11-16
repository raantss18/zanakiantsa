import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:zanakiantsa/activities/figure.dart';

/// Figures des questions écrites (ADR 0078) : chaque figure du contenu a un type connu et se dessine sans erreur.
void main() {
  final specs = <String, Map<String, dynamic>>{};
  final texts = <String, String>{};
  Object? plain(Object? y) => y is YamlMap
      ? {for (final e in y.entries) '${e.key}': plain(e.value)}
      : y is YamlList
          ? [for (final v in y) plain(v)]
          : y;
  for (final f in Directory('../content').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.yaml'))) {
    final doc = loadYaml(f.readAsStringSync());
    if (doc is! YamlMap) continue;
    void scan(Object? items, String where) {
      if (items is! YamlList) return;
      for (final (i, it) in items.indexed) {
        if (it is YamlMap && it['figure'] != null) {
          specs['$where[$i]'] = Map<String, dynamic>.from(plain(it['figure']) as Map);
          texts['$where[$i]'] = '${it['texte']}';
        }
      }
    }

    scan(doc['items'], f.path);
    if (doc['en'] is YamlMap) scan((doc['en'] as YamlMap)['items'], '${f.path} en');
  }

  test('les types connus du contenu sont ceux du dessin', () {
    for (final e in specs.entries) {
      expect(QuizFigure.types, contains(e.value['type']), reason: e.key);
    }
  });

  test('chaque échiquier montre les pièces que le texte nomme, à leur place', () {
    const letters = {'roi': 'k', 'dame': 'q', 'tour': 'r', 'fou': 'b', 'cavalier': 'n', 'pion': 'p'};
    final mention = RegExp(r'\b(roi|dame|tour|fou|cavalier|pion) (blanc|noir) en ([a-h][1-8])\b', caseSensitive: false);
    for (final e in texts.entries) {
      final spec = specs[e.key];
      if (spec == null || spec['type'] != 'echiquier') continue;
      final board = <String, String>{};
      final rows = (spec['fen'] as String).split(' ').first.split('/');
      expect(rows.length, 8, reason: e.key);
      for (var r = 0; r < 8; r++) {
        var f = 0;
        for (final ch in rows[r].split('')) {
          final n = int.tryParse(ch);
          if (n != null) {
            f += n;
          } else {
            board['${'abcdefgh'[f]}${8 - r}'] = ch;
            f++;
          }
        }
      }
      for (final m in mention.allMatches(e.value)) {
        final l = letters[m[1]!.toLowerCase()]!;
        final want = m[2]!.toLowerCase() == 'blanc' ? l.toUpperCase() : l;
        expect(board[m[3]], want, reason: '${e.key} : ${m[0]}');
      }
    }
  });

  for (final type in QuizFigure.types) {
    testWidgets('chaque figure « $type » du contenu se dessine', (t) async {
      final mine = specs.entries.where((e) => e.value['type'] == type).toList();
      final all = mine.isEmpty ? [MapEntry('exemple', <String, dynamic>{'type': type})] : mine;
      for (final e in all) {
        await t.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: 360, child: QuizFigure(e.value)))));
        expect(t.takeException(), isNull, reason: e.key);
        await t.pumpWidget(MaterialApp(home: Center(child: SizedBox(width: 760, child: QuizFigure(e.value)))));
        expect(t.takeException(), isNull, reason: e.key);
      }
    });
  }
}
