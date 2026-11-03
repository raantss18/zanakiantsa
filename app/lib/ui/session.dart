import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../activities/calcul.dart';
import '../activities/ce1.dart';
import '../activities/chess.dart';
import '../activities/code.dart';
import '../activities/explore.dart';
import '../activities/choose.dart';
import '../activities/letters.dart';
import '../activities/listen.dart';
import '../activities/motif.dart';
import '../activities/numbers.dart';
import '../activities/composer.dart';
import '../activities/denombrer.dart';
import '../app_state.dart';
import '../audio/sfx.dart';
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
  Attempt(this.app, this.skill, this.question, this.onDone, this.onCorrect, {this.example = false}) : finished = example;

  /// Découverte guidée (ADR 0029) : l'idée, puis l'exemple résolu sous les yeux de l'enfant, sans réponse à donner
  /// ni journal ; « J'ai compris » mène aux vraies questions.
  final bool example;

  /// L'exemple est montré jusqu'au bout : le bouton « J'ai compris » apparaît.
  bool exampleDone = false;
  bool _exampleStarted = false;
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
  bool finished;

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

  /// Domaine d'anglais : les mots entre « » sont dits par la voix anglaise (ADR 0022).
  bool get _english => skill.params['langue'] == 'en';

  Future<void> say(String key, {bool force = false}) => example && key == 'consigne'
      ? Future.value() // pendant l'exemple, la voix raconte l'idée et la démonstration, pas la consigne
      : _english ? app.voice.sayMixed(phrase(key), force: force) : app.voice.say(phrase(key), id: voiceId(key), force: force);

  /// Affiche et dit une phrase de l'énoncé.
  Future<void> show(String key) {
    statementKey = key;
    helpText = null;
    notifyListeners();
    final spoken = say(key);
    if (example && !_exampleStarted) {
      _exampleStarted = true;
      spoken.then((_) => _runExample());
    }
    return spoken;
  }

  /// « Réécouter » : une demande explicite, dite même voix coupée (ADR 0025).
  Future<void> listen() => helpText != null
      ? (_english ? app.voice.sayMixed(helpText!, force: true) : app.voice.say(helpText!, force: true))
      : say(statementKey, force: true);

  Future<void> _record({required bool correct, required bool demonstrated}) => app.record(Answer(
        skill: skill.id,
        attempts: misses + (correct ? 1 : 0),
        correct: correct,
        demonstrated: demonstrated,
        millis: DateTime.now().difference(_started).inMilliseconds,
        at: DateTime.now(),
      ));

  /// L'idée (si le contenu en a une), puis la démonstration jouée par l'activité, puis « J'ai compris ».
  Future<void> _runExample() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final idea = skill.idea == null ? null : fill(skill.idea!, question, words, vars: skill.vars(question));
    if (idea != null) {
      helpText = idea;
      notifyListeners();
      await (_english ? app.voice.sayMixed(idea) : app.voice.say(idea));
    }
    demonstrate = true;
    helpText = phrase('demonstration');
    notifyListeners();
    await say('demonstration');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    exampleDone = true;
    notifyListeners();
  }

  /// [why] : ce que cette réponse-là montre (« 72, ce serait 7 paquets de dix… »), dit avant l'aide (ADR 0029).
  Future<void> submit(bool ok, {String? why}) async {
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
      app.voice.success(app.universe.id);
      await Future<void>.delayed(sfxLength);
      await say('bravo');
      final enc = app.common.list('encouragements');
      final i = _rand.nextInt(enc.length);
      await app.voice.say(enc[i], id: 'commun.encouragements.$i');
    } else {
      misses++;
      switch (helpAfter(misses)) {
        case Help.hint:
          await _help('indice', why: why);
        case Help.example:
          await _help('exemple', why: why);
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

  Future<void> _help(String key, {String? why}) async {
    // D'abord ce que montre la réponse (si on sait le dire), puis l'aide : une idée à la fois, en grand dans la bulle.
    if (why == null) {
      helpText = phrase(key);
      notifyListeners();
      await app.voice.say(app.common.text('encore'), id: 'commun.encore');
    } else {
      helpText = why;
      notifyListeners();
      await (_english ? app.voice.sayMixed(why) : app.voice.say(why));
      // Voix coupée : on laisse le temps de lire l'explication avant l'aide.
      if (!app.voice.voiceOn) await Future<void>.delayed(const Duration(seconds: 3));
      helpText = phrase(key);
      notifyListeners();
    }
    final text = helpText;
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

/// Essais seulement : `--dart-define=DEV_SKILL=<id>,<id>…` fait jouer ces compétences, une question chacune. Vide en
/// version publiée.
const devSkill = String.fromEnvironment('DEV_SKILL');

/// Une séance de questions dans un domaine (ADR 0018). Le dessin a sa propre page (activities/draw.dart).
class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.topic});
  final String topic;
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  late final AppState app = AppScope.of(context);
  late final List<String> plan =
      devSkill.isEmpty ? app.progressOf(app.topic(widget.topic)).plan(DateTime.now()) : devSkill.split(",");
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
    if (attempt == null) {
      attempt = _next();
      _music();
    }
  }

  /// Trame sonore : pas pendant un exercice d'écoute, où les sons sont la question (ADR 0025).
  void _music() {
    if (over || attempt?.skill.activity == 'ecouter') {
      app.voice.stopMusic();
    } else {
      app.voice.startMusic(app.universe.id);
    }
  }

  /// Compétences déjà présentées dans cette séance (découverte guidée, ADR 0029).
  final _introduced = <String>{};

  Attempt _next() {
    final skill = app.skill(plan[index]);
    final q = skill.draw(_rand, last: _last, avoid: app.recentOf(skill.id));
    _last = q;
    app.remember(skill.id, skill.signature(q));
    // Première rencontre (rien au journal) : d'abord l'idée et un exemple résolu.
    final example = _introduced.add(skill.id) && app.journal.every((x) => x.skill != skill.id);
    return Attempt(app, skill, q, _advance, () => setState(() => stars++), example: example);
  }

  /// « J'ai compris » : l'exemple laisse la place à une vraie question de la même compétence.
  void _understood() {
    final old = attempt;
    setState(() => attempt = _next());
    old?.dispose();
    _music();
  }

  Future<void> _advance() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (index + 1 >= plan.length) {
      await app.logSession(SessionLog(theme: widget.topic, started: _started, ended: DateTime.now()));
      setState(() => over = true);
      app.voice.stopMusic();
      app.voice.fanfare();
      await Future<void>.delayed(sfxLength);
      await app.voice.say(app.common.text('fin_seance'), id: 'commun.fin_seance');
      final e = app.universeWords.episode(app.sessionsDone)!;
      await app.voice.say(app.universeWords.story[e], id: 'univers.${app.universe.id}.histoire.$e');
      if (app.rewards.unlockedSince(before)) {
        await app.voice.say(app.common.text('nouvel_autocollant'), id: 'commun.nouvel_autocollant');
      }
      await sayDayStatus(app, widget.topic);
      return;
    }
    final old = attempt;
    setState(() {
      index++;
      attempt = _next();
    });
    old?.dispose();
    _music();
  }

  @override
  void dispose() {
    app.voice.stop();
    app.voice.stopMusic();
    attempt?.dispose();
    // Retour en cours de séance : le temps compte pour la journée, sans faire avancer l'histoire (ADR 0018).
    if (!over && (index > 0 || DateTime.now().difference(_started) > const Duration(seconds: 20))) {
      app.logSession(SessionLog(theme: widget.topic, started: _started, ended: DateTime.now(), complete: false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final a = attempt!;
    return MusicScope(
      resume: _music,
      child: Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            SessionTopBar(
              onVoiceOn: () => attempt?.listen(),
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
                  ? DayEnd(
                      theme: widget.topic,
                      again: () => Navigator.of(context)
                          .pushReplacement(MaterialPageRoute(builder: (_) => SessionPage(topic: widget.topic))),
                      child: _End(
                        stars: stars,
                        universe: u,
                        words: app.universeWords,
                        episode: app.universeWords.episode(app.sessionsDone)!,
                        newSticker: app.rewards.unlockedSince(before) ? u.stickers[app.rewards.stickers - 1] : null,
                      ),
                    )
                  : Stack(children: [
                      Positioned.fill(
                        // Pendant l'exemple, l'activité laisse la place à la pastille « Nouveau » en haut et au bouton
                        // « J'ai compris » en bas (pas de chevauchement).
                        top: a.example ? 52 : 0,
                        bottom: a.example ? 104 : 0,
                        child: switch (a.skill.activity) {
                          'denombrer' => CountActivity(key: ObjectKey(a), attempt: a),
                          'composer' => ComposeActivity(key: ObjectKey(a), attempt: a),
                          'choisir' => ChooseActivity(key: ObjectKey(a), attempt: a),
                          'motif' => MotifActivity(key: ObjectKey(a), attempt: a),
                          'ecouter' => ListenActivity(key: ObjectKey(a), attempt: a),
                          'echecs' => ChessActivity(key: ObjectKey(a), attempt: a),
                          'batonnets' when a.skill.params['mode'] == 'casser' => BreakTenActivity(key: ObjectKey(a), attempt: a),
                          'batonnets' => SticksActivity(key: ObjectKey(a), attempt: a),
                          'paquets' => PacketsActivity(key: ObjectKey(a), attempt: a),
                          'groupes' || 'tables' => GroupsActivity(key: ObjectKey(a), attempt: a),
                          'partage' => ShareActivity(key: ObjectKey(a), attempt: a),
                          'programmer' => CodeActivity(key: ObjectKey(a), attempt: a),
                          'solide' => SolidActivity(key: ObjectKey(a), attempt: a),
                          'syllabes' => SyllablesActivity(key: ObjectKey(a), attempt: a),
                          'lettre' => LetterActivity(key: ObjectKey(a), attempt: a),
                          'tracer' => TraceActivity(key: ObjectKey(a), attempt: a),
                          'multibase' => MultibaseActivity(key: ObjectKey(a), attempt: a),
                          'posee' => ColumnOpActivity(key: ObjectKey(a), attempt: a),
                          'heure' => ClockActivity(key: ObjectKey(a), attempt: a),
                          'planetes' => PlanetsActivity(key: ObjectKey(a), attempt: a),
                          'corps' => BodyActivity(key: ObjectKey(a), attempt: a),
                          _ => CalcActivity(key: ObjectKey(a), attempt: a),
                        },
                      ),
                      Positioned.fill(child: Celebration(trigger: stars, scene: u.scene)),
                      if (a.example) ...[
                        Positioned(left: 12, top: 4, child: _NewBadge(title: a.skill.title)),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: ListenableBuilder(
                            listenable: a,
                            builder: (_, _) => AnimatedOpacity(
                              opacity: a.exampleDone ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: IgnorePointer(
                                ignoring: !a.exampleDone,
                                child: Center(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: green,
                                      minimumSize: const Size(260, 76),
                                      textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700),
                                    ),
                                    onPressed: _understood,
                                    icon: const Icon(Icons.check_rounded, size: 40),
                                    label: const Text("J'ai compris, à moi !"),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ]),
            ),
          ]),
        ),
      ),
    ),
    );
  }
}

/// ← retour (≠ Accueil), progression, étoiles de la séance (nombre écrit à côté de l'étoile).
class SessionTopBar extends StatelessWidget {
  const SessionTopBar({super.key, required this.progress, required this.stars, required this.universe, required this.onBack, this.onVoiceOn});
  final double progress;

  /// Appelé quand l'enfant rallume la voix (la consigne est redite).
  final VoidCallback? onVoiceOn;
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
          const SizedBox(width: 8),
          SoundToggles(onVoiceOn: onVoiceOn),
          const SizedBox(width: 8),
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

/// Fin de séance : étoiles, épisode gagné du fil d'histoire (ADR 0017), nouvel autocollant éventuel, Accueil.
class _End extends StatelessWidget {
  const _End({required this.stars, required this.universe, required this.words, required this.episode, this.newSticker});
  final int stars;
  final Universe universe;
  final UniverseWords words;
  final int episode;
  final String? newSticker;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Art('2b50', size: 64),
          const SizedBox(width: 12),
          Text('× $stars', style: Theme.of(context).textTheme.displayLarge, semanticsLabel: stars > 1 ? '$stars étoiles' : '$stars étoile'),
        ]),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(children: [
            Art(universe.mascot, size: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                EpisodeLabel(index: episode, count: words.story.length),
                Text(words.story[episode], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink, height: 1.2)),
              ]),
            ),
          ]),
        ),
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
      ]);
}

/// Dit où en est la journée après une activité : pause si ce domaine est fini, fin de journée si tout l'est.
Future<void> sayDayStatus(AppState app, String theme) async {
  final plan = app.dayPlan();
  if (!plan.items.any((i) => i.theme == theme) || !plan.item(theme).finished) return;
  final k = plan.finished ? 'journee_finie' : 'pause';
  await app.voice.say(app.common.text(k), id: 'commun.$k');
}

/// Carte de fin d'une activité (ADR 0018) : ce qu'on a gagné ([child]), puis la suite de la journée. Domaine pas
/// encore fini : « Encore » ou Accueil. Fini : une pause pour bouger, puis l'accueil propose l'activité suivante.
/// Journée finie : bravo et à demain.
class DayEnd extends StatelessWidget {
  const DayEnd({super.key, required this.theme, required this.again, required this.child});
  final String theme;
  final VoidCallback again;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final plan = app.dayPlan();
    final item = plan.items.where((i) => i.theme == theme).firstOrNull;
    final done = item?.finished ?? false;
    Widget round(IconData icon, String label, VoidCallback onTap, {bool primary = true}) => Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 104,
            height: 104,
            child: primary
                ? FilledButton(
                    style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero),
                    onPressed: onTap,
                    child: Icon(icon, size: 64, semanticLabel: label),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero, side: const BorderSide(color: ink, width: 3)),
                    onPressed: onTap,
                    child: Icon(icon, size: 56, color: ink, semanticLabel: label),
                  ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
        ]);
    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const PlayfulTitle('Bravo !', size: 40),
            const SizedBox(height: 12),
            child,
            if (done) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEAF5EC), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Art(plan.finished ? '1f3c6' : '1f938', size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app.common.text(plan.finished ? 'journee_finie' : 'pause'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink, height: 1.2),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(spacing: 32, runSpacing: 16, alignment: WrapAlignment.center, children: [
              if (!done) round(Icons.replay_rounded, 'Encore', again, primary: false),
              round(Icons.home_rounded, 'Accueil', () => Navigator.of(context).pop()),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Interrupteurs « Voix » et « Musique » (docs/design.md § 5, ADR 0025) : ronds de 48 dp ; coupé = fond gris, icône
/// barrée et contour (pas seulement la couleur) ; état lu par le lecteur d'écran.
class SoundToggles extends StatelessWidget {
  const SoundToggles({super.key, this.onVoiceOn});
  final VoidCallback? onVoiceOn;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final music = MusicScope.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Toggle(
        on: app.voice.voiceOn,
        label: 'Voix',
        onIcon: Icons.record_voice_over_rounded,
        offIcon: Icons.voice_over_off_rounded,
        onChanged: (v) async {
          await app.setVoiceOn(v);
          if (v) onVoiceOn?.call();
        },
      ),
      const SizedBox(width: 6),
      _Toggle(
        on: app.voice.soundOn,
        label: 'Musique',
        onIcon: Icons.music_note_rounded,
        offIcon: Icons.music_off_rounded,
        onChanged: (v) async {
          await app.setSoundOn(v);
          if (v) music?.resume();
        },
      ),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.label, required this.onIcon, required this.offIcon, required this.onChanged});
  final bool on;
  final String label;
  final IconData onIcon, offIcon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).universe;
    return Semantics(
      toggled: on,
      button: true,
      label: '$label, ${on ? 'activée' : 'coupée'}',
      excludeSemantics: true,
      child: Tooltip(
        message: '$label : ${on ? 'activée' : 'coupée'}',
        child: Material(
          color: on ? surface : const Color(0xFFBFC7C1),
          shape: CircleBorder(side: on ? BorderSide.none : const BorderSide(color: ink, width: 2)),
          elevation: on ? 2 : 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onChanged(!on),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Icon(on ? onIcon : offIcon, size: 28, color: on ? (u.night ? u.primary : u.onCard) : ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// La trame sonore d'une page de leçon : [resume] la relance quand l'enfant rallume la musique (si l'exercice le permet).
class MusicScope extends InheritedWidget {
  const MusicScope({super.key, required this.resume, required super.child});
  final VoidCallback resume;

  static MusicScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<MusicScope>();

  @override
  bool updateShouldNotify(MusicScope old) => false;
}

/// Pastille « Nouveau » au-dessus de l'exemple résolu : on voit qu'on découvre, pas qu'on est évalué.
class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
        decoration: BoxDecoration(color: Brand.yellow, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded, color: ink, size: 24),
          const SizedBox(width: 6),
          Flexible(
            child: Text('Nouveau : $title', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
          ),
        ]),
      );
}
