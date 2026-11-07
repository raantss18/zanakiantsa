import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/content/content.dart';
import 'package:zanakiantsa/core/events.dart';
import 'package:zanakiantsa/core/report.dart';
import 'package:zanakiantsa/update/updater.dart';

Topic topic() => Topic(jsonDecode(File('assets/content/compter.json').readAsStringSync()) as Map<String, dynamic>);

void main() {
  group('Contenu compilé', () {
    test('46 compétences, prérequis connus et placés avant', () {
      final t = topic();
      expect(t.skills.length, 46);
      final seen = <String>{};
      for (final s in t.skills) {
        expect(seen.containsAll(s.prerequisites), isTrue, reason: s.id);
        seen.add(s.id);
      }
    });

    test('questions toujours dans les bornes, sur 2 000 tirages', () {
      final r = Random(1);
      for (final s in topic().skills) {
        for (var i = 0; i < 2000; i++) {
          final q = s.draw(r);
          switch (s.activity) {
            case 'denombrer':
              expect(q.n, inInclusiveRange(s.p('min'), s.p('max')));
            case 'composer':
              expect(q.n, inInclusiveRange(s.p('cible_min'), s.p('cible_max')));
              expect(q.a, lessThan(q.n));
              expect(q.a + q.b, q.n);
            case 'batonnets' when s.params['mode'] == 'casser':
              expect(q.n, q.a * 10);
              expect(q.b, inInclusiveRange(1, 9));
              expect(s.expected(q), q.n - q.b);
              expect(s.expected(q), greaterThanOrEqualTo(1));
            case 'batonnets':
              expect(q.n, inInclusiveRange(s.p('min'), s.p('max')));
              expect(q.a * 10 + q.b, q.n);
            case 'multibase':
              expect(q.n, inInclusiveRange(s.p('min'), s.p('max')));
              expect(q.a * 100 + q.b * 10 + q.n % 10, q.n);
            case 'posee':
              final sub = s.params['op'] == '-';
              expect(q.n, sub ? q.a - q.b : q.a + q.b);
              expect(q.n, greaterThan(0));
              // Toujours une retenue (addition) ou une dizaine à casser (soustraction), comme demandé.
              expect(sub ? q.a % 10 < q.b % 10 : q.a % 10 + q.b % 10 >= 10, isTrue);
            case 'heure':
              expect(q.n, inInclusiveRange(1, 12));
              expect(List<int>.from(s.params['minutes'] as List), contains(q.b));
              expect(clockText(q.n, q.b), isNot(contains('{')));
            case 'paquets':
              expect(q.a * q.b, q.n);
              expect(q.a, inInclusiveRange(2, s.p('paquets_max')));
              expect(q.n, lessThanOrEqualTo(s.p('total_max')));
              expect(s.expected(q), q.a);
            case 'quiz': // test/levels_test.dart
              expect(q.n, inInclusiveRange(0, s.items.length - 1));
            case 'fraction': // test/fractions_test.dart
              expect(q.b, greaterThanOrEqualTo(2));
            case 'groupes' || 'tables' || 'partage':
              expect(q.a * q.b, q.n);
              if (s.params.containsKey('total_max')) expect(q.n, lessThanOrEqualTo(s.p('total_max')));
              if (s.activity == 'partage') expect(s.expected(q), q.b);
            default:
              expect(q.a + q.b, q.n);
              expect(q.n, lessThanOrEqualTo(s.p('total_max')));
              // a et b ≥ 1 : les énoncés sont de petites histoires (« il en arrive {b} »).
              expect(min(q.a, q.b), greaterThanOrEqualTo(1));
              if (s.params['forme'] == 'complement') {
                expect(q.n, 10);
                expect(s.expected(q), q.b);
                expect(q.b, greaterThan(0));
              }
          }
        }
      }
    });

    test('aucune phrase ne contient « faux » ni « échec » (ADR 0006/0008)', () {
      final text = File('assets/content/compter.json').readAsStringSync() + File('assets/content/commun.json').readAsStringSync();
      expect(text.toLowerCase(), isNot(contains('faux')));
      expect(text.toLowerCase(), isNot(contains('échec')));
    });

    test('les variables {n} {a} {b} sont toutes remplacées', () {
      final r = Random(2);
      for (final s in topic().skills) {
        final q = s.draw(r);
        for (final k in s.phrases.keys) {
          expect(s.say(k, q), isNot(contains('{')), reason: '${s.id}.$k');
        }
      }
    });
  });

  group('Rapport hebdomadaire', () {
    final now = DateTime(2026, 11, 9, 18);
    Answer a(String s, DateTime at, {bool ok = true, int attempts = 1}) =>
        Answer(skill: s, attempts: attempts, correct: ok, demonstrated: false, millis: 1, at: at);

    test('ne compte que les 7 derniers jours', () {
      final journal = [
        a('x', DateTime(2026, 11, 2, 9)), // hors fenêtre
        a('x', DateTime(2026, 11, 3, 9)),
        a('x', DateTime(2026, 11, 9, 9), ok: false, attempts: 3),
      ];
      final sessions = [
        SessionLog(theme: 'compter', started: DateTime(2026, 11, 1, 9), ended: DateTime(2026, 11, 1, 9, 10)),
        SessionLog(theme: 'compter', started: DateTime(2026, 11, 8, 9), ended: DateTime(2026, 11, 8, 9, 12)),
      ];
      final r = weekReport(['x', 'y'], journal, sessions, now);
      expect((r.sessions, r.minutes), (1, 12));
      expect(r.lines.single.answers, 2);
      expect(r.lines.single.successes, 1);
      expect(r.lines.single.helped, 1);
    });
  });

  group('Mise à jour signée (ADR 0011)', () {
    test('signature valide acceptée ; contenu modifié ou autre clé refusés', () async {
      final algo = Ed25519();
      final kp = await algo.newKeyPair();
      final pub = base64.encode((await kp.extractPublicKey()).bytes);
      final body = utf8.encode(jsonEncode({
        'format': 1,
        'latest': {
          'build': 2,
          'version': '0.2.0',
          'notes': 'test',
          'apk': {'url': 'https://example.invalid/a.apk', 'sha256': 'ab', 'bytes': 1},
        },
      }));
      final sig = base64.encode((await algo.sign(body, keyPair: kp)).bytes);
      expect((await parseSigned(body, sig, publicKey: pub))?.build, 2);
      final tampered = [...body]..[10] ^= 1;
      expect(await parseSigned(tampered, sig, publicKey: pub), isNull);
      expect(await parseSigned(body, sig), isNull, reason: 'clé de l’app ≠ clé de test');
    });
  });
}
