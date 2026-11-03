import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../ui/session.dart';
import '../ui/theme.dart';
import '../ui/universe.dart';

/// Écouter : deux sons joués l'un après l'autre, la carte qui sonne s'allume ; on touche celle qui répond à la question
/// (plus aigu, plus fort, plus long, plus rapide… ADR 0019). Sons fabriqués par l'app (lib/audio/sfx.dart).
class ListenActivity extends StatefulWidget {
  const ListenActivity({super.key, required this.attempt});
  final Attempt attempt;
  @override
  State<ListenActivity> createState() => _ListenActivityState();
}

class _ListenActivityState extends State<ListenActivity> {
  Attempt get a => widget.attempt;
  late final int right = a.question.n;
  late final List<Uint8List> sounds = () {
    final (sa, sb) = listenPair(a.skill.params['dimension'] as String);
    // La bonne carte porte le son qui a la propriété demandée : A si on demande le 1er mot, sinon B.
    final good = wav(a.question.b == 0 ? sa : sb), other = wav(a.question.b == 0 ? sb : sa);
    return right == 0 ? [good, other] : [other, good];
  }();
  final tried = <int>{};
  int? playing;
  bool _playingAll = false;

  @override
  void initState() {
    super.initState();
    a.addListener(_changed);
    a.show('question').then((_) => _playBoth());
  }

  @override
  void dispose() {
    a.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _play(int i) async {
    if (!mounted) return;
    setState(() => playing = i);
    await a.speech.playWav(sounds[i]);
    if (mounted) setState(() => playing = null);
  }

  Future<void> _playBoth() async {
    if (_playingAll) return;
    _playingAll = true;
    try {
      for (final i in [0, 1]) {
        await _play(i);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } finally {
      // Même si un son échoue, les cartes redeviennent touchables.
      _playingAll = false;
      if (mounted) setState(() => playing = null);
    }
  }

  void _tap(int i) {
    if (a.busy || a.finished || tried.contains(i) || _playingAll) return;
    final ok = i == right;
    if (!ok) setState(() => tried.add(i));
    a.submit(ok);
  }

  @override
  Widget build(BuildContext context) {
    final u = a.app.universe;
    final shown = a.demonstrate || a.solved;
    return LayoutBuilder(builder: (_, k) {
      final size = ((k.maxWidth - 96) / 2).clamp(140.0, 240.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Wrap(spacing: 32, runSpacing: 24, alignment: WrapAlignment.center, children: [
            for (final i in [0, 1])
              PicButton(
                size: size,
                label: 'Son ${i + 1}',
                selected: playing == i,
                tried: tried.contains(i),
                highlight: shown && i == right,
                onPressed: a.busy || a.finished ? null : () => _tap(i),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedScale(
                    scale: playing == i ? 1.25 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Art(u.objects[i], size: size * 0.42),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(playing == i ? Icons.volume_up_rounded : Icons.music_note_rounded, size: 36, color: u.onCard),
                    const SizedBox(width: 6),
                    Text('${i + 1}', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: u.onCard)),
                  ]),
                ]),
              ),
          ]),
          const SizedBox(height: 28),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(220, 72), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 24, fontWeight: FontWeight.w700)),
            onPressed: _playingAll ? null : _playBoth,
            icon: const Icon(Icons.replay_rounded, size: 36),
            label: const Text('Réécouter'),
          ),
        ]),
      );
    });
  }
}
