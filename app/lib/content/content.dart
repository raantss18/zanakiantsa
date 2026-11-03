/// Contenu compilé par `tool/build_content.dart` (assets/content/*.json) et génération des questions.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../core/progress.dart';

/// Les mots d'univers dont une phrase a besoin : l'objet compté et le contenant.
class Words {
  const Words({
    required this.singular,
    required this.plural,
    required this.feminine,
    required this.container,
    this.firstName = 'Zaza',
  });
  final String singular, plural, container;

  /// Prénom de la mascotte de l'univers (« Robi a 2 engrenages… »).
  final String firstName;
  final bool feminine;

  static const neutral = Words(singular: 'objet', plural: 'objets', feminine: false, container: 'la boîte');
}

final _elision = RegExp(r"\b([Dd])e ([aeiouyàâéèêëîïôûœAEIOUYÉ])");

/// Remplit {n} {a} {b} {objet} {objets} {contenant} {prenom} {un} {Chacun}, puis les variables propres à l'activité
/// [vars] ({texte}, {bonne}, {explication}, {mot}, {rep}) ; « de » devant voyelle devient « d' ».
String fill(String text, Question q, Words? words, {Map<String, String> vars = const {}}) {
  final w = words ?? Words.neutral;
  // Les variables d'activité d'abord : un sujet de dessin peut lui-même contenir {un} {objet}.
  for (final e in vars.entries) {
    text = text.replaceAll('{${e.key}}', e.value);
  }
  // « 1 couronne », « 4 couronnes » : en français, 0 et 1 restent au singulier.
  String noun(int k) => k <= 1 ? w.singular : w.plural;
  final s = text
      .replaceAll('{n} {objets}', '${q.n} ${noun(q.n)}')
      .replaceAll('{a} {objets}', '${q.a} ${noun(q.a)}')
      .replaceAll('{b} {objets}', '${q.b} ${noun(q.b)}')
      .replaceAll('{n}', '${q.n}')
      .replaceAll('{a}', '${q.a}')
      .replaceAll('{b}', '${q.b}')
      .replaceAll('{objets}', w.plural)
      .replaceAll('{objet}', w.singular)
      .replaceAll('{contenant}', w.container)
      .replaceAll('{prenom}', w.firstName)
      .replaceAll('{un}', w.feminine ? 'une' : 'un')
      .replaceAll('{Chacun}', w.feminine ? 'Chacune' : 'Chacun');
  return s.replaceAllMapped(_elision, (m) => "${m[1]}'${m[2]}");
}

class Skill {
  Skill(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['titre'] as String,
        level = j['niveau'] as String,
        prerequisites = List<String>.from(j['prerequis'] as List),
        activity = j['activite'] as String,
        params = Map<String, dynamic>.from(j['parametres'] as Map),
        phrases = Map<String, String>.from(j['phrases'] as Map),
        items = [for (final i in j['items'] as List? ?? const []) Item(Map<String, dynamic>.from(i as Map))],
        idea = j['idee'] as String?,
        variants = [for (final v in j['variantes'] as List? ?? const []) v as String];

  /// Autres façons de poser la même question (« {a} + {b} = ? », une petite histoire…), tirées au hasard (ADR 0030).
  final List<String> variants;

  /// L'idée en 2–3 phrases, présentée avant l'exemple résolu à la découverte de la compétence (ADR 0029).
  final String? idea;

  final String id, title, level, activity;
  final List<String> prerequisites;
  final Map<String, dynamic> params;
  final Map<String, String> phrases;

  /// Questions écrites dans le contenu (`choisir`) ou sujets (`dessin`).
  final List<Item> items;

  SkillRef get ref => SkillRef(id, prerequisites);

  int p(String k) => (params[k] as num).toInt();

  /// Objet de l'univers utilisé (1 = petits nombres, 2 = grands), paramètre `objet` du contenu.
  int get objectIndex => params.containsKey('objet') ? p('objet') - 1 : 0;

  /// Une phrase, avec les nombres et les mots de l'univers (ADR 0014) remplacés et accordés.
  String say(String key, Question q, {Words? words}) =>
      fill(key == 'question' && q.v > 0 && q.v <= variants.length ? variants[q.v - 1] : phrases[key]!, q, words, vars: vars(q));

  /// Ce qui rend deux questions « les mêmes » pour l'enfant (le tirage d'aléa interne des activités n'en fait pas
  /// partie, sauf quand il est la question elle-même : motifs, échecs, robot).
  String signature(Question q) => switch (activity) {
        'choisir' || 'dessin' || 'planetes' || 'corps' || 'solide' => '${q.n}',
        'ecouter' => '${q.n}${q.b}',
        'motif' || 'echecs' || 'programmer' => '${q.a}',
        _ => '${q.n}/${q.a}/${q.b}',
      };

  /// Variables d'activité d'une question.
  Map<String, String> vars(Question q) => switch (activity) {
        'choisir' || 'dessin' || 'planetes' || 'corps' => items[q.n].vars,
        'solide' => {'bonne': solidNames[(params['solides'] as List)[q.n]] ?? ''},
        'ecouter' => {'mot': (params['mots'] as List)[q.b] as String, 'rep': '${q.n + 1}'},
        'batonnets' when params['mode'] == 'casser' => {'reste': '${q.n - q.b}'},
        'batonnets' => {'dizaines': q.a <= 1 ? '${q.a} dizaine' : '${q.a} dizaines', 'unites': q.b <= 1 ? '${q.b} unité' : '${q.b} unités'},
        _ => const {},
      };


  /// Identifiant de voix stable (`docs/voix/script.csv`).
  String voiceId(String key) => '$id.$key';

  /// Tire une question selon les paramètres. [last] évite de reposer exactement la même.
  /// Tire une question au niveau de la compétence, en évitant celles de [avoid] (signatures déjà posées dans la séance
  /// ou les séances récentes, ADR 0030) et, à défaut, au moins la précédente [last].
  Question draw(Random r, {Question? last, Set<String> avoid = const {}}) {
    Question withVariant(Question q) => variants.isEmpty ? q : Question(n: q.n, a: q.a, b: q.b, v: r.nextInt(variants.length + 1));
    Question? notLast;
    for (var i = 0; i < 60; i++) {
      final q = _draw(r);
      final fresh = last == null || signature(q) != signature(last);
      if (fresh && !avoid.contains(signature(q))) return withVariant(q);
      if (fresh) notLast ??= q;
    }
    return withVariant(notLast ?? _draw(r));
  }

  Question _draw(Random r) {
    int between(int lo, int hi) => lo + r.nextInt(hi - lo + 1);
    switch (activity) {
      case 'denombrer':
        return Question(n: between(p('min'), p('max')));
      case 'composer':
        final n = between(p('cible_min'), p('cible_max'));
        final a = min(between(p('depart_min'), p('depart_max')), n - 1).clamp(0, n);
        return Question(n: n, a: a, b: n - a);
      case 'solide':
        return Question(n: r.nextInt((params['solides'] as List).length), a: r.nextInt(1 << 30));
      case 'choisir' || 'dessin' || 'planetes' || 'corps':
        return Question(n: r.nextInt(items.length), a: r.nextInt(1 << 30));
      case 'ecouter':
        return Question(n: r.nextInt(2), a: r.nextInt(1 << 30), b: r.nextInt(2));
      case 'echecs':
        return Question(n: between(1, p('etoiles')), a: r.nextInt(1 << 30));
      case 'batonnets' when params['mode'] == 'casser':
        // Un nombre entier de dizaines, moins un nombre inférieur à 10 (programme de CP).
        final tens = between(p('min') ~/ 10, p('max') ~/ 10);
        return Question(n: tens * 10, a: tens, b: between(1, 9));
      case 'batonnets':
        final n = between(p('min'), p('max'));
        return Question(n: n, a: n ~/ 10, b: n % 10);
      case 'paquets':
        // [n] objets en paquets de [b] : combien de paquets ([a]) ?
        final b = between(p('par_min'), p('par_max'));
        final a = between(2, min(p('paquets_max'), p('total_max') ~/ b));
        return Question(n: a * b, a: a, b: b);
      case 'groupes':
        // [a] groupes de [b] : le tout ne dépasse pas total_max (programme CP : champ numérique ≤ 30).
        while (true) {
          final a = params.containsKey('groupes_fixe') ? p('groupes_fixe') : between(2, p('groupes_max'));
          final b = between(params.containsKey('par_min') ? p('par_min') : 1, p('par_max'));
          if (a * b <= p('total_max')) return Question(n: a * b, a: a, b: b);
        }
      case 'tables':
        final tables = List<int>.from(params['tables'] as List);
        final a = tables[r.nextInt(tables.length)];
        final b = between(1, 10);
        return Question(n: a * b, a: a, b: b);
      case 'partage':
        final a = params.containsKey('parts_fixe') ? p('parts_fixe') : between(2, p('parts_max'));
        final b = between(1, p('par_max'));
        return Question(n: a * b, a: a, b: b);
      case 'motif' || 'programmer':
        return Question(n: 0, a: r.nextInt(1 << 30));
      default: // calcul
        final total = params.containsKey('total_fixe') ? p('total_fixe') : between(2, p('total_max'));
        // a et b ≥ 1 : les énoncés racontent une petite histoire (« il en arrive {b} »), qui n'a pas de sens avec 0.
        final a = between(1, total - 1);
        return Question(n: total, a: a, b: total - a);
    }
  }

  /// Réponse attendue : le total (dénombrer, composer, somme) ou le nombre manquant (complément).
  int expected(Question q) => switch (activity) {
        'calcul' when params['forme'] == 'complement' => q.b,
        'partage' => q.b,
        'paquets' => q.a,
        'batonnets' when params['mode'] == 'casser' => q.n - q.b,
        _ => q.n,
      };
}

/// Une question écrite (`choisir`) : énoncé, bonne image, autres images, explication ; ou un sujet de dessin.
class Item {
  Item(Map<String, dynamic> j)
      : text = j['texte'] as String,
        right = j['bonne'] == null ? null : Pic.from(j['bonne'] as List),
        others = [for (final o in j['autres'] as List? ?? const []) Pic.from(o as List)],
        explanation = j['explication'] as String? ?? '',
        target = j['cible'] as String?;
  final String text, explanation;

  /// Ce qu'il faut toucher dans une scène (`planetes`, `corps`).
  final String? target;
  final Pic? right;
  final List<Pic> others;

  Map<String, String> get vars => {'texte': text, 'bonne': right?.name ?? '', 'explication': explanation};
}

/// Une image (code Twemoji) et son nom dit (« l'oreille »).
class Pic {
  const Pic(this.art, this.name);
  Pic.from(List l) : this(l[0] as String, l[1] as String);
  final String art, name;
}

/// Noms des solides (activité `solide`, ADR 0024), avec leur article.
const solidNames = {
  'cube': 'le cube', 'pave': 'le pavé', 'boule': 'la boule', 'cylindre': 'le cylindre', 'cone': 'le cône', 'pyramide': 'la pyramide',
};

class Question {
  const Question({required this.n, this.a = 0, this.b = 0, this.v = 0});
  final int n, a, b;

  /// Énoncé : 0 = la phrase `question`, k > 0 = la k-ième de `variantes` (ADR 0030).
  final int v;
}

class Topic {
  Topic(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['titre'] as String,
        name = j['nom'] as String,
        icon = j['icone'] as String,
        skills = [for (final s in j['competences'] as List) Skill(Map<String, dynamic>.from(s as Map))];

  /// [title] pour le parent, [name] pour l'enfant (« Les nombres »), [icon] : code Twemoji.
  final String id, title, name, icon;
  final List<Skill> skills;

  Skill skill(String id) => skills.firstWhere((s) => s.id == id);
}

class Common {
  Common(Map<String, dynamic> j) : phrases = Map<String, dynamic>.from(j['phrases'] as Map);
  final Map<String, dynamic> phrases;
  String text(String k) => phrases[k] as String;
  List<String> list(String k) => List<String>.from(phrases[k] as List);
}

/// Domaines dans l'ordre de `content/domaines.yaml` (assets/content/domaines.json).
Future<(List<Topic>, Common)> loadContent() async {
  Future<Map<String, dynamic>> json(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/content/$name.json')) as Map<String, dynamic>;
  final order = List<String>.from((await json('domaines'))['ordre'] as List);
  return ([for (final id in order) Topic(await json(id))], Common(await json('commun')));
}
