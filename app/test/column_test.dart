import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/core/column.dart';

// Opérations posées chiffre par chiffre (ADR 0046).
List<(ColumnKind, int, int)> s(List<ColumnStep> steps) => [for (final x in steps) (x.kind, x.column, x.value)];

void main() {
  test('45 + 37 : unités, retenue, dizaines', () {
    expect(s(additionSteps(45, 37)), [(ColumnKind.result, 0, 2), (ColumnKind.carry, 1, 1), (ColumnKind.result, 1, 8)]);
  });

  test('23 + 14 : sans retenue', () {
    expect(s(additionSteps(23, 14)), [(ColumnKind.result, 0, 7), (ColumnKind.result, 1, 3)]);
  });

  test('78 + 65 : retenue aux dizaines, puis centaine', () {
    expect(s(additionSteps(78, 65)),
        [(ColumnKind.result, 0, 3), (ColumnKind.carry, 1, 1), (ColumnKind.result, 1, 4), (ColumnKind.result, 2, 1)]);
  });

  test('52 − 27 : on casse une dizaine', () {
    expect(s(subtractionSteps(52, 27)), [(ColumnKind.borrow, 1, 4), (ColumnKind.result, 0, 5), (ColumnKind.result, 1, 2)]);
  });

  test('52 − 47 : pas de zéro inutile aux dizaines', () {
    expect(s(subtractionSteps(52, 47)), [(ColumnKind.borrow, 1, 4), (ColumnKind.result, 0, 5)]);
  });

  test('les chiffres écrits donnent toujours le bon résultat, sur tout le contenu', () {
    for (var a = 12; a <= 79; a++) {
      for (var b = 12; b <= 79; b++) {
        var n = 0;
        for (final x in additionSteps(a, b)) {
          if (x.kind == ColumnKind.result) n += x.value * [1, 10, 100][x.column];
        }
        expect(n, a + b, reason: '$a + $b');
      }
    }
    for (var a = 21; a <= 98; a++) {
      for (var b = 1; b <= a; b++) {
        var n = 0;
        for (final x in subtractionSteps(a, b)) {
          if (x.kind == ColumnKind.result) n += x.value * [1, 10, 100][x.column];
          expect(x.value, inInclusiveRange(0, 9), reason: '$a − $b');
        }
        expect(n, a - b, reason: '$a − $b');
      }
    }
  });

  test('l\'explication d\'une erreur ne donne jamais le chiffre attendu', () {
    for (final (a, b) in [(45, 37), (78, 65), (23, 14)]) {
      for (final x in additionSteps(a, b)) {
        if (x.kind == ColumnKind.result) expect(x.why.contains('= ${x.value}'), isFalse);
      }
    }
  });
}
