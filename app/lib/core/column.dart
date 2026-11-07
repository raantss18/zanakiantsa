/// Opérations posées en colonnes, chiffre par chiffre (ADR 0046) : l'enfant écrit lui-même chaque chiffre du
/// résultat, de droite à gauche, et la retenue (addition) ou la dizaine cassée (soustraction « par cassage »).
/// Repère : « Poser et effectuer des additions en colonnes : l'élève positionne les unités sous les unités, les dizaines
/// sous les dizaines » ; soustraction posée « par cassage » ou « par compensation » (repères annuels de progression,
/// cycle 2, CE1 — texte cité dans content/compter/addition-posee.yaml et soustraction-posee.yaml).
library;

import 'dart:math';

import '../l10n/l10n.dart';

/// Ce qu'on écrit : un chiffre du résultat, une retenue (en haut de la colonne suivante), ou le nouveau chiffre des
/// dizaines du haut après en avoir cassé une.
enum ColumnKind { result, carry, borrow }

class ColumnStep {
  const ColumnStep(this.kind, this.column, this.value, this.prompt, this.why);
  final ColumnKind kind;

  /// 0 unités, 1 dizaines, 2 centaines.
  final int column;
  final int value;

  /// Ce qu'on demande à l'enfant (écrit et dit).
  final String prompt;

  /// Ce qu'on lui dit s'il se trompe : où regarder, sans donner le chiffre.
  final String why;
}

const columnNames = ['unités', 'dizaines', 'centaines'];

/// Le nom de la colonne dans la langue de l'app.
String _col(int c) => t(columnNames[c]);

int digit(int n, int col) => n ~/ [1, 10, 100][col] % 10;

int digits(int n) => n >= 100 ? 3 : n >= 10 ? 2 : 1;

/// Les étapes d'une addition posée : unités, retenue éventuelle, dizaines, centaines s'il en reste.
List<ColumnStep> additionSteps(int a, int b) {
  final out = <ColumnStep>[];
  final cols = max(digits(a), digits(b));
  var carry = 0;
  for (var c = 0; c < cols; c++) {
    final x = digit(a, c), y = digit(b, c), s = x + y + carry;
    final sum = carry == 0 ? '$x + $y' : tf('{x} + {y} + la retenue {c}', {'x': x, 'y': y, 'c': carry});
    out.add(ColumnStep(
      ColumnKind.result,
      c,
      s % 10,
      tf('Aux {col} : {sum}. Écris le chiffre des {col}.', {'col': _col(c), 'sum': sum}),
      s >= 10
          ? tf('Calcule {sum} : cela fait plus de dix. Écris seulement le chiffre des {col}.', {'sum': sum, 'col': _col(c)})
          : carry > 0
              ? tf("N'oublie pas la retenue : calcule {sum}.", {'sum': sum})
              : tf('Calcule {x} + {y}.', {'x': x, 'y': y}),
    ));
    carry = s ~/ 10;
    if (carry > 0 && c + 1 < cols) {
      out.add(ColumnStep(ColumnKind.carry, c + 1, carry, tf('{sum} = {s}. Écris la retenue en haut des {col}.', {'sum': sum, 's': s, 'col': _col(c + 1)}),
          tf('{s}, c\'est 1 dizaine et {u} unités : la dizaine part en retenue.', {'s': s, 'u': s % 10})));
    }
  }
  if (carry > 0) {
    out.add(ColumnStep(ColumnKind.result, cols, carry, tf('Il reste la retenue : écris-la aux {col}.', {'col': _col(cols)}),
        tf('La retenue, ce sont des {col} : on l\'écrit telle quelle.', {'col': _col(cols)})));
  }
  return out;
}

/// Les étapes d'une soustraction posée par cassage (a ≥ b) : si on ne peut pas enlever, on casse une dizaine du haut
/// (l'enfant écrit combien il en reste), puis on calcule. Pas de zéro inutile à gauche du résultat.
List<ColumnStep> subtractionSteps(int a, int b) {
  final out = <ColumnStep>[];
  final cols = digits(a);
  var borrowed = 0;
  for (var c = 0; c < cols; c++) {
    var x = digit(a, c) - borrowed;
    final y = digit(b, c);
    borrowed = 0;
    if (x < y) {
      final next = digit(a, c + 1);
      out.add(ColumnStep(
        ColumnKind.borrow,
        c + 1,
        next - 1,
        tf('On ne peut pas enlever {y} de {x} : on casse une dizaine. Combien en reste-t-il en haut ?', {'y': y, 'x': x}),
        next == 1 && english ? t('Il y avait 1 dizaine en haut ; on la casse.') : tf('Il y avait {n} dizaines en haut ; on en casse une.', {'n': next}),
      ));
      x += 10;
      borrowed = 1;
    }
    final r = x - y;
    if (c == cols - 1 && c > 0 && r == 0) break;
    out.add(ColumnStep(
      ColumnKind.result,
      c,
      r,
      tf('Aux {col} : {x} − {y}. Écris le résultat.', {'col': _col(c), 'x': x, 'y': y}),
      tf('On enlève le chiffre du bas de celui du haut : {x} − {y}.', {'x': x, 'y': y}),
    ));
  }
  return out;
}

List<ColumnStep> columnSteps(int a, int b, {required bool subtract}) => subtract ? subtractionSteps(a, b) : additionSteps(a, b);
