import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/activities/shapes.dart';
import 'package:zanakiantsa/audio/sfx.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/rewards.dart';
import 'package:zanakiantsa/ui/universe.dart';

Answer ok() => Answer(skill: 's', attempts: 1, correct: true, demonstrated: false, millis: 1, at: DateTime(2026));

void main() {
  group('Accords des phrases (ADR 0014)', () {
    const q = Question(n: 7, a: 3, b: 4);
    test('« un par un » / « une par une » et « Chacun » selon le genre', () {
      const f = Words(singular: 'fleur', plural: 'fleurs', feminine: true, container: 'le panier');
      const m = Words(singular: 'papillon', plural: 'papillons', feminine: false, container: 'le panier');
      expect(fill('Touche les {objets} {un} par {un}. {Chacun} ne compte qu\'une fois.', q, f),
          'Touche les fleurs une par une. Chacune ne compte qu\'une fois.');
      expect(fill('Touche les {objets} {un} par {un}.', q, m), 'Touche les papillons un par un.');
    });
    test('« de » devant voyelle devient « d\' »', () {
      const w = Words(singular: 'engrenage', plural: 'engrenages', feminine: false, container: 'la caisse à outils');
      expect(fill('Combien de {objets} ?', q, w), "Combien d'engrenages ?");
      expect(fill('Il y a {n} {objets} dans {contenant}.', q, w), 'Il y a 7 engrenages dans la caisse à outils.');
      expect(fill('Il y a {a} {objets}.', const Question(n: 5, a: 1, b: 4), w), 'Il y a 1 engrenage.');
      expect(fill('{a} et {b} font {n}.', const Question(n: 5, a: 1, b: 4), w), '1 et 4 font 5.');
    });
  });

  group('Univers', () {
    final words = (jsonDecode(File('assets/content/univers.json').readAsStringSync()) as Map)['univers'] as Map;
    test('chez les petits, 3 univers par genre ; mots et dessins présents pour chacun', () {
      expect(universes.where((u) => u.band == Band.petits && u.boy == true).length, 3);
      expect(universes.where((u) => u.band == Band.petits && u.boy == false).length, 3);
      for (final u in universes) {
        expect(words.containsKey(u.id), isTrue, reason: u.id);
        expect((words[u.id] as Map)['genre'], switch (u.boy) { true => 'garcon', false => 'fille', null => 'mixte' }, reason: u.id);
        expect(u.stickers.length, stickersPerUniverse, reason: u.id);
        for (final code in {u.mascot, u.container, ...u.objects, ...u.stickers, ...u.decor, u.scene.hero, ...u.scene.burst}) {
          expect(File('assets/art/$code.svg').existsSync(), isTrue, reason: '${u.id} : $code.svg');
        }
      }
    });
    test('aucune phrase de compétence ne garde une variable non remplacée, dans aucun univers', () {
      final topic = Topic(jsonDecode(File('assets/content/compter.json').readAsStringSync()) as Map<String, dynamic>);
      for (final w in words.values) {
        for (final o in (w as Map)['objets'] as List) {
          final ws = Words(singular: o[0], plural: o[1], feminine: o[2] == 'f', container: w['contenant'], firstName: w['prenom']);
          for (final s in topic.skills) {
            for (final k in s.phrases.keys) {
              expect(s.say(k, const Question(n: 5, a: 2, b: 3), words: ws), isNot(contains('{')), reason: '${s.id}.$k');
            }
          }
        }
      }
    });
  });

  group('Récompenses (ADR 0015)', () {
    test('une étoile par réussite, un autocollant toutes les 5, plafonné à 12', () {
      expect(Rewards.from(List.generate(4, (_) => ok())).stickers, 0);
      expect(Rewards.from(List.generate(5, (_) => ok())).stickers, 1);
      expect(Rewards.from(List.generate(7, (_) => ok())).toNext, 3);
      expect(Rewards.from(List.generate(500, (_) => ok())).stickers, stickersPerUniverse);
      expect(Rewards.from(List.generate(500, (_) => ok())).toNext, 0);
      expect(const Rewards(10).unlockedSince(const Rewards(9)), isTrue);
    });
  });

  group('Placement des objets', () {
    test('toujours n objets, jamais deux objets qui se chevauchent (n = 1 à 12, 200 tirages)', () {
      final r = Random(3);
      for (var n = 1; n <= 12; n++) {
        for (var k = 0; k < 200; k++) {
          for (final area in [const Size(440, 420), const Size(900, 330)]) {
            final s = Scatter(n, r);
            expect(s.spots.length, n);
            final rad = s.radius(area);
            final pts = [for (final p in s.spots) Offset(p.dx * area.width, p.dy * area.height)];
            for (var i = 0; i < n; i++) {
              for (var j = i + 1; j < n; j++) {
                expect((pts[i] - pts[j]).distance, greaterThan(2 * rad), reason: 'n=$n');
              }
            }
          }
        }
      }
    });
  });

  group('Fil d\'histoire et bruitages (ADR 0017)', () {
    final all = (jsonDecode(File('assets/content/univers.json').readAsStringSync())['univers'] as Map)
        .map((k, v) => MapEntry(k as String, UniverseWords(Map<String, dynamic>.from(v as Map))));
    test('intro avant la 1re séance, un épisode par séance, le dernier reste', () {
      for (final w in all.values) {
        expect(w.episode(0), isNull);
        expect(w.episode(1), 0);
        expect(w.episode(3), 2);
        expect(w.episode(500), w.story.length - 1);
      }
    });
    test('chaque monde a son bruitage, court, sans saturation, présent dans les assets', () {
      for (final u in universes) {
        expect(sfxNames, contains(u.id));
      }
      for (final name in sfxNames) {
        final s = samples(name);
        expect(s.length / sampleRate, lessThanOrEqualTo(sfxLength.inMilliseconds / 1000), reason: name);
        expect(s.map((v) => v.abs()).reduce(max), closeTo(0.5, 1e-9), reason: name);
        // les fichiers livrés sont bien ceux du code (sinon : dart run tool/build_sounds.dart)
        expect(File('assets/audio/sfx/$name.wav').readAsBytesSync(), wav(s), reason: name);
      }
    });
  });
}
