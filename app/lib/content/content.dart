/// Contenu compilé par `tool/build_content.dart` (assets/content/*.json) et génération des questions.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../core/progress.dart';

/// Les mots d'univers dont une phrase a besoin : l'objet compté et le contenant.
class Words {
  const Words({required this.singular, required this.plural, required this.feminine, required this.container});
  final String singular, plural, container;
  final bool feminine;

  static const neutral = Words(singular: 'objet', plural: 'objets', feminine: false, container: 'la boîte');
}

final _elision = RegExp(r"\b([Dd])e ([aeiouyàâéèêëîïôûœAEIOUYÉ])");

/// Remplit {n} {a} {b} {objet} {objets} {contenant} {un} {Chacun} ; « de » devant voyelle devient « d' ».
String fill(String text, Question q, Words? words) {
  final w = words ?? Words.neutral;
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
        phrases = Map<String, String>.from(j['phrases'] as Map);

  final String id, title, level, activity;
  final List<String> prerequisites;
  final Map<String, dynamic> params;
  final Map<String, String> phrases;

  SkillRef get ref => SkillRef(id, prerequisites);

  int p(String k) => (params[k] as num).toInt();

  /// Objet de l'univers utilisé (1 = petits nombres, 2 = grands), paramètre `objet` du contenu.
  int get objectIndex => params.containsKey('objet') ? p('objet') - 1 : 0;

  /// Une phrase, avec les nombres et les mots de l'univers (ADR 0014) remplacés et accordés.
  String say(String key, Question q, {Words? words}) => fill(phrases[key]!, q, words);


  /// Identifiant de voix stable (`docs/voix/script.csv`).
  String voiceId(String key) => '$id.$key';

  /// Tire une question selon les paramètres. [last] évite de reposer exactement la même.
  Question draw(Random r, {Question? last}) {
    for (var i = 0; i < 20; i++) {
      final q = _draw(r);
      if (last == null || q.n != last.n || q.a != last.a) return q;
    }
    return _draw(r);
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
      default: // calcul
        final total = params.containsKey('total_fixe') ? p('total_fixe') : between(2, p('total_max'));
        final a = between(params['forme'] == 'complement' ? 1 : 0, total - (params['forme'] == 'complement' ? 1 : 0));
        return Question(n: total, a: a, b: total - a);
    }
  }

  /// Réponse attendue : le total (dénombrer, composer, somme) ou le nombre manquant (complément).
  int expected(Question q) => activity == 'calcul' && params['forme'] == 'complement' ? q.b : q.n;
}

class Question {
  const Question({required this.n, this.a = 0, this.b = 0});
  final int n, a, b;
}

class Topic {
  Topic(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['titre'] as String,
        skills = [for (final s in j['competences'] as List) Skill(Map<String, dynamic>.from(s as Map))];
  final String id, title;
  final List<Skill> skills;

  Skill skill(String id) => skills.firstWhere((s) => s.id == id);
}

class Common {
  Common(Map<String, dynamic> j) : phrases = Map<String, dynamic>.from(j['phrases'] as Map);
  final Map<String, dynamic> phrases;
  String text(String k) => phrases[k] as String;
  List<String> list(String k) => List<String>.from(phrases[k] as List);
}

Future<(Topic, Common)> loadContent() async {
  final theme = Topic(jsonDecode(await rootBundle.loadString('assets/content/compter.json')) as Map<String, dynamic>);
  final common = Common(jsonDecode(await rootBundle.loadString('assets/content/commun.json')) as Map<String, dynamic>);
  return (theme, common);
}
