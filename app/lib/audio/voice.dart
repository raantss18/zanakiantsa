/// Voix off : fichier enregistré `assets/audio/voix/<id>.ogg` s'il existe, sinon synthèse fr-FR (ADR 0002).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Voice {
  final _tts = FlutterTts();

  /// Voix anglaise pour les mots d'anglais (ADR 0022) ; initialisée au premier besoin.
  final _en = FlutterTts();
  late final Future<void> _enReady = () async {
    await _en.setLanguage('en-GB');
    await _en.setSpeechRate(0.4);
    await _en.awaitSpeakCompletion(true);
  }();
  final _player = AudioPlayer();
  final _sfx = AudioPlayer();
  Set<String> _recorded = {};
  late final Future<void> _ready = _init();

  /// Lance l'initialisation sans bloquer le démarrage (le moteur TTS met plusieurs secondes à se lier) ;
  /// [say] l'attend si besoin.
  void init() => _ready;

  Future<void> _init() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45); // ⚠ un peu plus lent que la normale pour les 5–7 ans, à régler à l'essai
    await _tts.awaitSpeakCompletion(true);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _recorded = {
      for (final a in manifest.listAssets())
        if (a.startsWith('assets/audio/voix/')) a.split('/').last.replaceAll('.ogg', ''),
    };
  }

  /// Dit une phrase ; attend la fin. [id] permet de jouer la voix enregistrée correspondante.
  Future<void> say(String text, {String? id}) async {
    await _ready;
    await stop();
    if (id != null && _recorded.contains(id)) {
      await _player.play(AssetSource('audio/voix/$id.ogg'));
      await _player.onPlayerComplete.first;
    } else {
      await _tts.speak(text);
    }
  }

  /// Phrase en français dont les passages entre « » sont en anglais (« Touche : « red ». ») : chaque morceau est dit
  /// par la bonne voix, l'un après l'autre.
  Future<void> sayMixed(String text) async {
    await _ready;
    await _enReady;
    await stop();
    for (final (i, part) in text.split(RegExp('[«»]')).indexed) {
      final t = part.trim();
      if (t.isEmpty || RegExp(r'^[\s.,:;!?]+$').hasMatch(t)) continue;
      await (i.isOdd ? _en : _tts).speak(t);
    }
  }

  Future<void> stop() async {
    await _en.stop();
    await _tts.stop();
    await _player.stop();
  }

  /// Bruitage de bonne réponse propre au monde (ADR 0017).
  Future<void> success(String universe) => _sfx.play(AssetSource('audio/sfx/$universe.wav'));

  /// Joue un son fabriqué par l'app (WAV) et attend sa fin.
  Future<void> playWav(Uint8List wav) async {
    await stop();
    await _sfx.stop();
    await _sfx.play(BytesSource(wav, mimeType: 'audio/wav'));
    await _sfx.onPlayerComplete.first;
  }

  /// Fin de séance.
  Future<void> fanfare() => _sfx.play(AssetSource('audio/sfx/fanfare.wav'));
}
