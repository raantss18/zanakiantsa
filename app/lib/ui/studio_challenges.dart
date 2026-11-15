import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/studio.dart';
import '../l10n/l10n.dart';
import 'adaptive.dart';
import 'chess_play.dart';
import 'studio.dart';
import 'theme.dart';
import 'universe.dart';

/// Défis du robot (ADR 0077) : la liste des dessins modèles, avec ceux déjà réussis (écrit, pas seulement coloré).

Future<Set<String>> loadChallengesDone(AppState app) async => decodeDone(await app.store.get('defis'));

Future<void> markChallengeDone(AppState app, String id) async {
  final done = await loadChallengesDone(app);
  if (done.add(id)) await app.store.set('defis', encodeDone(done));
}

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({super.key});
  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  late final AppState app = AppScope.of(context);
  Set<String>? done;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (done == null) _load();
  }

  Future<void> _load() async {
    final d = await loadChallengesDone(app);
    if (mounted) setState(() => done = d);
  }

  Future<void> _open(StudioChallenge c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudioPage(challenge: c)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = done ?? const <String>{};
    return Scaffold(
      body: UniverseBackground(
        universe: app.universe,
        child: SafeArea(
          child: Column(
            children: [
              pageHeader(context, t('Défis du robot')),
              Expanded(
                child: ListView(
                  padding: readablePadding(context),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
                      child: Text(
                        tf(
                          'Le robot doit refaire le dessin en pointillés. Écris le programme, lance-le, et compare. Défis réussis : {n} sur {total}.',
                          {'n': d.length, 'total': studioChallenges.length},
                        ),
                        style: const TextStyle(fontSize: 18, color: ink),
                      ),
                    ),
                    for (final c in studioChallenges) _card(c, d.contains(c.id)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(StudioChallenge c, bool ok) {
    final r = runStudio(c.model());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(c),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD5DBD7)),
                  ),
                  child: CustomPaint(painter: StudioPainter(const [], r.view, model: r.segments.toList())),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Art(c.art, size: 30),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              t(c.title),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink),
                            ),
                          ),
                        ],
                      ),
                      Text(t(c.text), style: const TextStyle(fontSize: 17, color: Color(0xFF4A554E))),
                      if (ok)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: green, size: 24),
                            const SizedBox(width: 4),
                            Text(
                              t('Réussi'),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: green),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 32, color: ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
