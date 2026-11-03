import 'package:flutter/material.dart';

import '../activities/draw.dart';

import '../app_state.dart';
import '../core/rewards.dart';
import 'theme.dart';
import 'universe.dart';

/// Album d'autocollants de l'univers (ADR 0015) : gagnés en couleur ; à gagner en silhouette avec un cadenas (forme,
/// pas seulement couleur). Combien d'étoiles manquent pour le prochain : écrit.
class AlbumPage extends StatelessWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.universe;
    final r = s.rewards;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Material(
                  color: surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Retour',
                    iconSize: 32,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Mon album', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: u.onBackground)),
                const Spacer(),
                Material(
                  color: surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    tooltip: 'Mes dessins',
                    iconSize: 32,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DrawingsPage())),
                    icon: const Art('1f3a8', size: 32),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
                  child: Row(children: [
                    const Art('2b50', size: 28),
                    const SizedBox(width: 6),
                    Text('${r.stars}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
                  ]),
                ),
              ]),
            ),
            if (r.toNext > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    'Encore ${r.toNext} étoile${r.toNext > 1 ? 's' : ''} pour le prochain autocollant !',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink),
                  ),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (_, k) {
                  final cols = k.maxWidth > k.maxHeight ? 6 : 3;
                  return GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: cols,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (var i = 0; i < stickersPerUniverse; i++)
                        _Sticker(code: u.stickers[i], won: i < r.stickers),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Sticker extends StatelessWidget {
  const _Sticker({required this.code, required this.won});
  final String code;
  final bool won;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: won ? surface : const Color(0xFFE4E7E5),
          borderRadius: BorderRadius.circular(24),
          boxShadow: won ? cardShadow : null,
        ),
        child: Stack(alignment: Alignment.center, children: [
          won
              ? Art(code, size: 72, label: 'Autocollant gagné')
              : ColorFiltered(
                  colorFilter: const ColorFilter.mode(Color(0xFF9AA49D), BlendMode.srcIn),
                  child: Art(code, size: 64, opacity: 0.5),
                ),
          if (!won) const Icon(Icons.lock_rounded, size: 34, color: Color(0xFF5F6B63), semanticLabel: 'À gagner'),
        ]),
      );
}
