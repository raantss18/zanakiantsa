import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';

import 'audio/voice.dart';
import 'books/books.dart';
import 'content/content.dart';
import 'core/day.dart';
import 'core/events.dart';
import 'core/progress.dart';
import 'core/rewards.dart';
import 'core/streak.dart';
import 'l10n/l10n.dart';
import 'store/store.dart';
import 'ui/universe.dart';

/// État de l'app : contenu, stockage, voix, réglages. Un seul objet, transmis par [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.topics, this.common, this.words, this.store, this.voice, this.library);

  /// Bibliothèque hors ligne (ADR 0026).
  final Library library;

  /// Domaines, dans l'ordre de content/domaines.yaml (ADR 0018).
  List<Topic> topics;
  Common common;
  Map<String, UniverseWords> words;
  final Store store;
  final Voice voice;

  List<Answer> journal = [];
  List<SessionLog> sessions = [];

  /// Séances finies (tous domaines) : font avancer le fil d'histoire (ADR 0017).
  int sessionsDone = 0;

  /// Compétences réussies au test de départ (ADR 0045), pour l'enfant en cours.
  Set<String> placed = {};

  /// Temps de jeu proposé par jour, réglé par le parent (ADR 0018).
  int dailyMinutes = defaultDailyMinutes;

  /// Âge de l'enfant, réglé dans l'espace parent (ADR 0006). ⚠ 5 ans par défaut.
  int age = 5;

  /// Classe choisie par le parent ; null : celle de l'âge (ADR 0057).
  int? chosenClass;

  /// La classe de l'enfant, qui décide où commencent les leçons.
  int get schoolClass => chosenClass ?? classForAge(age);

  /// Le plus haut niveau de chaque domaine.
  Map<String, int> get topLevels => {for (final t in topics) t.id: t.skills.map((s) => s.ref.level).fold(0, max)};

  /// Change la langue de toute l'app (ADR 0064) : textes, domaines proposés et voix. La progression de l'enfant ne bouge
  /// pas : elle est rangée par notion, pas par langue.
  Future<void> setLanguage(String lang) async {
    if (lang == appLang) return;
    await voice.stopAll();
    await store.set('langue', lang);
    appLang = lang;
    voice.lang = lang;
    final (t, c) = await loadContent();
    topics = t;
    common = c;
    words = await loadUniverseWords();
    notifyListeners();
  }

  /// La classe la plus avancée pour laquelle l'app a des leçons.
  int get highestLevel => topLevels.values.fold(0, max);

  /// Genre saisi par le parent (ADR 0014) : null tant que l'app n'est pas préparée.
  bool? boy;
  String? universeId;

  static Future<AppState> load() async {
    final store = await Store.open();
    // La langue d'abord : elle décide des textes et des domaines chargés (ADR 0064).
    appLang = await store.get('langue') == 'en' ? 'en' : 'fr';
    final (topics, common) = await loadContent();
    final words = await loadUniverseWords();
    final voice = Voice()
      ..engine = await store.get('moteur_voix')
      ..lang = appLang
      ..init();
    final s = AppState(topics, common, words, store, voice, await Library.load());
    await s._loadProfiles();
    await s.refresh();
    return s;
  }

  /// Enfants de la famille (ADR 0034) : prénom facultatif, rangé sur l'appareil seulement.
  List<ChildProfile> profiles = [];

  /// Plusieurs enfants : l'accueil demande d'abord « Qui joue ? » à chaque lancement.
  bool chosen = true;

  ChildProfile get current => profiles.firstWhere((p) => p.id == store.child, orElse: () => profiles.first);

  Future<void> _loadProfiles() async {
    final raw = await store.get('profils');
    profiles = raw == null
        ? [const ChildProfile(1, '')]
        : [for (final p in jsonDecode(raw) as List) ChildProfile((p as Map)['id'] as int, p['nom'] as String)];
    store.child = int.tryParse(await store.get('profil_actif') ?? '') ?? profiles.first.id;
    if (!profiles.any((p) => p.id == store.child)) store.child = profiles.first.id;
    chosen = profiles.length <= 1;
  }

  Future<void> _saveProfiles() =>
      store.set('profils', jsonEncode([for (final p in profiles) {'id': p.id, 'nom': p.name}]));

  /// Change d'enfant : tout (journal, réglages, mondes, livres) devient le sien.
  Future<void> switchChild(int id) async {
    await voice.stopMusic();
    store.child = id;
    await store.set('profil_actif', '$id');
    chosen = true;
    await refresh();
  }

  /// Ajoute un enfant (espace parent) et le rend actif, avec son âge et ses mondes.
  Future<void> addChild(String name, int years, bool isBoy) async {
    final id = profiles.map((p) => p.id).fold(0, max) + 1;
    profiles = [...profiles, ChildProfile(id, name.trim())];
    await _saveProfiles();
    await switchChild(id);
    await setAge(years);
    await setGender(isBoy);
  }

  /// « Changer d'enfant » : l'accueil redemande « Qui joue ? ».
  void askWhoPlays() {
    voice.stop();
    chosen = false;
    notifyListeners();
  }

  Future<void> renameChild(int id, String name) async {
    profiles = [for (final p in profiles) p.id == id ? ChildProfile(id, name.trim()) : p];
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> refresh() async {
    journal = await store.answers();
    sessions = await store.sessions();
    sessionsDone = sessions.where((s) => s.complete).length;
    dailyMinutes = int.tryParse(await store.get('minutes_jour') ?? '') ?? defaultDailyMinutes;
    final rec = await store.get('recents');
    recents = rec == null
        ? {}
        : {for (final e in (jsonDecode(rec) as Map).entries) e.key as String: List<String>.from(e.value as List)};
    final marks = await store.get('marque_pages');
    bookmarks = marks == null ? {} : {for (final e in (jsonDecode(marks) as Map).entries) int.parse(e.key as String): e.value as int};
    lastBook = int.tryParse(await store.get('livre_dernier') ?? '');
    dailyDoneDay = int.tryParse(await store.get('defi_jour') ?? '');
    _dailyPlan = null;
    try {
      final raw = await store.get('defi_jour_plan');
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _dailyPlan = (j['jour'] as int, List<String>.from(j['plan'] as List));
      }
    } catch (_) {}
    final known = await store.get('test_depart');
    placed = known == null || known.isEmpty ? {} : Set<String>.from(jsonDecode(known) as List);
    voice
      ..voiceOn = await store.get('voix') != 'non'
      ..soundOn = await store.get('musique') != 'non';
    age = int.tryParse(await store.get('age') ?? '') ?? 5;
    topicBand = bandForAge(age).name; // noms des domaines selon l'âge (ADR 0066)
    chosenClass = int.tryParse(await store.get('classe') ?? '');
    final g = await store.get('genre');
    boy = g == null ? null : g == 'garcon';
    universeId = await store.get('univers');
    notifyListeners();
  }

  bool get ready => boy != null;

  /// Tranche d'âge de l'enfant (ADR 0066) : elle décide des mondes proposés.
  Band get band => bandForAge(age);

  /// Univers courant : de sa tranche d'âge, et pour les petits du genre de l'enfant (ADR 0014, 0066). Quand l'enfant
  /// grandit et change de tranche, il passe au premier monde de la nouvelle tranche (il peut en changer).
  Universe get universe {
    final u = universeById(universeId);
    return choices.contains(u) ? u : choices.first;
  }

  List<Universe> get choices => worldsFor(age, boy);

  UniverseWords get universeWords => words[universe.id]!;

  /// Mots pour les phrases d'une compétence (objet selon le paramètre `objet`, ADR 0014).
  Words wordsFor(Skill skill) {
    final w = universeWords;
    final o = w.objects[skill.objectIndex.clamp(0, w.objects.length - 1)];
    return Words(singular: o.singular, plural: o.plural, feminine: o.feminine, container: w.container, firstName: w.firstName);
  }

  /// Code du dessin de l'objet d'une compétence.
  String objectArt(Skill skill) => universe.objects[skill.objectIndex.clamp(0, universe.objects.length - 1)];

  /// Questions posées récemment, par compétence (signatures, ADR 0030) : on ne les repose pas tout de suite, même
  /// d'une séance à l'autre.
  Map<String, List<String>> recents = {};
  static const recentPerSkill = 12;

  Set<String> recentOf(String skill) => {...?recents[skill]};

  Future<void> remember(String skill, String signature) async {
    final l = recents.putIfAbsent(skill, () => [])
      ..remove(signature)
      ..add(signature);
    if (l.length > recentPerSkill) l.removeAt(0);
    await store.set('recents', jsonEncode(recents));
  }

  /// Marque-pages (ADR 0026) : la page où chaque livre commencé a été laissé, et le dernier livre ouvert.
  Map<int, int> bookmarks = {};
  int? lastBook;

  Future<void> setBookmark(int book, int page) async {
    lastBook = book;
    bookmarks[book] = page;
    await store.set('marque_pages', jsonEncode({for (final e in bookmarks.entries) '${e.key}': e.value}));
    await store.set('livre_dernier', '$book');
  }

  /// Livre fini : son marque-page est retiré (il reste « dernier livre lu »).
  Future<void> clearBookmark(int book) async {
    bookmarks.remove(book);
    await store.set('marque_pages', jsonEncode({for (final e in bookmarks.entries) '${e.key}': e.value}));
  }

  /// Livres finis au moins une fois (une réponse `livre-<id>` dans le journal).
  Set<String> get booksRead => {for (final a in journal) if (a.skill.startsWith('livre-')) a.skill};

  Topic topic(String id) => topics.firstWhere((t) => t.id == id);

  /// Compétence d'un domaine quelconque (les identifiants sont uniques dans tout le contenu).
  Skill skill(String id) => topics.expand((t) => t.skills).firstWhere((s) => s.id == id);

  /// La progression d'un domaine. Gardée tant que rien de ce dont elle dépend n'a changé (journal, séances, classe, test de
  /// départ, contenu) : l'accueil, le tableau de bord et la rangée « À revoir » la demandaient des dizaines de fois par
  /// affichage, chaque fois en relisant tout le journal (revue du 2026-11-14).
  Progress progressOf(Topic t) {
    final key = (journal, sessionsDone, schoolClass, placed, topics);
    if (!identical(key.$1, _progressKey?.$1) || key.$2 != _progressKey?.$2 || key.$3 != _progressKey?.$3 || !identical(key.$4, _progressKey?.$4) || !identical(key.$5, _progressKey?.$5)) {
      _progressKey = key;
      _progress.clear();
    }
    return _progress.putIfAbsent(t.id, () {
      final l = t.levelsFor(schoolClass);
      return Progress([for (final s in t.skills) s.ref], journal,
          sessionsDone: sessionsDone, startLevel: l.start, floor: l.floor, ceiling: l.ceiling, placed: placed);
    });
  }

  (List<Answer>, int, int, Set<String>, List<Topic>)? _progressKey;
  final _progress = <String, Progress>{};

  /// Les domaines proposés à cet enfant (ADR 0065, 0070) : ceux qui ont au moins une leçon dans la fenêtre de sa classe
  /// (deux classes en dessous à deux au-dessus), plus le dessin libre. À 12 ans, plus de « Les sons » ni des suites de maternelle.
  List<Topic> get shownTopics => [
        for (final t in topics)
          if (t.ageless || _inWindow(t)) t
      ];

  bool _inWindow(Topic t) {
    final l = t.levelsFor(schoolClass);
    return t.skills.any((s) => s.ref.level >= l.floor && s.ref.level <= l.ceiling);
  }

  /// Une question que la séance sait poser : le dessin libre a sa propre page (activities/draw.dart), il n'entre ni dans
  /// « À revoir » ni dans le défi du jour (avant, il tombait dans l'activité de calcul, revue du 2026-11-14).
  bool _askable(String skillId) => skill(skillId).activity != 'dessin';

  /// Le domaine d'une compétence.
  Topic topicOf(String skillId) => topics.firstWhere((t) => t.skills.any((s) => s.id == skillId));

  /// « À revoir aujourd'hui » (ADR 0071) : les révisions dues de tous les domaines proposés, mêlées, les plus anciennes
  /// d'abord, [reviewSize] au plus. Une notion revient juste avant d'être oubliée (boîtes de Leitner, ADR 0007).
  static const reviewSize = 8;
  List<String> dueReviews([DateTime? now]) {
    final at = now ?? DateTime.now();
    final due = <(String, DateTime)>[];
    for (final t in shownTopics) {
      final p = progressOf(t);
      due.addAll(p.due(at).where((d) => p.inRange(d.$1) && _askable(d.$1)));
    }
    due.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final d in due.take(reviewSize)) d.$1];
  }

  /// Série de jours joués (ADR 0071).
  Streak streak([DateTime? now]) => streakOf(sessions, now ?? DateTime.now());

  /// Le défi du jour (ADR 0071) : huit questions de ce qu'il a acquis, tous domaines mêlés ; null s'il n'a encore rien acquis.
  /// Le même toute la journée : le plan du jour est gardé (avant, il changeait dès qu'une notion était acquise).
  List<String>? dailyChallengePlan([DateTime? now]) {
    final day = dayNumber(now ?? DateTime.now()) + devDayShift;
    final kept = _dailyPlan;
    if (kept != null && kept.$1 == day && kept.$2.every((id) => topics.any((t) => t.skills.any((s) => s.id == id)))) return kept.$2;
    final pool = <String>[];
    for (final t in shownTopics) {
      final p = progressOf(t);
      pool.addAll(p.challengePool.where((id) => p.inRange(id) && _askable(id)));
    }
    final plan = dailyChallenge(pool, day);
    if (plan != null) {
      _dailyPlan = (day, plan);
      store.set('defi_jour_plan', jsonEncode({'jour': day, 'plan': plan}));
    }
    return plan;
  }

  (int, List<String>)? _dailyPlan;

  /// Le jour (voir [dayNumber]) du dernier défi du jour fini.
  int? dailyDoneDay;
  bool dailyDone([DateTime? now]) => dailyDoneDay == dayNumber(now ?? DateTime.now()) + devDayShift;

  Future<void> finishDaily() async {
    dailyDoneDay = dayNumber(DateTime.now()) + devDayShift;
    await store.set('defi_jour', '$dailyDoneDay');
    notifyListeners();
  }

  /// Note les compétences réussies au test de départ.
  Future<void> place(Iterable<String> ids) async {
    placed = {...placed, ...ids};
    await store.set('test_depart', jsonEncode(placed.toList()));
    notifyListeners();
  }

  DayPlan dayPlan([DateTime? now]) => DayPlan.of(now ?? DateTime.now(), sessions,
      minutes: dailyMinutes, tops: topLevels, classe: schoolClass, visible: dayDomains);

  /// Les domaines que la journée peut proposer (ADR 0065, « même les trois thèmes proposés doivent être adaptés au
  /// niveau de l'enfant ») : d'abord ceux où il a encore une leçon à apprendre à son niveau, les plus avancés d'abord ;
  /// les autres domaines proposés (dessin, domaines finis) seulement s'il en manque pour faire trois.
  List<String> get dayDomains => dayCandidates(
        [for (final t in shownTopics) t.id],
        learning: {for (final t in shownTopics) if (!t.ageless && progressOf(t).newSkill != null) t.id},
        tops: topLevels,
      );

  Future<void> logSession(SessionLog s) async {
    await store.addSession(s);
    sessions = [...sessions, s];
    if (s.complete) sessionsDone++;
    notifyListeners();
  }

  /// Interrupteurs de la barre des leçons (ADR 0025), mémorisés.
  Future<void> setVoiceOn(bool on) async {
    voice.voiceOn = on;
    await store.set('voix', on ? 'oui' : 'non');
    notifyListeners();
  }

  Future<void> setSoundOn(bool on) async {
    voice.soundOn = on;
    await store.set('musique', on ? 'oui' : 'non');
    if (!on) await voice.stopMusic();
    notifyListeners();
  }

  Future<void> setDailyMinutes(int m) async {
    await store.set('minutes_jour', '$m');
    dailyMinutes = m;
    notifyListeners();
  }

  Rewards get rewards => Rewards.from(journal);

  Future<void> record(Answer a) async {
    await store.add(a);
    journal = [...journal, a];
    notifyListeners();
  }

  Future<void> setAge(int years) async {
    await store.set('age', '$years');
    age = years;
    topicBand = bandForAge(years).name;
    notifyListeners();
  }

  /// [classe] null, ou celle de son âge : la classe suit de nouveau l'âge.
  Future<void> chooseClass(int? classe) async {
    final chosen = classe == classForAge(age) ? null : classe;
    await store.set('classe', chosen == null ? '' : '$chosen');
    chosenClass = chosen;
    notifyListeners();
  }

  Future<void> setGender(bool isBoy) async {
    await store.set('genre', isBoy ? 'garcon' : 'fille');
    boy = isBoy;
    if (!choices.contains(universeById(universeId))) await setUniverse(choices.first.id);
    notifyListeners();
  }

  Future<void> setUniverse(String id) async {
    final u = universeById(id);
    if (!choices.contains(u)) return; // jamais un monde d'une autre tranche ni, chez les petits, de l'autre genre (ADR 0014, 0066)
    await store.set('univers', id);
    universeId = id;
    notifyListeners();
  }
}

class ChildProfile {
  const ChildProfile(this.id, this.name);
  final int id;
  final String name;

  String get label => name.isEmpty ? 'Enfant $id' : name;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
