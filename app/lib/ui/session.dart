import 'dart:math';

import 'package:flutter/material.dart';

import '../activities/calcul.dart';
import '../activities/composer.dart';
import '../activities/denombrer.dart';
import '../app_state.dart';
import '../content/content.dart';
import '../core/events.dart';
import '../core/rules.dart';
import 'theme.dart';

/// Gère une question : essais, aide qui monte, démonstration ou indice final, retour, journal (ADR 0006–0008).
class Attempt extends ChangeNotifier {
  Attempt(this.app, this.skill, this.question, this.onDone);
  final AppState app;
  final Skill skill;
  final Question question;
  final VoidCallback onDone;
  final _started = DateTime.now();
  final _rand = Random();

  int misses = 0;
  bool busy = false;
  bool finished = false;

  /// Vrai quand l'activité doit montrer la bonne réponse (moins de 6 ans, 3 essais manqués).
  bool demonstrate = false;

  /// Texte de l'aide en cours (aussi dit à voix haute) ; affiché dans la bulle.
  String? helpText;

  String phrase(String key) => skill.say(key, question);

  Future<void> say(String key) => app.voice.say(phrase(key), id: skill.voiceId(key));

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
    notifyListeners();
    if (ok) {
      finished = true;
      helpText = null;
      notifyListeners();
      await _record(correct: true, demonstrated: false);
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
    // La bulle reste quelques secondes après la voix, puis libère l'écran.
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (helpText == text && !finished) hideHelp();
    });
  }

  void hideHelp() {
    helpText = null;
    notifyListeners();
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
  final _rand = Random();
  final _started = DateTime.now();
  int index = 0;
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
    return Attempt(app, skill, q, _advance);
  }

  Future<void> _advance() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    if (index + 1 >= plan.length) {
      await app.store.sessionDone(_started, DateTime.now());
      setState(() => over = true);
      await app.voice.say(app.common.text('fin_seance'), id: 'commun.fin_seance');
      return;
    }
    setState(() {
      index++;
      attempt = _next();
    });
  }

  @override
  void dispose() {
    app.voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = attempt!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          iconSize: 36,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: over ? 1 : index / plan.length,
            minHeight: 14,
            color: green,
            backgroundColor: const Color(0xFFE6F3E9),
          ),
        ),
        actions: [
          if (!over)
            IconButton(
              tooltip: 'Réécouter',
              iconSize: 40,
              icon: const Icon(Icons.volume_up_rounded, color: green),
              onPressed: () => a.say(a.skill.activity == 'calcul' ? 'question' : 'consigne'),
            ),
        ],
      ),
      body: SafeArea(child: over ? const _End() : _activity(a)),
    );
  }

  Widget _activity(Attempt a) {
    final key = ValueKey(index);
    // La bulle d'aide flotte par-dessus l'activité : elle ne doit jamais changer la taille de la zone de jeu
    // (sinon des objets sortent de la zone qui reçoit les touchers — erreur vue sur la tablette le 2026-11-02).
    return Stack(children: [
      Positioned.fill(
        child: switch (a.skill.activity) {
          'denombrer' => CountActivity(key: key, attempt: a),
          'composer' => ComposeActivity(key: key, attempt: a),
          _ => CalcActivity(key: key, attempt: a),
        },
      ),
      Positioned(
        top: 8,
        left: 16,
        right: 16,
        child: ListenableBuilder(
          listenable: a,
          builder: (_, _) => AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: a.helpText == null
                ? const SizedBox.shrink()
                // Transparente aux touchers : l'enfant peut continuer à jouer pendant que l'aide est affichée.
                : IgnorePointer(
                    key: ValueKey(a.helpText),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4DE),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
                      ),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_rounded, color: gold, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text(a.helpText!, style: Theme.of(context).textTheme.bodyLarge)),
                      ]),
                    ),
                  ),
          ),
        ),
      ),
    ]);
  }
}

class _End extends StatelessWidget {
  const _End();
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, size: 160, color: gold, semanticLabel: 'Séance finie'),
          const SizedBox(height: 24),
          SizedBox(
            width: 140,
            height: 140,
            child: FilledButton(
              style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: green),
              onPressed: () => Navigator.of(context).pop(),
              child: const Icon(Icons.home_rounded, size: 80, color: Colors.white, semanticLabel: 'Accueil'),
            ),
          ),
        ]),
      );
}
