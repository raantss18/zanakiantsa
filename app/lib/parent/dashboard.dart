/// Le tableau de bord de l'espace parent (ADR 0061) : quatre lectures simples, sans jargon ni pourcentage inutile.
///   - le temps de jeu des 7 derniers jours, face au temps réglé ;
///   - la réussite du premier coup cette semaine, comparée à la semaine d'avant ;
///   - le progrès par domaine : notions acquises sur le total ;
///   - à revoir : les notions où l'enfant bloque, avec l'explication que l'app a donnée le plus souvent.
library;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/events.dart';
import '../core/report.dart';
import '../l10n/l10n.dart';
import 'notebook_style.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.app, required this.sessions});
  final AppState app;
  final List<SessionLog> sessions;

  @override
  Widget build(BuildContext context) {
    final st = parentStats(app.journal, sessions, DateTime.now());
    final titles = {for (final t in app.topics) for (final s in t.skills) s.id: s.title};
    final name = app.current.label;
    final streak = app.streak();
    final due = app.dueReviews().length;
    final total = st.minutesPerDay.fold<int>(0, (a, b) => a + b);
    // Le bilan en phrases (ADR 0071) : ce qu'un parent pressé veut savoir, puis un seul conseil.
    final advice = st.toReview.isNotEmpty
        ? tf('Conseil : jouez cinq minutes avec {name} à « {skill} ». L’app explique chaque erreur, puis repose une question proche.', {'name': name, 'skill': titles[st.toReview.first.skill] ?? st.toReview.first.skill})
        : st.daysPlayed < 3
            ? t('Conseil : mieux vaut un peu chaque jour qu’une longue séance par semaine. Une révision de quelques minutes suffit les jours chargés.')
            : due > 0
                ? tf('Conseil : le bouton « À revoir » de l’accueil propose {n} notions à revoir aujourd’hui, juste avant qu’elles s’oublient.', {'n': due})
                : t('Conseil : continuez ainsi. Demandez-lui de vous expliquer ce qu’il a appris : expliquer aide à retenir.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
        title: t('Le bilan de la semaine'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Line(Icons.calendar_today_rounded, tf('{name} a joué {days} jours sur 7, {minutes} minutes en tout.', {'name': name, 'days': st.daysPlayed, 'minutes': total})),
          if (streak.days >= 2) _Line(Icons.local_fire_department_rounded, tf('Série en cours : {n} jours. Un jour de repos ne la casse pas.', {'n': streak.days})),
          _Line(
            Icons.emoji_events_rounded,
            st.learned.isEmpty
                ? t('Pas de nouvelle notion acquise cette semaine : c’est normal quand les leçons sont nouvelles.')
                : tf('Notions acquises cette semaine : {list}.', {'list': [for (final id in st.learned.take(4)) titles[id] ?? id].join(', ') + (st.learned.length > 4 ? '…' : '')}),
          ),
          if (st.toReview.isNotEmpty) _Line(Icons.flag_rounded, tf('À aider : {list}.', {'list': [for (final r in st.toReview) titles[r.skill] ?? r.skill].join(', ')})),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF3F0FA), borderRadius: BorderRadius.circular(12)),
            child: Text(advice, style: _body),
          ),
        ]),
      ),
      _Card(title: t('Temps de jeu, 7 derniers jours'), child: _Days(minutes: st.minutesPerDay, target: app.dailyMinutes)),
      _Card(title: t('Réussi du premier coup'), child: _FirstTry(now: st.firstTryThisWeek, before: st.firstTryLastWeek)),
      _Card(
        title: t('Progrès par domaine'),
        child: Column(children: [
          for (final t in app.topics)
            if (t.skills.isNotEmpty) _Bar(label: t.name, done: [for (final s in t.skills) if (app.progressOf(t).mastered(s.id)) s].length, total: t.skills.length),
          const SizedBox(height: 4),
          Text(tf('Les notions d’avant la classe de {name} comptent comme acquises ; « Je sais déjà » les vérifie.', {'name': name}), style: _small),
        ]),
      ),
      _Card(
        title: t('À revoir'),
        child: st.toReview.isEmpty
            ? Text(t('Rien de bloquant cette semaine.'), style: _body)
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final r in st.toReview)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 3), child: Icon(Icons.flag_rounded, color: marge, size: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(titles[r.skill] ?? r.skill, style: _strong),
                          Text(tf('Difficile {failures} fois sur {answers} cette semaine.', {'failures': r.failures, 'answers': r.answers}), style: _small),
                          if (r.error != null) Text(tf('L’app a expliqué : « {error} »', {'error': r.error!}), style: _body),
                        ]),
                      ),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

const _body = TextStyle(fontFamily: 'Andika', fontSize: 16, height: 1.35, color: texteCahier);
const _small = TextStyle(fontFamily: 'Andika', fontSize: 14, height: 1.3, color: Color(0xFF4A4560));
const _strong = TextStyle(fontFamily: 'Andika', fontSize: 17, fontWeight: FontWeight.w700, color: encre);

/// Une phrase du bilan, avec son icône.
class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: violet, size: 22)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: _body)),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(18), border: Border.all(color: encre.withValues(alpha: .35), width: 1.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontFamily: 'Andika', fontSize: 18, fontWeight: FontWeight.w700, color: encre)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

/// Sept colonnes : une par jour, le temps réglé en pointillé ; le nombre de minutes écrit au-dessus (pas seulement la hauteur).
class _Days extends StatelessWidget {
  const _Days({required this.minutes, required this.target});
  final List<int> minutes;
  final int target;

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  static const _lettersEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final top = [target, ...minutes].reduce((a, b) => a > b ? a : b).toDouble();
    const h = 110.0;
    final total = minutes.fold<int>(0, (a, b) => a + b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: h + 44,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: 18 + h * (1 - target / top),
            child: CustomPaint(size: const Size(double.infinity, 2), painter: _Dashed()),
          ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(minutes[i] == 0 ? '' : '${minutes[i]}', style: _small),
                  const SizedBox(height: 2),
                  Container(
                    height: (h * minutes[i] / top).clamp(minutes[i] == 0 ? 3.0 : 6.0, h),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(color: minutes[i] >= target ? violet : violet.withValues(alpha: .55), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                  ),
                  const SizedBox(height: 4),
                  Text((english ? _lettersEn : _letters)[today.subtract(Duration(days: 6 - i)).weekday - 1], style: i == 6 ? _strong : _small),
                ]),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 6),
      Text(tf('{total} min en tout. Le pointillé : {target} min par jour, le temps que vous avez réglé.', {'total': total, 'target': target}), style: _small),
    ]);
  }
}

class _Dashed extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = marge
      ..strokeWidth = 2;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, 0), Offset(x + 5, 0), p);
    }
  }

  @override
  bool shouldRepaint(_Dashed old) => false;
}

class _FirstTry extends StatelessWidget {
  const _FirstTry({required this.now, required this.before});
  final double? now, before;

  @override
  Widget build(BuildContext context) {
    final n = now;
    if (n == null) return Text(t('Pas encore de réponse cette semaine.'), style: _body);
    final pct = (n * 100).round();
    final b = before;
    String trend = t('Pas de comparaison : pas de réponse la semaine d’avant.');
    IconData icon = Icons.horizontal_rule_rounded;
    if (b != null) {
      final d = pct - (b * 100).round();
      trend = d == 0 ? t('Comme la semaine d’avant.') : tf('{sign}{d} points par rapport à la semaine d’avant ({before} %).', {'sign': d > 0 ? '+' : '−', 'd': d.abs(), 'before': (b * 100).round()});
      icon = d > 0 ? Icons.trending_up_rounded : d < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded;
    }
    return Row(children: [
      Text('$pct %', style: const TextStyle(fontFamily: 'Fredoka', fontSize: 40, fontWeight: FontWeight.w700, color: violet)),
      const SizedBox(width: 14),
      Icon(icon, color: encre, size: 30),
      const SizedBox(width: 8),
      Expanded(child: Text(tf('des réponses trouvées sans aide. {trend}', {'trend': trend}), style: _body)),
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.done, required this.total});
  final String label;
  final int done, total;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(width: 112, child: Text(label, style: _body, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 12, backgroundColor: const Color(0xFFE8E4F2), color: violet),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 56, child: Text('$done / $total', textAlign: TextAlign.right, style: _small)),
        ]),
      );
}
