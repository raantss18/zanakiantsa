import 'package:flutter/widgets.dart';

import 'audio/voice.dart';
import 'content/content.dart';
import 'core/events.dart';
import 'core/progress.dart';
import 'store/store.dart';

/// État de l'app : contenu, stockage, voix, réglages. Un seul objet, transmis par [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.theme, this.common, this.store, this.voice);
  final Topic theme;
  final Common common;
  final Store store;
  final Voice voice;

  List<Answer> journal = [];
  int sessionsDone = 0;

  /// Âge de l'enfant, réglé dans l'espace parent (ADR 0006). ⚠ 5 ans par défaut.
  int age = 5;

  static Future<AppState> load() async {
    final (theme, common) = await loadContent();
    final store = await Store.open();
    final voice = Voice()..init();
    final s = AppState(theme, common, store, voice);
    await s.refresh();
    return s;
  }

  Future<void> refresh() async {
    journal = await store.answers();
    sessionsDone = (await store.sessions()).length;
    age = int.tryParse(await store.get('age') ?? '') ?? 5;
    notifyListeners();
  }

  Progress get progress =>
      Progress([for (final s in theme.skills) s.ref], journal, sessionsDone: sessionsDone);

  Future<void> record(Answer a) async {
    await store.add(a);
    journal = [...journal, a];
  }

  Future<void> setAge(int years) async {
    await store.set('age', '$years');
    age = years;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
