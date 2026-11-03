/// Voix off : fichier enregistré `assets/audio/voix/<id>.ogg` s'il existe, sinon synthèse fr-FR (ADR 0002).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Durée maximale qu'on attend une phrase : bien plus que le temps de la dire (≈ 12 caractères par seconde à la
/// vitesse réglée), pour qu'un moteur de synthèse muet ou absent ne bloque jamais l'activité.
Duration speechBudget(String text) => Duration(milliseconds: 2500 + 150 * text.length);

/// Attend [f] au plus [budget] ; au-delà, on continue comme si la phrase était finie.
Future<void> _bounded(Future<void> f, Duration budget) => f.timeout(budget, onTimeout: () {});

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
    await _bounded(_ready, const Duration(seconds: 8));
    await stop();
    if (id != null && _recorded.contains(id)) {
      await _player.play(AssetSource('audio/voix/$id.ogg'));
      await _bounded(_player.onPlayerComplete.first, speechBudget(text));
    } else {
      await _bounded(_tts.speak(text), speechBudget(text));
    }
  }

  /// Phrase en français dont les passages entre « » sont en anglais (« Touche : « red ». ») : chaque morceau est dit
  /// par la bonne voix, l'un après l'autre.
  Future<void> sayMixed(String text) async {
    await _bounded(_ready, const Duration(seconds: 8));
    await _bounded(_enReady, const Duration(seconds: 8));
    await stop();
    for (final (i, part) in text.split(RegExp('[«»]')).indexed) {
      final t = part.trim();
      if (t.isEmpty || RegExp(r'^[\s.,:;!?]+$').hasMatch(t)) continue;
      await _bounded((i.isOdd ? _en : _tts).speak(t), speechBudget(t));
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
    // WAV 16 bits mono : 44 octets d'en-tête, puis 2 octets par échantillon.
    await _bounded(_sfx.onPlayerComplete.first, Duration(milliseconds: 1000 + (wav.length - 44) * 1000 ~/ (2 * 22050)));
  }

  /// Fin de séance.
  Future<void> fanfare() => _sfx.play(AssetSource('audio/sfx/fanfare.wav'));
}
