/// Voix off : fichier enregistré `assets/audio/voix/<id>.ogg` s'il existe (français), sinon synthèse dans la langue de
/// l'app (ADR 0002, 0064).
library;

import 'spoken.dart';
import 'dart:async';

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

  /// Variantes acceptées pour chaque langue, de la préférée à la moins bonne.
  static const _variants = {
    'fr-FR': ['fr-FR', 'fr-CA', 'fr-BE', 'fr-CH'],
    'en-GB': ['en-GB', 'en-US', 'en-AU'],
  };

  /// Règle la langue et la vitesse du moteur avant **chaque** phrase, sans jamais se fier à ce qui a été réglé avant.
  /// ⚠ flutter_tts n'a qu'un seul moteur natif pour toute l'app, et son code Android (4.2.5,
  /// `FlutterTtsPlugin.kt`, `onInitListener…`) remet la langue à celle du téléphone chaque fois que le moteur
  /// démarre ou se reconnecte (aussi après un `speak` refusé). Une langue gardée en mémoire par l'app devenait donc
  /// fausse : le français était lu par la voix anglaise sur un téléphone réglé en anglais (bugs du 2026-11-03 et du
  /// 2026-11-05, ADR 0044). Rend false si le moteur n'a aucune voix de cette langue : on se tait alors plutôt que de
  /// lire le texte avec une voix d'une autre langue (le texte reste écrit).
  Future<bool> _useLang(String lang) async {
    for (final tag in _variants[lang] ?? [lang]) {
      Object? r;
      try {
        r = await _tts.setLanguage(tag).timeout(_command);
      } on TimeoutException {
        // Moteur en train de démarrer : l'ordre est gardé en file et passera avant la phrase.
        r = 1;
      } catch (e) {
        debugPrint('langue ignorée : $e');
      }
      if (r == 1 || r == true) {
        _current = lang;
        await bounded(_tts.setSpeechRate(lang == 'fr-FR' ? 0.45 : 0.4), _command);
        return true;
      }
    }
    lastError = lang == 'fr-FR' ? 'pas de voix française dans ce moteur' : 'pas de voix anglaise dans ce moteur';
    return false;
  }

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

  /// Fin de la phrase en cours, signalée par le moteur (fin, annulation ou erreur).
  Completer<void>? _phrase;

  /// La dernière erreur du moteur de synthèse (pour l'espace parent).
  String? lastError;

  void _ended() {
    final c = _phrase;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Dit une phrase avec le moteur et attend sa fin : celle que le moteur signale, ou au plus la limite de temps.
  Future<void> _speak(String text) async {
    final done = _phrase = Completer<void>();
    // Les notations de maths dites en mots, dans la langue réglée pour cette phrase (ADR 0067).
    final said = spoken(text, _current.startsWith('en') ? 'en' : 'fr');
    await bounded(Future.any([_tts.speak(said), done.future]), speechBudget(said));
  }

  /// Langue réglée pour la phrase en cours (voir [_useLang]).
  String _current = 'fr-FR';

  /// Moteur de synthèse choisi dans l'espace parent (null : celui du téléphone). Certains moteurs livrés avec les
  /// téléphones parlent mal le français ou ne disent jamais quand une phrase est finie.
  String? engine;

  /// Langue de l'app (ADR 0064) : 'fr' ou 'en'. Chaque phrase est dite dans cette langue ; les voix enregistrées n'existent
  /// qu'en français, on ne les joue donc qu'en français.
  String lang = 'fr';
  String get _base => lang == 'en' ? 'en-GB' : 'fr-FR';

  /// Tout se tait : voix et musique (changement de langue).
  Future<void> stopAll() async {
    await stop();
    await stopMusic();
  }

  Future<void> _init() async {
    if (engine != null) await bounded(_tts.setEngine(engine!), const Duration(seconds: 4));
    // Vitesse un peu plus lente que la normale pour les 5–7 ans (⚠ à régler à l'essai), fixée par [_useLang].
    await _useLang(_base);
    await _tts.awaitSpeakCompletion(true);
    // Le moteur peut échouer (voix française pas installée…) : flutter_tts ne termine alors jamais l'attente de fin de
    // phrase (vu dans son code Android, 4.2.5). On écoute aussi l'erreur pour ne pas rester muet
    // jusqu'à la limite de temps (bug du 2026-11-03 : longs silences, phrases décalées).
    _tts.setCompletionHandler(_ended);
    _tts.setErrorHandler((message) {
      lastError = '$message';
      _ended();
    });
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    _recorded = {
      for (final a in manifest.listAssets())
        if (a.startsWith('assets/audio/voix/')) a.split('/').last.replaceAll('.ogg', ''),
    };
  }

  /// Dit une phrase ; attend la fin. [id] permet de jouer la voix enregistrée correspondante. Voix coupée : rien,
  /// sauf si [force] (l'enfant a touché « Réécouter »).
  /// [lang] : langue du texte quand ce n'est pas celle de l'app (un livre en français lu depuis l'app en anglais).
  Future<void> say(String text, {String? id, bool force = false, String? lang}) async {
    if (_hidden || (!voiceOn && !force)) return;
    await bounded(_ready, const Duration(seconds: 8));
    await stop();
    await _duck(true);
    final tag = lang == null ? _base : (lang == 'en' ? 'en-GB' : 'fr-FR');
    if (this.lang == 'fr' && lang != 'en' && id != null && _recorded.contains(id)) {
      await bounded(_player.play(AssetSource('audio/voix/$id.ogg')), _command);
      await bounded(_player.onPlayerComplete.first, speechBudget(text));
    } else if (await _useLang(tag)) {
      await _speak(text);
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

  /// Appli cachée : plus aucune phrase ni aucun son jusqu'à son retour (une phrase qui suivait dans un enchaînement
  /// ne repart pas en arrière-plan, bug du 2026-11-03).
  bool _hidden = false;

  /// Appli cachée : on coupe la phrase en cours et on met la trame en pause (sans l'oublier).
  Future<void> pauseAll() async {
    _hidden = true;
    await stop();
    if (_musicPlaying) await bounded(_music.pause(), _command);
  }

  Future<void> resumeMusic() async {
    _hidden = false;
    if (_musicPlaying && soundOn) await bounded(_music.resume(), _command);
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    await bounded(_music.stop(), _command);
  }

  /// Phrase en français dont les passages entre « » sont en anglais (« Touche : « red ». ») : chaque morceau est dit
  /// par la bonne voix, l'un après l'autre.
  /// Une phrase dans la langue de l'app, dont les passages entre « » sont dans la langue étudiée [quoted] (ADR 0022,
  /// 0064) : l'anglais pour un enfant qui utilise l'app en français, le français pour la lecture et la grammaire françaises
  /// quand l'app est en anglais.
  Future<void> sayMixed(String text, {bool force = false, String quoted = 'en'}) async {
    if (_hidden || (!voiceOn && !force)) return;
    await bounded(_ready, const Duration(seconds: 8));
    await stop();
    for (final (i, part) in text.split(RegExp('[«»]')).indexed) {
      final t = part.trim();
      if (t.isEmpty || RegExp(r'^[\s.,:;!?]+$').hasMatch(t)) continue;
      await _duck(true);
      if (await _useLang(i.isOdd ? (quoted == 'en' ? 'en-GB' : 'fr-FR') : _base)) await _speak(t);
    }
    await _duck(false);
  }

  Future<void> stop() async {
    // Celui qui attendait la fin de la phrase coupée n'attend plus (l'annulation du moteur, elle, peut arriver après
    // le début de la phrase suivante : on ne s'y fie pas).
    _ended();
    _phrase = null;
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
    if (_hidden) return;
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

  /// Pour l'espace parent : les moteurs du téléphone, celui utilisé, et si le français y est disponible.
  Future<(List<String>, String?, bool)> info() async {
    await bounded(_ready, const Duration(seconds: 8));
    var engines = <String>[];
    String? current;
    var fr = false;
    try {
      engines = [for (final e in await _tts.getEngines as List) '$e'];
      current = engine ?? '${await _tts.getDefaultEngine}';
      fr = await _tts.isLanguageAvailable(_base) == true;
    } catch (_) {}
    return (engines, current, fr);
  }

  /// Change de moteur (espace parent) ; la langue et la vitesse sont reprises.
  Future<void> useEngine(String name) async {
    await stop();
    engine = name;
    await bounded(_tts.setEngine(name), const Duration(seconds: 4));
    await _useLang(_base);
    await bounded(_tts.awaitSpeakCompletion(true), _command);
  }

  /// Essai de la voix : dit une phrase et rend le temps mis. Fin signalée bien avant la limite : le moteur prévient
  /// quand il a fini (bon signe). Au bout de la limite : il ne prévient pas, les phrases risquent d'être coupées ou
  /// espacées.
  Future<(bool, Duration, String?)> test() async {
    final text = lang == 'en'
        ? "Hello! I am the voice of Zanak'i Antsa. Can you hear me well?"
        : "Bonjour ! Je suis la voix de Zanak'i Antsa. Est-ce que tu m'entends bien ?";
    await bounded(_ready, const Duration(seconds: 8));
    await stop();
    lastError = null;
    if (!await _useLang(_base)) return (false, Duration.zero, lastError);
    final watch = Stopwatch()..start();
    await _speak(text);
    final took = watch.elapsed;
    return (lastError == null && took < speechBudget(text) - const Duration(milliseconds: 300), took, lastError);
  }

  /// Une parole attachée à un écran ou à une question (voir [Speech]).
  Speech scope() => Speech(this);
}

/// La parole d'un écran ou d'une question : tant qu'elle est ouverte, elle parle par la voix de l'app ; fermée (écran
/// quitté, question suivante), elle coupe la phrase en cours et ne dit plus rien, même si un enchaînement de phrases
/// (« Bravo… », encouragement, histoire…) était en route. Corrige « on sort, et ça parle toujours » (2026-11-03).
class Speech {
  Speech(this._voice);
  final Voice _voice;
  bool _closed = false;

  bool get closed => _closed;

  Future<void> say(String text, {String? id, bool force = false}) =>
      _closed ? Future.value() : _voice.say(text, id: id, force: force);

  Future<void> sayMixed(String text, {bool force = false, String quoted = 'en'}) =>
      _closed ? Future.value() : _voice.sayMixed(text, force: force, quoted: quoted);

  Future<void> playWav(Uint8List wav) => _closed ? Future.value() : _voice.playWav(wav);

  void close() {
    if (_closed) return;
    _closed = true;
    _voice.stop();
  }
}
