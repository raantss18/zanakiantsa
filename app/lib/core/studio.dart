/// Programmes libres (ADR 0076) : l'enfant écrit ce qu'il veut avec des blocs, sans parcours ni bonne réponse. Le robot
/// dessine en avançant (crayon posé ou levé, six couleurs nommées), tourne d'un angle choisi, répète, et joue des notes.
/// Repères : la fiche éduscol « Programmer » (cycles 3 et 4) demande de « programmer des déplacements » et des
/// « séquences d'instructions » avec des « boucles » (https://eduscol.education.fr/document/14773/download). L'idée du
/// robot qui dessine vient de la tortue de Logo (Papert, 1980) ; les blocs emboîtés, de Scratch. Aucun code ni dessin
/// repris (CLAUDE.md règle 7).
library;

import 'dart:convert';
import 'dart:math';

enum StudioKind { forward, turnLeft, turnRight, repeat, penUp, penDown, colour, note }

/// Angles proposés (degrés) : le quart de tour d'abord, puis ceux des polygones et des étoiles.
const studioAngles = [15, 30, 45, 60, 72, 90, 120, 135, 144, 180];

/// Couleurs du crayon : nom écrit (jamais la couleur seule) et valeur ARGB.
const studioColours = [
  ('noir', 0xFF1B211D),
  ('rouge', 0xFFDC2626),
  ('orange', 0xFFEA580C),
  ('vert', 0xFF15803D),
  ('bleu', 0xFF1D4ED8),
  ('violet', 0xFF7E22CE),
];

/// Notes : la gamme de do majeur, du do au do aigu.
const studioNotes = ['do', 'ré', 'mi', 'fa', 'sol', 'la', 'si', 'do aigu'];

/// Au-delà, le programme est arrêté (une boucle dans une boucle grossit vite).
const studioMaxActions = 600;

/// Place dans un programme (blocs du dedans compris).
const studioMaxBlocks = 60;

/// Boucles l'une dans l'autre, au plus (au-delà, l'enfant ne s'y retrouve plus et la ligne déborde du téléphone).
const studioMaxDepth = 4;

/// Tours de boucle, au plus, même vides : 20 « répéter » vides emboîtés faisaient 4^20 tours et figeaient l'app.
const studioMaxLoops = 5000;

/// Un bloc. [n] : nombre de pas (avancer), angle (tourner), nombre de tours (répéter), couleur ou note (indice).
class StudioBlock {
  StudioBlock(this.kind, {int? n, List<StudioBlock>? body}) : n = n ?? defaultN(kind), body = body ?? [];
  final StudioKind kind;
  int n;
  final List<StudioBlock> body;

  bool get isContainer => kind == StudioKind.repeat;

  int get size => 1 + body.fold(0, (s, b) => s + b.size);

  static int defaultN(StudioKind k) => switch (k) {
    StudioKind.forward => 3,
    StudioKind.turnLeft || StudioKind.turnRight => 90,
    StudioKind.repeat => 4,
    StudioKind.colour => 1,
    _ => 0,
  };

  /// Les valeurs possibles de [n], dans l'ordre des boutons − et +.
  List<int> get choices => switch (kind) {
    StudioKind.forward => [for (var i = 1; i <= 9; i++) i],
    StudioKind.turnLeft || StudioKind.turnRight => studioAngles,
    StudioKind.repeat => [for (var i = 2; i <= 12; i++) i],
    StudioKind.colour => [for (var i = 0; i < studioColours.length; i++) i],
    StudioKind.note => [for (var i = 0; i < studioNotes.length; i++) i],
    _ => const [],
  };

  bool get hasValue => choices.isNotEmpty;

  /// Valeur précédente ou suivante (null au bout).
  int? shifted(int by) {
    final i = choices.indexOf(n) + by;
    return i >= 0 && i < choices.length ? choices[i] : null;
  }

  StudioBlock copy() => StudioBlock(kind, n: n, body: [for (final b in body) b.copy()]);

  Map<String, Object> toJson() => {
    'k': kind.name,
    'n': n,
    if (body.isNotEmpty) 'b': [for (final b in body) b.toJson()],
  };

  /// Lecture prudente : un bloc inconnu est sauté, une valeur hors liste revient à la valeur par défaut.
  static StudioBlock? fromJson(Object? j, [int depth = 0]) {
    if (j is! Map || depth > 8) return null;
    final kind = StudioKind.values.where((k) => k.name == j['k']).firstOrNull;
    if (kind == null) return null;
    final b = StudioBlock(
      kind,
      body: [
        if (kind == StudioKind.repeat && j['b'] is List)
          for (final c in j['b'] as List) ?fromJson(c, depth + 1),
      ],
    );
    final n = j['n'];
    if (n is int && b.choices.contains(n)) b.n = n;
    return b;
  }
}

int studioSize(List<StudioBlock> p) => p.fold(0, (s, b) => s + b.size);

/// Le robot : position (en pas), cap en degrés (0 = vers le haut, sens des aiguilles d'une montre), crayon, couleur.
class Turtle {
  const Turtle(this.x, this.y, this.heading, this.pen, this.colour);
  static const start = Turtle(0, 0, 0, true, 1);
  final double x, y, heading;
  final bool pen;
  final int colour;

  Turtle copyWith({double? x, double? y, double? heading, bool? pen, int? colour}) =>
      Turtle(x ?? this.x, y ?? this.y, heading ?? this.heading, pen ?? this.pen, colour ?? this.colour);
}

/// Un trait dessiné.
class Segment {
  const Segment(this.x0, this.y0, this.x1, this.y1, this.colour);
  final double x0, y0, x1, y1;
  final int colour;
}

/// Un pas du programme : l'état du robot après, le trait tracé (ou null), la note jouée (ou null).
class Frame {
  const Frame(this.turtle, {this.segment, this.note});
  final Turtle turtle;
  final Segment? segment;
  final int? note;
}

class StudioRun {
  StudioRun(this.frames, this.tooLong);
  final List<Frame> frames;
  final bool tooLong;

  Iterable<Segment> get segments => frames.map((f) => f.segment).nonNulls;

  /// Le cadre à montrer : tout ce que le robot a parcouru, au moins 12 pas de côté, centré, avec une marge.
  (double, double, double) get view {
    var x0 = 0.0, x1 = 0.0, y0 = 0.0, y1 = 0.0;
    for (final f in frames) {
      x0 = min(x0, f.turtle.x);
      x1 = max(x1, f.turtle.x);
      y0 = min(y0, f.turtle.y);
      y1 = max(y1, f.turtle.y);
    }
    final span = max(12.0, max(x1 - x0, y1 - y0) + 2);
    return ((x0 + x1) / 2, (y0 + y1) / 2, span);
  }
}

/// Exécute un programme libre (rien n'arrête le robot, sauf un programme trop long).
StudioRun runStudio(List<StudioBlock> program) {
  final frames = <Frame>[];
  var t = Turtle.start;
  var tooLong = false;
  var loops = 0;

  bool run(List<StudioBlock> blocks) {
    for (final b in blocks) {
      if (b.kind == StudioKind.repeat) {
        for (var i = 0; i < b.n; i++) {
          if (++loops > studioMaxLoops) {
            tooLong = true;
            return false;
          }
          if (!run(b.body)) return false;
        }
        continue;
      }
      if (frames.length >= studioMaxActions) {
        tooLong = true;
        return false;
      }
      switch (b.kind) {
        case StudioKind.forward:
          final a = t.heading * pi / 180;
          // Arrondi : après des virages de 60° ou 72°, les sommets retombent exactement au même endroit.
          double r(double v) => (v * 1e6).roundToDouble() / 1e6;
          final next = t.copyWith(x: r(t.x + b.n * sin(a)), y: r(t.y - b.n * cos(a)));
          frames.add(Frame(next, segment: t.pen ? Segment(t.x, t.y, next.x, next.y, t.colour) : null));
          t = next;
        case StudioKind.turnLeft || StudioKind.turnRight:
          final d = b.kind == StudioKind.turnLeft ? -b.n : b.n;
          t = t.copyWith(heading: (t.heading + d) % 360);
          frames.add(Frame(t));
        case StudioKind.penUp || StudioKind.penDown:
          t = t.copyWith(pen: b.kind == StudioKind.penDown);
          frames.add(Frame(t));
        case StudioKind.colour:
          t = t.copyWith(colour: b.n);
          frames.add(Frame(t));
        case StudioKind.note:
          frames.add(Frame(t, note: b.n));
        case StudioKind.repeat:
          break;
      }
    }
    return true;
  }

  run(program);
  return StudioRun(frames, tooLong);
}

/// Un programme enregistré : son nom, sa date, ses blocs.
class SavedProgram {
  SavedProgram(this.id, this.name, this.date, this.blocks);
  final int id;
  final String name;
  final DateTime date;
  final List<StudioBlock> blocks;

  Map<String, Object> toJson() => {
    'id': id,
    'nom': name,
    'date': date.millisecondsSinceEpoch,
    'blocs': [for (final b in blocks) b.toJson()],
  };

  static SavedProgram? fromJson(Object? j) {
    if (j is! Map || j['id'] is! int || j['nom'] is! String || j['date'] is! int || j['blocs'] is! List) return null;
    final date = j['date'] as int;
    // Une date hors des bornes de DateTime ferait planter toute la liste (relecture du 2026-11-15).
    if (date.abs() > 8640000000000000) return null;
    return SavedProgram(j['id'] as int, j['nom'] as String, DateTime.fromMillisecondsSinceEpoch(date), [
      for (final b in j['blocs'] as List) ?StudioBlock.fromJson(b),
    ]);
  }
}

/// Au plus 40 programmes gardés par enfant (le plus ancien part).
const maxSavedPrograms = 40;

List<SavedProgram> decodePrograms(String? s) {
  if (s == null) return [];
  try {
    final j = jsonDecode(s);
    return j is List ? [for (final p in j) ?SavedProgram.fromJson(p)] : [];
  } on FormatException {
    return [];
  }
}

String encodePrograms(List<SavedProgram> ps) => jsonEncode([for (final p in ps) p.toJson()]);

/// Des idées pour commencer : un programme à ouvrir, regarder, puis changer. Titre et phrase en français (clés de t()).
class StudioIdea {
  const StudioIdea(this.art, this.title, this.text, this.build);
  final String art, title, text;
  final List<StudioBlock> Function() build;
}

StudioBlock _f(int n) => StudioBlock(StudioKind.forward, n: n);
StudioBlock _r(int a) => StudioBlock(StudioKind.turnRight, n: a);
StudioBlock _l(int a) => StudioBlock(StudioKind.turnLeft, n: a);
StudioBlock _rep(int n, List<StudioBlock> body) => StudioBlock(StudioKind.repeat, n: n, body: body);
StudioBlock _c(int i) => StudioBlock(StudioKind.colour, n: i);
StudioBlock _note(int i) => StudioBlock(StudioKind.note, n: i);

final studioIdeas = [
  StudioIdea(
    '1f4d0',
    'Un carré',
    'Quatre fois : avancer, tourner d\'un quart de tour.',
    () => [
      _rep(4, [_f(5), _r(90)]),
    ],
  ),
  StudioIdea(
    '1f3c1',
    'Un escalier',
    'Monter une marche, puis encore, et encore.',
    () => [
      _c(2),
      _rep(4, [_f(2), _r(90), _f(2), _l(90)]),
    ],
  ),
  StudioIdea(
    '2b50',
    'Une étoile',
    'Cinq branches : tourner de 144° à chaque pointe.',
    () => [
      _c(2),
      _rep(5, [_f(8), _r(144)]),
    ],
  ),
  StudioIdea(
    '1f4a0',
    'Un hexagone',
    'Six côtés, six virages de 60° : un tour complet.',
    () => [
      _c(4),
      _rep(6, [_f(4), _r(60)]),
    ],
  ),
  StudioIdea(
    '1f33c',
    'Une fleur',
    'Un carré, tourner un peu, et recommencer : une boucle dans une boucle.',
    () => [
      _c(5),
      _rep(12, [
        _rep(4, [_f(4), _r(90)]),
        _r(30),
      ]),
    ],
  ),
  StudioIdea(
    '1f3b5',
    'Frère Jacques',
    'Le début de la chanson, note après note. Change les notes pour en faire une autre.',
    () => [
      _rep(2, [_note(0), _note(1), _note(2), _note(0)]),
      _rep(2, [_note(2), _note(3), _note(4)]),
    ],
  ),
  StudioIdea(
    '1f483',
    'La danse du robot',
    'Il avance, tourne et chante à chaque coin.',
    () => [
      _rep(4, [_f(4), _note(4), _r(90), _note(7)]),
    ],
  ),
];

/// Défis du robot (ADR 0077) : un dessin modèle, l'enfant écrit le programme qui le refait. Le dessin compte, pas le
/// chemin : avancer de 4 ou deux fois de 2, dans un sens ou dans l'autre, c'est pareil ; la couleur ne compte pas.
/// [best] : le nombre de blocs de la solution la plus courte connue (montré après la réussite, jamais imposé).
class StudioChallenge {
  const StudioChallenge(this.id, this.art, this.title, this.text, this.model, this.best);
  final String id, art, title, text;
  final List<StudioBlock> Function() model;
  final int best;
}

/// Les points d'un dessin, un tous les quarts de pas le long de chaque trait, rangés dans une grille de 0,1 pas.
Set<(int, int)> _drawingPoints(Iterable<Segment> segments) {
  final pts = <(int, int)>{};
  for (final s in segments) {
    final len = sqrt(pow(s.x1 - s.x0, 2) + pow(s.y1 - s.y0, 2));
    final steps = max(1, (len * 4).round());
    for (var i = 0; i <= steps; i++) {
      final x = s.x0 + (s.x1 - s.x0) * i / steps, y = s.y0 + (s.y1 - s.y0) * i / steps;
      pts.add(((x * 10).round(), (y * 10).round()));
    }
  }
  return pts;
}

bool _covers(Set<(int, int)> a, Set<(int, int)> b) {
  for (final (x, y) in a) {
    var near = false;
    for (var dx = -1; dx <= 1 && !near; dx++) {
      for (var dy = -1; dy <= 1 && !near; dy++) {
        near = b.contains((x + dx, y + dy));
      }
    }
    if (!near) return false;
  }
  return true;
}

/// Vrai si les deux programmes tracent le même dessin (au dixième de pas près, sans regarder les couleurs).
bool sameDrawing(StudioRun a, StudioRun b) {
  final pa = _drawingPoints(a.segments), pb = _drawingPoints(b.segments);
  return pa.isNotEmpty && _covers(pa, pb) && _covers(pb, pa);
}

/// Du plus simple au plus difficile : une ligne, des angles droits, le crayon levé, les boucles, puis les angles des
/// polygones et une boucle dans une boucle.
final studioChallenges = [
  StudioChallenge('ligne', '270f', 'Une ligne droite', 'Le robot trace un trait vers le haut.', () => [_f(6)], 1),
  StudioChallenge(
    'l',
    '1f9ed',
    'Un coin',
    'Monter, puis tourner pour aller à droite.',
    () => [_f(5), _r(90), _f(3)],
    3,
  ),
  StudioChallenge(
    'pointilles',
    '2728',
    'Deux traits',
    'Un trait, un trou sans dessiner, puis un autre trait.',
    () => [_f(3), StudioBlock(StudioKind.penUp), _f(2), StudioBlock(StudioKind.penDown), _f(3)],
    5,
  ),
  StudioChallenge(
    'carre',
    '1f4d0',
    'Un carré',
    'Quatre côtés pareils, quatre virages pareils.',
    () => [
      _rep(4, [_f(5), _r(90)]),
    ],
    3,
  ),
  StudioChallenge(
    'rectangle',
    '1f4fa',
    'Un rectangle',
    'Deux grands côtés et deux petits.',
    () => [
      _rep(2, [_f(3), _r(90), _f(6), _r(90)]),
    ],
    5,
  ),
  StudioChallenge(
    'escalier',
    '1f3d4',
    'Un escalier',
    'Trois marches vers la droite.',
    () => [
      _rep(3, [_f(2), _r(90), _f(2), _l(90)]),
    ],
    5,
  ),
  StudioChallenge(
    'triangle',
    '1f3d5',
    'Un triangle',
    'Trois côtés pareils : de combien faut-il tourner ?',
    () => [
      _rep(3, [_f(6), _r(120)]),
    ],
    3,
  ),
  StudioChallenge(
    'maison',
    '1f3e0',
    'Une maison',
    'Des murs et un toit pointu.',
    () => [_f(4), _r(30), _f(4), _r(120), _f(4), _r(30), _f(4), _r(90), _f(4)],
    9,
  ),
  StudioChallenge(
    'hexagone',
    '1f4a0',
    'Un hexagone',
    'Six côtés pareils, et un tour complet en tout.',
    () => [
      _rep(6, [_f(4), _r(60)]),
    ],
    3,
  ),
  StudioChallenge(
    'etoile',
    '2b50',
    'Une étoile',
    'Cinq pointes ; le robot fait deux tours en tout.',
    () => [
      _rep(5, [_f(8), _r(144)]),
    ],
    3,
  ),
  StudioChallenge(
    'moulin',
    '1f33c',
    'Un moulin',
    'Un carré, tourner, et recommencer : une boucle dans une boucle.',
    () => [
      _rep(8, [
        _rep(4, [_f(3), _r(90)]),
        _r(45),
      ]),
    ],
    5,
  ),
];

/// Les défis réussis (identifiants), gardés dans le réglage `defis` de l'enfant.
Set<String> decodeDone(String? s) => s == null || s.isEmpty ? {} : s.split(',').toSet();

String encodeDone(Set<String> ids) => (ids.toList()..sort()).join(',');
