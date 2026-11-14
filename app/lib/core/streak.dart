/// Série de jours et défi du jour (ADR 0071). Calculés depuis le journal des séances : rien à perdre, rien à racheter.
library;

import 'day.dart';
import 'events.dart';

/// La série en cours : [days] jours joués, [playedToday] si aujourd'hui en fait partie, [best] la plus longue série.
class Streak {
  const Streak(this.days, this.best, {required this.playedToday});
  final int days, best;
  final bool playedToday;
}

/// Un jour compte dès qu'une séance y a été jouée (finie ou non : jouer suffit). Pas de punition (CLAUDE.md, règle 11) :
/// **un jour de repos ne casse pas la série** — elle s'arrête seulement après deux jours de suite sans jouer —, et un jour
/// de repos ne compte ni en plus ni en moins. La série est « en cours » tant que le dernier jour joué est aujourd'hui,
/// hier ou avant-hier.
Streak streakOf(Iterable<SessionLog> sessions, DateTime now) {
  final played = {for (final s in sessions) dayNumber(s.started)}.toList()..sort();
  if (played.isEmpty) return const Streak(0, 0, playedToday: false);
  final today = dayNumber(now);
  var best = 0, run = 0;
  int? last;
  for (final d in played) {
    run = last != null && d - last <= 2 ? run + 1 : 1;
    if (run > best) best = run;
    last = d;
  }
  final alive = today - played.last <= 2;
  return Streak(alive ? run : 0, best, playedToday: played.last == today);
}

/// Questions du défi du jour.
const dailyChallengeSize = 8;

/// Le défi du jour : [dailyChallengeSize] questions tirées de [pool] (ce que l'enfant a déjà acquis, tous domaines
/// mêlés), les mêmes toute la journée, différentes le lendemain. Chaque notion une fois avant d'en reprendre une.
/// null : rien d'acquis encore, pas de défi.
List<String>? dailyChallenge(List<String> pool, int day, {int n = dailyChallengeSize}) {
  if (pool.isEmpty) return null;
  // Mélange déterministe (générateur congruentiel), sans dépendre de l'implémentation de Random d'une version à l'autre.
  var seed = (day * 2654435761 + 12345) & 0x7fffffff;
  int next(int max) {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed % max;
  }

  final out = <String>[];
  while (out.length < n) {
    final round = [...pool];
    for (var i = round.length - 1; i > 0; i--) {
      final j = next(i + 1);
      final x = round[i];
      round[i] = round[j];
      round[j] = x;
    }
    out.addAll(round);
  }
  return out.take(n).toList();
}
