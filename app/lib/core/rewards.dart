/// Récompenses (ADR 0015) : calculées depuis le journal, donc rien ne se perd jamais.
library;

import 'events.dart';

/// Étoiles nécessaires pour un autocollant.
const starsPerSticker = 5;

/// Autocollants par univers.
const stickersPerUniverse = 12;

class Rewards {
  const Rewards(this.stars);

  /// Une étoile par réponse trouvée dans les 3 essais, sans démonstration.
  factory Rewards.from(Iterable<Answer> journal) => Rewards(journal.where((a) => a.success).length);

  final int stars;

  int get stickers => (stars ~/ starsPerSticker).clamp(0, stickersPerUniverse);

  /// Étoiles restantes avant le prochain autocollant (0 quand l'album est complet).
  int get toNext => stickers >= stickersPerUniverse ? 0 : starsPerSticker - stars % starsPerSticker;

  /// Vrai si passer de [before] à ce total débloque un nouvel autocollant.
  bool unlockedSince(Rewards before) => stickers > before.stickers;
}
