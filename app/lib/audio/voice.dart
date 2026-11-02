/// Voix off : fichier enregistré `assets/audio/voix/<id>.ogg` s'il existe, sinon synthèse fr-FR (ADR 0002).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class Voice {
  final _tts = FlutterTts();
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

  Future<void> stop() async {
    await _tts.stop();
    await _player.stop();
  }

  Future<void> ding() => _sfx.play(AssetSource('audio/ding.wav'));
}
