/// Les fractions (ADR 0056) : mots, réponses proposées et explication de chaque erreur, sans rien d'affichage, pour être
/// testés. Programme : cycle 2 (fractions d'un tout au CE1, bande-unité au CE2), cycle 3 (fractions supérieures à 1 et
/// fraction d'une quantité au CM1).
library;

import 'dart:math';

import '../l10n/l10n.dart';

class Frac {
  const Frac(this.n, this.d, {this.whole = 0});

  /// Numérateur et dénominateur ; [whole] : l'entier devant (« 1 + 3/4 »), pour les fractions supérieures à 1.
  final int n, d, whole;

  double get value => whole + n / d;

  @override
  bool operator ==(Object other) => other is Frac && other.n == n && other.d == d && other.whole == whole;
  @override
  int get hashCode => Object.hash(n, d, whole);
  @override
  String toString() => whole > 0 ? '$whole + $n/$d' : '$n/$d';
}

const _denominators = {
  2: 'demi', 3: 'tiers', 4: 'quart', 5: 'cinquième', 6: 'sixième', 7: 'septième', 8: 'huitième', 9: 'neuvième', 10: 'dixième', 12: 'douzième',
};
const _numbers = ['zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf', 'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf', 'vingt'];

const _denEn = {2: 'half', 3: 'third', 4: 'quarter', 5: 'fifth', 6: 'sixth', 7: 'seventh', 8: 'eighth', 9: 'ninth', 10: 'tenth', 12: 'twelfth'};
const _numEn = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty'];

/// « un demi », « trois huitièmes », « deux tiers » (« tiers » ne prend pas de marque du pluriel de plus) ; en anglais
/// « one half », « three eighths », « two thirds », « seven halves » (ADR 0064).
String fracWords(int n, int d) {
  if (english) {
    final name = _denEn[d] ?? 'over $d';
    final count = n < _numEn.length ? _numEn[n] : '$n';
    final plural = name == 'half' ? 'halves' : '${name}s';
    return n > 1 && _denEn.containsKey(d) ? '$count $plural' : '$count $name';
  }
  final name = _denominators[d] ?? 'sur $d';
  final count = n < _numbers.length ? _numbers[n] : '$n';
  return n > 1 && !name.endsWith('s') ? '$count ${name}s' : '$count $name';
}

/// « 1 et trois quarts » se dit, « 1 + 3/4 » s'écrit.
String fracSumWords(Frac f) => english ? '${f.whole} and ${fracWords(f.n, f.d)}' : '${f.whole} plus ${fracWords(f.n, f.d)}';

/// Trois réponses (la bonne et deux erreurs typiques, sans doublon), mélangées.
List<Frac> fracChoices(Frac right, List<Frac> typical, Random r, {required Frac Function(int) fill}) {
  final out = <Frac>{right};
  for (final t in typical) {
    if (out.length < 3 && t.n > 0 && t.d > 0) out.add(t);
  }
  for (var i = 1; out.length < 3; i++) {
    out.add(fill(i));
  }
  return out.toList()..shuffle(r);
}

/// Lire une fraction : parts coloriées et parts blanches confondues, numérateur et dénominateur inversés.
List<Frac> readChoices(int n, int d, Random r) => fracChoices(
      Frac(n, d),
      [Frac(d - n, d), Frac(d, n)],
      r,
      fill: (i) => Frac(n, d + i),
    );

/// Ajouter deux fractions de même dénominateur : l'erreur typique ajoute aussi les dénominateurs.
List<Frac> sumChoices(int a, int c, int d, Random r) => fracChoices(
      Frac(a + c, d),
      [Frac(a + c, 2 * d), Frac(a * c, d)],
      r,
      fill: (i) => Frac(a + c + i, d),
    );

/// Une fraction supérieure à 1 écrite avec un entier : l'entier ou le reste se trompe.
List<Frac> wholeChoices(int n, int d, Random r) {
  final w = n ~/ d, rest = n % d;
  return fracChoices(
    Frac(rest, d, whole: w),
    [Frac(rest, d, whole: w + 1), Frac(d - rest, d, whole: w)],
    r,
    fill: (i) => Frac(rest, d, whole: w + 1 + i),
  );
}

/// Trois nombres pour « un tiers de 12 » : le bon, le dénominateur lu comme résultat, et un voisin.
List<int> quantityChoices(int right, int total, int d, Random r) {
  final out = <int>{right};
  for (final t in [d, total - right, right + 1, right + 2]) {
    if (out.length < 3 && t > 0) out.add(t);
  }
  return out.toList()..shuffle(r);
}

/// Ce que montre une réponse fausse à la lecture d'une fraction ; null si on ne sait rien en dire.
String? readWhy(Frac right, Frac chosen) {
  if (chosen.d == right.n && chosen.n == right.d) return t('En bas, on écrit le nombre total de parts ; en haut, les parts coloriées.');
  if (chosen.d == right.d && chosen.n == right.d - right.n) return t('Ça, ce sont les parts blanches. On compte les parts coloriées.');
  return null;
}

String? sumWhy(Frac right, Frac chosen) {
  if (chosen.d == 2 * right.d) return t('Les parts gardent la même taille : le dénominateur ne change pas.');
  if (chosen.d == right.d) return t('Le dénominateur ne change pas : on ajoute seulement les parts coloriées.');
  return null;
}

String? wholeWhy(Frac right, Frac chosen) {
  if (chosen.whole != right.whole) return t('Compte les bandes entièrement coloriées : ce nombre est l\'entier.');
  if (chosen.n != right.n) return t('Regarde la dernière bande : compte seulement ses parts coloriées.');
  return null;
}

String colorWhy(int colored, int wanted, int d) => colored < wanted
    ? colored > 1 || (english && colored == 0)
        ? tf('Tu as colorié {n} parts sur {d}. Il en faut plus.', {'n': colored, 'd': d})
        : tf('Tu as colorié {n} part sur {d}. Il en faut plus.', {'n': colored, 'd': d})
    : tf('Tu as colorié {n} parts sur {d}. C\'est trop.', {'n': colored, 'd': d});

/// Comparer deux fractions de numérateur 1 : plus on partage, plus les parts sont petites (c'est contre-intuitif, dit le
/// programme, pour qui ne regarde que 3 < 6).
String unitCompareWhy(int smallD, int bigD) => tf('{big}, c\'est plus petit que {small} : plus on partage, plus les parts sont petites.',
    {'big': '${fracWords(1, bigD)[0].toUpperCase()}${fracWords(1, bigD).substring(1)}', 'small': fracWords(1, smallD)});

String sameCompareWhy(int more, int less, int d) =>
    tf('Les parts ont la même taille : {more} parts, c\'est plus que {less} parts.', {'more': more, 'less': less});

String placeWhy(int tapped, int wanted, int d) => tapped == d && wanted < d
    ? tf('Tout au bout, c\'est la bande entière : {d} parts sur {d}.', {'d': d})
    : tapped > 1 || (english && tapped == 0)
        ? tf('Ici, ça fait {n} parts depuis zéro. Il en faut {w}.', {'n': tapped, 'w': wanted})
        : tf('Ici, ça fait {n} part depuis zéro. Il en faut {w}.', {'n': tapped, 'w': wanted});

String quantityWhy(int chosen, int d) => chosen == d
    ? tf('{d}, c\'est le nombre de parts. On cherche combien il y en a dans une part.', {'d': d})
    : tf('Partage en {d} parts égales, puis compte une seule part.', {'d': d});
