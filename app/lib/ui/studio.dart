import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../audio/sfx.dart';
import '../audio/voice.dart';
import '../core/events.dart';
import '../core/studio.dart';
import '../l10n/l10n.dart';
import 'adaptive.dart';
import 'chess_play.dart';
import 'studio_challenges.dart';
import 'theme.dart';
import 'universe.dart';

/// Programmes libres (ADR 0076) : l'atelier où l'enfant écrit ce qu'il veut, sans bonne réponse ni étoile. Le robot
/// dessine et joue des notes ; le programme s'enregistre sur l'appareil (réglage `programmes` de l'enfant).

Future<List<SavedProgram>> loadPrograms(AppState app) async => decodePrograms(await app.store.get('programmes'));

Future<void> storePrograms(AppState app, List<SavedProgram> ps) => app.store.set('programmes', encodePrograms(ps));

String studioColourName(int i) => t(studioColours[i.clamp(0, studioColours.length - 1)].$1);

String studioNoteName(int i) => t(studioNotes[i.clamp(0, studioNotes.length - 1)]);

/// Le nom d'un bloc, écrit tel qu'il se lit. [palette] : « … » à la place de la valeur.
String studioBlockName(StudioBlock b, {bool palette = false}) {
  String v(String s) => palette ? '…' : s;
  return switch (b.kind) {
    StudioKind.forward => tf('avancer de {n}', {'n': v('${b.n}')}),
    StudioKind.turnLeft => tf('tourner à gauche de {n}', {'n': v('${b.n}°')}),
    StudioKind.turnRight => tf('tourner à droite de {n}', {'n': v('${b.n}°')}),
    StudioKind.repeat => tf('répéter {n} fois', {'n': v('${b.n}')}),
    StudioKind.penUp => t('lever le crayon'),
    StudioKind.penDown => t('poser le crayon'),
    StudioKind.colour => tf('couleur {c}', {'c': v(studioColourName(b.n))}),
    StudioKind.note => tf('jouer la note {c}', {'c': v(studioNoteName(b.n))}),
  };
}

IconData _icon(StudioKind k) => switch (k) {
  StudioKind.forward => Icons.straight_rounded,
  StudioKind.turnLeft => Icons.turn_left_rounded,
  StudioKind.turnRight => Icons.turn_right_rounded,
  StudioKind.repeat => Icons.repeat_rounded,
  StudioKind.penUp => Icons.edit_off_rounded,
  StudioKind.penDown => Icons.edit_rounded,
  StudioKind.colour => Icons.palette_rounded,
  StudioKind.note => Icons.music_note_rounded,
};

/// Familles de blocs (toujours avec le nom écrit) : mouvement, boucle, crayon, son. Texte blanc lisible sur chacune.
Color _colour(StudioKind k) => switch (k) {
  StudioKind.repeat => const Color(0xFFB45309),
  StudioKind.penUp || StudioKind.penDown || StudioKind.colour => const Color(0xFF0F766E),
  StudioKind.note => const Color(0xFF7E22CE),
  _ => const Color(0xFF15803D),
};

class StudioPage extends StatefulWidget {
  const StudioPage({super.key, this.saved, this.idea, this.challenge});
  final SavedProgram? saved;
  final StudioIdea? idea;

  /// Un défi du robot (ADR 0077) : le dessin modèle s'affiche en pointillés.
  final StudioChallenge? challenge;
  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late final AppState app = AppScope.of(context);
  late final Speech speech = app.voice.scope();
  final _started = DateTime.now();

  final program = <StudioBlock>[];
  final open = <StudioBlock>[];
  final added = <(List<StudioBlock>, StudioBlock)>[];

  /// L'enregistrement en cours d'édition (null : pas encore enregistré) et son nom.
  int? savedId;
  String? name;
  bool dirty = false;

  StudioRun? lastRun;
  int shown = 0;
  bool running = false, _stop = false, _saving = false;
  String? message;

  /// Le dessin modèle du défi (null hors défi).
  late final StudioRun? model = widget.challenge == null ? null : runStudio(widget.challenge!.model());

  @override
  void initState() {
    super.initState();
    if (widget.saved case final s?) {
      program.addAll([for (final b in s.blocks) b.copy()]);
      savedId = s.id;
      name = s.name;
    } else if (widget.idea case final i?) {
      program.addAll(i.build());
      name = t(i.title);
      dirty = true;
    } else if (widget.challenge case final c?) {
      name = t(c.title);
      message = tf('{text} Refais le dessin en pointillés.', {'text': t(c.text)});
    }
    // Un programme rouvert s'efface aussi bloc par bloc (« Effacer le dernier bloc » restait grisé).
    void seed(List<StudioBlock> list) {
      for (final b in list) {
        added.add((list, b));
        seed(b.body);
      }
    }

    seed(program);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (message != null) {
        speech.say(message!);
      } else if (program.isEmpty) {
        speech.say(
          t(
            'Écris ton programme avec les blocs, puis appuie sur le bouton vert. Le robot dessine et joue de la musique.',
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _stop = true;
    speech.close();
    if (DateTime.now().difference(_started) > const Duration(seconds: 20)) {
      app.logSession(SessionLog(theme: 'code', started: _started, ended: DateTime.now(), complete: false));
    }
    super.dispose();
  }

  List<StudioBlock> get _target => open.isEmpty ? program : open.last.body;

  void _edited() {
    dirty = true;
    message = null;
  }

  void _add(StudioKind k) {
    if (studioSize(program) >= studioMaxBlocks) {
      speech.say(t('Plus de place : utilise un bloc « répéter ».'), force: true);
      return;
    }
    if (k == StudioKind.repeat && open.length >= studioMaxDepth) {
      speech.say(
        tf('Pas plus de {n} boucles l\'une dans l\'autre : ferme d\'abord un bloc.', {'n': studioMaxDepth}),
        force: true,
      );
      return;
    }
    final b = StudioBlock(k);
    setState(() {
      final list = _target;
      list.add(b);
      added.add((list, b));
      if (b.isContainer) open.add(b);
      _edited();
    });
    speech.say(studioBlockName(b));
  }

  void _undo() {
    if (added.isEmpty) return;
    setState(() {
      final (list, b) = added.removeLast();
      list.remove(b);
      open.remove(b);
      added.removeWhere((e) => _inside(b, e.$2));
      _edited();
    });
  }

  bool _inside(StudioBlock c, StudioBlock b) => c.body.any((x) => identical(x, b) || _inside(x, b));

  /// Effacer tout un programme : on demande d'abord (rien ne s'efface d'un geste).
  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Tout effacer ?')),
        content: Text(
          t('Tous les blocs de ce programme partent. Le programme enregistré, lui, reste dans « Mes programmes ».'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Non, garder'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Oui, tout effacer'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      program.clear();
      open.clear();
      added.clear();
      lastRun = null;
      shown = 0;
      _edited();
    });
  }

  Future<void> _run() async {
    final r = runStudio(program);
    setState(() {
      lastRun = r;
      shown = 0;
      running = true;
      _stop = false;
      message = null;
    });
    // Tout le programme en 7 s au plus (une note dure le temps de la jouer).
    final delay = Duration(milliseconds: (7000 ~/ max(1, r.frames.length)).clamp(25, 320));
    for (var i = 0; i < r.frames.length; i++) {
      if (_stop || !mounted) break;
      setState(() => shown = i + 1);
      final note = r.frames[i].note;
      if (note != null) {
        await speech.playWav(noteWav(note));
      } else {
        await Future<void>.delayed(delay);
      }
    }
    if (!mounted) return;
    setState(() {
      running = false;
      if (r.tooLong) {
        message = tf(
          'Le programme est très long : le robot s\'est arrêté au bout de {n} pas. Une boucle tourne-t-elle trop de fois ?',
          {'n': studioMaxActions},
        );
      } else if (_stop) {
        message = t('Programme arrêté.');
      } else if (widget.challenge case final c?) {
        message = sameDrawing(r, model!)
            ? (studioSize(program) <= c.best
                  ? t('Bravo, c\'est le même dessin ! Et ton programme est aussi court que possible.')
                  : tf('Bravo, c\'est le même dessin ! Idée : il peut s\'écrire avec {n} blocs seulement.', {
                      'n': c.best,
                    }))
            : t('Pas encore pareil : compare ton dessin avec les pointillés, puis change un bloc.');
      } else if (r.segments.isEmpty && r.frames.every((f) => f.note == null)) {
        message = t('Le robot a bougé sans dessiner : pose le crayon, ou ajoute « avancer ».');
      }
    });
    final c = widget.challenge;
    if (c != null && !_stop && !r.tooLong && sameDrawing(r, model!)) {
      app.voice.success(app.universe.id);
      await markChallengeDone(app, c.id);
      if (!mounted) return;
    }
    if (message != null) speech.say(message!);
  }

  /// Un seul enregistrement à la fois (deux touchers ouvraient deux fenêtres).
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _saveOnce();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveOnce() async {
    final all = await loadPrograms(app);
    if (!mounted) return;
    final controller = TextEditingController(text: name ?? tf('Mon programme {n}', {'n': all.length + 1}));
    final chosen = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Enregistrer mon programme')),
        content: TextField(
          controller: controller,
          autofocus: false,
          maxLength: 30,
          style: const TextStyle(fontSize: 20),
          decoration: InputDecoration(labelText: t('Son nom')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(t('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: Text(t('Enregistrer'))),
        ],
      ),
    );
    controller.dispose();
    if (chosen == null || !mounted) return;
    final n = chosen.isEmpty ? tf('Mon programme {n}', {'n': all.length + 1}) : chosen;
    final id = savedId ?? DateTime.now().millisecondsSinceEpoch;
    final p = SavedProgram(id, n, DateTime.now(), [for (final b in program) b.copy()]);
    all.removeWhere((x) => x.id == id);
    all.insert(0, p);
    while (all.length > maxSavedPrograms) {
      all.removeLast();
    }
    await storePrograms(app, all);
    if (!mounted) return;
    setState(() {
      savedId = id;
      name = n;
      dirty = false;
      message = tf('« {name} » est enregistré dans « Mes programmes ».', {'name': n});
    });
    speech.say(message!);
  }

  /// En partant avec des changements : garder ou non (une question, deux grands boutons).
  Future<void> _leave() async {
    if (!dirty || program.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Garder ce programme ?')),
        content: Text(t('Il n\'est pas encore enregistré.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Non, partir'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Oui, l\'enregistrer'))),
        ],
      ),
    );
    if (!mounted || keep == null) return;
    if (keep) {
      await _save();
      if (!mounted || dirty) return;
    }
    dirty = false;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    return PopScope(
      canPop: !dirty || program.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: UniverseBackground(
          universe: u,
          child: SafeArea(
            child: Column(
              children: [
                pageHeader(
                  context,
                  name ?? t('Programme libre'),
                  actions: [
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: running || _saving || program.isEmpty ? null : _save,
                        icon: const Icon(Icons.save_rounded, size: 28),
                        label: Text(
                          t('Enregistrer'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, k) {
                      final Widget body;
                      if (k.maxWidth > k.maxHeight * 1.2) {
                        final side = min(k.maxHeight - 24, k.maxWidth * 0.5);
                        body = Row(
                          children: [
                            _stage(u, side),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(child: _programPanel()),
                                  const SizedBox(height: 8),
                                  _palette(),
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        final side = min(k.maxWidth - 24, k.maxHeight * (k.maxWidth >= 600 ? 0.42 : 0.3));
                        body = Column(
                          children: [
                            _stage(u, side, k.maxWidth),
                            const SizedBox(height: 8),
                            Expanded(child: _programPanel()),
                            const SizedBox(height: 8),
                            _palette(),
                          ],
                        );
                      }
                      return Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: body);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La feuille du robot, et sous elle l'état du crayon écrit (ou le message du dernier essai).
  Widget _stage(Universe u, double side, [double? textWidth]) {
    final r = lastRun;
    final frames = r == null ? const <Frame>[] : r.frames.take(shown).toList();
    final turtle = frames.isEmpty ? Turtle.start : frames.last.turtle;
    final m = model;
    // Pendant un défi, le cadre englobe aussi le modèle (il ne bouge pas d'un essai à l'autre).
    final view = m != null ? StudioRun([...m.frames, ...?r?.frames], false).view : r?.view ?? (0.0, 0.0, 12.0);
    final scale = side / view.$3;
    final px = (turtle.x - view.$1) * scale + side / 2, py = (turtle.y - view.$2) * scale + side / 2;
    // Pendant l'essai, la note jouée s'écrit (le son n'est jamais la seule trace).
    final note = running && frames.isNotEmpty ? frames.last.note : null;
    final status =
        message ??
        (note != null
            ? tf('Le robot joue la note {c}', {'c': studioNoteName(note)})
            : turtle.pen
            ? tf('Crayon posé, couleur {c}', {'c': studioColourName(turtle.colour)})
            : t('Crayon levé : le robot avance sans dessiner'));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: side,
          height: side,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow,
            border: Border.all(color: u.onCard, width: 3),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: tf('Dessin du robot : {n} traits', {'n': frames.where((f) => f.segment != null).length}),
                  child: CustomPaint(painter: StudioPainter(frames, view, model: m?.segments.toList())),
                ),
              ),
              Positioned(
                left: px - 24,
                top: py - 24,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Art(u.mascot, size: 32),
                      Transform.rotate(
                        angle: turtle.heading * pi / 180,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Icon(Icons.navigation_rounded, size: 18, color: u.night ? u.primary : u.onCard),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Le message prend toute la largeur en portrait : coupé à la largeur du dessin, « Bravo… » perdait sa fin.
        SizedBox(
          width: textWidth ?? side,
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  List<Widget> _lines(List<StudioBlock> blocks, int depth) => [
    for (final b in blocks) ...[
      Padding(
        padding: EdgeInsets.only(left: depth * 22.0, bottom: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _colour(b.kind),
            borderRadius: BorderRadius.circular(12),
            border: open.contains(b) ? Border.all(color: gold, width: 4) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon(b.kind), color: Colors.white, size: 26),
              const SizedBox(width: 6),
              if (b.kind == StudioKind.colour) ...[
                // La couleur montrée en plus de son nom écrit.
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Color(studioColours[b.n].$2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  studioBlockName(b),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (b.hasValue && !running) ...[
                const SizedBox(width: 4),
                _valueButton(Icons.remove_rounded, t('Moins'), b, -1),
                _valueButton(Icons.add_rounded, t('Plus'), b, 1),
              ],
            ],
          ),
        ),
      ),
      if (b.isContainer) ...[
        ..._lines(b.body, depth + 1),
        if (open.contains(b))
          Padding(
            padding: EdgeInsets.only(left: (depth + 1) * 22.0, bottom: 4),
            child: Text(
              t('… les blocs suivants vont ici'),
              style: const TextStyle(fontSize: 16, color: Color(0xFF4A554E)),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(left: depth * 22.0, bottom: 6),
          child: Text(
            tf('fin de « {name} »', {'name': studioBlockName(b)}),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _colour(b.kind)),
          ),
        ),
      ],
    ],
  ];

  Widget _valueButton(IconData icon, String label, StudioBlock b, int by) {
    final next = b.shifted(by);
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: label,
        onPressed: next == null
            ? null
            : () {
                setState(() {
                  b.n = next;
                  _edited();
                });
                // La note s'entend quand on la change : on choisit à l'oreille.
                if (b.kind == StudioKind.note) speech.playWav(noteWav(next));
              },
        icon: Icon(icon, color: Colors.white, size: 26),
        style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF)),
      ),
    );
  }

  Widget _programPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tf('Blocs : {used} sur {limit}', {'used': studioSize(program), 'limit': studioMaxBlocks}),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
                ),
              ),
              IconButton.filledTonal(
                iconSize: 30,
                tooltip: t('Effacer le dernier bloc'),
                onPressed: running || added.isEmpty ? null : _undo,
                icon: const Icon(Icons.backspace_rounded),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                iconSize: 30,
                tooltip: t('Tout effacer'),
                onPressed: running || program.isEmpty ? null : _clearAll,
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 88,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: running ? const Color(0xFFB91C1C) : green,
                    disabledBackgroundColor: const Color(0xFFBFC7C1),
                  ),
                  onPressed: running ? () => setState(() => _stop = true) : (program.isEmpty ? null : _run),
                  child: Icon(
                    running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    size: 44,
                    color: Colors.white,
                    semanticLabel: running ? t('Arrêter le programme') : t('Lancer le programme'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (program.isEmpty)
                    Text(
                      t(
                        'Touche les blocs en dessous pour écrire le programme. Tout est permis : il n\'y a pas de faute.',
                      ),
                      style: const TextStyle(fontSize: 17),
                    ),
                  ..._lines(program, 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nom court sur la palette (le nom complet s'écrit dans le programme et se dit à l'ajout).
  String _short(StudioKind k) => switch (k) {
    StudioKind.forward => t('avancer'),
    StudioKind.turnLeft => t('à gauche'),
    StudioKind.turnRight => t('à droite'),
    StudioKind.repeat => t('répéter'),
    StudioKind.penUp => t('crayon levé'),
    StudioKind.penDown => t('crayon posé'),
    StudioKind.colour => t('couleur'),
    StudioKind.note => t('note'),
  };

  /// Palette en grille de cases égales : sur une tablette en portrait, un `Wrap` de longs boutons prenait la moitié de
  /// l'écran et cachait le programme (essai du 2026-11-15).
  Widget _palette() => LayoutBuilder(
    builder: (_, k) {
      final cols = (k.maxWidth / 150).floor().clamp(3, 5);
      Widget cell(Widget child) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: SizedBox(height: 52, child: child),
        ),
      );
      Widget label(String s) => FittedBox(fit: BoxFit.scaleDown, child: Text(s));
      const text = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
      final buttons = <Widget>[
        for (final k in StudioKind.values)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _colour(k),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: text,
            ),
            onPressed: running ? null : () => _add(k),
            icon: Icon(_icon(k), size: 24),
            label: label(_short(k)),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            backgroundColor: surface,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: text,
          ),
          onPressed: running || open.isEmpty ? null : () => setState(open.removeLast),
          icon: const Icon(Icons.keyboard_return_rounded, size: 24),
          label: label(t('Fermer le bloc')),
        ),
      ];
      return Column(
        children: [
          for (var r = 0; r < buttons.length; r += cols)
            Row(
              children: [
                for (var c = r; c < r + cols; c++)
                  c < buttons.length ? cell(buttons[c]) : const Expanded(child: SizedBox()),
              ],
            ),
        ],
      );
    },
  );
}

/// Dessine les traits du robot sur un quadrillage léger (une case = un pas, quand les cases restent assez grandes).
class StudioPainter extends CustomPainter {
  StudioPainter(this.frames, this.view, {this.model});
  final List<Frame> frames;
  final (double, double, double) view;

  /// Le dessin modèle d'un défi, en pointillés gris (le trait plein est celui de l'enfant : jamais la couleur seule).
  final List<Segment>? model;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final scale = side / view.$3;
    Offset at(double x, double y) => Offset((x - view.$1) * scale + side / 2, (y - view.$2) * scale + side / 2);
    if (scale >= 14) {
      final grid = Paint()
        ..color = const Color(0xFFE3E8E5)
        ..strokeWidth = 1;
      final x0 = (view.$1 - view.$3 / 2).floor(), y0 = (view.$2 - view.$3 / 2).floor();
      for (var i = 0; i <= view.$3 + 2; i++) {
        final x = at((x0 + i).toDouble(), 0).dx, y = at(0, (y0 + i).toDouble()).dy;
        canvas.drawLine(Offset(x, 0), Offset(x, side), grid);
        canvas.drawLine(Offset(0, y), Offset(side, y), grid);
      }
    }
    if (model case final ms?) {
      final dash = Paint()
        ..color = const Color(0xFF8A958E)
        ..strokeWidth = max(3, scale * 0.22)
        ..strokeCap = StrokeCap.round;
      final on = max(4.0, scale * 0.3);
      for (final s in ms) {
        final a = at(s.x0, s.y0), b = at(s.x1, s.y1);
        final len = (b - a).distance;
        if (len == 0) continue;
        final dir = (b - a) / len;
        for (var d = 0.0; d < len; d += on * 2) {
          canvas.drawLine(a + dir * d, a + dir * min(len, d + on), dash);
        }
      }
    }
    final pen = Paint()
      ..strokeWidth = max(2.5, scale * 0.16)
      ..strokeCap = StrokeCap.round;
    for (final f in frames) {
      final s = f.segment;
      if (s == null) continue;
      pen.color = Color(studioColours[s.colour].$2);
      canvas.drawLine(at(s.x0, s.y0), at(s.x1, s.y1), pen);
    }
  }

  @override
  // Comparer les listes elles-mêmes : une couleur changée garde le même nombre de traits (aperçu resté rouge).
  bool shouldRepaint(StudioPainter old) =>
      !identical(old.frames, frames) || old.frames.length != frames.length || old.view != view || old.model != model;
}

/// « Mes programmes » : des idées pour commencer, puis les programmes enregistrés (aperçu du dessin, nom, date).
class ProgramsPage extends StatefulWidget {
  const ProgramsPage({super.key});
  @override
  State<ProgramsPage> createState() => _ProgramsPageState();
}

class _ProgramsPageState extends State<ProgramsPage> {
  late final AppState app = AppScope.of(context);
  List<SavedProgram>? programs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (programs == null) _load();
  }

  Future<void> _load() async {
    final ps = await loadPrograms(app);
    if (mounted) setState(() => programs = ps);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _load();
  }

  Future<void> _delete(SavedProgram p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tf('Supprimer « {name} » ?', {'name': p.name})),
        content: Text(t('Il ne pourra pas revenir.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('Non, garder'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('Oui, supprimer'))),
        ],
      ),
    );
    if (ok != true) return;
    final all = await loadPrograms(app)
      ..removeWhere((x) => x.id == p.id);
    await storePrograms(app, all);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ps = programs;
    return Scaffold(
      body: UniverseBackground(
        universe: app.universe,
        child: SafeArea(
          child: Column(
            children: [
              pageHeader(context, t('Mes programmes')),
              Expanded(
                child: ListView(
                  padding: readablePadding(context),
                  children: [
                    _section(t('Mes programmes enregistrés')),
                    if (ps != null && ps.isEmpty)
                      _note(t('Pas encore de programme enregistré. Écris-en un, ou ouvre une idée ci-dessous.')),
                    for (final p in ps ?? const <SavedProgram>[]) _savedCard(p),
                    const SizedBox(height: 12),
                    _section(t('Des idées pour commencer')),
                    _note(
                      t(
                        'Ouvre une idée, regarde ce qu\'elle fait, puis change un nombre ou un bloc pour inventer la tienne.',
                      ),
                    ),
                    for (final i in studioIdeas) _ideaCard(i),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String s) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      s,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink),
    ),
  );

  Widget _note(String s) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
    child: Text(s, style: const TextStyle(fontSize: 18, color: ink)),
  );

  Widget _thumb(List<StudioBlock> blocks) {
    final r = runStudio(blocks);
    final notes = r.frames.where((f) => f.note != null).length;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5DBD7)),
      ),
      child: r.segments.isEmpty && notes > 0
          ? const Icon(Icons.music_note_rounded, size: 56, color: Color(0xFF7E22CE))
          : CustomPaint(painter: StudioPainter(r.frames, r.view)),
    );
  }

  Widget _savedCard(SavedProgram p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(StudioPage(saved: p)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _thumb(p.blocks),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                    ),
                    Text(
                      tf('{n} blocs · {date}', {
                        'n': studioSize(p.blocks),
                        'date': '${p.date.day}/${p.date.month}/${p.date.year}',
                      }),
                      style: const TextStyle(fontSize: 17, color: Color(0xFF4A554E)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: IconButton(
                  tooltip: t('Supprimer ce programme'),
                  iconSize: 30,
                  onPressed: () => _delete(p),
                  icon: const Icon(Icons.delete_outline_rounded, color: ink),
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 32, color: ink),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _ideaCard(StudioIdea i) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _open(StudioPage(idea: i)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _thumb(i.build()),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Art(i.art, size: 30),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            t(i.title),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                          ),
                        ),
                      ],
                    ),
                    Text(t(i.text), style: const TextStyle(fontSize: 17, color: Color(0xFF4A554E))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 32, color: ink),
            ],
          ),
        ),
      ),
    ),
  );
}
