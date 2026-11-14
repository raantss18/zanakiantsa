import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/parent/rating.dart';

// Votre avis (ADR 0074) : le nombre d'étoiles lu dans avis.json, écrit par tool/build_site.py.
void main() {
  test('le nombre d\'étoiles du fichier du site', () {
    expect(starsFrom('{"etoiles": 12, "maj": "2026-11-14T16:35:21Z"}'), 12);
    expect(starsFrom('{"etoiles": 0}'), 0);
  });

  test('fichier absent, abîmé ou sans nombre : pas de nombre', () {
    expect(starsFrom('{"etoiles": null}'), isNull);
    expect(starsFrom('{"etoiles": -3}'), isNull);
    expect(starsFrom('<html>404</html>'), isNull);
    expect(starsFrom(''), isNull);
  });

  test('seules les pages du projet s\'ouvrent', () {
    expect(repoUrl, 'https://github.com/raantss18/zanakiantsa');
    expect(ratingUrl, startsWith('https://raantss18.github.io/zanakiantsa/'));
  });
}
