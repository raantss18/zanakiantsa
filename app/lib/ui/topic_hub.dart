import 'dart:math';

import 'package:flutter/material.dart';

import '../activities/draw.dart';
import '../app_state.dart';
import '../content/content.dart';
import '../core/progress.dart';
import '../l10n/l10n.dart';
import 'adaptive.dart';
import 'chess_play.dart';
import 'session.dart';
import 'theme.dart';
import 'universe.dart';

/// L'accueil d'un domaine (ADR 0042), la même profondeur partout : apprendre (la séance, reprise où l'enfant s'était
/// arrêté), « Je sais déjà » (test de départ, ADR 0045), le défi (tout ce qui est acquis, mêlé, avec un record), et « Mon carnet » (ce qui est su, ce qui est à
/// revoir, les erreurs qui reviennent). Les échecs y ajoutent leurs parties, le dessin ses dessins.
class TopicHub extends StatefulWidget {
  const TopicHub({super.key, required this.topic});
  final String topic;
  @override
  State<TopicHub> createState() => _TopicHubState();
}

class _TopicHubState extends State<TopicHub> {
  late final AppState app = AppScope.of(context);
  late final Topic topic = app.topic(widget.topic);
  SessionResume? resume;
  int? record;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final r = await SessionResume.load(app, widget.topic);
    final best = await challengeRecord(app, widget.topic);
    if (mounted) {
      setState(() {
        resume = r;
        record = best;
      });
    }
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    await app.refresh();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final p = app.progressOf(topic);
    final canChallenge = p.challengePlan(Random(1)) != null;
    final dessin = widget.topic == 'dessin';
    final echecs = widget.topic == 'echecs';
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            pageHeader(context, topic.name),
            Expanded(
              child: ListView(padding: readablePadding(context), children: [
                if (dessin) ...[
                  hubCard('1f3a8', t('Dessiner'), t('Un sujet précis, et je regarde si je reconnais ton dessin.'), () => _go(const DrawPage())),
                  hubCard('1f5bc', t('Mes dessins'), t('Tous tes dessins, avec leur date.'), () => _go(const DrawingsPage())),
                ] else ...[
                  hubCard(
                    '1f4d6',
                    echecs ? t('Les leçons') : t('Apprendre'),
                    resume == null
                        ? t('La suite de ce que tu apprends.')
                        : tf('Reprendre où tu t\'es arrêté : question {n} sur {total}.', {'n': resume!.index + 1, 'total': resume!.plan.length}),
                    () => _go(SessionPage(topic: widget.topic, resume: resume)),
                  ),
                  if (p.placementPlan() case final test?)
                    hubCard(
                      '1f50d',
                      t('Je sais déjà'),
                      tf('Un petit test pour sauter ce que tu sais : {n} compétences, deux questions chacune. Il s\'arrête dès que tu hésites.', {'n': test.length ~/ placementPerSkill}),
                      () => _go(SessionPage(topic: widget.topic, placement: true)),
                    ),
                  hubCard(
                    '1f3c5',
                    t('Le défi'),
                    canChallenge
                        ? t('Dix questions mêlées de tout ce que tu sais.') + (record == null ? '' : tf(' Ton record : {record} sur 10.', {'record': record!}))
                        : t('Il s\'ouvre quand tu as appris ta première compétence ici.'),
                    canChallenge ? () => _go(SessionPage(topic: widget.topic, challenge: true)) : null,
                  ),
                ],
                if (echecs) ...[
                  hubCard('1f916', t('Contre le robot'), t('Une vraie partie. Choisis le niveau et ta couleur.'), () => chooseRobotGame(context)),
                  hubCard('1f46b', t('À deux'), t('Une partie avec quelqu\'un, sur la même tablette.'),
                      () => _go(const GamePage(mode: 'deux', level: 0, childWhite: true))),
                  hubCard('1f4dc', t('Mes parties'), t('Revoir mes parties coup par coup, avec des conseils.'), () => _go(const GamesPage())),
                ],
                hubCard('1f4d2', t('Mon carnet'), t('Ce que tu sais, ce qui est à revoir, et les erreurs qui reviennent.'),
                    () => _go(NotebookPage(topic: widget.topic))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Une grande carte d'accueil : image, titre, une phrase ; grisée et non touchable si [onTap] est null (avec la phrase
/// qui dit pourquoi, pas seulement le gris).
Widget hubCard(String art, String title, String text, VoidCallback? onTap) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Material(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Art(art, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700, color: ink)),
                    Text(text, style: const TextStyle(fontSize: 18, color: Color(0xFF3D4741), height: 1.2)),
                  ]),
                ),
                if (onTap != null) const Icon(Icons.arrow_forward_rounded, size: 36, color: ink),
              ]),
            ),
          ),
        ),
      ),
    );

/// « Mon carnet » d'un domaine (ADR 0042) : chaque compétence avec son état écrit (acquise, en cours, à revoir, pas
/// commencée), la réussite sur les dernières questions, puis les erreurs qui reviennent le plus — celles que l'app a
/// expliquées pendant les questions.
class NotebookPage extends StatelessWidget {
  const NotebookPage({super.key, required this.topic});
  final String topic;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.universe;
    final tp = app.topic(topic);
    final p = app.progressOf(tp);
    final ids = {for (final s in tp.skills) s.id};
    final answers = [for (final a in app.journal) if (ids.contains(a.skill)) a];
    final counts = <String, int>{};
    for (final a in answers) {
      for (final e in a.errors) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
    }
    final frequent = (counts.entries.toList()..sort((a, b) => b.value - a.value)).take(5).toList();
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            pageHeader(context, t('Mon carnet')),
            Expanded(
              child: ListView(padding: readablePadding(context), children: [
                _section(tf('Mes compétences : {name}', {'name': tp.name})),
                for (final s in tp.skills) _skillRow(s, p),
                const SizedBox(height: 16),
                _section(t('Les erreurs qui reviennent')),
                if (frequent.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t('Pas encore d\'erreur notée ici. Chaque erreur expliquée pendant les questions viendra s\'écrire ici.'),
                          style: const TextStyle(fontSize: 18)),
                    ),
                  )
                else
                  for (final e in frequent)
                    Card(
                      child: ListTile(
                        leading: const Art('1f4a1', size: 36),
                        title: Text(e.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        trailing: Text('× ${e.value}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      ),
                    ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
      );

  /// Une compétence : son état en mots et en icône (jamais la couleur seule), et la réussite des 10 dernières questions.
  Widget _skillRow(Skill s, Progress p) {
    final last = p.answersOf(s.id);
    final recent = last.length > 10 ? last.sublist(last.length - 10) : last;
    final ok = recent.where((a) => a.success).length;
    final (icon, state) = p.earned(s.id)
        ? (recent.length >= 5 && ok * 2 < recent.length ? ('1f501', t('À revoir')) : ('2705', t('Acquise')))
        : p.skipped(s.id)
            ? ('1f393', t('Déjà de ton âge'))
            : recent.isEmpty
                ? (p.unlocked(s.ref) ? ('1f195', t('Pas commencée')) : ('1f512', t('Plus tard')))
                : ('1f331', t('En cours'));
    return Card(
      child: ListTile(
        minTileHeight: 64,
        leading: Art(icon, size: 36),
        title: Text(s.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        subtitle: Text(
            recent.isEmpty
                ? state
                : recent.length == 1
                    ? (ok == 1 ? tf('{state} · réussie la dernière fois', {'state': state}) : tf('{state} · pas encore réussie la dernière fois', {'state': state}))
                    : ok > 1
                        ? tf('{state} · {ok} réussies sur les {n} dernières', {'state': state, 'ok': ok, 'n': recent.length})
                        : tf('{state} · {ok} réussie sur les {n} dernières', {'state': state, 'ok': ok, 'n': recent.length}),
            style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
