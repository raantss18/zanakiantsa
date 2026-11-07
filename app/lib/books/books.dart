/// Livres de la bibliothèque (ADR 0026) : importés d'African Storybook par `tool/import_livres.py`, sous licence
/// CC BY 4.0, et classiques du domaine public en texte seul (Wikisource, `tool/import_classiques.py`, niveaux 5 à 7),
/// rangés dans assets/livres/ (catalogue.json, images/). Rien n'est téléchargé par l'app.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

class BookPage {
  BookPage(Map<String, dynamic> j)
      : text = j['texte'] as String,
        image = j['image'] as String?;
  final String text;
  final String? image;
}

class Book {
  Book(Map<String, dynamic> j)
      : id = j['id'] as int,
        title = j['titre'] as String,
        shelf = j['etagere'] as String,
        level = j['niveau'] as int,
        pages = [for (final p in j['pages'] as List) BookPage(Map<String, dynamic>.from(p as Map))],
        credits = j['credits'] as String,
        licence = j['licence'] as String,
        source = j['source'] as String,
        author = j['auteur'] as String?;
  final int id, level;

  /// Auteur, pour les classiques du domaine public (les crédits d'African Storybook le donnent déjà).
  final String? author;
  final String title, shelf, credits, licence, source;
  final List<BookPage> pages;

  String? imagePath(BookPage p) => p.image == null ? null : 'assets/livres/images/${p.image}';

  /// Couverture : la première page illustrée.
  String? get cover => pages.where((p) => p.image != null).map(imagePath).firstOrNull;

  /// Identifiant de « compétence » pour le journal : une étoile quand le livre est fini la première fois.
  String get skillId => 'livre-$id';
}

class Library {
  Library(Map<String, dynamic> j)
      : shelves = Map<String, String>.from(j['etageres'] as Map),
        books = [for (final b in j['livres'] as List) Book(Map<String, dynamic>.from(b as Map))];
  final Map<String, String> shelves;
  final List<Book> books;

  static Future<Library> load() async =>
      Library(jsonDecode(await rootBundle.loadString('assets/livres/catalogue.json')) as Map<String, dynamic>);
}
