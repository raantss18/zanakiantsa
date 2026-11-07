/// Contenu compilé par `tool/build_content.dart` (assets/content/*.json) et génération des questions.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../core/fractions.dart';
import '../l10n/l10n.dart';
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
  // « 1 couronne », « 4 couronnes » : en français, 0 et 1 restent au singulier ; en anglais, seul 1 (« 0 gears »).
  String noun(int k) => (english ? k == 1 : k <= 1) ? w.singular : w.plural;
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
      .replaceAll('{un}', english ? 'a' : (w.feminine ? 'une' : 'un'))
      .replaceAll('{Chacun}', english ? 'Each' : (w.feminine ? 'Chacune' : 'Chacun'));
  return english ? s : s.replaceAllMapped(_elision, (m) => "${m[1]}'${m[2]}");
}

class Skill {
  Skill(Map<String, dynamic> raw) : this._(localized(raw));
  Skill._(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['titre'] as String,
        level = j['niveau'] as String,
        prerequisites = List<String>.from(j['prerequis'] as List),
        activity = j['activite'] as String,
        params = Map<String, dynamic>.from(j['parametres'] as Map),
        phrases = Map<String, String>.from(j['phrases'] as Map),
        items = [for (final i in j['items'] as List? ?? const []) Item(Map<String, dynamic>.from(i as Map))],
        idea = j['idee'] as String?,
        localWords = j['mots'] as List?,
        studied = j['langue'] as String? ?? (Map<String, dynamic>.from(j['parametres'] as Map))['langue'] as String?,
        variants = [for (final v in j['variantes'] as List? ?? const []) v as String];

  /// Autres façons de poser la même question (« {a} + {b} = ? », une petite histoire…), tirées au hasard (ADR 0030).
  final List<String> variants;

  /// Langue étudiée dans cette leçon, si ce n'est pas seulement la langue de l'app (ADR 0064) : 'en' pour l'anglais,
  /// 'fr' pour la lecture et la grammaire françaises vues depuis l'app en anglais.
  final String? studied;

  /// Les mots comparés (« aigu », « grave »…) dans la langue de l'app, si le bloc `en:` les donne (activité `ecouter`).
  final List? localWords;

  /// L'idée en 2–3 phrases, présentée avant l'exemple résolu à la découverte de la compétence (ADR 0029).
  final String? idea;

  final String id, title, level, activity;
  final List<String> prerequisites;
  final Map<String, dynamic> params;
  final Map<String, String> phrases;

  /// Questions écrites dans le contenu (`choisir`) ou sujets (`dessin`).
  final List<Item> items;

  SkillRef get ref => SkillRef(id, prerequisites, level: levelRank(level));

  int p(String k) => (params[k] as num).toInt();

  /// Objet de l'univers utilisé (1 = petits nombres, 2 = grands), paramètre `objet` du contenu.
  int get objectIndex => params.containsKey('objet') ? p('objet') - 1 : 0;

  /// Une phrase, avec les nombres et les mots de l'univers (ADR 0014) remplacés et accordés.
  String say(String key, Question q, {Words? words}) =>
      fill(key == 'question' && q.v > 0 && q.v <= variants.length ? variants[q.v - 1] : phrases[key]!, q, words, vars: vars(q));

  /// La lettre ou la syllabe en jeu (activités `lettre` et `tracer`, ADR 0031), telle qu'on la dit et l'écrit.
  String letterOf(Question q) => switch (params['mode']) {
        'initiale' => items[q.n].letter!,
        'syllabe' => '${(params['consonnes'] as List)[q.n]}${(params['voyelles'] as List)[q.b]}',
        'casse' => ((params['lettres'] as List)[q.n] as String).toUpperCase(),
        _ => (params['lettres'] as List)[q.n] as String,
      };

  /// Ce qui rend deux questions « les mêmes » pour l'enfant (le tirage d'aléa interne des activités n'en fait pas
  /// partie, sauf quand il est la question elle-même : motifs, échecs, robot).
  String signature(Question q) => switch (activity) {
        'choisir' || 'dessin' || 'planetes' || 'corps' || 'solide' || 'probleme' || 'quiz' => '${q.n}',
        'ecouter' || 'lettre' || 'syllabes' || 'tracer' => '${q.n}/${q.b}',
        'motif' || 'echecs' || 'programmer' || 'blocs' => '${q.a}',
        _ => '${q.n}/${q.a}/${q.b}',
      };

  /// Variables d'activité d'une question.
  Map<String, String> vars(Question q) => switch (activity) {
        'choisir' || 'dessin' || 'planetes' || 'corps' || 'probleme' || 'quiz' => items[q.n].vars,
        'solide' => {'bonne': solidNames[(params['solides'] as List)[q.n]] ?? ''},
        'syllabes' => {
            ...items[q.n].vars,
            'rep': english
                ? (items[q.n].syllables.length == 1 ? '1 syllable' : '${items[q.n].syllables.length} syllables')
                : (items[q.n].syllables.length <= 1 ? '1 syllabe' : '${items[q.n].syllables.length} syllabes'),
          },
        'lettre' || 'tracer' => {...?(params['mode'] == 'initiale' ? items[q.n].vars : null), 'lettre': letterOf(q)},
        'ecouter' => {'mot': ((localWords ?? params['mots']) as List)[q.b] as String, 'rep': '${q.n + 1}'},
        'batonnets' when params['mode'] == 'casser' => {'reste': '${q.n - q.b}'},
        'heure' => {'heure': clockText(q.n, q.b)},
        'suite' => {'pas': stepWords[q.b.abs()] ?? '${q.b.abs()}'},
        'fraction' => fractionVars(q, params['mode'] as String),
        'multibase' => {'centaines': _count(q.a, 'centaine', 'hundred'), 'dizaines': _count(q.b, 'dizaine', 'ten'), 'unites': _count(q.n % 10, 'unité', 'one')},
        'batonnets' => {'dizaines': _count(q.a, 'dizaine', 'ten'), 'unites': _count(q.b, 'unité', 'one')},
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
      case 'syllabes':
        return Question(n: r.nextInt(items.length), a: r.nextInt(1 << 30));
      case 'lettre' when params['mode'] == 'initiale':
        return Question(n: r.nextInt(items.length), a: r.nextInt(1 << 30));
      case 'lettre' when params['mode'] == 'syllabe':
        return Question(n: r.nextInt((params['consonnes'] as List).length), b: r.nextInt((params['voyelles'] as List).length), a: r.nextInt(1 << 30));
      case 'lettre' || 'tracer':
        return Question(n: r.nextInt((params['lettres'] as List).length), a: r.nextInt(1 << 30));
      case 'solide':
        return Question(n: r.nextInt((params['solides'] as List).length), a: r.nextInt(1 << 30));
      case 'choisir' || 'dessin' || 'planetes' || 'corps' || 'probleme' || 'quiz':
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
      case 'multibase':
        final n = between(p('min'), p('max'));
        return Question(n: n, a: n ~/ 100, b: (n ~/ 10) % 10);
      case 'posee':
        // Deux nombres à deux chiffres (CE1) ; [retenue] : au moins une retenue (addition) ou un emprunt (soustraction).
        while (true) {
          final x = between(p('min'), p('max')), y = between(p('min'), p('max'));
          final sub = params['op'] == '-';
          final (a, b) = sub ? (max(x, y), min(x, y)) : (x, y);
          final carry = sub ? (a % 10) < (b % 10) : (a % 10) + (b % 10) >= 10;
          if (sub && a == b) continue;
          if (params['retenue'] == true && !carry) continue;
          return Question(n: sub ? a - b : a + b, a: a, b: b);
        }
      case 'heure':
        // [n] heure (1–12), [b] minutes : 0, ou 30 et 15/45 selon le niveau.
        final mins = List<int>.from(params['minutes'] as List);
        return Question(n: between(1, 12), b: mins[r.nextInt(mins.length)], a: r.nextInt(1 << 30));
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
      case 'motif' || 'programmer' || 'blocs':
        return Question(n: 0, a: r.nextInt(1 << 30));
      case 'suite':
        // Cinq nombres de [b] en [b] à partir de [a] (n'importe quel nombre, programme du cycle 2), entre min et max ;
        // [n] : celui qui manque, jamais le premier (il faut voir au moins deux nombres avant de deviner la règle).
        final steps = List<int>.from(params['pas'] as List);
        final b = steps[r.nextInt(steps.length)];
        final lo = params.containsKey('min') ? p('min') : 0;
        final a = b > 0 ? between(lo, p('max') - 4 * b) : between(lo - 4 * b, p('max'));
        return Question(n: a + between(1, 4) * b, a: a, b: b);
      case 'fraction':
        // Voir fractionVars : [b] le dénominateur, [n] la réponse, [a] selon le mode.
        final ds = List<int>.from(params['denominateurs'] as List);
        final d = ds[r.nextInt(ds.length)];
        switch (params['mode']) {
          case 'comparer_unitaires': // 1/a contre 1/b
            final others = ds.where((x) => x != d).toList();
            return Question(n: 1, a: others[r.nextInt(others.length)], b: d);
          case 'comparer': // a/b contre n/b
            final x = between(1, d - 1);
            var y = between(1, d - 1);
            while (y == x && d > 2) {
              y = between(1, d - 1);
            }
            if (x == y) return Question(n: 1, a: 1, b: 3);
            return Question(n: x, a: y, b: d);
          case 'additionner': // a/b + (n-a)/b = n/b, sans dépasser 1
            final dd = d < 3 ? 3 : d;
            final sum = between(2, dd);
            return Question(n: sum, a: between(1, sum - 1), b: dd);
          case 'superieure': // n/b > 1, sans multiple de b
            var n = between(d + 1, 3 * d - 1);
            while (n % d == 0) {
              n = between(d + 1, 3 * d - 1);
            }
            return Question(n: n, a: 0, b: d);
          case 'quantite': // un b-ième de a = n
            final k = between(2, p('par_max'));
            return Question(n: k, a: k * d, b: d);
          case 'unitaire':
            return Question(n: 1, a: r.nextInt(2), b: d);
          default: // lire, colorier, placer ; [a] : la forme (bande ou disque)
            return Question(n: between(1, d - 1), a: r.nextInt(2), b: d);
        }
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
        'heure' => q.n * 100 + q.b,
        'batonnets' when params['mode'] == 'casser' => q.n - q.b,
        _ => q.n,
      };
}

/// Les mots d'une question de fractions (ADR 0056).
Map<String, String> fractionVars(Question q, String mode) => switch (mode) {
      'comparer_unitaires' => {'frac': fracWords(1, q.b), 'frac2': fracWords(1, q.a), 'plus': fracWords(1, min(q.a, q.b))},
      'comparer' => {'frac': fracWords(q.n, q.b), 'frac2': fracWords(q.a, q.b), 'plus': fracWords(max(q.n, q.a), q.b)},
      'additionner' => {'frac': fracWords(q.a, q.b), 'frac2': fracWords(q.n - q.a, q.b), 'plus': fracWords(q.n, q.b)},
      'superieure' => {'frac': fracWords(q.n, q.b), 'plus': fracSumWords(Frac(q.n % q.b, q.b, whole: q.n ~/ q.b))},
      'quantite' => {'frac': fracWords(1, q.b)},
      _ => {'frac': fracWords(q.n, q.b)},
    };

/// « 3 dizaines », « 1 dizaine » ; en anglais « 3 tens », « 1 ten » (0 au pluriel, comme en anglais).
String _count(int k, String fr, String en) => english ? (k == 1 ? '1 $en' : '$k ${en}s') : (k <= 1 ? '$k $fr' : '$k ${fr}s');

/// Le pas d'une suite de nombres, tel qu'on le dit (« de deux en deux »).
const _stepWordsFr = {1: 'un', 2: 'deux', 5: 'cinq', 10: 'dix', 100: 'cent'};
const _stepWordsEn = {1: 'one', 2: 'two', 5: 'five', 10: 'ten', 100: 'a hundred'};
Map<int, String> get stepWords => english ? _stepWordsEn : _stepWordsFr;

/// Une question écrite (`choisir`) : énoncé, bonne image, autres images, explication ; ou un sujet de dessin.
class Item {
  Item(Map<String, dynamic> j)
      : text = j['texte'] as String,
        right = j['bonne'] == null ? null : Pic.from(j['bonne'] as List),
        others = [for (final o in j['autres'] as List? ?? const []) Pic.from(o as List)],
        explanation = j['explication'] as String? ?? '',
        target = j['cible'] as String?,
        image = j['image'] as String?,
        syllables = [for (final s in j['syllabes'] as List? ?? const []) s as String],
        letter = j['lettre'] as String?,
        name = j['nom'] as String?,
        fen = j['fen'] as String?,
        moves = [for (final m in j['coups'] as List? ?? const []) m as String],
        minStrokes = j['traits'] as int? ?? 1,
        traps = [for (final t in j['pieges'] as List? ?? const []) Trap(Map<String, dynamic>.from(t as Map))];

  /// Question écrite (`quiz`, ADR 0057) : les mauvaises réponses et ce que chacune montre ; la bonne est dans [name].
  final List<Trap> traps;

  /// Problème d'échecs (ADR 0040) : la position (FEN) et les coups justes (UCI).
  final String? fen;
  final List<String> moves;

  /// Dessin (ADR 0038) : ce qu'on dessine (« un soleil »), et le nombre minimum de traits attendus.
  final String? name;
  final int minStrokes;

  /// Dessin : noms anglais acceptés du modèle de dessins (champ `cible`, séparés par « | »).
  List<String> get labels => (target ?? '').split('|').where((x) => x.isNotEmpty).toList();

  /// Lire et écrire (ADR 0031) : l'image du mot, ses syllabes orales, sa première lettre.
  final String? image, letter;
  final List<String> syllables;
  final String text, explanation;

  /// Ce qu'il faut toucher dans une scène (`planetes`, `corps`).
  final String? target;
  final Pic? right;
  final List<Pic> others;

  Map<String, String> get vars => {
        'texte': text,
        'bonne': right?.name ?? name ?? '',
        // Syllabes séparées par des virgules : la voix marque la pause, l'écrit reste lisible (« la, pin »).
        'explication': syllables.isNotEmpty ? syllables.join(', ') : explanation,
        'lettre': ?letter,
      };
}

/// Une image (code Twemoji) et son nom dit (« l'oreille »).
/// Une mauvaise réponse d'une question écrite et ce qu'elle montre (ADR 0057).
class Trap {
  Trap(Map<String, dynamic> j)
      : text = j['texte'] as String,
        why = j['pourquoi'] as String;
  final String text, why;
}

class Pic {
  const Pic(this.art, this.name);
  Pic.from(List l) : this(l[0] as String, l[1] as String);
  final String art, name;
}

/// L'heure dite comme à l'école : « 3 heures », « 3 heures et demie », « 3 heures et quart », « 4 heures moins le quart ».
String clockText(int h, int m) {
  if (english) {
    // L'heure dite en anglais : « 3 o'clock », « half past 3 », « quarter past 3 », « quarter to 4 ».
    String hh(int x) => x == 12 ? 'twelve' : '$x';
    return switch (m) {
      0 => h == 12 ? 'twelve o’clock' : '$h o’clock',
      30 => 'half past ${hh(h)}',
      15 => 'quarter past ${hh(h)}',
      45 => 'quarter to ${hh(h % 12 + 1)}',
      _ => '$m minutes past ${hh(h)}',
    };
  }
  String hours(int x) => x == 12 ? 'midi' : (x == 1 ? '1 heure' : '$x heures');
  return switch (m) {
    0 => hours(h),
    30 => '${hours(h)} et demie',
    15 => '${hours(h)} et quart',
    45 => '${hours(h % 12 + 1)} moins le quart',
    _ => '${hours(h)} $m',
  };
}

/// Noms des solides (activité `solide`, ADR 0024), avec leur article.
const _solidNamesFr = {
  'cube': 'le cube', 'pave': 'le pavé', 'boule': 'la boule', 'cylindre': 'le cylindre', 'cone': 'le cône', 'pyramide': 'la pyramide',
};
const _solidNamesEn = {
  'cube': 'the cube', 'pave': 'the cuboid', 'boule': 'the sphere', 'cylindre': 'the cylinder', 'cone': 'the cone', 'pyramide': 'the pyramid',
};
Map<String, String> get solidNames => english ? _solidNamesEn : _solidNamesFr;

class Question {
  const Question({required this.n, this.a = 0, this.b = 0, this.v = 0});
  final int n, a, b;

  /// Énoncé : 0 = la phrase `question`, k > 0 = la k-ième de `variantes` (ADR 0030).
  final int v;
}

/// Tranche d'âge de l'enfant actif ('petits', 'moyens', 'grands'), tenue à jour par l'état de l'app (ADR 0066) : elle
/// choisit le nom des domaines.
String topicBand = 'petits';

class Topic {
  Topic(Map<String, dynamic> raw) : this._(localized(raw));
  Topic._(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['titre'] as String,
        _name = j['nom'] as String,
        _names = {for (final e in (j['noms'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
        icon = j['icone'] as String,
        intro = [for (final s in j['intro'] as List? ?? const []) IntroScene(Map<String, dynamic>.from(s as Map))],
        ageless = j['sans_age'] == true,
        skills = [for (final s in j['competences'] as List) Skill(Map<String, dynamic>.from(s as Map))];

  /// Domaine pour tous les âges (le dessin libre) : le plancher de classe ne le cache jamais (ADR 0065).
  final bool ageless;

  /// [title] pour le parent, [name] pour l'enfant (« Les nombres »), [icon] : code Twemoji.
  final String id, title, icon;
  final String _name;
  final Map<String, String> _names;

  /// Nom pour l'enfant, selon sa tranche d'âge (ADR 0066) : « Lire et écrire » chez les petits, « Français » chez les grands.
  String get name => _names[topicBand] ?? _name;

  /// Animation de méthode jouée à l'ouverture du domaine (ADR 0033).
  final List<IntroScene> intro;
  final List<Skill> skills;

  Skill skill(String id) => skills.firstWhere((s) => s.id == id);
}

/// Une scène d'animation de méthode : une phrase dite et écrite, des images qui arrivent, un grand texte (« 2 + 1 = 3 »).
class IntroScene {
  IntroScene(Map<String, dynamic> j)
      : text = j['texte'] as String,
        images = [for (final i in j['images'] as List? ?? const []) i as String],
        big = j['grand'] as String?;
  final String text;
  final List<String> images;
  final String? big;
}

class Common {
  Common(Map<String, dynamic> j) : phrases = Map<String, dynamic>.from(j['phrases'] as Map);
  final Map<String, dynamic> phrases;
  String text(String k) => phrases[k] as String;
  List<String> list(String k) => List<String>.from(phrases[k] as List);
}

/// Domaines dans l'ordre de `content/domaines.yaml` (assets/content/domaines.json).
/// Les domaines entièrement traduits en anglais (ADR 0064), pour le dire au parent.
Future<(List<String>, int)> translatedTopics() async {
  Future<Map<String, dynamic>> json(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/content/$name.json')) as Map<String, dynamic>;
  final order = List<String>.from((await json('domaines'))['ordre'] as List);
  return ([for (final id in order) if (translated(await json(id))) id], order.length);
}

/// En anglais (ADR 0064), seuls les domaines entièrement traduits sont proposés.
Future<(List<Topic>, Common)> loadContent() async {
  Future<Map<String, dynamic>> json(String name) async =>
      jsonDecode(await rootBundle.loadString('assets/content/$name.json')) as Map<String, dynamic>;
  final order = List<String>.from((await json('domaines'))['ordre'] as List);
  final topics = <Topic>[];
  for (final id in order) {
    final j = await json(id);
    if (!english || translated(j)) topics.add(Topic(j));
  }
  return (topics, Common(localized(await json('commun'))));
}
