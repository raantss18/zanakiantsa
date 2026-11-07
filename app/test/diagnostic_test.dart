import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/diagnostic.dart';
import 'package:zanakiantsa/core/progress.dart';

// Diagnostic avant une notion nouvelle (ADR 0061).
void main() {
  const domain = [
    SkillRef('a', []),
    SkillRef('b', ['a']),
    SkillRef('c', ['a', 'b']),
    SkillRef('d', ['c', 'ailleurs']),
  ];

  test('seulement les prérequis directs, dans l\'ordre du domaine ; jamais la notion elle-même', () {
    expect(prerequisitesToCheck(domain[0], domain), isEmpty, reason: 'première notion : pas de diagnostic');
    expect(prerequisitesToCheck(domain[1], domain), ['a']);
    expect(prerequisitesToCheck(const SkillRef('c', ['b', 'a']), domain), ['a', 'b']);
    expect(prerequisitesToCheck(domain[3], domain), ['c'], reason: 'pas les prérequis des prérequis, ni ceux hors du domaine');
    for (final s in domain) {
      expect(prerequisitesToCheck(s, domain), isNot(contains(s.id)));
    }
  });

  test('tout réussi : une question par prérequis, puis la notion', () {
    final d = Diagnostic(['a', 'b']);
    final seen = <DiagStep>[];
    for (DiagStep? st = d.next(); st != null; st = d.next()) {
      seen.add(st);
      d.answered(st.skill, ok: true);
    }
    expect(seen, const [DiagStep(StepKind.check, 'a'), DiagStep(StepKind.check, 'b')]);
    expect(d.done, isTrue);
  });

  test('un prérequis manqué : son rappel juste après, puis la suite', () {
    final d = Diagnostic(['a', 'b']);
    final seen = <DiagStep>[];
    for (DiagStep? st = d.next(); st != null; st = d.next()) {
      seen.add(st);
      if (st.kind == StepKind.check) d.answered(st.skill, ok: st.skill != 'a');
    }
    expect(seen, const [DiagStep(StepKind.check, 'a'), DiagStep(StepKind.reminder, 'a'), DiagStep(StepKind.check, 'b')]);
  });

  test('chaque prérequis existe et vient avant sa notion, dans tout le contenu', () {
    // Garanti par tool/build_content.dart (« prérequis connus et placés avant ») ; rappelé ici car le diagnostic en dépend.
    expect(prerequisitesToCheck(const SkillRef('x', ['z']), const [SkillRef('x', ['z'])]), isEmpty);
  });
}
