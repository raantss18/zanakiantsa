import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/audio/spoken.dart';

// ADR 0067 : ce que la voix dit des notations de maths.
void main() {
  String fr(String s) => spoken(s, 'fr');
  String en(String s) => spoken(s, 'en');

  test('signes et opérations', () {
    expect(fr('mettre x à x * 3'), 'mettre x à x fois 3');
    expect(en('set x to x * 2'), 'set x to x times 2');
    expect(fr('Combien font 2,5 × 4 ?'), 'Combien font 2,5 fois 4 ?');
    expect(fr('(−5) + 3 = −2'), '(moins 5) + 3 = moins 2');
    expect(fr('12 ÷ 4'), '12 divisé par 4');
    expect(en('−3 × 2'), 'minus 3 times 2');
  });

  test('fractions, puissances, racines', () {
    expect(fr('Combien font 3/4 de 20 ?'), 'Combien font 3 sur 4 de 20 ?');
    expect(fr('x² + 1'), 'x au carré + 1');
    expect(fr('10⁴ = 10 000'), '10 puissance 4 = 10 000');
    expect(fr('10⁻³'), '10 puissance moins 3');
    expect(fr('√49 = 7'), 'racine carrée de 49 = 7');
    expect(fr('Une aire de 12 cm²'), 'Une aire de 12 centimètres carrés');
    expect(en('An area of 12 cm²'), 'An area of 12 square centimetres');
    expect(fr('0,8⁵'), '0,8 puissance 5');
  });

  test('suites, fonctions, intervalles', () {
    expect(fr('uₙ₊₁ = uₙ + 3'), 'u indice n+1 = u indice n + 3');
    expect(fr("f′(x) = 2x"), 'f prime de x = 2x');
    expect(fr('f(3) = 7'), 'f de 3 = 7');
    expect(fr('E(X) = n × p'), 'E de X = n fois p');
    expect(en('P(A) = 0,3'), 'P of A = 0,3');
    expect(
      fr('x ∈ ]3 ; +∞['),
      "x appartient à l’intervalle de 3 à plus l'infini, 3 exclu",
    );
    expect(fr('[0 ; 5]'), 'l’intervalle de 0 à 5, 0 compris, 5 compris');
    expect(fr('Δ = b² − 4ac'), 'delta = b au carré moins 4ac');
  });

  test('ce qui ne doit pas changer', () {
    for (final s in [
      'Bonjour ! Je suis Robi.',
      'Il est 14 h 30.',
      'Touche le chiffre 7.',
      'Le 25 décembre.',
      '2026-11-08',
    ]) {
      expect(fr(s), s);
    }
    expect(fr('pi'), 'pi');
  });

  test('chimie et unités', () {
    expect(fr('1s² 2s² 2p⁶ 3s¹'), '1s 2 2s 2 2p 6 3s 1');
    expect(fr('L’ion Na⁺ et l’ion Cl⁻.'), 'L’ion Na plus et l’ion Cl moins.');
    expect(fr('Ca²⁺'), 'Ca 2 plus');
    expect(fr('¹²₆C'), 'C, nombre de masse 12, numéro atomique 6');
    expect(fr('≈ 340 W/m²'), 'environ 340 watts par mètre carré');
    expect(en('about 340 W/m²'), 'about 340 watts per square metre');
    expect(fr('90 km/h, soit 25 m/s'), '90 kilomètres par heure, soit 25 mètres par seconde');
    expect(fr('15 °C'), '15 degrés Celsius');
    expect(fr('10⁻¹⁰ m'), '10 puissance moins 10 m');
  });
}
