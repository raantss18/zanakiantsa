import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/diagnostic.dart';
import 'package:zanakiantsa/ui/session.dart';

/// Reprise d'une séance laissée en cours (ADR 0078) : tout ce qu'il faut pour repartir au même endroit se garde et se
/// relit, pour toutes les sortes de séances.
void main() {
  test('une reprise se garde et se relit telle quelle', () {
    const r = SessionResume(['a', 'b', 'c'], 1, 2,
        kind: SessionResume.lecon,
        topic: 'monde',
        lesson: 'b',
        firstTry: 1,
        diag: ['check:a', 'reminder:x'],
        introduced: ['a'],
        diagnosed: ['b'],
        day: 20261115);
    final back = SessionResume.fromJson(jsonDecode(jsonEncode(r.toJson())))!;
    expect(back.plan, r.plan);
    expect(back.index, 1);
    expect(back.stars, 2);
    expect(back.kind, SessionResume.lecon);
    expect(back.lesson, 'b');
    expect(back.firstTry, 1);
    expect(back.diag, r.diag);
    expect(back.introduced, ['a']);
    expect(back.diagnosed, ['b']);
    expect(back.day, 20261115);
  });

  test('l\'ancien format (parcours seul) se relit encore', () {
    final r = SessionResume.fromJson({'plan': ['a', 'b'], 'index': 1, 'stars': 0}, topic: 'lire')!;
    expect(r.kind, SessionResume.parcours);
    expect(r.topic, 'lire');
    expect(r.key, 'reprise_lire');
  });

  test('une donnée abîmée ne fait rien planter', () {
    expect(SessionResume.fromJson('x'), isNull);
    expect(SessionResume.fromJson({'plan': ['a'], 'index': 'un', 'stars': 0}), isNull);
  });

  test('une clé par sorte de séance', () {
    expect(SessionResume.keyFor(SessionResume.parcours, 'lire', null), 'reprise_lire');
    expect(SessionResume.keyFor(SessionResume.lecon, 'lire', 'syllabes'), 'reprise_lecon_syllabes');
    expect(SessionResume.keyFor(SessionResume.defi, 'lire', null), 'reprise_defi_lire');
  });

  test('la vérification des prérequis reprend à l\'étape en cours', () {
    final d = Diagnostic(['p1', 'p2']);
    final current = d.next()!;
    final saved = [current.toString(), ...d.saved];
    final back = Diagnostic.restore(saved);
    expect(back.next(), const DiagStep(StepKind.check, 'p1'));
    expect(back.next(), const DiagStep(StepKind.check, 'p2'));
    expect(back.next(), isNull);
    expect(Diagnostic.restore(['n\'importe', 'reminder:p3']).next(), const DiagStep(StepKind.reminder, 'p3'));
  });
}
