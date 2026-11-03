import 'package:flutter/material.dart';

import '../app_state.dart';
import '../content/content.dart';
import 'topic_intro.dart';
import 'theme.dart';
import 'universe.dart';

/// « Tout explorer » (ADR 0032) : tous les domaines, à tout moment, en plus des trois proposés du jour. Chaque carte dit
/// combien de compétences sont maîtrisées (écrit, pas seulement une barre).
class AllTopicsPage extends StatelessWidget {
  const AllTopicsPage({super.key});

  Future<void> open(BuildContext context, AppState app, Topic t) => openTopic(context, app, t.id);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(children: [
                Material(
                  color: surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(tooltip: 'Retour', iconSize: 32, onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: ink)),
                ),
                const SizedBox(width: 12),
                const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PlayfulTitle('Tout explorer'))),
              ]),
            ),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 240,
                childAspectRatio: 0.95,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  for (final t in app.topics)
                    Builder(builder: (context) {
                      final p = app.progressOf(t);
                      final done = t.skills.where((s) => p.mastered(s.id)).length;
                      return Semantics(
                        button: true,
                        label: '${t.name}, $done compétences maîtrisées sur ${t.skills.length}',
                        excludeSemantics: true,
                        child: Material(
                          color: surface,
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => open(context, app, t),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                Art(t.icon, size: 64),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(t.name, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
                                ),
                                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Art('2b50', size: 22),
                                  const SizedBox(width: 4),
                                  Text('$done / ${t.skills.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63))),
                                ]),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
