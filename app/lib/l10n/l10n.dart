/// Langue de l'app (ADR 0064) : français ou anglais, choisie dans l'espace parent pour tout l'appareil.
/// L'interface écrit `t('texte en français')` : le français est la clé, la traduction anglaise est dans `en.dart`.
/// Un texte sans traduction reste en français : `test/l10n_test.dart` vérifie que les écrans traduits n'en oublient pas.
library;

import 'en.dart';
import 'en_activites.dart';

/// 'fr' ou 'en'. Réglée par AppState au chargement et à chaque changement.
String appLang = 'fr';

bool get english => appLang == 'en';

/// Le texte dans la langue de l'app.
String t(String fr) => english ? (en[fr] ?? enActivites[fr] ?? fr) : fr;

/// Avec des valeurs : `tf('Version {v} disponible.', {'v': '1.0.0'})`.
String tf(String fr, Map<String, Object> values) {
  var s = t(fr);
  values.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

/// Une donnée de contenu dans la langue de l'app : le bloc `en:` du YAML remplace les champs qu'il contient.
Map<String, dynamic> localized(Map<String, dynamic> j) {
  final e = j['en'];
  if (!english || e is! Map) return j;
  return {...j, ...Map<String, dynamic>.from(e)};
}

/// Un domaine se montre en anglais seulement s'il est entièrement traduit : jamais deux langues mêlées à l'écran.
bool translated(Map<String, dynamic> theme) =>
    theme['en'] is Map && (theme['competences'] as List).every((s) => (s as Map)['en'] is Map);
