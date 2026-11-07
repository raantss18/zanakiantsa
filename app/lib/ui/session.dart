import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../activities/blocks.dart';
import '../activities/calcul.dart';
import '../activities/ce1.dart';
import '../activities/chess.dart';
import '../activities/code.dart';
import '../activities/explore.dart';
import '../activities/fractions.dart';
import '../activities/problem.dart';
import '../activities/choose.dart';
import '../activities/letters.dart';
import '../activities/listen.dart';
import '../activities/motif.dart';
import '../activities/numbers.dart';
import '../activities/composer.dart';
import '../activities/denombrer.dart';
import '../app_state.dart';
import '../audio/sfx.dart';
import '../audio/voice.dart';
import '../content/content.dart';
import '../core/events.dart';
import '../core/rewards.dart';
import '../core/rules.dart';
import 'celebrate.dart';
import 'adaptive.dart';
import 'narrator.dart';
import 'theme.dart';
import 'universe.dart';

/// Gère une question : essais, aide qui monte, démonstration ou indice final, retour, journal (ADR 0006–0008), et ce
/// que le bandeau narrateur affiche (ADR 0016).
class Attempt extends ChangeNotifier {
  Attempt(this.app, this.skill, this.question, this.onDone, this.onCorrect, {this.example = false, this.challenge = false})
      : finished = example;

  /// Question d'un défi (ADR 0042) ou du test de départ (ADR 0045) : notée comme telle dans le journal.
  final bool challenge;

  /// Ce que montraient les essais manqués (gardé dans le journal, ADR 0042).
  final errors = <String>[];

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

  /// La parole de cette question : coupée dès qu'on passe à la suivante ou qu'on quitte la séance.
  late final Speech speech = app.voice.scope();

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
      : _english ? speech.sayMixed(phrase(key), force: force) : speech.say(phrase(key), id: voiceId(key), force: force);

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
      ? (_english ? speech.sayMixed(helpText!, force: true) : speech.say(helpText!, force: true))
      : say(statementKey, force: true);

  Future<void> _record({required bool correct, required bool demonstrated}) => app.record(Answer(
        skill: skill.id,
        attempts: misses + (correct ? 1 : 0),
        correct: correct,
        demonstrated: demonstrated,
        millis: DateTime.now().difference(_started).inMilliseconds,
        at: DateTime.now(),
        errors: errors,
        challenge: challenge,
      ));

  /// L'idée (si le contenu en a une), puis la démonstration jouée par l'activité, puis « J'ai compris ».
  Future<void> _runExample() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final idea = skill.idea == null ? null : fill(skill.idea!, question, words, vars: skill.vars(question));
    if (idea != null) {
      helpText = idea;
      notifyListeners();
      await _sayAndRead(idea);
    }
    demonstrate = true;
    helpText = phrase('demonstration');
    notifyListeners();
    final watch = Stopwatch()..start();
    await say('demonstration');
    await _readingTime(helpText!, watch.elapsed);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    exampleDone = true;
    notifyListeners();
  }

  /// Le temps de lire le texte affiché avant de passer à la suite, moins ce que la voix a déjà pris ([spoken]). Sans
  /// voix (coupée, ou pas de voix française sur l'appareil), l'idée ou l'explication défilait sans pouvoir être lue.
  Future<void> _readingTime(String text, [Duration spoken = Duration.zero]) {
    final left = Duration(milliseconds: (1500 + 60 * text.length).clamp(1500, 8000)) - spoken;
    return left > Duration.zero ? Future<void>.delayed(left) : Future.value();
  }

  /// Dit [text] (voix anglaise pour les passages entre « » en anglais), puis laisse le temps de le lire.
  Future<void> _sayAndRead(String text) async {
    final watch = Stopwatch()..start();
    await (_english ? speech.sayMixed(text) : speech.say(text));
    await _readingTime(text, watch.elapsed);
  }

  /// [why] : ce que cette réponse-là montre (« 72, ce serait 7 paquets de dix… »), dit avant l'aide (ADR 0029).
  Future<void> submit(bool ok, {String? why}) async {
    if (busy || finished) return;
    busy = true;
    _helpTimer?.cancel();
    notifyListeners();
    // try/finally : quoi qu'il arrive au son ou à l'enregistrement, l'écran redevient utilisable.
    try {
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
        await speech.say(enc[i], id: 'commun.encouragements.$i');
      } else {
        misses++;
        // Sans explication propre à cette erreur, on garde le conseil de la compétence : c'est ce qu'il y a à revoir.
        errors.add(why ?? phrase('indice'));
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
              await speech.say(app.common.text('apres_indice'), id: 'commun.apres_indice');
              await say('indice');
            }
        }
      }
    } finally {
      busy = false;
      notifyListeners();
    }
    if (finished) onDone();
  }

  Future<void> _help(String key, {String? why}) async {
    // D'abord ce que montre la réponse (si on sait le dire), puis l'aide : une idée à la fois, en grand dans la bulle.
    if (why == null) {
      helpText = phrase(key);
      notifyListeners();
      await speech.say(app.common.text('encore'), id: 'commun.encore');
    } else {
      helpText = why;
      notifyListeners();
      // On laisse le temps de lire l'explication avant l'aide.
      await _sayAndRead(why);
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
    speech.close();
    super.dispose();
  }
}

/// Une séance laissée en cours (ADR 0039) : le plan, la question où reprendre, les étoiles déjà gagnées. Gardée par
/// enfant et par domaine jusqu'à la fin de la séance, même si l'enfant sort, change de domaine ou ferme l'app.
class SessionResume {
  const SessionResume(this.plan, this.index, this.stars);
  final List<String> plan;
  final int index, stars;

  static String _key(String topic) => 'reprise_$topic';

  Future<void> save(AppState app, String topic) =>
      app.store.set(_key(topic), jsonEncode({'plan': plan, 'index': index, 'stars': stars}));

  static Future<void> clear(AppState app, String topic) => app.store.set(_key(topic), '');

  /// La reprise de ce domaine, si elle est encore valable (toutes ses compétences existent toujours).
  static Future<SessionResume?> load(AppState app, String topic) async {
    final raw = await app.store.get(_key(topic));
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final r = SessionResume(List<String>.from(j['plan'] as List), j['index'] as int, j['stars'] as int);
      final ids = {for (final s in app.topic(topic).skills) s.id};
      if (r.index <= 0 || r.index >= r.plan.length || !r.plan.every(ids.contains)) return null;
      return r;
    } catch (_) {
      return null;
    }
  }
}

/// Record du défi d'un domaine (réussites du premier coup), null s'il n'y en a pas encore.
Future<int?> challengeRecord(AppState app, String topic) async => int.tryParse(await app.store.get('defi_$topic') ?? '');

/// Essais seulement : `--dart-define=DEV_SKILL=<id>,<id>…` fait jouer ces compétences, une question chacune. Vide en
/// version publiée.
const devSkill = String.fromEnvironment('DEV_SKILL');

/// Une séance de questions dans un domaine (ADR 0018). Le dessin a sa propre page (activities/draw.dart).
class SessionPage extends StatefulWidget {
  const SessionPage({super.key, required this.topic, this.resume, this.challenge = false, this.placement = false});
  final String topic;

  /// Test de départ (ADR 0045) : deux questions par compétence pas encore acquise, dans l'ordre ; réussies du premier
  /// coup, elle est notée comme sue ; à la première hésitation, le test s'arrête et c'est là que l'enfant commence.
  final bool placement;

  /// Défi (ADR 0042) : 10 questions mêlées de ce qui est acquis, sans exemple ; on compte les réussites du premier
  /// coup et on garde le record.
  final bool challenge;

  /// Séance laissée en cours dans ce domaine : on la reprend à la même question (voir [SessionResume]).
  final SessionResume? resume;
  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  late final AppState app = AppScope.of(context);
  late List<String> plan = devSkill.isNotEmpty
      ? devSkill.split(",")
      : widget.challenge
          ? app.progressOf(app.topic(widget.topic)).challengePlan(Random()) ?? app.progressOf(app.topic(widget.topic)).plan(DateTime.now())
          : widget.placement
              ? app.progressOf(app.topic(widget.topic)).placementPlan() ?? app.progressOf(app.topic(widget.topic)).plan(DateTime.now())
              : widget.resume?.plan ?? app.progressOf(app.topic(widget.topic)).plan(DateTime.now());

  /// La compétence nouvelle de la séance : dès qu'elle est acquise, la suite passe à la suivante (ADR 0037).
  late String? _target = widget.challenge || widget.placement ? null : app.progressOf(app.topic(widget.topic)).newSkill;

  /// Test de départ : les compétences sues, et celle où il s'est arrêté (null : rien manqué).
  final _known = <String>[];
  String? _stoppedAt;

  /// Ni reprise ni compétence cible : le défi et le test de départ se jouent d'une traite.
  bool get _oneGo => widget.challenge || widget.placement;

  /// Défi : réussites du premier coup, et le record d'avant (pour dire « nouveau record ! »).
  int firstTry = 0;
  int? _record;
  late final Rewards before = app.rewards;

  /// La parole de la séance (fin de séance, histoire…) : coupée quand on quitte la page.
  late final Speech speech = app.voice.scope();
  final _rand = Random();
  final _started = DateTime.now();
  late int index = widget.resume?.index ?? 0;
  late int stars = widget.resume?.stars ?? 0;
  Attempt? attempt;
  Question? _last;
  bool over = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (attempt == null) {
      attempt = _next();
      _music();
      if (widget.challenge) challengeRecord(app, widget.topic).then((r) => _record = r);
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
    final target = _target;
    if (devSkill.isEmpty && target != null) {
      final p = app.progressOf(app.topic(widget.topic));
      if (p.earned(target)) {
        plan = p.adapt(plan, index, target, _rand);
        _target = p.newSkill;
      }
    }
    final skill = app.skill(plan[index]);
    final q = skill.draw(_rand, last: _last, avoid: app.recentOf(skill.id));
    _last = q;
    app.remember(skill.id, skill.signature(q));
    // Première rencontre (rien au journal hors défi et test de départ) : d'abord l'idée et un exemple résolu.
    final example = !_oneGo && _introduced.add(skill.id) && app.journal.every((x) => x.skill != skill.id || x.challenge);
    late final Attempt a;
    a = Attempt(app, skill, q, _advance, () => setState(() {
          stars++;
          if (a.misses == 0) firstTry++;
        }), example: example, challenge: _oneGo);
    return a;
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
    if (widget.placement) await _placementStep();
    if (index + 1 >= plan.length || _stoppedAt != null) {
      if (devSkill.isEmpty && (!_oneGo || _known.isNotEmpty)) SessionResume.clear(app, widget.topic);
      if (widget.challenge) await _endChallenge();
      await app.logSession(SessionLog(theme: widget.topic, started: _started, ended: DateTime.now()));
      setState(() => over = true);
      app.voice.stopMusic();
      app.voice.fanfare();
      await Future<void>.delayed(sfxLength);
      if (_oneGo) {
        await speech.say(widget.challenge ? challengeText : placementText);
        return;
      }
      await speech.say(app.common.text('fin_seance'), id: 'commun.fin_seance');
      final e = app.universeWords.episode(app.sessionsDone)!;
      await speech.say(app.universeWords.story[e], id: 'univers.${app.universe.id}.histoire.$e');
      if (app.rewards.unlockedSince(before)) {
        await speech.say(app.common.text('nouvel_autocollant'), id: 'commun.nouvel_autocollant');
      }
      await sayDayStatus(app, widget.topic, speech);
      return;
    }
    final old = attempt;
    setState(() {
      index++;
      attempt = _next();
    });
    old?.dispose();
    _music();
    // Le point de reprise : si l'enfant sort maintenant, il reviendra à cette question.
    if (devSkill.isEmpty && !_oneGo) SessionResume(plan, index, stars).save(app, widget.topic);
  }

  /// Test de départ, après chaque question : hésitation (essai manqué) → on s'arrête là ; dernière question d'une
  /// compétence réussie du premier coup → elle est sue.
  Future<void> _placementStep() async {
    final a = attempt!;
    final id = plan[index];
    if (!a.solved || a.misses > 0) {
      _stoppedAt = id;
    } else if (index + 1 >= plan.length || plan[index + 1] != id) {
      _known.add(id);
      await app.place([id]);
    }
  }

  String get placementText {
    final start = _stoppedAt ?? app.progressOf(app.topic(widget.topic)).newSkill;
    final known = _known.length;
    final head = known == 0
        ? 'Pas de souci, on va l\'apprendre ensemble. '
        : 'Bravo, tu sais déjà $known compétence${known > 1 ? 's' : ''} : ${[for (final id in _known) app.skill(id).title].join(', ')}. ';
    return start == null ? '${head}Tu sais tout ce qu\'il y a ici !' : '${head}Tu commences à : ${app.skill(start).title}.';
  }

  /// Fin de défi : le score, et le record s'il est battu.
  Future<void> _endChallenge() async {
    if (firstTry > (_record ?? -1)) await app.store.set('defi_${widget.topic}', '$firstTry');
  }

  String get challengeText {
    final record = _record;
    final beaten = record == null || firstTry > record;
    return 'Défi : $firstTry sur ${plan.length} du premier coup. '
        '${beaten ? (record == null ? 'C\'est ton premier record !' : 'Nouveau record !') : 'Ton record : $record.'}';
  }

  @override
  void dispose() {
    speech.close();
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
          // Paysage (ADR 0052, 0054) : le texte passe dans une colonne à gauche et l'activité prend toute la hauteur.
          child: LayoutBuilder(builder: (context, k) {
            final side = !over && activityBesideText(k.biggest);
            // Pendant un exemple, le badge « Nouveau » et le bouton « J'ai compris » : sur la page, ou dans la colonne de
            // gauche quand l'échiquier a toute la hauteur.
            final badge = a.example ? _NewBadge(title: a.skill.title) : null;
            final understood = a.example
                ? ListenableBuilder(
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
                          ) : null;
            // Dans la colonne de gauche, le texte prend toute la hauteur que le badge et le bouton laissent.
            final sideHeight = (k.maxHeight - 72 - (badge == null ? 0 : 56) - (understood == null ? 0 : 96)).clamp(narratorHeight, 420.0);
            final narrator = ListenableBuilder(
              listenable: a,
              builder: (_, _) => Narrator(
                universe: u,
                text: a.bandText,
                help: a.helpText != null,
                cheer: stars,
                onListen: a.listen,
                height: side ? sideHeight : narratorHeight,
              ),
            );
            // La zone de l'activité : sous la barre du haut, et sous le texte ou à côté de lui.
            final area = Size(
              k.maxWidth - (side ? sidePanelWidth(k.maxWidth) : 0),
              k.maxHeight - 72 - (side ? 0 : narratorHeight) - (a.example && !side ? 156 : 0),
            );
            final fills = activitiesThatFill.contains(a.skill.activity);
            final scale = fills ? 1.0 : activityScale(area);
            // Centrée en hauteur seulement là où elle est agrandie ou à côté du texte : ailleurs, rien ne change.
            final room = !fills && (scale > 1 || side) ? (area.height - 8) / scale : null;
            final content = over
                  ? DayEnd(
                      theme: widget.topic,
                      again: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => SessionPage(topic: widget.topic, challenge: widget.challenge))),
                      child: _oneGo
                          ? Text(widget.challenge ? challengeText : placementText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink, height: 1.25))
                          : _End(
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
                        top: a.example && !side ? 52 : 0,
                        bottom: a.example && !side ? 104 : 0,
                        child: ScaledActivity(scale: scale, child: ActivityRoom(height: room, child: switch (a.skill.activity) {
                          'denombrer' => CountActivity(key: ObjectKey(a), attempt: a),
                          'composer' => ComposeActivity(key: ObjectKey(a), attempt: a),
                          'choisir' => ChooseActivity(key: ObjectKey(a), attempt: a),
                          'motif' => MotifActivity(key: ObjectKey(a), attempt: a),
                          'ecouter' => ListenActivity(key: ObjectKey(a), attempt: a),
                          'echecs' => ChessActivity(key: ObjectKey(a), attempt: a),
                          'probleme' => ProblemActivity(key: ObjectKey(a), attempt: a),
                          'batonnets' when a.skill.params['mode'] == 'casser' => BreakTenActivity(key: ObjectKey(a), attempt: a),
                          'batonnets' => SticksActivity(key: ObjectKey(a), attempt: a),
                          'paquets' => PacketsActivity(key: ObjectKey(a), attempt: a),
                          'groupes' || 'tables' => GroupsActivity(key: ObjectKey(a), attempt: a),
                          'partage' => ShareActivity(key: ObjectKey(a), attempt: a),
                          'programmer' => CodeActivity(key: ObjectKey(a), attempt: a),
                          'blocs' => BlocksActivity(key: ObjectKey(a), attempt: a),
                          'solide' => SolidActivity(key: ObjectKey(a), attempt: a),
                          'syllabes' => SyllablesActivity(key: ObjectKey(a), attempt: a),
                          'lettre' => LetterActivity(key: ObjectKey(a), attempt: a),
                          'tracer' => TraceActivity(key: ObjectKey(a), attempt: a),
                          'multibase' => MultibaseActivity(key: ObjectKey(a), attempt: a),
                          'posee' => ColumnOpActivity(key: ObjectKey(a), attempt: a),
                          'heure' => ClockActivity(key: ObjectKey(a), attempt: a),
                          'suite' => SequenceActivity(key: ObjectKey(a), attempt: a),
                          'fraction' => FractionActivity(key: ObjectKey(a), attempt: a),
                          'planetes' => PlanetsActivity(key: ObjectKey(a), attempt: a),
                          'corps' => BodyActivity(key: ObjectKey(a), attempt: a),
                          _ => CalcActivity(key: ObjectKey(a), attempt: a),
                        })),
                      ),
                      Positioned.fill(child: Celebration(trigger: stars, scene: u.scene)),
                      // Essais seulement (jamais publié) : passer à la compétence suivante pour regarder chaque écran.
                      if (devSkill.isNotEmpty) Positioned(left: 4, bottom: 4, child: FloatingActionButton.small(heroTag: 'devSkip', onPressed: _advance, child: const Icon(Icons.skip_next))),
                      if (a.example && !side) ...[
                        Positioned(left: 12, right: 12, top: 4, child: Align(alignment: Alignment.centerLeft, child: badge!)),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 16,
                          child: understood!,
                        ),
                      ],
                    ]);
            return Column(children: [
              SessionTopBar(
                onVoiceOn: () => attempt?.listen(),
                progress: over ? 1 : index / plan.length,
                stars: stars,
                universe: u,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              if (side)
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: sidePanelWidth(k.maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(children: [
                          if (badge != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Align(alignment: Alignment.centerLeft, child: badge)),
                          narrator,
                          if (understood != null) Padding(padding: const EdgeInsets.only(top: 8), child: understood),
                        ]),
                      ),
                    ),
                    Expanded(child: content),
                  ]),
                )
              else ...[
                if (!over) narrator,
                Expanded(child: content),
              ],
            ]);
          }),
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
Future<void> sayDayStatus(AppState app, String theme, [Speech? speech]) async {
  final plan = app.dayPlan();
  if (!plan.items.any((i) => i.theme == theme) || !plan.item(theme).finished) return;
  final k = plan.finished ? 'journee_finie' : 'pause';
  await (speech?.say ?? app.voice.say)(app.common.text(k), id: 'commun.$k');
}

/// Carte de fin d'une activité (ADR 0018) : ce qu'on a gagné ([child]), puis la suite de la journée. Domaine pas
/// encore fini : « Continuer » (une nouvelle série de questions, pas les mêmes : flèche vers l'avant, pas une flèche
/// qui tourne, qui ferait croire qu'on rejoue la série) ou Accueil. Fini : une pause pour bouger, puis l'accueil propose l'activité suivante.
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
    Widget round(IconData icon, String label, VoidCallback onTap, {bool primary = true, String? detail}) => Column(mainAxisSize: MainAxisSize.min, children: [
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
          if (detail != null) Text(detail, style: const TextStyle(fontSize: 15, color: Color(0xFF4A554E))),
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
              if (!done) round(Icons.arrow_forward_rounded, 'Continuer', again, detail: 'nouvelles questions'),
              round(Icons.home_rounded, 'Accueil', () => Navigator.of(context).pop(), primary: done),
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
        constraints: const BoxConstraints(maxWidth: 480),
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
