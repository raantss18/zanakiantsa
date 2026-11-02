/// Révisions en boîtes de Leitner (ADR 0007). Une carte = une compétence maîtrisée.
library;

import 'events.dart';

/// Intervalles en jours des boîtes 1 à 5 (⚠ à recaler après mesure, ADR 0007).
const leitnerDays = [1, 2, 4, 8, 16];

class ReviewCard {
  const ReviewCard(this.box, this.due);
  final int box;
  final DateTime due;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Réussite : boîte suivante (max 5) ; échec : retour en boîte 1. L'échéance part du jour de la réponse.
ReviewCard review(ReviewCard? card, bool success, DateTime when) {
  final box = success ? ((card?.box ?? 0) + 1).clamp(1, leitnerDays.length) : 1;
  return ReviewCard(box, _day(when).add(Duration(days: leitnerDays[box - 1])));
}

/// Rejoue le journal d'une compétence à partir du moment où elle est maîtrisée.
ReviewCard? cardFrom(List<Answer> answersOfSkill, bool Function(List<Answer>) masteredAfter) {
  ReviewCard? card;
  for (var i = 0; i < answersOfSkill.length; i++) {
    final upTo = answersOfSkill.sublist(0, i + 1);
    if (card == null) {
      if (masteredAfter(upTo)) card = review(null, true, answersOfSkill[i].at);
    } else {
      card = review(card, answersOfSkill[i].success, answersOfSkill[i].at);
    }
  }
  return card;
}

bool isDue(ReviewCard card, DateTime now) => !_day(now).isBefore(card.due);
