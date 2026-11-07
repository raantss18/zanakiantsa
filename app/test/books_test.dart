import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/books/books.dart';

void main() {
  final lib = Library(jsonDecode(File('assets/livres/catalogue.json').readAsStringSync()) as Map<String, dynamic>);

  final storybooks = lib.books.where((b) => b.licence != 'Domaine public').toList();
  final classics = lib.books.where((b) => b.licence == 'Domaine public').toList();

  test('bibliothèque : chaque livre est sous CC BY 4.0, crédité, rangé, et ses images existent (ADR 0026)', () {
    expect(storybooks, isNotEmpty);
    expect(lib.books.map((b) => b.id).toSet().length, lib.books.length, reason: 'pas de doublon');
    for (final b in storybooks) {
      expect(b.licence, 'CC BY 4.0', reason: b.title);
      expect(b.credits, contains('Attribution 4.0'), reason: b.title);
      expect(b.level, inInclusiveRange(1, 5));
      expect(b.cover, isNotNull, reason: '${b.title} : pas de couverture');
    }
    for (final b in lib.books) {
      expect(lib.shelves.keys, contains(b.shelf), reason: b.title);
      expect(b.pages, isNotEmpty);
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

  test('classiques du domaine public : auteur, source Wikisource, licence, niveaux 5 à 7, pages de taille raisonnable', () {
    expect(classics.length, greaterThanOrEqualTo(25));
    for (final b in classics) {
      expect(b.author, isNotNull, reason: b.title);
      expect(b.author!.trim(), isNotEmpty, reason: b.title);
      expect(b.credits, contains(b.author!), reason: b.title);
      expect(b.source, startsWith('https://fr.wikisource.org/wiki/'), reason: b.title);
      expect(b.licence, 'Domaine public', reason: b.title);
      expect(b.shelf, 'classiques', reason: b.title);
      expect(b.level, inInclusiveRange(5, 7), reason: b.title);
      expect(b.id, greaterThan(900000), reason: '${b.title} : numéro hors de ceux d\'African Storybook');
      for (final p in b.pages) {
        expect(p.image, isNull, reason: b.title);
        expect(p.text.length, inInclusiveRange(1, 1200), reason: '${b.title} : page trop longue');
        // Rien de Wikisource laissé dans le texte : appels de note, numéros de page, bandeaux.
        expect(p.text, isNot(matches(RegExp(r'\[\d+\]|Wikisource|modifier|Page:'))), reason: '${b.title} : ${p.text}');
      }
    }
    for (final level in [5, 6, 7]) {
      expect(classics.where((b) => b.level == level), isNotEmpty, reason: 'niveau $level');
    }
  });

  // ADR 0068 : « les livres aussi doivent convenir à l'âge ».
  test('chaque âge a ses livres : pas de classiques pour les petits, pas de premiers mots pour les grands', () {
    final lib = Library(jsonDecode(File('assets/livres/catalogue.json').readAsStringSync()) as Map<String, dynamic>);
    for (final age in [5, 7, 9, 11, 13, 17, 40]) {
      expect(lib.forAge(age).length, greaterThanOrEqualTo(25), reason: '$age ans');
    }
    expect(lib.forAge(6).every((b) => b.level <= 3), isTrue);
    expect(lib.forAge(15).every((b) => b.level >= 4), isTrue);
    expect(lib.forAge(15).any((b) => b.author != null && b.author!.isNotEmpty), isTrue, reason: 'les classiques');
  });
}
