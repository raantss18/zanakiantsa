import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/books/books.dart';

void main() {
  final lib = Library(jsonDecode(File('assets/livres/catalogue.json').readAsStringSync()) as Map<String, dynamic>);

  test('bibliothèque : chaque livre est sous CC BY 4.0, crédité, rangé, et ses images existent (ADR 0026)', () {
    expect(lib.books, isNotEmpty);
    expect(lib.books.map((b) => b.id).toSet().length, lib.books.length, reason: 'pas de doublon');
    for (final b in lib.books) {
      expect(b.licence, 'CC BY 4.0', reason: b.title);
      expect(b.credits, contains('Attribution 4.0'), reason: b.title);
      expect(lib.shelves.keys, contains(b.shelf), reason: b.title);
      expect(b.level, inInclusiveRange(1, 5));
      expect(b.pages, isNotEmpty);
      expect(b.cover, isNotNull, reason: '${b.title} : pas de couverture');
      for (final p in b.pages) {
        final img = b.imagePath(p);
        if (img != null) expect(File(img).existsSync(), isTrue, reason: img);
        // Texte remis d'aplomb : plus de « Ã© » ni de « â€™ » laissés par un double encodage.
        expect(p.text, isNot(matches(RegExp('Ã|â€'))), reason: '${b.title} : ${p.text}');
      }
    }
  });

  test('chaque étagère a des livres, les grands ont des livres de niveau 4 ou 5', () {
    for (final s in lib.shelves.keys) {
      expect(lib.books.where((b) => b.shelf == s), isNotEmpty, reason: s);
    }
    expect(lib.books.where((b) => b.shelf == 'grands').every((b) => b.level >= 4), isTrue);
  });
}
