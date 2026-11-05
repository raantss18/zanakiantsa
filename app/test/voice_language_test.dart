import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zanakiantsa/audio/voice.dart';

// Bug du 2026-11-05 (autre téléphone, réglé en anglais) : le français était lu par la voix anglaise. Le moteur
// Android remet sa langue à celle du téléphone quand il (re)démarre ; l'app gardait en mémoire « fr-FR déjà réglé ».
// Ce faux moteur fait la même chose, et note la langue de chaque phrase dite.
class FakeEngine {
  FakeEngine(this.voices);
  final Set<String> voices;
  String lang = 'en-US';
  final spoken = <(String, String)>[];

  /// Ce que fait flutter_tts au démarrage ou à la reconnexion du moteur.
  void restart() => lang = 'en-US';

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'setLanguage':
        if (!voices.contains(call.arguments)) return 0;
        lang = call.arguments as String;
        return 1;
      case 'speak':
        final a = call.arguments;
        spoken.add((a is Map ? a['text'] as String : a as String, lang));
        return 1;
      default:
        return 1;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  FakeEngine install(Set<String> voices) {
    final e = FakeEngine(voices);
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'), e.handle);
    // Les lecteurs (musique, bruitages) ne servent pas ici : ils répondent « fait ».
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (_) async => 1);
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (_) async => 1);
    return e;
  }

  test('le français reste en français après un redémarrage du moteur', () async {
    final e = install({'fr-FR', 'en-GB', 'en-US'});
    final v = Voice()..init();
    await v.say('Bonjour');
    e.restart();
    await v.say('Combien de pommes ?');
    expect(e.spoken, [('Bonjour', 'fr-FR'), ('Combien de pommes ?', 'fr-FR')]);
  });

  test('après un passage en anglais, le français revient', () async {
    final e = install({'fr-FR', 'en-GB'});
    final v = Voice()..init();
    await v.sayMixed('Touche : « red ».');
    await v.say('Bravo');
    expect(e.spoken, [('Touche :', 'fr-FR'), ('red', 'en-GB'), ('Bravo', 'fr-FR')]);
  });

  test('sans voix française, rien n\'est lu avec la voix anglaise', () async {
    final e = install({'en-US'});
    final v = Voice()..init();
    await v.say('Bonjour');
    expect(e.spoken, isEmpty);
    expect(v.lastError, contains('française'));
  });

  test('une variante proche est acceptée (français du Canada, anglais américain)', () async {
    final e = install({'fr-CA', 'en-US'});
    final v = Voice()..init();
    await v.sayMixed('Touche : « red ».');
    expect(e.spoken, [('Touche :', 'fr-CA'), ('red', 'en-US')]);
  });
}
