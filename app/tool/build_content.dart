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
  // ADR 0019
  'choisir': <String>{},
  'motif': {'base'},
  'ecouter': {'dimension', 'mots'},
  'echecs': {'piece', 'etoiles'},
  'dessin': <String>{},
  // ADR 0021 (cycle 2)
  'batonnets': {'mode', 'min', 'max'},
  'groupes': {'par_max', 'total_max'},
  'tables': {'tables'},
  'partage': {'par_max'},
  'paquets': {'par_min', 'par_max', 'paquets_max', 'total_max'},
  // ADR 0023
  'programmer': {'mode', 'grille', 'min', 'max'},
  // ADR 0024
  'solide': {'solides'},
  'planetes': <String>{},
  'corps': <String>{},
  // ADR 0031
  'syllabes': <String>{},
  'lettre': {'mode'},
  'tracer': {'style', 'lettres'},
  // ADR 0035 (CE1)
  'multibase': {'min', 'max'},
  'posee': {'op', 'min', 'max'},
  'heure': {'minutes'},
  // ADR 0036 (suites de nombres)
  'suite': {'pas', 'max'},
  // ADR 0040 (problèmes d'échecs sur de vraies positions)
  'probleme': {'theme'},
  // ADR 0041 (blocs : boucles et conditions)
  'blocs': {'mode'},
  // ADR 0056 (fractions)
  'fraction': {'mode', 'denominateurs'},
  // ADR 0057 (questions écrites, collège)
  'quiz': <String>{},
};
const sceneTargets = {
  'planetes': {'mercure', 'venus', 'terre', 'mars', 'jupiter', 'saturne', 'uranus', 'neptune'},
  'corps': {'tete', 'cou', 'tronc', 'bras', 'mains', 'jambes', 'pieds'},
};
const solidIds = {'cube', 'pave', 'boule', 'cylindre', 'cone', 'pyramide'};
/// Activités dont les questions sont écrites dans `items`.
const withItems = {'choisir', 'dessin', 'planetes', 'corps', 'syllabes', 'probleme', 'quiz'};
const letterModes = {'nom', 'casse', 'cursive', 'initiale', 'syllabe'};
const dimensions = {'hauteur', 'intensite', 'duree', 'tempo'};
const pieces = {'r', 'b', 'q', 'k', 'n', 'p'};
const chessModes = {'etoiles', 'prise', 'echec', 'mat'};
const requiredPhrases = {'consigne', 'question', 'indice', 'exemple', 'demonstration', 'bravo'};
final placeholder = RegExp(r'\{(\w+)\}');
const allowedPlaceholders = {
  'n', 'a', 'b', 'objet', 'objets', 'contenant', 'un', 'Chacun', 'prenom', //
  'texte', 'bonne', 'explication', 'mot', 'rep', 'choisi', // variables d'activité (ADR 0019, 0048)
  'dizaines', 'unites', 'reste', // bâtonnets (ADR 0021)
  'lettre', // lire et écrire (ADR 0031)
  'centaines', 'heure', // CE1 (ADR 0035)
  'pas', // suites de nombres (ADR 0036)
  'frac', 'frac2', 'plus', // fractions (ADR 0056)
};

/// Une image doit exister dans assets/art (Twemoji, licence dans assets/art/LICENCE.txt).
void checkArt(String where, String code) {
  if (!File('assets/art/$code.svg').existsSync()) fail(where, 'image absente : assets/art/$code.svg');
}

void checkItems(String where, String act, List items) {
  if (items.isEmpty) fail(where, 'items : au moins une question');
  for (final (i, raw) in items.indexed) {
    final it = Map<String, dynamic>.from(raw as Map);
    final w = '$where/items[$i]';
    if (it['texte'] is! String) fail(w, 'texte manquant');
    checkPhrase(w, it['texte'] as String? ?? '');
    if (act == 'syllabes') {
      if (it['image'] is! String) {
        fail(w, 'image manquante');
      } else {
        checkArt(w, it['image'] as String);
      }
      final syl = it['syllabes'] as List? ?? const [];
      if (syl.isEmpty || syl.length > 4) fail(w, 'syllabes : de 1 à 4');
    }
    if (sceneTargets.containsKey(act)) {
      if (!sceneTargets[act]!.contains(it['cible'])) fail(w, 'cible inconnue « ${it['cible']} »');
      if (it['explication'] is! String) fail(w, 'explication manquante');
    }
    if (act == 'probleme') {
      // Positions et solutions vérifiées par le moteur dans app/test/problems_test.dart.
      if (it['fen'] is! String) fail(w, 'fen manquante');
      if ((it['coups'] as List? ?? const []).isEmpty) fail(w, 'coups : au moins une solution');
      if (it['explication'] is! String) fail(w, 'explication manquante');
    }
    if (act == 'dessin') {
      // ADR 0038 : chaque sujet dit ce qu'on attend, et le modèle de dessins doit pouvoir le vérifier.
      for (final k in ['nom', 'cible', 'explication']) {
        if (it[k] is! String) fail(w, '$k manquant');
      }
      if (it['traits'] is! int) fail(w, 'traits : nombre minimum de traits');
    }
    if (act == 'quiz') {
      // ADR 0057 : chaque mauvaise réponse dit ce qu'elle montre.
      for (final k in ['nom', 'explication']) {
        if (it[k] is! String) fail(w, '$k manquant');
      }
      final traps = it['pieges'] as List? ?? const [];
      if (traps.length < 2) fail(w, 'au moins deux pièges');
      for (final t in traps) {
        if (t is! Map || t['texte'] is! String || t['pourquoi'] is! String) fail(w, 'piège : texte et pourquoi');
      }
      final all = [it['nom'], for (final t in traps) if (t is Map) t['texte']];
      if (all.toSet().length != all.length) fail(w, 'deux fois la même réponse');
      continue;
    }
    if (act != 'choisir') continue;
    final pics = [it['bonne'], ...(it['autres'] as List? ?? const [])];
    if ((it['autres'] as List? ?? const []).length < 2) fail(w, 'au moins deux autres images');
    if (it['explication'] is! String) fail(w, 'explication manquante');
    for (final p in pics) {
      if (p is! List || p.length != 2) {
        fail(w, 'image : [code, nom]');
      } else {
        checkArt(w, p[0] as String);
      }
    }
    if (pics.whereType<List>().map((p) => p[0]).toSet().length != pics.length) fail(w, 'deux fois la même image');
  }
}

/// Bloc `en:` d'une compétence (ADR 0064) : mêmes phrases que le français, mêmes questions dans le même ordre, mêmes
/// images ; seules les variables connues. Un bloc partiel mélangerait les langues à l'écran.
void checkEnglish(String where, Map<String, dynamic> s) {
  final e = s['en'];
  if (e == null) return;
  if (e is! Map) return fail(where, 'en : un bloc');
  final en = Map<String, dynamic>.from(e);
  for (final k in en.keys) {
    if (!{'titre', 'idee', 'phrases', 'variantes', 'items', 'langue', 'mots'}.contains(k)) fail(where, 'en : champ inconnu « $k »');
  }
  if (en['titre'] is! String) fail(where, 'en : titre manquant');
  final fr = Map<String, dynamic>.from(s['phrases'] as Map);
  final ph = Map<String, dynamic>.from(en['phrases'] as Map? ?? const {});
  if (!ph.keys.toSet().containsAll(fr.keys) || !fr.keys.toSet().containsAll(ph.keys)) fail(where, 'en : mêmes phrases que le français');
  for (final p in ph.values) {
    checkPhrase('$where/en', '$p');
  }
  if (s['idee'] != null && en['idee'] is! String) fail(where, 'en : idee manquante');
  if (en['idee'] != null) checkPhrase('$where/en/idee', en['idee'] as String);
  if ((s['variantes'] as List?)?.length != (en['variantes'] as List?)?.length) fail(where, 'en : autant de variantes');
  final items = s['items'] as List? ?? const [];
  final eitems = en['items'] as List? ?? const [];
  if (items.length != eitems.length) fail(where, 'en : autant de questions (${items.length})');
  for (var i = 0; i < items.length && i < eitems.length; i++) {
    final a = Map<String, dynamic>.from(items[i] as Map), b = Map<String, dynamic>.from(eitems[i] as Map);
    if (!a.keys.toSet().containsAll(b.keys) || !b.keys.toSet().containsAll(a.keys)) fail(where, 'en : question ${i + 1}, mêmes champs');
    String art(Object? x) => x is List ? '${x[0]}' : '';
    if (art(a['bonne']) != art(b['bonne'])) fail(where, 'en : question ${i + 1}, même image');
    if (a['image'] != b['image'] || a['fen'] != b['fen'] || '${a['coups']}' != '${b['coups']}') fail(where, 'en : question ${i + 1}, même image ou position');
  }
}

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
  for (final k in ['nom', 'icone']) {
    if (theme[k] is! String) fail('$id/_theme.yaml', 'champ « $k » manquant');
  }
  checkArt('$id/_theme.yaml', theme['icone'] as String? ?? '');
  // Animation de méthode (ADR 0033) : 2 à 4 scènes, texte court, images existantes.
  final intro = theme['intro'] as List? ?? const [];
  if (intro.length < 2 || intro.length > 4) fail('$id/_theme.yaml', 'intro : de 2 à 4 scènes');
  for (final sc in intro) {
    final m = Map<String, dynamic>.from(sc as Map);
    if (m['texte'] is! String || (m['texte'] as String).length > 90) fail('$id/_theme.yaml', 'intro : texte de 90 caractères au plus');
    for (final img in m['images'] as List? ?? const []) {
      checkArt('$id/_theme.yaml', img as String);
    }
  }
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
      if (withItems.contains(act)) checkItems(where, act as String, s['items'] as List? ?? const []);
      if (act == 'ecouter' && (!dimensions.contains(params['dimension']) || (params['mots'] as List?)?.length != 2)) {
        fail(where, 'ecouter : dimension ${dimensions.join('|')} et deux mots');
      }
      if (act == 'lettre') {
        if (!letterModes.contains(params['mode'])) fail(where, 'lettre : mode ${letterModes.join('|')}');
        if (params['mode'] == 'initiale') {
          for (final it in s['items'] as List? ?? const []) {
            final m = Map<String, dynamic>.from(it as Map);
            if (m['lettre'] is! String || m['image'] is! String) fail(where, 'initiale : texte, image et lettre');
            if (m['image'] is String) checkArt(where, m['image'] as String);
          }
          if ((s['items'] as List? ?? const []).length < 4) fail(where, 'initiale : au moins 4 mots');
        }
      }
      if (act == 'solide') {
        final l = List<String>.from(params['solides'] as List);
        if (l.length < 3 || !solidIds.containsAll(l)) fail(where, 'solide : au moins trois parmi ${solidIds.join('|')}');
      }
      if (act == 'echecs') {
        if (!pieces.contains(params['piece'])) fail(where, 'echecs : pièce ${pieces.join('|')}');
        final mode = params['mode'] ?? 'etoiles';
        if (!chessModes.contains(mode)) fail(where, 'echecs : mode ${chessModes.join('|')}');
        if (mode == 'mat' && !{'r', 'q'}.contains(params['piece'])) fail(where, 'echecs : mat avec r ou q seulement');
        if (mode == 'echec' && {'k', 'p'}.contains(params['piece'])) fail(where, 'echecs : échec avec r, b, q ou n');
      }
      if (act == 'motif' && !RegExp(r'^(AB|ABB|AAB|ABC|AB\+)$').hasMatch('${params['base']}')) {
        fail(where, 'motif : base AB, ABB, AAB, ABC ou AB+ (évolutif)');
      }
    }
    final prog = Map<String, dynamic>.from(s['programme'] as Map);
    if (!sources.containsKey(prog['source'])) fail(where, 'source de programme inconnue « ${prog['source']} »');
    final phrases = Map<String, dynamic>.from(s['phrases'] as Map);
    final missing = requiredPhrases.difference(phrases.keys.toSet());
    if (missing.isNotEmpty) fail(where, 'phrases manquantes : ${missing.join(', ')}');
    phrases.forEach((k, v) => checkPhrase('$where/$k', v as String));
    // Autres énoncés de la même question (ADR 0030) : facultatifs, au plus 6.
    final variantes = s['variantes'];
    if (variantes != null) {
      if (variantes is! List || variantes.length > 6 || variantes.any((v) => v is! String)) {
        fail(where, 'variantes : une liste de 6 phrases au plus');
      } else {
        for (final (i, v) in variantes.indexed) {
          checkPhrase('$where/variantes[$i]', v as String);
        }
      }
    }
    // Idée de la découverte guidée (ADR 0029) : facultative, 2–3 phrases courtes.
    if (s.containsKey('idee')) {
      final idee = s['idee'];
      if (idee is! String || idee.length > 220) fail(where, 'idee : une chaîne de 220 caractères au plus');
      checkPhrase('$where/idee', idee as String? ?? '');
    }
    checkEnglish(where, s);
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
    'nom': theme['nom'],
    'icone': theme['icone'],
    'intro': intro,
    'ages': theme['ages'],
    if (theme['en'] != null) 'en': theme['en'],
    'sources': sources,
    'competences': [for (final sid in order) if (skills[sid] != null) skills[sid]],
  };
}

/// Univers (ADR 0014) : genre connu, deux objets [singulier, pluriel, m/f], contenant, intro et histoire présents.
void checkUniverses(Map<String, dynamic> u) {
  final all = Map<String, dynamic>.from(u['univers'] as Map);
  for (final g in ['garcon', 'fille']) {
    if (all.values.where((v) => (v as Map)['genre'] == g).length != 3) fail('univers.yaml', '3 univers attendus pour « $g »');
  }
  all.forEach((id, v) {
    final m = Map<String, dynamic>.from(v as Map);
    for (final k in ['genre', 'prenom', 'nom', 'mascotte', 'objets', 'contenant', 'intro']) {
      if (!m.containsKey(k)) fail('univers.yaml/$id', 'champ « $k » manquant');
    }
    final story = m['histoire'] as List? ?? const [];
    if (story.length < 6) fail('univers.yaml/$id', 'histoire : au moins 6 épisodes');
    for (final e in story) {
      if ((e as String).length > 70) fail('univers.yaml/$id', 'épisode trop long (> 70 car.) : $e');
    }
    final objs = m['objets'] as List? ?? const [];
    if (objs.length != 2 || objs.any((o) => (o as List).length != 3 || !['m', 'f'].contains(o[2]))) {
      fail('univers.yaml/$id', 'objets : deux entrées [singulier, pluriel, m|f]');
    }
  });
}

void main(List<String> args) {
  final check = args.contains('--check');
  final root = Directory('../content');
  final outputs = <String, String>{};
  final voice = <String>['id;texte'];
  const json = JsonEncoder.withIndent('  ');

  final commun = load(File('${root.path}/commun.yaml'));
  outputs['assets/content/commun.json'] = '${json.convert(commun)}\n';
  final univers = load(File('${root.path}/univers.yaml'));
  checkUniverses(univers);
  outputs['assets/content/univers.json'] = '${json.convert(univers)}\n';
  (univers['univers'] as Map).forEach((id, u) {
    voice.add('univers.$id.intro;${(u as Map)['intro']}');
    final story = u['histoire'] as List;
    for (var i = 0; i < story.length; i++) {
      voice.add('univers.$id.histoire.$i;${story[i]}');
    }
  });
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

  // Domaines : l'ordre de domaines.yaml ; chaque dossier doit y être, et inversement (ADR 0018).
  final domains = load(File('${root.path}/domaines.yaml'));
  final order = List<String>.from(domains['ordre'] as List);
  final dirs = {for (final d in root.listSync().whereType<Directory>()) d.path.split('/').last: d};
  if (order.toSet().length != order.length || !order.toSet().containsAll(dirs.keys) || !dirs.keys.toSet().containsAll(order)) {
    fail('domaines.yaml', '« ordre » doit lister chaque dossier de content/ une fois');
  }
  outputs['assets/content/domaines.json'] = '${json.convert(domains)}\n';
  for (final name in order.where(dirs.containsKey)) {
    final theme = buildTheme(dirs[name]!);
    if (theme['id'] != name) fail('$name/_theme.yaml', 'l’id doit être le nom du dossier');
    outputs['assets/content/${theme['id']}.json'] = '${json.convert(theme)}\n';
    for (final (i, sc) in (theme['intro'] as List).indexed) {
      voice.add('${theme['id']}.intro.$i;${sc['texte']}');
    }
    for (final s in theme['competences'] as List) {
      (s['phrases'] as Map).forEach((k, v) => voice.add('${s['id']}.$k;$v'));
      if (s['idee'] != null) voice.add('${s['id']}.idee;${s['idee']}');
      for (final (i, v) in (s['variantes'] as List? ?? const []).indexed) {
        voice.add('${s['id']}.variantes.$i;$v');
      }
      for (final (i, it) in (s['items'] as List? ?? const []).indexed) {
        voice.add('${s['id']}.items.$i;${it['texte']}');
        if (it['explication'] != null) voice.add('${s['id']}.items.$i.explication;${it['explication']}');
      }
    }
  }
  // Une ligne par phrase : les retours à la ligne (programmes affichés ligne à ligne) deviennent « / ».
  outputs['../docs/voix/script.csv'] = '${voice.map((l) => l.replaceAll('\n', ' / ')).join('\n')}\n';

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
