import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';
import 'package:zanakiantsa/activities/figure.dart';

/// Figures des questions écrites (ADR 0078) : chaque figure du contenu a un type connu et se dessine sans erreur.
void main() {
  final specs = <String, Map<String, dynamic>>{};
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
        if (it is YamlMap && it['figure'] != null) specs['$where[$i]'] = Map<String, dynamic>.from(plain(it['figure']) as Map);
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
