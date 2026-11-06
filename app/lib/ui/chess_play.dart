import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_state.dart';
import '../audio/voice.dart';
import '../core/deep_analysis.dart';
import '../core/engine.dart';
import '../core/game.dart';
import '../core/uci.dart';
import '../engines/maia.dart';
import '../engines/stockfish.dart';
import 'adaptive.dart';
import 'theme.dart';
import 'universe.dart';

/// Les échecs en vrai (ADR 0040) : jouer contre le robot (3 niveaux) ou à deux sur la même tablette, chaque partie
/// enregistrée sur l'appareil (par enfant) puis revue coup par coup avec des commentaires : mat manqué, pièce laissée
/// en prise, prise gratuite manquée, bons coups.

/// Une partie enregistrée.
class SavedGame {
  SavedGame({
    required this.date,
    required this.mode,
    required this.level,
    required this.childWhite,
    required this.result,
    required this.moves,
    this.notes,
    this.deep = false,
  });

  final DateTime date;

  /// « robot » ou « deux ».
  final String mode;
  final int level;
  final bool childWhite;
  final String result;
  final List<String> moves;

  /// Commentaires de l'analyse, calculés une fois puis gardés.
  List<MoveNote>? notes;

  /// Stockfish a déjà regardé la partie (ADR 0053) : les parties plus anciennes le seront à leur prochaine ouverture.
  bool deep;

  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(),
        'mode': mode,
        'level': level,
        'white': childWhite,
        'result': result,
        'moves': moves,
        if (notes != null) 'notes': [for (final n in notes!) n.toJson()],
        if (deep) 'deep': true,
      };

  static SavedGame fromJson(Map<String, dynamic> j) => SavedGame(
        date: DateTime.parse(j['date'] as String),
        mode: j['mode'] as String,
        level: j['level'] as int,
        childWhite: j['white'] as bool,
        result: j['result'] as String,
        moves: List<String>.from(j['moves'] as List),
        notes: j['notes'] == null ? null : [for (final n in j['notes'] as List) MoveNote.fromJson(n as Map<String, dynamic>)],
        deep: j['deep'] as bool? ?? false,
      );

  /// Ce que la partie a donné, du point de vue de l'enfant (contre le robot) ou des Blancs (à deux).
  String get outcome {
    if (result == '*') return 'Pas finie';
    if (result == '1/2-1/2') return 'Partie nulle';
    if (mode == 'deux') return result == '1-0' ? 'Les Blancs gagnent' : 'Les Noirs gagnent';
    return (result == '1-0') == childWhite ? 'Gagnée' : 'Perdue';
  }

  String get title => mode == 'robot' ? (isMaia(level) ? 'Contre Maia $level' : 'Contre le robot, niveau $level') : 'À deux';
}

/// Les parties de l'enfant (les 30 dernières), gardées dans ses réglages.
Future<List<SavedGame>> loadGames(AppState app) async {
  final raw = await app.store.get('parties');
  if (raw == null || raw.isEmpty) return [];
  try {
    return [for (final g in jsonDecode(raw) as List) SavedGame.fromJson(g as Map<String, dynamic>)];
  } catch (_) {
    return [];
  }
}

Future<void> saveGames(AppState app, List<SavedGame> games) =>
    app.store.set('parties', jsonEncode([for (final g in games.take(30)) g.toJson()]));

/// Échiquier touchable : cases claires et foncées, coordonnées écrites, pièces SVG. Repères jamais par la couleur
/// seule : case choisie = cadre épais, coups possibles = points (ou anneau sur une pièce à prendre), dernier coup =
/// cadre fin, roi en échec = anneau rouge et « Échec ! » écrit à côté, coup conseillé = cadre doré.
class ChessBoardView extends StatelessWidget {
  const ChessBoardView({
    super.key,
    required this.position,
    this.flipped = false,
    this.selected,
    this.targets = const {},
    this.last,
    this.advice,
    this.onTap,
  });

  final Position position;
  final bool flipped;
  final int? selected;
  final Set<int> targets;
  final Move? last, advice;
  final ValueChanged<int>? onTap;

  static const light = Color(0xFFF0D9B5), dark = Color(0xFFB58863);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, k) {
        final side = min(k.maxWidth, k.maxHeight);
        final cell = side / 8;
        final check = position.inCheck ? position.kingOf(position.whiteToMove) : null;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: const BoxDecoration(boxShadow: cardShadow),
            child: Column(children: [
              for (var row = 0; row < 8; row++)
                Row(children: [
                  for (var col = 0; col < 8; col++) _square(flipped ? row * 8 + (7 - col) : (7 - row) * 8 + col, cell, check),
                ]),
            ]),
          ),
        );
      });

  Widget _square(int s, double cell, int? check) {
    final p = position.board[s];
    final isDark = (s % 8 + s ~/ 8).isEven;
    final ring = advice != null && (advice!.from == s || advice!.to == s);
    final lastHere = last != null && (last!.from == s || last!.to == s);
    Border? border;
    if (ring) {
      border = Border.all(color: gold, width: 5);
    } else if (s == selected) {
      border = Border.all(color: const Color(0xFF1D6FD6), width: 4);
    } else if (lastHere) {
      border = Border.all(color: const Color(0xCC1B211D), width: 2);
    }
    final coordStyle = TextStyle(fontSize: cell * 0.2, fontWeight: FontWeight.w700, color: isDark ? light : dark);
    final bottomRow = flipped ? s ~/ 8 == 7 : s ~/ 8 == 0;
    final leftCol = flipped ? s % 8 == 7 : s % 8 == 0;
    return Semantics(
      label: '${squareName(s)}${p == null ? '' : ', ${pieceName(p)} ${_colour(p)}'}',
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap == null ? null : () => onTap!(s),
        child: Container(
          width: cell,
          height: cell,
          decoration: BoxDecoration(color: isDark ? dark : light, border: border),
          child: Stack(alignment: Alignment.center, children: [
            if (s == check)
              Container(
                width: cell * 0.92,
                height: cell * 0.92,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x55D62828), border: Border.all(color: const Color(0xFFB71C1C), width: 3)),
              ),
            if (p != null)
              SizedBox(
                width: cell * 0.9,
                height: cell * 0.9,
                child: FittedBox(child: SvgPicture.asset('assets/echecs/${isWhitePiece(p) ? p.toLowerCase() : 'b${p.toLowerCase()}'}.svg')),
              ),
            if (targets.contains(s))
              p == null
                  ? Container(width: cell * 0.28, height: cell * 0.28, decoration: const BoxDecoration(color: Color(0x991B211D), shape: BoxShape.circle))
                  : Container(
                      width: cell * 0.95,
                      height: cell * 0.95,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x991B211D), width: 4)),
                    ),
            if (leftCol) Positioned(left: 2, top: 1, child: ExcludeSemantics(child: Text('${s ~/ 8 + 1}', style: coordStyle))),
            if (bottomRow) Positioned(right: 2, bottom: 0, child: ExcludeSemantics(child: Text('abcdefgh'[s % 8], style: coordStyle))),
          ]),
        ),
      ),
    );
  }
}

/// Boutons des pages d'échecs : texte normal (le thème grossit les boutons-réponses des leçons, pas ceux-ci).
final _button = FilledButton.styleFrom(minimumSize: const Size(0, 56), textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700));

/// « blanc », « blanche », « noir », « noire » : accordé avec la pièce (la tour, la dame).
String _colour(String p) {
  final fem = 'RQ'.contains(p.toUpperCase());
  return isWhitePiece(p) ? (fem ? 'blanche' : 'blanc') : (fem ? 'noire' : 'noir');
}

/// Barre du haut des pages d'échecs : ← retour et un titre.
Widget pageHeader(BuildContext context, String title, {List<Widget> actions = const []}) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(children: [
        Material(
          color: surface,
          shape: const CircleBorder(),
          elevation: 2,
          child: IconButton(tooltip: 'Retour', iconSize: 32, onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: ink)),
        ),
        const SizedBox(width: 12),
        Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PlayfulTitle(title))),
        ...actions,
      ]),
    );

/// Paysage (ADR 0052) : l'échiquier aussi grand que possible, le panneau de texte et de boutons juste à côté, le tout
/// centré dans la place disponible.
Widget boardBeside({required Widget board, required Widget panel, required double panelWidth}) => LayoutBuilder(builder: (_, a) {
      final side = max(160.0, min(a.maxHeight - 24, a.maxWidth - panelWidth - 28));
      return Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: side, height: side, child: board),
          const SizedBox(width: 16),
          SizedBox(width: panelWidth, height: a.maxHeight, child: panel),
        ]),
      );
    });

/// Choisir le niveau et la couleur, puis jouer contre le robot.
Future<void> chooseRobotGame(BuildContext context) async {
  var level = 1;
  var color = 'blancs';
  // Maia (ADR 0051) n'est proposé que si le programme est dans l'app (arm64).
  final maia = await Maia.available();
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Contre le robot'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Niveau', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: 1, label: Text('1')),
              ButtonSegment(value: 2, label: Text('2')),
              ButtonSegment(value: 3, label: Text('3')),
            ],
            selected: isMaia(level) ? <int>{} : {level},
            onSelectionChanged: (v) => set(() => level = v.isEmpty ? level : v.first),
          ),
          if (maia) ...[
            const SizedBox(height: 12),
            const Text('Ou un robot qui joue comme les humains', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              emptySelectionAllowed: true,
              segments: [for (final r in maiaRatings) ButtonSegment(value: r, label: Text('Maia $r'))],
              selected: isMaia(level) ? {level} : <int>{},
              onSelectionChanged: (v) => set(() => level = v.isEmpty ? level : v.first),
            ),
          ],
          const SizedBox(height: 4),
          Text(isMaia(level)
              ? 'Maia $level a appris sur des parties de joueurs de $level points (classement Lichess) : il joue et se trompe comme eux.'
              : const {1: 'Facile : le robot se trompe souvent.', 2: 'Moyen.', 3: 'Fort : le robot ne laisse rien en prise.'}[level]!),
          const SizedBox(height: 16),
          const Text('Je joue avec', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'blancs', label: Text('les Blancs')),
              ButtonSegment(value: 'noirs', label: Text('les Noirs')),
            ],
            selected: {color},
            onSelectionChanged: (v) => set(() => color = v.first),
          ),
          const SizedBox(height: 8),
          const Text('Les Blancs jouent en premier.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(style: _button, onPressed: () => Navigator.pop(ctx, true), child: const Text('Jouer')),
        ],
      ),
    ),
  );
  if (go == true && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GamePage(mode: 'robot', level: level, childWhite: color == 'blancs')));
  }
}

/// Une partie, contre le robot ou à deux.
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.mode, required this.level, required this.childWhite});
  final String mode;
  final int level;
  final bool childWhite;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final AppState app = AppScope.of(context);
  final game = Game();

  /// Maia, quand on joue contre lui (ADR 0051) ; coupé quand on quitte la partie.
  Maia? _maia;
  bool _maiaFailed = false;

  /// La parole de la partie : coupée quand on la quitte.
  late final Speech speech = app.voice.scope();
  int? selected;
  bool thinking = false, hints = true, flipped = false, _saved = false;
  String? message;

  bool get robot => widget.mode == 'robot';
  bool get childTurn => !robot || game.position.whiteToMove == widget.childWhite;

  @override
  void initState() {
    super.initState();
    flipped = robot && !widget.childWhite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      speech.say(robot ? 'C\'est parti ! Les Blancs commencent.' : 'Partie à deux. Les Blancs commencent.');
      if (!childTurn) _robotPlays();
    });
  }

  @override
  void dispose() {
    speech.close();
    _maia?.dispose();
    if (!_saved && game.moves.length >= 2) _save();
    super.dispose();
  }

  Future<SavedGame> _save() async {
    _saved = true;
    final g = SavedGame(
      date: DateTime.now(),
      mode: widget.mode,
      level: widget.level,
      childWhite: widget.childWhite,
      result: game.result,
      moves: [for (final m in game.moves) m.uci],
    );
    final all = await loadGames(app);
    await saveGames(app, [g, ...all]);
    return g;
  }

  String get status {
    if (message != null) return message!;
    final end = game.end;
    if (end != null) return _endText(end);
    final side = game.position.whiteToMove ? 'les Blancs' : 'les Noirs';
    if (thinking) return 'Le robot réfléchit…';
    final check = game.position.inCheck ? 'Échec ! Protège ton roi. ' : '';
    return robot ? '$checkÀ toi de jouer.' : '$checkÀ $side de jouer.';
  }

  String _endText(GameEnd e) => switch (e) {
        GameEnd.checkmate => robot
            ? (game.result == (widget.childWhite ? '1-0' : '0-1') ? 'Échec et mat : tu as gagné, bravo !' : 'Échec et mat : le robot a gagné. Revois la partie pour comprendre.')
            : 'Échec et mat : ${game.result == '1-0' ? 'les Blancs' : 'les Noirs'} gagnent !',
        GameEnd.stalemate => 'Pat : le roi n\'est pas en échec mais ne peut plus bouger. Partie nulle.',
        GameEnd.insufficient => 'Plus assez de pièces pour faire mat. Partie nulle.',
        GameEnd.fiftyMoves => '50 coups sans prise ni pion avancé. Partie nulle.',
        GameEnd.repetition => 'La même position trois fois. Partie nulle.',
      };

  Future<void> _tap(int s) async {
    if (thinking || game.end != null || !childTurn) return;
    final p = game.position;
    final piece = p.board[s];
    if (piece != null && isWhitePiece(piece) == p.whiteToMove) {
      setState(() {
        selected = s;
        message = null;
      });
      return;
    }
    final from = selected;
    if (from == null) return;
    final candidates = [for (final m in p.legalMoves()) if (m.from == from && m.to == s) m];
    if (candidates.isEmpty) {
      setState(() => message = _whyNot(p, from, s));
      speech.say(message!);
      return;
    }
    var move = candidates.first;
    if (candidates.length > 1) {
      // Promotion (art. 3.7.5) : l'enfant choisit la pièce.
      final promo = await _choosePromotion(p.whiteToMove);
      if (promo == null) return;
      move = candidates.firstWhere((m) => m.promo == promo);
    }
    await _play(move);
    if (robot && game.end == null) await _robotPlays();
  }

  /// Pourquoi ce coup n'est pas permis, dit simplement.
  String _whyNot(Position p, int from, int to) {
    final piece = p.board[from]!;
    if (p.followsPieceRules(from, to)) {
      // La pièce peut aller là, mais son propre roi resterait (ou serait) en échec.
      return p.inCheck ? 'Ton roi est en échec : ce coup ne le protège pas.' : 'Interdit : ton roi serait en échec.';
    }
    final name = pieceName(piece);
    return '${name[0].toUpperCase()}${name.substring(1)} ne va pas là. Les points montrent où cette pièce peut aller.';
  }

  Future<String?> _choosePromotion(bool white) => showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ton pion devient…'),
          content: Wrap(spacing: 8, children: [
            for (final (k, name) in [('q', 'une dame'), ('r', 'une tour'), ('b', 'un fou'), ('n', 'un cavalier')])
              Semantics(
                button: true,
                label: name,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, k),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 64, height: 64, child: FittedBox(child: SvgPicture.asset('assets/echecs/${white ? k : 'b$k'}.svg'))),
                    Text(name),
                  ]),
                ),
              ),
          ]),
        ),
      );

  Future<void> _play(Move m) async {
    final san = game.position.san(m);
    setState(() {
      game.play(m);
      selected = null;
      message = null;
    });
    final end = game.end;
    if (end != null) {
      await speech.say(_endText(end));
      final saved = await _save();
      if (mounted) _endDialog(saved);
    } else if (san.endsWith('+')) {
      speech.say('Échec !');
    }
  }

  Future<void> _robotPlays() async {
    setState(() => thinking = true);
    final started = DateTime.now();
    final fen = game.position.fen;
    final seed = DateTime.now().millisecondsSinceEpoch;
    String? maiaMove;
    if (isMaia(widget.level) && !_maiaFailed) {
      _maia ??= await Maia.start(widget.level);
      if (_maia == null) _maiaFailed = true;
      final move = await _maia?.bestMove(fen);
      // Un coup qui n'est pas permis ne doit jamais arriver sur l'échiquier : le robot de l'app joue à la place.
      if (move != null && game.position.legalMoves().any((m) => m.uci == move)) maiaMove = move;
    }
    // (Type écrit : sous « ?? », Dart déduirait un type qui accepte null.)
    final String uci = maiaMove ?? await compute<(String, int, int), String>(robotMove, (fen, isMaia(widget.level) ? 3 : widget.level, seed));
    // Un petit temps pour voir le coup arriver, même quand le robot calcule très vite.
    final wait = const Duration(milliseconds: 700) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    setState(() => thinking = false);
    await _play(Move.parse(uci));
  }

  void _undo() {
    if (thinking || game.moves.isEmpty) return;
    setState(() {
      game.undo();
      // Contre le robot : on reprend aussi sa réponse, pour revenir à son propre coup.
      if (robot && !childTurn && game.moves.isNotEmpty) game.undo();
      selected = null;
      message = null;
    });
  }

  void _endDialog(SavedGame saved) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(saved.outcome),
          content: Text(status),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ReviewPage(game: saved)));
              },
              child: const Text('Revoir la partie'),
            ),
            FilledButton(
              style: _button,
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => GamePage(mode: widget.mode, level: widget.level, childWhite: widget.childWhite)));
              },
              child: const Text('Nouvelle partie'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final p = game.position;
    final targets = hints && selected != null ? {for (final m in p.legalMoves()) if (m.from == selected) m.to} : <int>{};
    final statusCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), boxShadow: cardShadow),
      child: Row(children: [
        if (thinking) const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 4)) else Art(p.whiteToMove ? '26aa' : '26ab', size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(status, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink, height: 1.2))),
      ]),
    );
    final board = ChessBoardView(
      position: p,
      flipped: flipped,
      selected: selected,
      targets: targets,
      last: game.moves.isEmpty ? null : game.moves.last,
      onTap: _tap,
    );
    final controls = Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
      FilledButton.tonalIcon(
        style: _button,
        onPressed: game.moves.isEmpty || thinking || game.end != null ? null : _undo,
        icon: const Icon(Icons.undo_rounded),
        label: Text(robot ? 'Reprendre mon coup' : 'Reprendre le coup'),
      ),
      FilterChip(
        avatar: const Icon(Icons.lightbulb_outline_rounded),
        label: const Text('Coups possibles'),
        selected: hints,
        onSelected: (v) => setState(() => hints = v),
      ),
      if (!robot)
        IconButton.filledTonal(
          tooltip: 'Tourner l\'échiquier',
          iconSize: 32,
          onPressed: () => setState(() => flipped = !flipped),
          icon: const Icon(Icons.screen_rotation_alt_rounded),
        ),
    ]);
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, k) {
            final header = pageHeader(context, robot ? (isMaia(widget.level) ? 'Maia ${widget.level}' : 'Robot · niveau ${widget.level}') : 'À deux');
            // Paysage (ADR 0052) : l'échiquier prend toute la hauteur, le texte et les boutons sont dans une colonne à
            // côté ; en une seule colonne, il restait un petit échiquier à côté de grandes écritures.
            if (isLandscape(k.biggest)) {
              return Column(children: [
                header,
                Expanded(
                  child: boardBeside(
                    board: board,
                    panelWidth: sidePanelWidth(k.maxWidth),
                    panel: Center(
                      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [statusCard, const SizedBox(height: 16), controls])),
                    ),
                  ),
                ),
              ]);
            }
            return Column(children: [
              header,
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: statusCard),
              Expanded(child: Padding(padding: const EdgeInsets.all(12), child: board)),
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: controls),
            ]);
          }),
        ),
      ),
    );
  }
}

/// « Mes parties » : la liste, de la plus récente à la plus ancienne.
class GamesPage extends StatefulWidget {
  const GamesPage({super.key});
  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> {
  late final AppState app = AppScope.of(context);
  late Future<List<SavedGame>> games = loadGames(app);

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            pageHeader(context, 'Mes parties'),
            Expanded(
              child: FutureBuilder<List<SavedGame>>(
                future: games,
                builder: (_, snap) {
                  final list = snap.data ?? const <SavedGame>[];
                  if (snap.hasData && list.isEmpty) {
                    return const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Pas encore de partie. Joue contre le robot ou à deux !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  }
                  return ListView(padding: const EdgeInsets.all(16), children: [
                    for (final (i, g) in list.indexed)
                      Card(
                        child: ListTile(
                          minTileHeight: 72,
                          leading: Art(g.outcome == 'Gagnée' ? '1f3c6' : g.outcome == 'Perdue' ? '1f4aa' : '265f', size: 44),
                          title: Text('${g.title} · ${g.outcome}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          subtitle: Text('${g.date.day}/${g.date.month}/${g.date.year} · ${(g.moves.length + 1) ~/ 2} coup${(g.moves.length + 1) ~/ 2 > 1 ? 's' : ''}'),
                          trailing: const Icon(Icons.play_arrow_rounded, size: 36),
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewPage(game: g, index: i)));
                            setState(() => games = loadGames(app));
                          },
                        ),
                      ),
                  ]);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Revoir une partie : avancer et reculer coup par coup ; sous l'échiquier, le commentaire du coup (s'il y en a un)
/// et le coup conseillé encadré d'or. En haut, le bilan : bons coups, mats manqués, pièces laissées en prise.
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key, required this.game, this.index});
  final SavedGame game;

  /// Rang dans la liste enregistrée (pour y garder l'analyse) ; null : c'est la plus récente.
  final int? index;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late final AppState app = AppScope.of(context);
  late final positions = () {
    final out = [Position.start()];
    for (final m in widget.game.moves) {
      out.add(out.last.play(Move.parse(m)));
    }
    return out;
  }();
  int ply = 0;
  List<MoveNote>? notes;

  bool get _analysedSide => widget.game.mode == 'deux' ? true : widget.game.childWhite;

  /// La part de l'analyse fine déjà faite (0 à 1) ; null quand Stockfish ne travaille pas.
  double? _deepDone;
  Stockfish? _stockfish;

  @override
  void initState() {
    super.initState();
    notes = widget.game.notes;
    _analyse();
  }

  @override
  void dispose() {
    _stockfish?.dispose();
    super.dispose();
  }

  Future<void> _analyse() async {
    var base = notes;
    if (base == null) {
      final raw = await compute(analyseGame, (startFen, widget.game.moves, _analysedSide));
      base = [for (final j in raw) MoveNote.fromJson(j)];
      if (!mounted) return;
      setState(() => notes = base);
      widget.game.notes = base;
      await _keep();
    }
    if (widget.game.deep || !mounted) return;
    // Les commentaires de base sont déjà là : l'enfant lit la partie pendant que Stockfish travaille.
    final engine = await Stockfish.start();
    if (engine == null) return;
    if (!mounted) {
      engine.dispose();
      return;
    }
    _stockfish = engine;
    setState(() => _deepDone = 0);
    try {
      final fine = await deepAnalyse(
        fen: startFen,
        moves: widget.game.moves,
        white: _analysedSide,
        base: base,
        search: engine.search,
        cancelled: () => !mounted,
        onProgress: (d) {
          if (mounted) setState(() => _deepDone = d);
        },
      );
      if (!mounted) return;
      setState(() {
        notes = fine;
        _deepDone = null;
      });
      widget.game
        ..notes = fine
        ..deep = true;
      await _keep();
    } catch (e) {
      // Le moteur a calé : les commentaires de base restent, on réessaiera à la prochaine ouverture.
      debugPrint('Analyse fine interrompue : $e');
      if (mounted) setState(() => _deepDone = null);
    } finally {
      // Fini ou non, le moteur s'arrête tout de suite : il ne doit pas occuper la mémoire pendant que l'enfant lit.
      _stockfish?.dispose();
      _stockfish = null;
    }
  }

  /// Gardée avec la partie : pas besoin de recalculer la prochaine fois.
  Future<void> _keep() async {
    final all = await loadGames(app);
    final i = widget.index ?? 0;
    if (i < all.length && all[i].date == widget.game.date) {
      all[i] = widget.game;
      await saveGames(app, all);
    }
  }

  MoveNote? get _note => ply == 0 ? null : notes?.where((n) => n.ply == ply - 1).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final g = widget.game;
    final note = _note;
    final advice = note?.better == null ? null : Move.parse(note!.better!);
    final shown = advice != null ? positions[ply - 1] : positions[ply];
    int n(String k) => notes?.where((x) => x.kind == k).length ?? 0;
    String plural(int c, String one, String many) => '$c ${c > 1 ? many : one}';
    // Seul ce qui a eu lieu est dit : une liste de zéros n'apprend rien à un enfant, et prend la place de l'échiquier.
    final said = [
      if (n('mat') + n('bien') > 0) plural(n('mat') + n('bien'), 'bon coup', 'bons coups'),
      if (n('mat_manque') > 0) plural(n('mat_manque'), 'mat manqué', 'mats manqués'),
      if (n('mat_permis') > 0) plural(n('mat_permis'), 'mat permis', 'mats permis'),
      if (n('gaffe') > 0) plural(n('gaffe'), 'matériel perdu', 'matériels perdus'),
      if (n('prise_manquee') > 0) plural(n('prise_manquee'), 'prise manquée', 'prises manquées'),
      if (n('fort') > 0) plural(n('fort'), 'coup plus fort à voir', 'coups plus forts à voir'),
    ];
    final summary = notes == null ? 'J\'analyse la partie…' : (said.isEmpty ? 'Rien à signaler.' : said.join(' · '));
    final summaryText = Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Text(summary, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: u.onBackground)),
    if (_deepDone != null) ...[
      const SizedBox(height: 4),
      Text('Je regarde la partie de plus près… ${(_deepDone! * 100).round()} %', style: TextStyle(fontSize: 16, color: u.onBackground)),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: _deepDone),
    ],
  ]),
);
    final board = ChessBoardView(
    position: shown,
    flipped: !_analysedSide,
    last: advice == null && ply > 0 ? Move.parse(g.moves[ply - 1]) : null,
    advice: advice,
  );
    final noteCard = Container(
  margin: const EdgeInsets.symmetric(horizontal: 16),
  padding: const EdgeInsets.all(12),
  width: double.infinity,
  decoration: BoxDecoration(
    color: note == null ? surface : (note.kind == 'bien' || note.kind == 'mat' ? const Color(0xFFEAF5EC) : const Color(0xFFFFF4DE)),
    borderRadius: BorderRadius.circular(20),
    boxShadow: cardShadow,
  ),
  child: Text(
    ply == 0
        ? 'Touche ▶ pour avancer coup par coup.'
        : 'Coup ${(ply + 1) ~/ 2}${ply.isOdd ? '' : '…'} ${positions[ply - 1].san(Move.parse(g.moves[ply - 1]))}'
            '${note == null ? '' : '\n${note.text}'}',
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink, height: 1.25),
  ),
);
    final controls = Padding(
  padding: const EdgeInsets.all(12),
  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    IconButton.filledTonal(tooltip: 'Début', iconSize: 36, onPressed: ply == 0 ? null : () => setState(() => ply = 0), icon: const Icon(Icons.first_page_rounded)),
    const SizedBox(width: 8),
    IconButton.filled(tooltip: 'Coup précédent', iconSize: 44, onPressed: ply == 0 ? null : () => setState(() => ply--), icon: const Icon(Icons.chevron_left_rounded)),
    const SizedBox(width: 8),
    IconButton.filled(
      tooltip: 'Coup suivant',
      iconSize: 44,
      onPressed: ply >= g.moves.length ? null : () => setState(() => ply++),
      icon: const Icon(Icons.chevron_right_rounded),
    ),
    const SizedBox(width: 8),
    IconButton.filledTonal(
      tooltip: 'Prochain conseil',
      iconSize: 36,
      onPressed: notes == null
          ? null
          : () {
              final next = notes!.where((n) => n.ply + 1 > ply).firstOrNull;
              if (next != null) setState(() => ply = next.ply + 1);
            },
      icon: const Icon(Icons.tips_and_updates_rounded),
    ),
  ]),
);
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, k) {
            final header = pageHeader(context, '${g.title} · ${g.outcome}');
            // Paysage (ADR 0052) : l'échiquier à gauche en grand ; le résumé, le conseil et les boutons à droite.
            if (isLandscape(k.biggest)) {
              return Column(children: [
                header,
                Expanded(
                  child: boardBeside(
                    board: board,
                    panelWidth: sidePanelWidth(k.maxWidth),
                    panel: Center(
                      child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [summaryText, const SizedBox(height: 8), noteCard, controls]),
                      ),
                    ),
                  ),
                ),
              ]);
            }
            return Column(children: [
              header,
              summaryText,
              Expanded(child: Padding(padding: const EdgeInsets.all(12), child: board)),
              noteCard,
              controls,
            ]);
          }),
        ),
      ),
    );
  }
}
