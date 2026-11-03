import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../activities/draw.dart';
import '../app_state.dart';
import '../content/content.dart';
import 'session.dart';
import 'theme.dart';
import 'universe.dart';

/// Ouvre un domaine (accueil, « Tout explorer ») : l'animation de méthode d'abord, la première fois du jour (ADR 0033),
/// puis l'activité.
Future<void> openTopic(BuildContext context, AppState app, String topicId) async {
  await app.voice.stop();
  if (!context.mounted) return;
  final t = app.topic(topicId);
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final seen = await app.store.get('intro_$topicId') == today;
  if (!context.mounted) return;
  if (!seen && t.intro.isNotEmpty) {
    await app.store.set('intro_$topicId', today);
    if (!context.mounted) return;
    final go = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => TopicIntro(topic: t)));
    if (go != true || !context.mounted) return;
  }
  // Séance laissée en cours : on la reprend où l'enfant s'était arrêté (ADR 0039).
  final resume = topicId == 'dessin' ? null : await SessionResume.load(app, topicId);
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => topicId == 'dessin' ? const DrawPage() : SessionPage(topic: topicId, resume: resume)));
  await app.refresh();
}

/// Petite animation de méthode : des scènes enchaînées — les images arrivent en rebondissant, un grand texte s'écrit
/// lettre à lettre, la phrase est écrite et dite. « Passer » toujours visible ; « C'est parti ! » à la fin. Sans
/// animation si l'appareil en demande moins.
class TopicIntro extends StatefulWidget {
  const TopicIntro({super.key, required this.topic});
  final Topic topic;
  @override
  State<TopicIntro> createState() => _TopicIntroState();
}

class _TopicIntroState extends State<TopicIntro> with TickerProviderStateMixin {
  late final AppState app = AppScope.of(context);
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final _float = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  int scene = 0;
  bool ended = false, _running = true;

  List<IntroScene> get scenes => widget.topic.intro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _running = false;
    app.voice.stop();
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    for (var i = 0; i < scenes.length && _running; i++) {
      setState(() => scene = i);
      _enter.forward(from: 0);
      // La phrase est dite même voix coupée : c'est la leçon elle-même (comme « Lis-moi »).
      await Future.wait([app.voice.say(scenes[i].text, id: '${widget.topic.id}.intro.$i', force: true), Future<void>.delayed(const Duration(milliseconds: 2600))]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (mounted && _running) setState(() => ended = true);
  }

  void _close(bool go) {
    _running = false;
    app.voice.stop();
    Navigator.of(context).pop(go);
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final sc = scenes[scene];
    final still = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(children: [
                Material(
                  color: surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(tooltip: 'Retour', iconSize: 32, onPressed: () => _close(false), icon: const Icon(Icons.arrow_back_rounded, color: ink)),
                ),
                const SizedBox(width: 12),
                Art(widget.topic.icon, size: 40),
                const SizedBox(width: 8),
                Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PlayfulTitle(widget.topic.name))),
              ]),
            ),
            // Où on en est : une pastille par scène (pleine = vue), « 2 / 3 » écrit.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < scenes.length; i++)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= scene ? (u.night ? u.primary : u.onCard) : null,
                      border: Border.all(color: u.night ? u.primary : u.onCard, width: 2),
                    ),
                  ),
                const SizedBox(width: 8),
                Text('${scene + 1} / ${scenes.length}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: u.onBackground)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(32), boxShadow: cardShadow),
                  padding: const EdgeInsets.all(20),
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_enter, _float]),
                    builder: (_, _) {
                      final t = still ? 1.0 : _enter.value;
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                          for (final (i, img) in sc.images.indexed)
                            Builder(builder: (_) {
                              // Chaque image arrive à son tour, avec un petit rebond, puis flotte doucement.
                              final local = ((t * 1.6) - i * 0.18).clamp(0.0, 1.0);
                              final pop = Curves.elasticOut.transform(local);
                              final bob = still ? 0.0 : sin((_float.value + i * 0.3) * pi) * 6;
                              return Transform.translate(
                                offset: Offset(0, bob),
                                child: Transform.scale(scale: pop, child: Art(img, size: sc.images.length > 3 ? 72 : 104)),
                              );
                            }),
                        ]),
                        if (sc.big != null) ...[
                          const SizedBox(height: 16),
                          // Le grand texte s'écrit lettre à lettre.
                          Text(
                            sc.big!.substring(0, (sc.big!.length * (still ? 1.0 : (t * 1.3).clamp(0.0, 1.0))).round()),
                            style: TextStyle(fontFamily: 'Andika', fontSize: 56, fontWeight: FontWeight.w700, color: u.night ? u.primary : u.onCard),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Text(sc.text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink, height: 1.25)),
                        ),
                      ]);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ended
                  ? SizedBox(
                      width: double.infinity,
                      height: 76,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: green, textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 28, fontWeight: FontWeight.w700)),
                        onPressed: () => _close(true),
                        icon: const Icon(Icons.play_arrow_rounded, size: 44),
                        label: const Text("C'est parti !"),
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: surface, textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 20, fontWeight: FontWeight.w700)),
                        onPressed: () => _close(true),
                        icon: const Icon(Icons.skip_next_rounded, size: 32),
                        label: const Text('Passer'),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
