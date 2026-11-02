import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../activities/calcul.dart';
import '../activities/composer.dart';
import '../activities/denombrer.dart';
import '../app_state.dart';
import '../content/content.dart';
import '../core/events.dart';
import '../core/rewards.dart';
import '../core/rules.dart';
import 'celebrate.dart';
import 'narrator.dart';
import 'theme.dart';
import 'universe.dart';

/// Gère une question : essais, aide qui monte, démonstration ou indice final, retour, journal (ADR 0006–0008), et ce
/// que le bandeau narrateur affiche (ADR 0016).
class Attempt extends ChangeNotifier {
  Attempt(this.app, this.skill, this.question, this.onDone, this.onCorrect);
  final AppState app;
  final Skill skill;
  final Question question;
  final VoidCallback onDone;
  final VoidCallback onCorrect;
  final _started = DateTime.now();
  final _rand = Random();
  late final Words words = app.wordsFor(skill);
  Timer? _helpTimer;

  int misses = 0;
  bool busy = false;
  bool finished = false;

  /// Vrai quand l'activité doit montrer la bonne réponse (moins de 6 ans, 3 essais manqués).
  bool demonstrate = false;

  /// Vrai quand l'enfant a trouvé : l'activité affiche sa réponse à la place du « ? ».
  bool solved = false;

  /// Clé de la phrase affichée dans le bandeau (consigne, puis question).
  String statementKey = 'consigne';

  /// Aide en cours : remplace l'énoncé dans la bulle.
  String? helpText;

  /// Texte écrit du bandeau.
  String get bandText => helpText ?? phrase(statementKey);

  String phrase(String key) => skill.say(key, question, words: words);

  /// Les phrases portent les mots de l'univers : l'identifiant de voix enregistrée en tient compte.
  String voiceId(String key) => '${skill.voiceId(key)}.${app.universe.id}';

  Future<void> say(String key) => app.voice.say(phrase(key), id: voiceId(key));

  /// Affiche et dit une phrase de l'énoncé.
  Future<void> show(String key) {
    statementKey = key;
    helpText = null;
    notifyListeners();
    return say(key);
  }

  Future<void> listen() => helpText != null ? app.voice.say(helpText!) : say(statementKey);

  Future<void> _record({required bool correct, required bool demonstrated}) => app.record(Answer(
        skill: skill.id,
        attempts: misses + (correct ? 1 : 0),
        correct: correct,
        demonstrated: demonstrated,
        millis: DateTime.now().difference(_started).inMilliseconds,
        at: DateTime.now(),
      ));

  Future<void> submit(bool ok) async {
    if (busy || finished) return;
    busy = true;
    _helpTimer?.cancel();
    notifyListeners();
    if (ok) {
      finished = true;
      solved = true;
      helpText = null;
      statementKey = 'bravo';
      notifyListeners();
      await _record(correct: true, demonstrated: false);
      onCorrect();
      app.voice.ding();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await say('bravo');
      final enc = app.common.list('encouragements');
      final i = _rand.nextInt(enc.length);
      await app.voice.say(enc[i], id: 'commun.encouragements.$i');
    } else {
      misses++;
      switch (helpAfter(misses)) {
        case Help.hint:
          await _help('indice');
        case Help.example:
          await _help('exemple');
        default:
          finished = true;
          if (afterLastMiss(app.age) == AfterLastMiss.demonstration) {
            demonstrate = true;
            helpText = phrase('demonstration');
            notifyListeners();
            await _record(correct: false, demonstrated: true);
            await say('demonstration');
            await Future<void>.delayed(const Duration(milliseconds: 800));
          } else {
            // 6 ans et plus : un indice, jamais la réponse (ADR 0006).
            helpText = phrase('indice');
            notifyListeners();
            await _record(correct: false, demonstrated: false);
            await app.voice.say(app.common.text('apres_indice'), id: 'commun.apres_indice');
            await say('indice');
          }
      }
    }
    busy = false;
    notifyListeners();
    if (finished) onDone();
  }

  Future<void> _help(String key) async {
    final text = helpText = phrase(key);
    notifyListeners();
    await app.voice.say(app.common.text('encore'), id: 'commun.encore');
    await say(key);
    // L'aide reste quelques secondes après la voix, puis l'énoncé revient.
    _helpTimer = Timer(const Duration(seconds: 5), () {
      if (helpText == text && !finished) {
        helpText = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _helpTimer?.cancel();
    super.dispose();
  }
}

/// Essais sur tablette seulement : `--dart-define=DEV_SKILL=<id>` fait jouer cette compétence. Vide en version publiée.
const devSkill = String.fromEnvironment('DEV_SKILL');

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  late final AppState app = AppScope.of(context);
  late final List<String> plan = devSkill.isEmpty ? app.progress.plan(DateTime.now()) : List.filled(3, devSkill);
  late final Rewards before = app.rewards;
  final _rand = Random();
  final _started = DateTime.now();
  int index = 0;
  int stars = 0;
  Attempt? attempt;
  Question? _last;
  bool over = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    attempt ??= _next();
  }

  Attempt _next() {
    final skill = app.theme.skill(plan[index]);
    final q = skill.draw(_rand, last: _last);
    _last = q;
    return Attempt(app, skill, q, _advance, () => setState(() => stars++));
  }

  Future<void> _advance() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (index + 1 >= plan.length) {
      await app.store.sessionDone(_started, DateTime.now());
      setState(() => over = true);
      await app.voice.say(app.common.text('fin_seance'), id: 'commun.fin_seance');
      if (app.rewards.unlockedSince(before)) {
        await app.voice.say(app.common.text('nouvel_autocollant'), id: 'commun.nouvel_autocollant');
      }
      return;
    }
    final old = attempt;
    setState(() {
      index++;
      attempt = _next();
    });
    old?.dispose();
  }

  @override
  void dispose() {
    app.voice.stop();
    attempt?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final a = attempt!;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            _TopBar(
              progress: over ? 1 : index / plan.length,
              stars: stars,
              universe: u,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            if (!over)
              ListenableBuilder(
                listenable: a,
                builder: (_, _) => Narrator(
                  universe: u,
                  text: a.bandText,
                  help: a.helpText != null,
                  cheer: stars,
                  onListen: a.listen,
                ),
              ),
            Expanded(
              child: over
                  ? _End(stars: stars, newSticker: app.rewards.unlockedSince(before) ? u.stickers[app.rewards.stickers - 1] : null)
                  : Stack(children: [
                      Positioned.fill(
                        child: switch (a.skill.activity) {
                          'denombrer' => CountActivity(key: ValueKey(index), attempt: a),
                          'composer' => ComposeActivity(key: ValueKey(index), attempt: a),
                          _ => CalcActivity(key: ValueKey(index), attempt: a),
                        },
                      ),
                      Positioned.fill(child: Celebration(trigger: stars, scene: u.scene)),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ← retour (≠ Accueil), progression, étoiles de la séance (nombre écrit à côté de l'étoile).
class _TopBar extends StatelessWidget {
  const _TopBar({required this.progress, required this.stars, required this.universe, required this.onBack});
  final double progress;
  final int stars;
  final Universe universe;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
        child: Row(children: [
          Material(
            color: surface,
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              tooltip: 'Retour',
              iconSize: 32,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 18,
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(9), boxShadow: cardShadow),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    widthFactor: progress.clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: ColoredBox(color: universe.night ? universe.primary : universe.onCard),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: stars > 1 ? '$stars étoiles' : '$stars étoile',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
              child: Row(children: [
                const Art('2b50', size: 30),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, an) => ScaleTransition(scale: an, child: c),
                  child: Text('$stars', key: ValueKey(stars), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink)),
                ),
              ]),
            ),
          ),
        ]),
      );
}

class _End extends StatelessWidget {
  const _End({required this.stars, this.newSticker});
  final int stars;
  final String? newSticker;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Art('2b50', size: 64),
                const SizedBox(width: 12),
                Text('× $stars', style: Theme.of(context).textTheme.displayLarge, semanticsLabel: stars > 1 ? '$stars étoiles' : '$stars étoile'),
              ]),
              if (newSticker != null) ...[
                const SizedBox(height: 16),
                const Text('Nouvel autocollant !', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Art(newSticker!, size: 120, label: 'Nouvel autocollant'),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: 120,
                height: 120,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.home_rounded, size: 72, semanticLabel: 'Accueil'),
                ),
              ),
            ]),
          ),
        ),
      );
}
