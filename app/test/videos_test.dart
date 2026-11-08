import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/videos/catalog.dart';

// ADR 0068 : vidéos éducatives, seulement des chaînes choisies, adaptées à l'âge.
void main() {
  final cat = Catalogue({
    'genere': '2026-11-08T03:17Z',
    'chaines': [
      {
        'id': 'UCpetits',
        'nom': 'Petits',
        'langue': 'fr',
        'ages': [5, 8],
        'domaines': ['nature'],
      },
      {
        'id': 'UCmoyens',
        'nom': 'Sciences',
        'langue': 'fr',
        'ages': [8, 14],
        'domaines': ['nature', 'explorer'],
      },
      {
        'id': 'UCgrands',
        'nom': 'Histoire',
        'langue': 'fr',
        'ages': [13, 99],
        'domaines': ['explorer'],
      },
      {
        'id': 'UCen',
        'nom': 'Kids',
        'langue': 'en',
        'ages': [5, 10],
        'domaines': ['nature'],
      },
    ],
    'videos': [
      {
        'id': 'a',
        'c': 0,
        't': 'Pourquoi les feuilles tombent',
        'd': 240,
        'p': '2024-01-01',
        'm': 'automne arbre',
      },
      {
        'id': 'b',
        'c': 1,
        't': 'La forêt amazonienne',
        'd': 540,
        'p': '2025-03-01',
        'm': 'jungle biodiversité',
      },
      {
        'id': 'c',
        'c': 1,
        't': 'Les volcans',
        'd': 900,
        'p': '2025-05-01',
        'm': 'lave séisme',
      },
      {
        'id': 'd',
        'c': 2,
        't': 'La Révolution française',
        'd': 1500,
        'p': '2023-07-14',
        'm': 'histoire 1789',
      },
      {
        'id': 'e',
        'c': 3,
        't': 'Why do leaves fall',
        'd': 200,
        'p': '2024-02-01',
        'm': 'autumn',
      },
      {
        'id': 'x',
        'c': 9,
        't': 'chaîne inconnue',
        'd': 100,
        'p': '2024-01-01',
        'm': '',
      },
    ],
  });

  test('chaque enfant ne voit que les chaînes de son âge, dans sa langue', () {
    expect(
      cat.videos.map((v) => v.id),
      isNot(contains('x')),
      reason: 'vidéo d\'une chaîne absente : ignorée',
    );
    expect(cat.forChild(age: 6, lang: 'fr').map((v) => v.id), ['a']);
    expect(cat.forChild(age: 6, lang: 'en').map((v) => v.id), ['e']);
    expect(cat.forChild(age: 9, lang: 'fr').map((v) => v.id), ['b', 'c']);
  });

  test('pas de limite de durée : une longue vidéo éducative est permise même aux petits', () {
    expect(
      cat.forChild(age: 9, lang: 'fr').map((v) => v.id),
      contains('c'),
      reason: '« Les volcans » dure 15 min',
    );
    expect(cat.forChild(age: 14, lang: 'fr').map((v) => v.id), [
      'b',
      'c',
      'd',
    ]);
  });

  test('la recherche ne cherche que dans les vidéos permises, sans tenir compte des accents', () {
    final pool = cat.forChild(age: 9, lang: 'fr');
    expect(search(pool, 'foret').map((v) => v.id), ['b']);
    expect(search(pool, 'Biodiversité jungle').map((v) => v.id), ['b']);
    expect(search(pool, 'volcan').map((v) => v.id), ['c']);
    expect(
      search(pool, 'révolution'),
      isEmpty,
      reason: 'chaîne d\'un autre âge',
    );
    expect(search(pool, ' '), isEmpty);
    expect(search(cat.forChild(age: 14, lang: 'fr'), 'révolution 1789').map((v) => v.id), ['d'], reason: 'les nombres comptent');
  });

  test('liste de départ : pas encore vues d\'abord, puis les vues ; d\'autres vidéos ensuite', () {
    final pool = cat.forChild(age: 14, lang: 'fr');
    expect(suggestions(pool, seen: {'d'}).map((v) => v.id).first, isNot('d'));
    expect(suggestions(pool, seen: {'d'}).map((v) => v.id).last, 'd');
    expect(
      suggestions(pool, seen: {}, domains: {'explorer'}).first.channel.domains,
      contains('explorer'),
    );
    final b = pool.firstWhere((v) => v.id == 'b');
    expect(more(pool, b, {'c'}).map((v) => v.id), [
      'd',
    ], reason: 'même matière, pas encore vue');
  });

  test('pas d\'âge maximum : une chaîne « jusqu\'à 18 ans » vaut aussi pour un adulte', () {
    final c = Channel({'id': 'UCx', 'nom': 'x', 'langue': 'fr', 'ages': [15, 18], 'domaines': <String>[]});
    expect([c.fits(14), c.fits(16), c.fits(40)], [false, true, true]);
    expect(cat.channels[1].fits(15), isFalse, reason: 'un maximum sous 18 reste un maximum');
  });

  test('le lecteur n\'accepte que les vidéos permises à cet enfant', () {
    final pool = cat.forChild(age: 9, lang: 'fr');
    expect(allowedVideo('b', pool), isTrue);
    expect(allowedVideo('c', pool), isTrue, reason: 'longue, mais de sa liste');
    expect(allowedVideo('d', pool), isFalse, reason: 'chaîne d\'un autre âge');
    expect(allowedVideo('dQw4w9WgXcQ', pool), isFalse, reason: 'hors des chaînes choisies');
    expect(allowedVideo('', pool), isTrue, reason: 'lecteur pas encore prêt : rien à bloquer');
  });

  test('durée écrite', () {
    expect(cat.videos.first.length, '4 min');
    expect(cat.videos.firstWhere((v) => v.id == 'd').length, '25 min');
  });
}
