/// Univers visuels (ADR 0014, docs/design.md) : couleurs, dessins Twemoji (CC BY 4.0), mots venus du contenu.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Un dessin Twemoji embarqué (`assets/art/<code>.svg`).
class Art extends StatelessWidget {
  const Art(this.code, {super.key, this.size = 48, this.label, this.opacity = 1});
  final String code;
  final double size;
  final String? label;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final img = SvgPicture.asset('assets/art/$code.svg', width: size, height: size);
    return Semantics(
      label: label,
      excludeSemantics: label == null,
      child: opacity < 1 ? Opacity(opacity: opacity, child: img) : img,
    );
  }
}

/// Le même dessin en image (pour Flame), rendu à [px] pixels.
Future<ui.Image> artImage(String code, int px) async {
  final info = await vg.loadPicture(SvgAssetLoader('assets/art/$code.svg'), null);
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..scale(px / info.size.width, px / info.size.height)
    ..drawPicture(info.picture);
  final img = await rec.endRecording().toImage(px, px);
  info.picture.dispose();
  return img;
}

/// Un nom avec son genre, pour accorder les phrases.
class Noun {
  const Noun(this.singular, this.plural, this.feminine);
  final String singular, plural;
  final bool feminine;
}

/// Mouvement de la scène de réussite d'un monde.
enum Motion {
  /// Traverse l'écran de gauche à droite (voiture qui passe la ligne d'arrivée).
  cross,

  /// Monte du bas vers le haut (fusée qui décolle).
  rise,

  /// Tourne et grandit au centre (engrenage qui se met en marche, robe qui virevolte).
  spin,

  /// Vole en vague de gauche à droite (fée).
  fly,

  /// Tombe d'en haut et rebondit au centre (couronne posée).
  drop,
}

/// Scène de réussite propre à un monde : un héros qui bouge, et des éclats qui jaillissent du centre.
class Scene {
  const Scene(this.hero, this.motion, this.burst);
  final String hero;
  final Motion motion;
  final List<String> burst;
}

class Universe {
  const Universe({
    required this.id,
    required this.boy,
    required this.mascot,
    required this.objects,
    required this.container,
    required this.bg1,
    required this.bg2,
    required this.primary,
    required this.onPrimary,
    required this.onCard,
    required this.stickers,
    required this.decor,
    required this.scene,
    this.night = false,
  });

  /// Ce qui se passe à l'écran à chaque bonne réponse.
  final Scene scene;

  final String id;
  final bool boy;

  /// Codes Twemoji : mascotte, objets (petits / grands nombres), contenant, autocollants (12), décor (6).
  final String mascot, container;
  final List<String> objects, stickers, decor;

  /// Couleurs vérifiées par `tool/contrast.py` (AA). [onCard] = couleur d'accent sur carte blanche.
  final Color bg1, bg2, primary, onPrimary, onCard;

  /// Fond sombre : texte clair directement sur le fond (titres) ; le reste reste sur cartes blanches.
  final bool night;

  Color get onBackground => night ? Colors.white : const Color(0xFF1B211D);
}

const universes = <Universe>[
  Universe(
    id: 'robots',
    scene: Scene('2699', Motion.spin, ['1f4a1', '1f529', '1f50b']),
    boy: true,
    mascot: '1f916',
    objects: ['2699', '1f50b'],
    container: '1f9f0',
    bg1: Color(0xFFE3F0FA),
    bg2: Color(0xFFC9DFF0),
    primary: Color(0xFF1F5F8B),
    onPrimary: Colors.white,
    onCard: Color(0xFF1F5F8B),
    stickers: ['1f916', '2699', '1f529', '1f50b', '1f4a1', '1f527', '1f9be', '1f6f8', '1f50c', '1f4e1', '1f579', '1f9f2'],
    decor: ['2699', '1f529', '1f527', '1f50c', '1f4a1', '1f9f2'],
  ),
  Universe(
    id: 'voitures',
    scene: Scene('1f3ce', Motion.cross, ['1f3c1', '1f3c6']),
    boy: true,
    mascot: '1f3ce',
    objects: ['1f697', '1f69a'],
    container: '1f3e0',
    bg1: Color(0xFFFFF3E0),
    bg2: Color(0xFFFFE0B2),
    primary: Color(0xFFB71C1C),
    onPrimary: Colors.white,
    onCard: Color(0xFFB71C1C),
    stickers: ['1f3ce', '1f697', '1f693', '1f692', '1f691', '1f68c', '1f69c', '1f69a', '1f3c1', '1f6a6', '1f6de', '1f3c6'],
    decor: ['1f3c1', '1f6a6', '1f6de', '26fd', '1f3c6', '1f68c'],
  ),
  Universe(
    id: 'espace',
    scene: Scene('1f680', Motion.rise, ['1f320', '1fa90', '2728']),
    boy: true,
    mascot: '1f9d1-200d-1f680',
    objects: ['1fa90', '1f6f0'],
    container: '1f680',
    bg1: Color(0xFF1A1F4A),
    bg2: Color(0xFF2D1E5C),
    primary: Color(0xFFFFC83D),
    onPrimary: Color(0xFF1B211D),
    onCard: Color(0xFF5E35B1),
    stickers: ['1f9d1-200d-1f680', '1f680', '1fa90', '1f319', '1f320', '1f6f0', '2604', '1f30d', '1f30c', '1f6f8', '1f52d', '1f4e1'],
    decor: ['1f319', '1f320', '2604', '1f30c', '1fa90', '1f30d'],
    night: true,
  ),
  Universe(
    id: 'fees',
    scene: Scene('1f9da-200d-2640-fe0f', Motion.fly, ['1f338', '2728', '1f337']),
    boy: false,
    mascot: '1f9da-200d-2640-fe0f',
    objects: ['1f98b', '1f338'],
    container: '1f9fa',
    bg1: Color(0xFFF6E8F8),
    bg2: Color(0xFFE3F4FB),
    primary: Color(0xFF7B1FA2),
    onPrimary: Colors.white,
    onCard: Color(0xFF7B1FA2),
    stickers: ['1f9da-200d-2640-fe0f', '1f98b', '1f338', '1f344', '2728', '1f308', '1f337', '1fa84', '1f33c', '1f41e', '1f41d', '1f9fa'],
    decor: ['1f338', '1f337', '2728', '1f33c', '1f344', '1f308'],
  ),
  Universe(
    id: 'mode',
    scene: Scene('1f457', Motion.spin, ['1f380', '2728', '1f48d']),
    boy: false,
    mascot: '1f483',
    objects: ['1f457', '1f380'],
    container: '1f9f3',
    bg1: Color(0xFFFDE7EF),
    bg2: Color(0xFFFFF6E0),
    primary: Color(0xFFAD1457),
    onPrimary: Colors.white,
    onCard: Color(0xFFAD1457),
    stickers: ['1f483', '1f457', '1f460', '1f45c', '1f453', '1f380', '1f48d', '1f452', '1fa9e', '1f9f5', '1f45b', '1f45a'],
    decor: ['1f380', '1f9f5', '1f452', '1f48d', '1f461', '1fa9e'],
  ),
  Universe(
    id: 'princesses',
    scene: Scene('1f451', Motion.drop, ['1f48e', '2728', '1f339']),
    boy: false,
    mascot: '1f478',
    objects: ['1f451', '1f48e'],
    container: '1f381',
    bg1: Color(0xFFEEE8F8),
    bg2: Color(0xFFFFF7CC),
    primary: Color(0xFF5E2A8C),
    onPrimary: Colors.white,
    onCard: Color(0xFF5E2A8C),
    stickers: ['1f478', '1f3f0', '1f451', '1f984', '1f48e', '1f3a0', '1f339', '1f438', '1f9a2', '1f381', '1f3b6', '1f4dc'],
    decor: ['1f3f0', '1f339', '1f984', '1f3b6', '1f48e', '1f3a0'],
  ),
];

Universe universeById(String? id) => universes.firstWhere((u) => u.id == id, orElse: () => universes.first);

/// Les mots d'un univers (content/univers.yaml).
class UniverseWords {
  UniverseWords(Map<String, dynamic> j)
      : name = j['nom'] as String,
        firstName = j['prenom'] as String,
        mascotName = j['mascotte'] as String,
        container = j['contenant'] as String,
        intro = j['intro'] as String,
        story = [for (final e in j['histoire'] as List) e as String],
        objects = [
          for (final o in j['objets'] as List) Noun((o as List)[0] as String, o[1] as String, o[2] == 'f'),
        ];
  final String name, firstName, mascotName, container, intro;
  final List<Noun> objects;

  /// Épisodes du fil d'histoire (ADR 0017) : un par séance finie ; le dernier reste affiché ensuite.
  final List<String> story;

  /// Épisode gagné après [sessions] séances (null avant la première : on montre l'intro).
  int? episode(int sessions) => sessions <= 0 ? null : (sessions - 1).clamp(0, story.length - 1);
}

Future<Map<String, UniverseWords>> loadUniverseWords() async {
  final j = jsonDecode(await rootBundle.loadString('assets/content/univers.json')) as Map<String, dynamic>;
  return {
    for (final e in (j['univers'] as Map).entries) e.key as String: UniverseWords(Map<String, dynamic>.from(e.value as Map)),
  };
}

/// Fond d'univers : dégradé + décor en filigrane (jamais derrière un texte sans carte, docs/design.md § 4).
class UniverseBackground extends StatelessWidget {
  const UniverseBackground({super.key, required this.universe, required this.child});
  final Universe universe;
  final Widget child;

  // Jamais dans la bande du haut (titre, boutons) : y ≥ -0.4.
  static const _spots = [
    Alignment(-0.88, -0.35), Alignment(0.9, -0.1), Alignment(-0.75, 0.35),
    Alignment(0.8, 0.55), Alignment(-0.25, 0.92), Alignment(0.35, 0.15),
  ];

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [universe.bg1, universe.bg2],
          ),
        ),
        child: Stack(children: [
          for (final (i, code) in universe.decor.indexed)
            Align(alignment: _spots[i % _spots.length], child: Art(code, size: 64, opacity: universe.night ? 0.22 : 0.12)),
          Positioned.fill(child: child),
        ]),
      );
}
