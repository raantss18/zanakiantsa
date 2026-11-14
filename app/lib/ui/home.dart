import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app_state.dart';
import '../audio/voice.dart';
import '../content/content.dart';
import '../core/day.dart';
import '../l10n/l10n.dart';
import '../parent/gate.dart';
import '../update/updater.dart';
import 'adaptive.dart';
import 'album.dart';
import 'topic_intro.dart';
import 'all_topics.dart';
import 'library.dart';
import 'session.dart';
import 'theme.dart';
import 'universe.dart';

/// Accueil enfant (ADR 0018) : l'épisode du fil d'histoire, puis les trois activités du jour en grandes cartes ; la
/// suivante à faire est mise en avant, celles finies portent une ✔. L'enfant enchaîne seul. Sans genre saisi, on
/// demande un adulte (ADR 0014).
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _welcome());
    // À chaque lancement, l'app regarde seule s'il y a une nouvelle version (demande d'Antsa du 2026-11-14 : la mise à jour
    // ne doit pas être cachée). Sans réseau, rien ne s'affiche. L'installation reste derrière la porte parent.
    Updater().check().then((r) {
      if (mounted && r != null) setState(() => _update = r);
    });
  }

  /// La nouvelle version trouvée au lancement, s'il y en a une : annoncée sur l'accueil.
  Release? _update;

  /// La parole de l'accueil (bienvenue, histoire, activités du jour) : coupée dès que l'enfant touche l'écran, sinon
  /// elle continuait par-dessus la page ouverte.
  Speech? _greeting;

  Future<void> _welcome() async {
    final s = AppScope.of(context);
    _greeting?.close();
    final g = _greeting = s.voice.scope();
    if (!s.ready) {
      await g.say(s.common.text('demande_adulte'), id: 'commun.demande_adulte');
      return;
    }
    final e = s.universeWords.episode(s.sessionsDone);
    e == null
        ? await g.say(s.universeWords.intro, id: 'univers.${s.universe.id}.intro')
        : await g.say(s.universeWords.story[e], id: 'univers.${s.universe.id}.histoire.$e');
    final plan = s.dayPlan();
    if (plan.finished) {
      await g.say(s.common.text('journee_finie'), id: 'commun.journee_finie');
    } else {
      final names = [for (final i in plan.items) s.topic(i.theme).name.toLowerCase()];
      await g.say(tf('{today} {list} et {last}.', {'today': s.common.text('aujourdhui'), 'list': names.take(names.length - 1).join(', '), 'last': names.last}));
    }
  }

  Future<void> _open(String theme) => openTopic(context, AppScope.of(context), theme);

  @override
  void dispose() {
    _greeting?.close();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.chosen) return const ProfilePicker();
    final u = s.universe;
    final plan = s.dayPlan();
    return Scaffold(
      // Un toucher n'importe où arrête le message d'accueil (« Réécouter » le relance).
      body: Listener(
        onPointerDown: (_) => _greeting?.close(),
        child: UniverseBackground(
          universe: u,
          // La mise en page suit la place réellement disponible (ADR 0052) : deux colonnes en paysage, et un
          // défilement plutôt que des cartes écrasées quand l'écran est bas ou la police grande.
          child: SafeArea(
            child: LayoutBuilder(builder: (context, k) {
              if (!s.ready) {
                return Column(children: [_Header(onListen: _welcome, update: _update != null), Expanded(child: _AskAdult(text: s.common.text('demande_adulte')))]);
              }
              return isLandscape(k.biggest) ? _landscape(context, s, u, plan, k) : _portrait(context, s, u, plan, k);
            }),
          ),
        ),
      ),
    );
  }

  Widget _card(AppState s, DayPlan plan, int n, {required bool wide, bool? compact}) {
    final item = plan.items[n];
    return DayCard(
      topic: s.topic(item.theme),
      item: item,
      number: n + 1,
      next: plan.next == item,
      pulse: _pulse,
      wide: wide,
      compact: compact,
      onTap: () => _open(item.theme),
    );
  }

  /// Portrait : en-tête, texte d'accueil, les trois cartes qui prennent le reste, puis les boutons du bas. Si le reste
  /// est trop petit pour les cartes, toute la page défile et elles gardent leur taille.
  Widget _portrait(BuildContext context, AppState s, Universe u, DayPlan plan, BoxConstraints k) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final strip = _strip(context, s, u);
    final layout = homeCardsFor(
      width: k.maxWidth - 32,
      cardsHeight: k.maxHeight - homeChrome(fontScale: scale, dayFinished: plan.finished, strip: strip != null),
    );
    final top = [
      _Header(onListen: _welcome, update: _update != null),
      _Intro(words: s.universeWords, sessions: s.sessionsDone, universe: u),
      ?strip,
      if (plan.finished) _DayDone(text: s.common.text('journee_finie')),
    ];
    final bottom = [_exploreButton(context, s, u), _bottomRow(context, s, u)];
    final count = plan.items.length;
    if (!layout.scrolls) {
      return Column(children: [
        ...top,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LayoutBuilder(builder: (_, kk) {
              final wide = kk.maxWidth > kk.maxHeight * 1.1;
              return Flex(direction: wide ? Axis.horizontal : Axis.vertical, children: [
                for (var n = 0; n < count; n++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: wide ? 0 : 12, right: wide && n < 2 ? 12 : 0),
                      child: _card(s, plan, n, wide: wide),
                    ),
                  ),
              ]);
            }),
          ),
        ),
        ...bottom,
      ]);
    }
    return SingleChildScrollView(
      child: Column(children: [
        ...top,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: layout.sideBySide
              ? SizedBox(
                  height: layout.height,
                  child: Row(children: [
                    for (var n = 0; n < count; n++)
                      Expanded(child: Padding(padding: EdgeInsets.only(right: n < count - 1 ? 12 : 0), child: _card(s, plan, n, wide: true))),
                  ]),
                )
              : Column(children: [
                  for (var n = 0; n < count; n++)
                    Padding(
                      padding: EdgeInsets.only(bottom: n < count - 1 ? homeCardGap : 0),
                      child: SizedBox(height: layout.height, child: _card(s, plan, n, wide: false, compact: true)),
                    ),
                ]),
        ),
        ...bottom,
      ]),
    );
  }

  /// Paysage : à gauche, l'en-tête, le texte d'accueil et les boutons ; à droite, les trois cartes l'une sous l'autre,
  /// chacune avec toute la hauteur dont elle a besoin (ce qui dépasse défile).
  Widget _landscape(BuildContext context, AppState s, Universe u, DayPlan plan, BoxConstraints k) {
    final cardH = max(landscapeCardHeight(k.maxHeight), homeCardMinRow);
    final count = plan.items.length;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: sidePanelWidth(k.maxWidth),
        child: Column(children: [
          // Le texte de Robi doit se lire en entier : la zone défilait, et avec un texte agrandi (150 % sur la SM-X135G) la
          // fin de la bulle restait cachée sans que rien ne le montre (signalé par Antsa, 2026-11-07). Elle rétrécit à la place.
          _Header(onListen: _welcome, update: _update != null), // hors de la zone qui rétrécit : ses boutons gardent leurs 48 dp
          Expanded(
            child: LayoutBuilder(
              builder: (_, box) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: box.maxWidth,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _Intro(words: s.universeWords, sessions: s.sessionsDone, universe: u),
                    ?_strip(context, s, u),
                    if (plan.finished) _DayDone(text: s.common.text('journee_finie')),
                  ]),
                ),
              ),
            ),
          ),
          _exploreButton(context, s, u),
          _bottomRow(context, s, u),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
          child: Column(children: [
            for (var n = 0; n < count; n++)
              Padding(
                padding: EdgeInsets.only(bottom: n < count - 1 ? homeCardGap : 0),
                child: SizedBox(height: cardH, child: _card(s, plan, n, wide: false, compact: cardH < homeCardCompactBelow)),
              ),
          ]),
        ),
      ),
    ]);
  }

  /// Série de jours, « À revoir » et « Défi du jour » (ADR 0071) : une rangée sous le texte d'accueil ; null quand il n'y a
  /// rien à y mettre (premiers jours : pas encore de série, rien d'acquis à revoir).
  Widget? _strip(BuildContext context, AppState s, Universe u) {
    final streak = s.streak();
    final due = s.dueReviews();
    final daily = s.dailyChallengePlan();
    final done = s.dailyDone();
    Future<void> go(Widget page) async {
      _greeting?.close();
      await s.voice.stop();
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
      await s.refresh();
    }

    final pills = [
      if (_update != null)
        HomePill(
          icon: Icons.system_update_rounded,
          color: Brand.pink,
          label: t('Mise à jour'),
          semantics: tf('Nouvelle version {v} : demande à un adulte', {'v': _update!.version}),
          onTap: () => openParentSpace(context),
        ),
      if (streak.days >= 2)
        HomePill(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFB3400F),
          label: tf('{n} jours', {'n': streak.days}),
          semantics: tf('Série : {n} jours de jeu', {'n': streak.days}),
        ),
      if (due.isNotEmpty)
        HomePill(
          icon: Icons.replay_circle_filled_rounded,
          color: Brand.teal,
          label: t('À revoir'),
          count: due.length,
          semantics: tf('À revoir aujourd’hui : {n} notions', {'n': due.length}),
          onTap: () => go(SessionPage.review(due)),
        ),
      if (daily != null)
        HomePill(
          icon: done ? Icons.check_circle_rounded : Icons.bolt_rounded,
          color: done ? green : Brand.purple,
          label: done ? t('Défi réussi') : t('Défi du jour'),
          semantics: done ? t('Défi du jour : réussi, rejouer') : t('Défi du jour'),
          onTap: () => go(SessionPage.daily(daily)),
        ),
    ];
    if (pills.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: homeStripHeight - 8,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, p) in pills.indexed) ...[if (i > 0) const SizedBox(width: 8), Expanded(flex: p.onTap == null ? 2 : 3, child: p)],
        ]),
      ),
    );
  }

  /// « Tout explorer » : les trois du jour sont proposées, tout le reste reste ouvert (ADR 0032).
  Widget _exploreButton(BuildContext context, AppState s, Universe u) =>
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: surface,
                side: BorderSide(color: u.night ? u.primary : u.onCard, width: 3),
                textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 22, fontWeight: FontWeight.w700),
                foregroundColor: ink,
              ),
              onPressed: () async {
                await s.voice.stop();
                if (!context.mounted) return;
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllTopicsPage()));
                await s.refresh();
              },
              icon: const Art('1f9ed', size: 32),
              // « Explore everything » est plus long : il rétrécit plutôt que de passer sur deux lignes coupées.
              label: FittedBox(fit: BoxFit.scaleDown, child: Text(t('Tout explorer'), maxLines: 1)),
            ),
          ),
        );

  /// Album, Mes livres (le plus grand bouton de la rangée, avec son nom écrit, ADR 0026) et le choix du monde. Le bouton
  /// du milieu rétrécit sur téléphone : la rangée ne déborde jamais.
  Widget _bottomRow(BuildContext context, AppState s, Universe u) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        // Le bouton « Mes livres » prend la place du milieu. Dans la colonne de 300 dp du paysage, il ne restait que
        // ~100 dp : le texte tombait à moins de la moitié de sa taille (signalé par Antsa, 2026-11-07). Quand la rangée est
        // étroite, les ronds passent à 60 dp (toujours ≥ 48) et « Mes livres » s'écrit sur deux lignes au lieu de rétrécir.
        child: LayoutBuilder(builder: (context, k) {
          final narrow = k.maxWidth < 360;
          final round = narrow ? 60.0 : 72.0;
          final gap = narrow ? 8.0 : 12.0;
          return Row(children: [
            _RoundButton(
              size: round,
              color: surface,
              tooltip: t('Mon album'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlbumPage())),
              child: Icon(Icons.collections_bookmark_rounded, size: narrow ? 32 : 38, color: ink),
            ),
            SizedBox(width: gap),
            // Mes livres : le plus grand bouton de la rangée, avec son nom écrit (ADR 0026).
            Expanded(
              child: Center(
                child: Semantics(
                  button: true,
                  label: t('Mes livres'),
                  excludeSemantics: true,
                  child: Material(
                    color: u.primary,
                    elevation: 3,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () async {
                        await s.voice.stop();
                        if (!context.mounted) return;
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LibraryPage()));
                        await s.refresh();
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: round),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(narrow ? 10 : 14, 6, narrow ? 12 : 20, 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Art('1f4da', size: narrow ? 36 : 48),
                            SizedBox(width: narrow ? 6 : 10),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  narrow ? t('Mes livres').replaceFirst(' ', '\n') : t('Mes livres'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: narrow ? 20 : 24, fontWeight: FontWeight.w700, color: u.onPrimary, height: 1.05),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: gap),
            _RoundButton(
              size: round,
              color: surface,
              tooltip: t('Changer de monde'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UniversePicker())),
              child: Art(u.mascot, size: narrow ? 40 : 48),
            ),
          ]);
        }),
      );
}

/// Une activité du jour : icône du domaine, nom écrit, barre du temps fait, et un rond d'action (▶ ou ✔ « Fini »).
/// La carte suivante à faire a un contour épais et un ▶ qui pulse ; l'état ne repose jamais sur la couleur seule.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.topic,
    required this.item,
    required this.number,
    required this.next,
    required this.pulse,
    required this.wide,
    required this.onTap,
    this.compact,
  });
  final Topic topic;
  final DayItem item;
  final int number;
  final bool next, wide;

  /// Version compacte (disque et bouton plus petits) : null, c'est la largeur de la carte qui décide ; la mise en page
  /// l'impose quand la hauteur manque (ADR 0052).
  final bool? compact;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, k) => _build(context, compact: compact ?? (!wide && k.maxWidth < 440)));

  /// [compact] : téléphone en portrait (carte de moins de 440 dp) — icône et bouton plus petits, nom sur deux lignes,
  /// pour que le nom du domaine ne soit jamais coupé.
  Widget _build(BuildContext context, {required bool compact}) {
    final u = AppScope.of(context).universe;
    final disc = compact ? 72.0 : 104.0;
    final accent = u.night ? u.primary : u.onCard;
    final done = item.finished;
    final icon = Stack(clipBehavior: Clip.none, children: [
      Container(
        width: disc,
        height: disc,
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Art(topic.icon, size: disc * 0.65),
      ),
      Positioned(
        left: -4,
        top: -4,
        child: CircleAvatar(
          radius: 17,
          backgroundColor: ink,
          child: Text('$number', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ]);
    final bar = Container(
      height: 16,
      decoration: BoxDecoration(color: const Color(0xFFE3E7E4), borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: item.ratio, heightFactor: 1, child: ColoredBox(color: done ? green : accent)),
        ),
      ),
    );
    final action = done
        ? Column(mainAxisSize: MainAxisSize.min, children: [
            const CircleAvatar(radius: 28, backgroundColor: green, child: Icon(Icons.check_rounded, size: 40, color: Colors.white)),
            const SizedBox(height: 2),
            Text(t('Fini'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: green)),
          ])
        : AnimatedBuilder(
            animation: pulse,
            builder: (_, child) => Transform.scale(scale: next ? 1 + 0.08 * pulse.value : 1, child: child),
            child: CircleAvatar(
              radius: compact ? 30 : 38,
              backgroundColor: next ? u.primary : const Color(0xFFE3E7E4),
              child: Icon(Icons.play_arrow_rounded, size: compact ? 44 : 56, color: next ? u.onPrimary : ink),
            ),
          );
    // Nom jamais coupé : deux lignes au besoin, et il rétrécit plutôt que de finir en « … ».
    final name = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: wide ? Alignment.center : Alignment.centerLeft,
      child: Text(topic.name, maxLines: 2, textAlign: wide ? TextAlign.center : TextAlign.start, style: TextStyle(fontFamily: 'Fredoka', fontSize: compact ? 25 : 29, fontWeight: FontWeight.w700, color: ink)),
    );
    final minutes = item.done.inMinutes;
    return Semantics(
      button: true,
      label: tf('{name}, {minutes} minutes sur {target}', {'name': topic.name, 'minutes': minutes, 'target': item.target.inMinutes}) + (done ? t(', fini') : ''),
      excludeSemantics: true,
      child: Material(
        color: surface,
        elevation: next ? 6 : 2,
        shadowColor: const Color(0x55000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: next ? u.primary : Colors.transparent, width: next ? 6 : 0),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 16),
            child: wide
                ? Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [icon, name, bar, action])
                : Row(children: [
                    icon,
                    SizedBox(width: compact ? 10 : 16),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        name,
                        const SizedBox(height: 12),
                        bar,
                      ]),
                    ),
                    SizedBox(width: compact ? 8 : 16),
                    action,
                  ]),
          ),
        ),
      ),
    );
  }
}

/// Bandeau « journée finie » : coupe, texte écrit (les cartes restent jouables, le parent règle la durée).
class _DayDone extends StatelessWidget {
  const _DayDone({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFEAF5EC), borderRadius: BorderRadius.circular(24), border: Border.all(color: green, width: 3)),
          child: Row(children: [
            const Art('1f3c6', size: 52),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink))),
          ]),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onListen, this.update = false});
  final VoidCallback onListen;

  /// Une nouvelle version attend : une pastille sur le cadenas de l'espace parent.
  final bool update;

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).universe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(children: [
        // Logo-texte de l'app (ADR 0027) ; il rétrécit plutôt que de pousser les boutons hors de l'écran.
        Flexible(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SvgPicture.asset('assets/logo/wordmark.svg', height: 76, semanticsLabel: "Zanak'i Antsa"),
          ),
        ),
        // Plusieurs enfants : le prénom de celui qui joue, pour changer (ADR 0034).
        if (AppScope.of(context).profiles.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Art('1f9d2', size: 24),
              label: Text(AppScope.of(context).current.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              backgroundColor: surface,
              onPressed: AppScope.of(context).askWhoPlays,
            ),
          ),
        const Spacer(),
        _RoundButton(size: 56, color: surface, tooltip: t('Réécouter'), onPressed: onListen, child: Icon(Icons.volume_up_rounded, color: u.onCard, size: 32)),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: update,
          backgroundColor: Brand.pink,
          smallSize: 14,
          child: _RoundButton(
            size: 48,
            color: surface,
            tooltip: update ? t('Espace parent : nouvelle version disponible') : t('Espace parent'),
            onPressed: () => openParentSpace(context),
            child: const Icon(Icons.lock_outline, color: Color(0xFF5F6B63), size: 24),
          ),
        ),
      ]),
    );
  }
}

/// La mascotte se présente, puis raconte l'épisode gagné (ADR 0017) : texte écrit sur une carte (jamais directement
/// sur le décor).
class _Intro extends StatelessWidget {
  const _Intro({required this.words, required this.sessions, required this.universe});
  final UniverseWords words;
  final int sessions;
  final Universe universe;

  @override
  Widget build(BuildContext context) {
    final e = words.episode(sessions);
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
          child: Row(children: [
            Art(universe.mascot, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (e != null) EpisodeLabel(index: e, count: words.story.length),
                Text(e == null ? words.intro : words.story[e], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink, height: 1.2)),
              ]),
            ),
          ]),
        ),
      );
  }
}

class _AskAdult extends StatelessWidget {
  const _AskAdult({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.family_restroom_rounded, size: 96, color: ink),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: ink)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 22)),
              onPressed: () => openParentSpace(context),
              icon: const Icon(Icons.lock_outline),
              label: Text(t('Espace parent')),
            ),
          ]),
        ),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.size, required this.color, required this.tooltip, required this.onPressed, required this.child});
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(width: size, height: size, child: Center(child: child)),
            ),
          ),
        ),
      );
}

/// Choix de l'univers : seulement ceux du genre de l'enfant (ADR 0014), nom écrit et dit.
class UniversePicker extends StatelessWidget {
  const UniversePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Row(children: [
              const SizedBox(width: 8),
              _RoundButton(
                size: 56,
                color: surface,
                tooltip: t('Retour'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Icon(Icons.arrow_back_rounded, color: ink, size: 32),
              ),
              const SizedBox(width: 12),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: PlayfulTitle(s.common.text('choisis_univers')))),
            ]),
            Expanded(
              child: LayoutBuilder(
                builder: (_, k) {
                  final wide = k.maxWidth > k.maxHeight;
                  final cards = [
                    for (final c in s.choices)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _UniverseCard(
                            universe: c,
                            name: s.words[c.id]!.name,
                            selected: c.id == u.id,
                            onTap: () async {
                              await s.setUniverse(c.id);
                              s.voice.say(s.words[c.id]!.name);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                          ),
                        ),
                      ),
                  ];
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: wide ? Row(children: cards) : Column(children: cards),
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

class _UniverseCard extends StatelessWidget {
  const _UniverseCard({required this.universe, required this.name, required this.selected, required this.onTap});
  final Universe universe;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: name,
        excludeSemantics: true,
        child: Material(
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          child: InkWell(
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [universe.bg1, universe.bg2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: selected ? Border.all(color: gold, width: 6) : null,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Stack(children: [
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Art(universe.mascot, size: 72),
                    const SizedBox(width: 12),
                    Art(universe.objects.first, size: 48),
                    Art(universe.objects.last, size: 48),
                  ]),
                ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999)),
                    child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ink)),
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: CircleAvatar(radius: 18, backgroundColor: gold, child: Icon(Icons.check_rounded, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ),
      );
}

/// « Qui joue ? » (ADR 0034) : un grand bouton par enfant, avec la mascotte de son monde et son prénom écrit.
class ProfilePicker extends StatelessWidget {
  const ProfilePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SvgPicture.asset('assets/logo/wordmark.svg', height: 96, semanticsLabel: "Zanak'i Antsa"),
            ),
            PlayfulTitle(t('Qui joue ?'), size: 40),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children: [
                    for (final p in s.profiles)
                      Semantics(
                        button: true,
                        label: p.label,
                        excludeSemantics: true,
                        child: Material(
                          color: surface,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32), side: BorderSide(color: u.night ? u.primary : u.onCard, width: 4)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () => s.switchChild(p.id),
                            child: SizedBox(
                              width: 200,
                              height: 220,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Art('1f9d2', size: 96),
                                const SizedBox(height: 12),
                                Text(p.label, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 30, fontWeight: FontWeight.w700, color: ink)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Une pastille de la rangée de l'accueil (ADR 0071) : icône, texte écrit, et un nombre éventuel. Avec [onTap], c'est un
/// bouton en relief (≥ 48 dp) ; sans, une simple étiquette plate (la série de jours ne se touche pas).
class HomePill extends StatelessWidget {
  const HomePill({super.key, required this.icon, required this.color, required this.label, required this.semantics, this.count, this.onTap});
  final IconData icon;
  final Color color;
  final String label, semantics;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: semantics,
        excludeSemantics: true,
        child: Material(
          color: surface,
          elevation: onTap == null ? 0 : 3,
          shape: StadiumBorder(side: BorderSide(color: onTap == null ? const Color(0x401B211D) : color, width: onTap == null ? 2 : 3)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 34),
                  const SizedBox(width: 6),
                  Text(label, maxLines: 1, style: const TextStyle(fontFamily: 'Fredoka', fontSize: 21, fontWeight: FontWeight.w700, color: ink)),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    CircleAvatar(radius: 15, backgroundColor: color, child: Text('$count', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}
