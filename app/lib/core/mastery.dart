/// Maîtrise : au moins 4 réussites sur les 5 dernières questions de la compétence (ADR 0007).
library;

import 'events.dart';

const masteryWindow = 5;
const masteryNeeded = 4;

bool isMastered(Iterable<Answer> answersOfSkill) {
  final last = answersOfSkill.toList();
  if (last.length < masteryWindow) return false;
  final window = last.sublist(last.length - masteryWindow);
  return window.where((a) => a.success).length >= masteryNeeded;
}
