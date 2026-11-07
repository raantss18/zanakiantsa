/// Le sens du tracé des lettres attachées (ADR 0049). Règles prises dans « L'écriture à l'école maternelle — La forme
/// des lettres », Ressources maternelle, éduscol, septembre 2015
/// (https://eduscol.education.fr/document/13564/download) :
/// - « pour l'écriture en cursive, le ductus doit être respecté » ;
/// - le rond de a, c, d, g, o, q « se trace en rotation à gauche à partir d'un repère situé en haut de la forme et
///   suffisamment à droite » (« le chiffre 2 (14h) d'une horloge ») ; « les lettres rondes n'ont pas de trait
///   d'attaque » ;
/// - les autres lettres commencent par un trait d'attaque, à gauche ; mais le modèle de l'app (Playwrite FR) n'en a
///   pas toujours (« i » part du haut de sa barre, « s » finit en bas à gauche) : on vérifie seulement que le tracé
///   avance de gauche à droite, et seulement pour les lettres vues finir à droite dans ce modèle ([leftToRight]).
/// Pour les capitales, « il n'est pas nécessaire d'imposer un ductus particulier » : rien n'est vérifié.
library;

import 'dart:ui';

import '../l10n/l10n.dart';

const roundLetters = {'a', 'c', 'd', 'g', 'o', 'q'};

/// Lettres dont le modèle affiché finit à droite de son départ (vu sur l'émulateur, 2026-11-05).
const leftToRight = {'e', 'i', 'l', 'm', 'n', 'r', 't', 'u'};

/// Lettres finies par un second geste : le point du i et du j, la barre du t.
const secondGesture = {'i': 'le point', 'j': 'le point', 't': 'la barre'};

/// Ce qui ne va pas dans le sens du tracé de [letter] (null : le geste est bon). [strokes] : les traits de l'enfant,
/// dans l'ordre ; [box] : le rectangle de la lettre, dans les mêmes coordonnées.
String? ductusError(String letter, List<List<Offset>> strokes, Rect box) {
  final drawn = [for (final s in strokes) if (s.length >= 3) s];
  if (drawn.isEmpty) return null;
  final second = secondGesture[letter];
  if (drawn.length > (second == null ? 1 : 2)) {
    return second == null
        ? t("Une lettre attachée se trace d'un seul geste, sans lever le doigt.")
        : tf("Trace « {letter} » d'un seul geste, sans lever le doigt ; {second} vient à la fin.", {'letter': letter, 'second': t(second)});
  }
  final first = drawn.first;
  final start = first.first;
  if (roundLetters.contains(letter)) {
    final startsTopRight = start.dx > box.left + 0.4 * box.width && start.dy < box.top + 0.5 * box.height;
    if (!startsTopRight || !turnsLeft(first)) {
      return t('Le rond commence en haut, à droite, et tourne vers la gauche, comme pour écrire un c.');
    }
  } else if (leftToRight.contains(letter) && first.last.dx <= start.dx) {
    return t("Une lettre attachée avance de gauche à droite : commence à gauche, finis à droite.");
  }
  return null;
}

/// Le début du trait tourne vers la gauche (sens inverse des aiguilles d'une montre, à l'écran) : aire signée de la
/// première moitié du trait, négative quand l'axe des y descend.
bool turnsLeft(List<Offset> points) {
  final part = points.sublist(0, (points.length / 2).ceil().clamp(3, points.length));
  var area = 0.0;
  for (var i = 0; i < part.length; i++) {
    final p = part[i], q = part[(i + 1) % part.length];
    area += p.dx * q.dy - q.dx * p.dy;
  }
  return area < 0;
}
