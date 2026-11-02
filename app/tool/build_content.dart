// Compile et valide le contenu : content/**/*.yaml → app/assets/content/*.json + docs/voix/script.csv.
// Usage (depuis app/) : dart run tool/build_content.dart [--check]
// --check : échoue si les fichiers générés ne correspondent pas au contenu (CI).
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const schemaVersion = 1;
const activities = {
  'denombrer': {'min', 'max', 'objet'},
  'composer': {'cible_min', 'cible_max', 'depart_min', 'depart_max'},
  'calcul': {'forme', 'total_max'},
};
const requiredPhrases = {'consigne', 'question', 'indice', 'exemple', 'demonstration', 'bravo'};
final placeholder = RegExp(r'\{(\w+)\}');
const allowedPlaceholders = {'n', 'a', 'b'};

final errors = <String>[];
void fail(String where, String msg) => errors.add('$where : $msg');

dynamic plain(dynamic y) => y is YamlMap
    ? {for (final e in y.entries) e.key.toString(): plain(e.value)}
    : y is YamlList
        ? [for (final v in y) plain(v)]
        : y;

Map<String, dynamic> load(File f) => Map<String, dynamic>.from(plain(loadYaml(f.readAsStringSync())) as Map);

void checkPhrase(String where, String text) {
  for (final m in placeholder.allMatches(text)) {
    if (!allowedPlaceholders.contains(m[1])) fail(where, 'variable inconnue {${m[1]}}');
  }
}

Map<String, dynamic> buildTheme(Directory dir) {
  final theme = load(File('${dir.path}/_theme.yaml'));
  final id = theme['id'] as String;
  final sources = Map<String, dynamic>.from(theme['sources'] as Map);
  final skills = <String, Map<String, dynamic>>{};
  for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.yaml') && !f.path.endsWith('_theme.yaml'))) {
    final s = load(f);
    final where = f.path.split('/').last;
    for (final k in ['id', 'titre', 'niveau', 'prerequis', 'programme', 'activite', 'parametres', 'phrases']) {
      if (!s.containsKey(k)) fail(where, 'champ « $k » manquant');
    }
    if (errors.isNotEmpty) continue;
    if ('${s['id']}.yaml' != where) fail(where, 'le nom du fichier doit être l’id');
    final act = s['activite'];
    final params = Map<String, dynamic>.from(s['parametres'] as Map);
    if (!activities.containsKey(act)) {
      fail(where, 'activité inconnue « $act »');
    } else {
      final missing = activities[act]!.difference(params.keys.toSet());
      if (missing.isNotEmpty) fail(where, 'paramètres manquants : ${missing.join(', ')}');
    }
    final prog = Map<String, dynamic>.from(s['programme'] as Map);
    if (!sources.containsKey(prog['source'])) fail(where, 'source de programme inconnue « ${prog['source']} »');
    final phrases = Map<String, dynamic>.from(s['phrases'] as Map);
    final missing = requiredPhrases.difference(phrases.keys.toSet());
    if (missing.isNotEmpty) fail(where, 'phrases manquantes : ${missing.join(', ')}');
    phrases.forEach((k, v) => checkPhrase('$where/$k', v as String));
    skills[s['id'] as String] = s;
  }
  final order = List<String>.from(theme['ordre'] as List);
  if (order.toSet().length != order.length || !order.toSet().containsAll(skills.keys) || !skills.keys.toSet().containsAll(order)) {
    fail('$id/_theme.yaml', '« ordre » doit lister chaque compétence une fois');
  }
  // Prérequis existants et placés avant (donc pas de cycle).
  for (final (i, sid) in order.indexed) {
    for (final p in List<String>.from(skills[sid]?['prerequis'] as List? ?? const [])) {
      if (!skills.containsKey(p)) fail('$sid.yaml', 'prérequis inconnu « $p »');
      if (order.indexOf(p) >= i) fail('$sid.yaml', 'le prérequis « $p » doit venir avant dans « ordre »');
    }
  }
  return {
    'schema': schemaVersion,
    'id': id,
    'titre': theme['titre'],
    'ages': theme['ages'],
    'sources': sources,
    'competences': [for (final sid in order) if (skills[sid] != null) skills[sid]],
  };
}

void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory('../content');
  final outputs = <String, String>{};
  final voice = <String>['id;texte'];
  const json = JsonEncoder.withIndent('  ');

  final commun = load(File('${root.path}/commun.yaml'));
  outputs['assets/content/commun.json'] = '${json.convert(commun)}\n';
  final cp = Map<String, dynamic>.from(commun['phrases'] as Map);
  cp.forEach((k, v) {
    if (v is List) {
      for (final (i, t) in v.indexed) {
        voice.add('commun.$k.$i;$t');
      }
    } else {
      voice.add('commun.$k;$v');
    }
  });

  for (final dir in root.listSync().whereType<Directory>().toList()..sort((a, b) => a.path.compareTo(b.path))) {
    final theme = buildTheme(dir);
    outputs['assets/content/${theme['id']}.json'] = '${json.convert(theme)}\n';
    for (final s in theme['competences'] as List) {
      (s['phrases'] as Map).forEach((k, v) => voice.add('${s['id']}.$k;$v'));
    }
  }
  outputs['../docs/voix/script.csv'] = '${voice.join('\n')}\n';

  if (errors.isNotEmpty) {
    stderr.writeln('Contenu invalide :\n${errors.map((e) => '  - $e').join('\n')}');
    exit(1);
  }
  var stale = false;
  outputs.forEach((path, text) {
    final f = File(path);
    if (check) {
      if (!f.existsSync() || f.readAsStringSync() != text) {
        stderr.writeln('À régénérer : $path');
        stale = true;
      }
    } else {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(text);
      stdout.writeln('écrit $path');
    }
  });
  if (stale) exit(1);
}
