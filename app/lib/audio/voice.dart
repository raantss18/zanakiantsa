/// Voix off : fichier enregistré `assets/audio/voix/<id>.ogg` s'il existe, sinon synthèse fr-FR (ADR 0002).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'sfx.dart';

/// Durée maximale qu'on attend une phrase : bien plus que le temps de la dire (≈ 12 caractères par seconde à la
/// vitesse réglée), pour qu'un moteur de synthèse muet ou absent ne bloque jamais l'activité.
Duration speechBudget(String text) => Duration(milliseconds: 2500 + 150 * text.length);

/// Attend [f] au plus [budget] ; au-delà, ou si le son échoue, on continue comme si la phrase était finie. Aucun appel
/// au son ne doit pouvoir bloquer un écran : sur certains téléphones, un lecteur ou le moteur de synthèse ne répond
/// jamais (vu le 2026-11-03 : exercice d'écoute figé, voix coupée).
Future<void> bounded(Future<void> f, Duration budget) async {
  try {
    await f.timeout(budget, onTimeout: () {});
  } catch (e) {
    debugPrint('son ignoré : $e');
  }
}

/// Budget d'une commande au lecteur (jouer, arrêter, volume) : elle répond d'habitude en quelques millisecondes.
const _command = Duration(milliseconds: 1500);

class Voice {
  final _tts = FlutterTts();

  /// Voix anglaise pour les mots d'anglais (ADR 0022) : créée seulement au premier mot anglais (une liaison au moteur
  /// de synthèse en moins pour tous les autres domaines, ADR 0028).
  FlutterTts? _enTts;
  FlutterTts get _en => _enTts ??= FlutterTts();
  late final Future<void> _enReady = () async {
    await _en.setLanguage('en-GB');
    await _en.setSpeechRate(0.4);
    await _en.awaitSpeakCompletion(true);
  }();
  final _player = AudioPlayer();
  final _sfx = AudioPlayer();
  final _music = AudioPlayer();

  /// Réglages de l'enfant (ADR 0025), mémorisés par l'app : voix ; musique et bruitages.
  bool voiceOn = true, soundOn = true;

  /// Trame sonore : volume bas, baissé pendant que la voix parle (elle ne couvre jamais une phrase).
  static const musicVolume = 0.15, duckedVolume = 0.04;
  final Map<String, Uint8List> _ambience = {};
  String? _musicWorld;
  bool _musicPlaying = false;
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

  /// Dit une phrase ; attend la fin. [id] permet de jouer la voix enregistrée correspondante. Voix coupée : rien,
  /// sauf si [force] (l'enfant a touché « Réécouter »).
  Future<void> say(String text, {String? id, bool force = false}) async {
    if (!voiceOn && !force) return;
    await bounded(_ready, const Duration(seconds: 8));
    await stop();
    await _duck(true);
    if (id != null && _recorded.contains(id)) {
      await bounded(_player.play(AssetSource('audio/voix/$id.ogg')), _command);
      await bounded(_player.onPlayerComplete.first, speechBudget(text));
    } else {
      await bounded(_tts.speak(text), speechBudget(text));
    }
    await _duck(false);
  }

  Future<void> _duck(bool down) async {
    if (_musicPlaying) await bounded(_music.setVolume(down ? duckedVolume : musicVolume), _command);
  }

  /// Lance la trame du monde en boucle (si la musique est activée). La boucle est fabriquée hors du fil de l'interface.
  Future<void> startMusic(String world) async {
    _musicWorld = world;
    if (!soundOn || _musicPlaying) return;
    _musicPlaying = true;
    // Une seule trame gardée en mémoire (≈ 0,7 Mo) : celle du monde en cours.
    _ambience.removeWhere((k, _) => k != world);
    final bytes = _ambience[world] ??= await compute(ambienceWav, world);
    if (!_musicPlaying || _musicWorld != world) return;
    await bounded(_music.setReleaseMode(ReleaseMode.loop), _command);
    await bounded(_music.setVolume(musicVolume), _command);
    await bounded(_music.play(BytesSource(bytes, mimeType: 'audio/wav')), _command);
  }

  /// Appli cachée : on coupe la phrase en cours et on met la trame en pause (sans l'oublier).
  Future<void> pauseAll() async {
    await stop();
    if (_musicPlaying) await bounded(_music.pause(), _command);
  }

  Future<void> resumeMusic() async {
    if (_musicPlaying && soundOn) await bounded(_music.resume(), _command);
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    await bounded(_music.stop(), _command);
  }

  /// Phrase en français dont les passages entre « » sont en anglais (« Touche : « red ». ») : chaque morceau est dit
  /// par la bonne voix, l'un après l'autre.
  Future<void> sayMixed(String text, {bool force = false}) async {
    if (!voiceOn && !force) return;
    await bounded(_ready, const Duration(seconds: 8));
    await bounded(_enReady, const Duration(seconds: 8));
    await stop();
    for (final (i, part) in text.split(RegExp('[«»]')).indexed) {
      final t = part.trim();
      if (t.isEmpty || RegExp(r'^[\s.,:;!?]+$').hasMatch(t)) continue;
      await _duck(true);
      await bounded((i.isOdd ? _en : _tts).speak(t), speechBudget(t));
    }
    await _duck(false);
  }

  Future<void> stop() async {
    if (_enTts != null) await bounded(_enTts!.stop(), _command);
    await bounded(_tts.stop(), _command);
    await bounded(_player.stop(), _command);
  }

  /// Bruitage de bonne réponse propre au monde (ADR 0017).
  Future<void> success(String universe) async {
    if (soundOn) await bounded(_sfx.play(AssetSource('audio/sfx/$universe.wav')), _command);
  }

  /// Joue un son fabriqué par l'app (WAV) et attend sa fin. C'est le contenu d'un exercice d'écoute : il joue même
  /// musique coupée.
  Future<void> playWav(Uint8List wav) async {
    await stop();
    await bounded(_sfx.stop(), _command);
    await bounded(_sfx.play(BytesSource(wav, mimeType: 'audio/wav')), _command);
    // WAV 16 bits mono : 44 octets d'en-tête, puis 2 octets par échantillon.
    await bounded(_sfx.onPlayerComplete.first, Duration(milliseconds: 1000 + (wav.length - 44) * 1000 ~/ (2 * 22050)));
  }

  /// Fin de séance.
  Future<void> fanfare() async {
    if (soundOn) await bounded(_sfx.play(AssetSource('audio/sfx/fanfare.wav')), _command);
  }
}
