/// Ce que la voix dit d'un texte écrit (ADR 0067) : les notations de maths deviennent des mots, l'écran ne change pas.
/// Sans cela, la synthèse vocale lit « 3/4 » comme une date, « −5 » comme un tiret, « x² » comme « x 2 », et saute
/// « ]3 ; +∞[ » ou « uₙ₊₁ ». Pur Dart, testé dans `test/spoken_test.dart`.
library;

const _sup = {
  '⁰': '0',
  '¹': '1',
  '²': '2',
  '³': '3',
  '⁴': '4',
  '⁵': '5',
  '⁶': '6',
  '⁷': '7',
  '⁸': '8',
  '⁹': '9',
  '⁻': '−',
  'ᵏ': 'k',
  'ⁿ': 'n',
};
const _sub = {
  '₀': '0',
  '₁': '1',
  '₂': '2',
  '₃': '3',
  '₄': '4',
  '₅': '5',
  '₆': '6',
  '₇': '7',
  '₈': '8',
  '₉': '9',
  'ₙ': 'n',
  '₊': '+',
  '₋': '−',
  'ₖ': 'k',
};

String _map(String s, Map<String, String> m) =>
    s.split('').map((c) => m[c] ?? c).join();

/// [lang] : 'fr' ou 'en'.
String spoken(String text, String lang) {
  final fr = lang != 'en';
  var s = text;
  String w(String f, String e) => fr ? f : e;

  // Intervalles : ]3 ; +∞[ , [0 ; 5]. Le crochet dit si la borne est comprise.
  s = s.replaceAllMapped(
    RegExp(r'([\[\]])\s*([^\[\];]{1,24}?)\s*;\s*([^\[\];]{1,24}?)\s*([\[\]])'),
    (m) {
      final a = m[2]!, b = m[3]!;
      final aIn = m[1] == '[', bIn = m[4] == ']';
      String bound(String v, bool inside) => v.contains('∞')
          ? ''
          : (inside
                ? w(', $v compris', ', $v included')
                : w(', $v exclu', ', $v excluded'));
      return w('l’intervalle de $a à $b', 'the interval from $a to $b') +
          bound(a, aIn) +
          bound(b, bIn);
    },
  );

  // Indices : uₙ₊₁ → u indice n+1.
  s = s.replaceAllMapped(
    RegExp('([A-Za-z])([₀-₉ₙₖ₊₋]+)'),
    (m) => '${m[1]} ${w('indice', 'sub')} ${_map(m[2]!, _sub)}',
  );

  // Puissances : x², 10⁴, 10⁻³, pᵏ.
  s = s.replaceAllMapped(RegExp('([0-9A-Za-z)])([⁰¹²³⁴⁵⁶⁷⁸⁹⁻ᵏⁿ]+)'), (m) {
    final e = _map(m[2]!, _sup);
    final base = m[1]!;
    if (e == '2') return '$base ${w('au carré', 'squared')}';
    if (e == '3' && !RegExp('[0-9]').hasMatch(base)) {
      return '$base ${w('au cube', 'cubed')}';
    }
    return '$base ${w('puissance', 'to the power of')} $e';
  });
  // Unités d'aire et de volume dites en entier (après les puissances : « cm au carré » se corrige ici).
  s = s
      .replaceAllMapped(
        RegExp(r'\b(k?m|cm|mm|dm) au carré'),
        (m) => '${_unit(m[1]!, fr)} ${w('carrés', 'squared')}',
      )
      .replaceAllMapped(
        RegExp(r'\b(k?m|cm|mm|dm) squared'),
        (m) => 'square ${_unit(m[1]!, fr)}',
      )
      .replaceAllMapped(
        RegExp(r'\b(k?m|cm|mm|dm) au cube'),
        (m) => '${_unit(m[1]!, fr)} ${w('cubes', 'cubed')}',
      );

  // Fonctions : f′(x) → f prime de x ; f(x) → f de x ; ‖u‖ → norme de u ; √ → racine carrée de.
  s = s.replaceAllMapped(
    RegExp(r"\b([fgh])[′']\(([a-z0-9]+)\)"),
    (m) => w('${m[1]} prime de ${m[2]}', '${m[1]} prime of ${m[2]}'),
  );
  s = s.replaceAllMapped(
    // f(3), E(X), P(A), V(X) : « f de 3 », « E de X ».
    RegExp(r'\b([fghEPV])\(([A-Za-z0-9]{1,3})\)'),
    (m) => w('${m[1]} de ${m[2]}', '${m[1]} of ${m[2]}'),
  );
  s = s.replaceAllMapped(
    RegExp(r'‖\s*([^‖]+?)\s*‖'),
    (m) => w('norme de ${m[1]}', 'magnitude of ${m[1]}'),
  );
  s = s.replaceAll('√', w(' racine carrée de ', ' square root of '));

  // Fractions écrites a/b (pas les dates : un seul chiffre ou deux de chaque côté, entourés d'espaces ou de ponctuation).
  s = s.replaceAllMapped(
    RegExp(r'(?<![\d/])(\d{1,3})\s*/\s*(\d{1,3})(?![\d/])'),
    (m) => '${m[1]} ${w('sur', 'over')} ${m[2]}',
  );

  // Signes.
  s = s
      .replaceAllMapped(
        RegExp(r'(^|[\s(=:;,])[−-](?=\s?\d)'),
        (m) => '${m[1]}${w('moins ', 'minus ')}',
      )
      .replaceAll('−', w(' moins ', ' minus '))
      .replaceAll('×', w(' fois ', ' times '))
      .replaceAll('÷', w(' divisé par ', ' divided by '))
      .replaceAll('≤', w(' inférieur ou égal à ', ' less than or equal to '))
      .replaceAll('≥', w(' supérieur ou égal à ', ' greater than or equal to '))
      .replaceAll('≠', w(' différent de ', ' not equal to '))
      .replaceAll('≈', w(' environ ', ' about '))
      .replaceAll('+∞', w("plus l'infini", 'plus infinity'))
      .replaceAll('∞', w("l'infini", 'infinity'))
      .replaceAll('∈', w(' appartient à ', ' is in '))
      .replaceAll('π', ' pi ')
      .replaceAll('Δ', ' delta ');
  return s.replaceAll(RegExp(r' {2,}'), ' ').trim();
}

String _unit(String u, bool fr) => switch (u) {
  'km' => fr ? 'kilomètres' : 'kilometres',
  'm' => fr ? 'mètres' : 'metres',
  'dm' => fr ? 'décimètres' : 'decimetres',
  'cm' => fr ? 'centimètres' : 'centimetres',
  _ => fr ? 'millimètres' : 'millimetres',
};
