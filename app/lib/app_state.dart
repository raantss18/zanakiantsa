import 'package:flutter/widgets.dart';

import 'audio/voice.dart';
import 'content/content.dart';
import 'core/events.dart';
import 'core/progress.dart';
import 'core/rewards.dart';
import 'store/store.dart';
import 'ui/universe.dart';

/// État de l'app : contenu, stockage, voix, réglages. Un seul objet, transmis par [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.theme, this.common, this.words, this.store, this.voice);
  final Topic theme;
  final Common common;
  final Map<String, UniverseWords> words;
  final Store store;
  final Voice voice;

  List<Answer> journal = [];
  int sessionsDone = 0;

  /// Âge de l'enfant, réglé dans l'espace parent (ADR 0006). ⚠ 5 ans par défaut.
  int age = 5;

  /// Genre saisi par le parent (ADR 0014) : null tant que l'app n'est pas préparée.
  bool? boy;
  String? universeId;

  static Future<AppState> load() async {
    final (theme, common) = await loadContent();
    final words = await loadUniverseWords();
    final store = await Store.open();
    final voice = Voice()..init();
    final s = AppState(theme, common, words, store, voice);
    await s.refresh();
    return s;
  }

  Future<void> refresh() async {
    journal = await store.answers();
    sessionsDone = (await store.sessions()).length;
    age = int.tryParse(await store.get('age') ?? '') ?? 5;
    final g = await store.get('genre');
    boy = g == null ? null : g == 'garcon';
    universeId = await store.get('univers');
    notifyListeners();
  }

  bool get ready => boy != null;

  /// Univers courant, toujours du genre de l'enfant (ADR 0014).
  Universe get universe {
    final u = universeById(universeId);
    if (boy == null || u.boy == boy) return u;
    return universes.firstWhere((x) => x.boy == boy);
  }

  List<Universe> get choices => [for (final u in universes) if (boy == null || u.boy == boy) u];

  UniverseWords get universeWords => words[universe.id]!;

  /// Mots pour les phrases d'une compétence (objet selon le paramètre `objet`, ADR 0014).
  Words wordsFor(Skill skill) {
    final w = universeWords;
    final o = w.objects[skill.objectIndex.clamp(0, w.objects.length - 1)];
    return Words(singular: o.singular, plural: o.plural, feminine: o.feminine, container: w.container);
  }

  /// Code du dessin de l'objet d'une compétence.
  String objectArt(Skill skill) => universe.objects[skill.objectIndex.clamp(0, universe.objects.length - 1)];

  Progress get progress => Progress([for (final s in theme.skills) s.ref], journal, sessionsDone: sessionsDone);

  Rewards get rewards => Rewards.from(journal);

  Future<void> record(Answer a) async {
    await store.add(a);
    journal = [...journal, a];
    notifyListeners();
  }

  Future<void> setAge(int years) async {
    await store.set('age', '$years');
    age = years;
    notifyListeners();
  }

  Future<void> setGender(bool isBoy) async {
    await store.set('genre', isBoy ? 'garcon' : 'fille');
    boy = isBoy;
    if (universeById(universeId).boy != isBoy) await setUniverse(universes.firstWhere((u) => u.boy == isBoy).id);
    notifyListeners();
  }

  Future<void> setUniverse(String id) async {
    final u = universeById(id);
    if (boy != null && u.boy != boy) return; // jamais un univers de l'autre genre (ADR 0014)
    await store.set('univers', id);
    universeId = id;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
