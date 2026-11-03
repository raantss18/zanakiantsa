/// Bruitages courts par monde (ADR 0017), synthétisés par code : aucun fichier son tiré d'ailleurs, donc rien à
/// créditer. `tool/build_sounds.dart` les écrit dans `assets/audio/sfx/` ; l'app ne fait que les jouer.
library;

import 'dart:math';
import 'dart:typed_data';

const sampleRate = 22050;

/// Durée maximale d'un bruitage : la voix attend ce délai avant de parler, pour ne pas se chevaucher.
const sfxLength = Duration(milliseconds: 600);

/// Crête : forte assez pour s'entendre, jamais criarde.
const _peak = 0.5;

typedef _Wave = double Function(double phase);

double _sine(double p) => sin(2 * pi * p);
double _triangle(double p) => 1 - 4 * (((p + 0.25) % 1) - 0.5).abs();
// Carré et dent de scie adoucis : quelques harmoniques seulement (moins agressif qu'un vrai carré).
double _square(double p) => _sine(p) + _sine(3 * p) / 3 + _sine(5 * p) / 5;
double _saw(double p) => _sine(p) - _sine(2 * p) / 2 + _sine(3 * p) / 3 - _sine(4 * p) / 4;
double _pluck(double p) => _sine(p) + 0.4 * _sine(2 * p) + 0.15 * _sine(3 * p);

/// Une note : départ et durée en secondes, fréquence de [f0] à [f1] (glissando), amortissement exponentiel [decay]
/// (0 = tenue), vibrato/trémolo optionnels.
class _Note {
  const _Note(this.start, this.duration, this.f0, this.wave, {double? f1, this.decay = 0, this.tremolo = 0}) : f1 = f1 ?? f0;
  final double start, duration, f0, f1, decay, tremolo;
  final _Wave wave;
}

const _c5 = 523.25, _e5 = 659.25, _g5 = 783.99, _c6 = 1046.5, _e6 = 1318.5, _g6 = 1568.0, _c7 = 2093.0, _e7 = 2637.0, _g7 = 3136.0;

final Map<String, List<_Note>> _sounds = {
  // bip-bip-bip qui monte
  'robots': [for (final (i, f) in [_c6, _e6, _g6].indexed) _Note(i * 0.16, 0.12, f, _square)],
  // moteur qui accélère
  'voitures': [const _Note(0, 0.55, 110, _saw, f1: 440, tremolo: 30)],
  // décollage : glissement qui monte en vibrant
  'espace': [const _Note(0, 0.55, 300, _sine, f1: 1500, tremolo: 18)],
  // poussière de fée : clochettes aiguës
  'fees': [for (final (i, f) in [_c7, _e7, _g7, _c7 * 2].indexed) _Note(i * 0.09, 0.28, f, _sine, decay: 12)],
  // « ta-da ! »
  'mode': [const _Note(0, 0.12, _g5, _triangle), const _Note(0.15, 0.4, _c6, _triangle, decay: 5)],
  // glissando de harpe
  'princesses': [for (final (i, f) in [_c5, _e5, _g5, _c6, _e6].indexed) _Note(i * 0.07, 0.3, f, _pluck, decay: 9)],
  // fin de séance, commune aux mondes
  'fanfare': [
    for (final (i, f) in [_c5, _e5, _g5].indexed) _Note(i * 0.1, 0.09, f, _triangle),
    const _Note(0.3, 0.3, _c6, _triangle, decay: 4),
  ],
};

Iterable<String> get sfxNames => _sounds.keys;

/// Échantillons normalisés à [_peak], avec 5 ms de fondu à chaque bout de note (pas de clic).
Float64List samples(String name) => _render(_sounds[name]!, _peak);

/// Les deux sons à comparer (activité « écouter », ADR 0019) : le son A porte le 1er mot du contenu (aigu, fort, long,
/// rapide), le son B le 2e (grave, doux, court, lent).
(Float64List, Float64List) listenPair(String dimension) => switch (dimension) {
      'hauteur' => (_render([const _Note(0, 0.9, 880, _triangle)], _peak), _render([const _Note(0, 0.9, 220, _triangle)], _peak)),
      // Même note : seule la crête change (rapport 6, environ 16 dB).
      'intensite' => (_render([const _Note(0, 0.9, 440, _triangle)], 0.6), _render([const _Note(0, 0.9, 440, _triangle)], 0.1)),
      'duree' => (_render([const _Note(0, 1.5, 523.25, _triangle)], _peak), _render([const _Note(0, 0.25, 523.25, _triangle)], _peak)),
      'tempo' => (
          _render([for (var i = 0; i < 8; i++) _Note(i * 0.2, 0.08, 660, _pluck, decay: 20)], _peak),
          _render([for (var i = 0; i < 3; i++) _Note(i * 0.7, 0.08, 660, _pluck, decay: 20)], _peak),
        ),
      _ => throw ArgumentError(dimension),
    };

Float64List _render(List<_Note> notes, double peak) {
  final end = notes.map((n) => n.start + n.duration).reduce(max);
  final out = Float64List((end * sampleRate).ceil());
  const fade = 0.005;
  for (final n in notes) {
    var phase = 0.0;
    final first = (n.start * sampleRate).round();
    final count = (n.duration * sampleRate).round();
    for (var k = 0; k < count && first + k < out.length; k++) {
      final t = k / sampleRate;
      final f = n.f0 + (n.f1 - n.f0) * t / n.duration;
      phase = (phase + f / sampleRate) % 1;
      final env = min(1.0, min(t, n.duration - t) / fade) * exp(-n.decay * t) * (n.tremolo > 0 ? 0.8 + 0.2 * sin(2 * pi * n.tremolo * t) : 1);
      out[first + k] += n.wave(phase) * env;
    }
  }
  final top = out.map((v) => v.abs()).reduce(max);
  for (var i = 0; i < out.length; i++) {
    out[i] *= peak / top;
  }
  return out;
}

/// Fichier WAV PCM 16 bits mono.
Uint8List wav(Float64List s) {
  final b = ByteData(44 + s.length * 2);
  void ascii(int at, String t) {
    for (final (i, c) in t.codeUnits.indexed) {
      b.setUint8(at + i, c);
    }
  }
  ascii(0, 'RIFF');
  b.setUint32(4, 36 + s.length * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  b
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 1, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, s.length * 2, Endian.little);
  for (var i = 0; i < s.length; i++) {
    b.setInt16(44 + i * 2, (s[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}
