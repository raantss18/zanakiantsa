/// Vidéos éducatives (ADR 0068) : liste de départ, recherche dans les chaînes choisies, « Vu », lecteur officiel YouTube.
/// Demande internet ; le catalogue (site/videos.json, mis à jour chaque jour) est gardé pour s'afficher hors connexion.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../parent/gate.dart';
import '../videos/catalog.dart';
import 'adaptive.dart';
import 'chess_play.dart' show pageHeader;
import 'theme.dart';
import 'universe.dart';

/// Le catalogue gardé de cet enfant (langue et âge) et sa date ; null s'il n'a jamais été chargé.
Future<(Catalogue, DateTime?)?> keptCatalogue(AppState app, String key) async {
  final kept = await app.store.get('videos_cat_$key');
  if (kept == null || kept.isEmpty) return null;
  final when = DateTime.tryParse(await app.store.get('videos_cat_${key}_date') ?? '');
  return (Catalogue(jsonDecode(kept) as Map<String, dynamic>), when);
}

/// Télécharge le catalogue de cet enfant et le garde ; null sans connexion (ou trop lente : 60 s au plus).
Future<Catalogue?> fetchCatalogue(AppState app, String key) async {
  try {
    final r = await http.get(catalogueUri(key)).timeout(const Duration(seconds: 60));
    if (r.statusCode != 200) return null;
    final body = utf8.decode(r.bodyBytes);
    final c = Catalogue(jsonDecode(body) as Map<String, dynamic>);
    await app.store.set('videos_cat_$key', body);
    await app.store.set('videos_cat_${key}_date', DateTime.now().toIso8601String());
    // L'ancien catalogue complet (1.0.6–1.0.7, ≈ 3 Mo) ne sert plus.
    await app.store.set('videos_catalogue', '');
    return c;
  } catch (_) {
    return null;
  }
}

Future<Set<String>> seenVideos(AppState app) async {
  final raw = await app.store.get('videos_vues');
  return raw == null ? {} : Set<String>.from(jsonDecode(raw) as List);
}

/// Vidéos masquées par un parent (derrière la porte parent) : l'enfant ne les revoit plus, ni dans la liste ni en recherche.
Future<Set<String>> hiddenVideos(AppState app) async {
  final raw = await app.store.get('videos_masquees');
  return raw == null ? {} : Set<String>.from(jsonDecode(raw) as List);
}

Future<void> hideVideo(AppState app, String id) async {
  final hidden = await hiddenVideos(app)
    ..add(id);
  await app.store.set('videos_masquees', jsonEncode(hidden.toList()));
}

Future<void> markSeen(AppState app, String id) async {
  final seen = await seenVideos(app)
    ..add(id);
  await app.store.set('videos_vues', jsonEncode(seen.toList()));
}

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});
  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  late final AppState app = AppScope.of(context);
  Catalogue? catalogue;
  bool loading = true;

  /// Toujours rien après quelques secondes : on dit que la connexion est lente (au lieu d'un rond qui tourne seul).
  bool slow = false;
  Set<String> seen = {}, hidden = {};
  String query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  /// La copie gardée s'affiche tout de suite ; le site n'est interrogé que si elle a plus de 12 h, en arrière-plan.
  Future<void> _load() async {
    await app.voice.stopAll();
    final key = catalogueKey(appLang, app.age);
    final kept = await keptCatalogue(app, key);
    final s = await seenVideos(app);
    final h = await hiddenVideos(app);
    if (!mounted) return;
    setState(() {
      catalogue = kept?.$1;
      seen = s;
      hidden = h;
      loading = kept == null;
    });
    final when = kept?.$2;
    if (when != null && DateTime.now().difference(when) < const Duration(hours: 12)) return;
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && loading) setState(() => slow = true);
    });
    final fresh = await fetchCatalogue(app, key);
    if (!mounted) return;
    setState(() {
      catalogue = fresh ?? catalogue;
      loading = false;
    });
  }

  List<Video> get pool => [
    for (final v
        in catalogue?.forChild(age: app.age, lang: appLang) ?? const <Video>[])
      if (!hidden.contains(v.id)) v,
  ];

  Future<void> _play(Video v) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(video: v, pool: pool),
      ),
    );
    final s = await seenVideos(app);
    final h = await hiddenVideos(app);
    if (mounted) {
      setState(() {
        seen = s;
        hidden = h;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    final today = {for (final i in app.dayPlan().items) i.theme};
    final list = query.trim().isEmpty
        ? suggestions(pool, seen: seen, domains: today)
        : search(pool, query);
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(
            children: [
              pageHeader(context, t('Vidéos')),
              Padding(
                padding: readablePadding(context, bottom: 8).copyWith(top: 0),
                child: TextField(
                  onChanged: (q) => setState(() => query = q),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 22),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: surface,
                    prefixIcon: const Icon(Icons.search_rounded, size: 32),
                    hintText: t('Chercher une vidéo (volcans, Égypte…)'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: loading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            if (slow)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  t('Les vidéos arrivent… La connexion est lente, encore un peu de patience.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: u.onBackground),
                                ),
                              ),
                          ],
                        ),
                      )
                    : list.isEmpty
                    ? _empty()
                    : query.trim().isEmpty
                    // Rangées par matière (demande d'Antsa du 2026-11-08 : « facile à explorer de façon intuitive ») :
                    // « Pour toi » d'abord, puis les matières du jour, puis les autres ; chaque rangée défile de côté.
                    ? ListView(
                        padding: readablePadding(context, side: 0),
                        children: [
                          _Shelf(
                            art: '2b50',
                            title: t('Pour toi'),
                            videos: list.take(12).toList(),
                            seen: seen,
                            onPlay: _play,
                            onAll: null,
                          ),
                          for (final e in _subjects(today))
                            _Shelf(
                              art: app.topic(e.key).icon,
                              title: app.topic(e.key).name,
                              videos: e.value.take(12).toList(),
                              seen: seen,
                              onPlay: _play,
                              onAll: e.value.length > 12
                                  ? () => _openSubject(e.key, e.value)
                                  : null,
                            ),
                        ],
                      )
                    : ListView(
                        padding: readablePadding(context),
                        children: [
                          for (final v in list)
                            _VideoCard(
                              video: v,
                              seen: seen.contains(v.id),
                              onTap: () => _play(v),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Les matières qui ont des vidéos : celles du jour d'abord, puis un ordre fixe.
  List<MapEntry<String, List<Video>>> _subjects(Set<String> today) {
    const order = ['nature', 'explorer', 'compter', 'lire', 'anglais', 'code', 'motifs', 'echecs', 'dessin', 'sons'];
    final rows = bySubject(pool, seen: seen);
    final keys = [
      for (final k in order) if (today.contains(k) && rows.containsKey(k)) k,
      for (final k in order) if (!today.contains(k) && rows.containsKey(k)) k,
    ];
    return [for (final k in keys) MapEntry(k, rows[k]!)];
  }

  Future<void> _openSubject(String id, List<Video> videos) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SubjectPage(
          title: app.topic(id).name,
          videos: videos,
          seen: seen,
          onPlay: _play,
        ),
      ),
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            catalogue == null
                ? t(
                    'Il faut internet pour voir les vidéos. Reviens quand la tablette est connectée.',
                  )
                : query.trim().isEmpty
                ? t('Pas encore de vidéos pour ton âge. Elles arrivent bientôt.')
                : t('Aucune vidéo trouvée. Essaie un autre mot.'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ),
      ),
    ),
  );
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.seen,
    required this.onTap,
  });
  final Video video;
  final bool seen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      button: true,
      label:
          '${video.title}, ${video.channel.name}, ${video.length}${seen ? t(', déjà vue') : ''}',
      excludeSemantics: true,
      child: Material(
        color: surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              SizedBox(
                width: 168,
                height: 96,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      video.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFFF1F3F2)),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            video.length,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.shownTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              video.channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF5F6B63),
                              ),
                            ),
                          ),
                          // « Vu » : icône et mot, jamais la couleur seule.
                          if (seen) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 20,
                              color: green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              t('Vu'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: green,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Le lecteur officiel YouTube (IFrame API), en mode confidentialité renforcée (youtube-nocookie). Rien ne sort de l'app :
/// le titre, le logo et les vidéos suggérées n'ouvrent ni YouTube ni le navigateur. Vue à 60 % : marquée « Vu ». Après,
/// d'autres vidéos sont proposées, toujours dans les chaînes choisies.
/// Liste blanche stricte : une vidéo hors de la liste de l'enfant lancée dans le lecteur est arrêtée aussitôt, et un écran
/// de l'app couvre le lecteur en pause et à la fin (là où YouTube montre d'autres vidéos).
/// Plein écran : bouton du lecteur, bouton de l'app, ou tablette tournée ; le retour Android en sort.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.video, required this.pool});
  final Video video;
  final List<Video> pool;
  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final AppState app = AppScope.of(context);
  late final YoutubePlayerController controller =
      YoutubePlayerController.fromVideoId(
        videoId: widget.video.id,
        autoPlay: true,
        params: YoutubePlayerParams(
          privacyEnhancedMode: true,
          strictRelatedVideos: true,
          showVideoAnnotations: false,
          showFullscreenButton: true,
          playsInline: true,
          interfaceLanguage: appLang,
          captionLanguage: appLang,
        ),
      );
  bool marked = false;
  bool blocked = false;
  Set<String> seen = {};
  PlayerState state = PlayerState.unknown;

  @override
  void initState() {
    super.initState();
    // Aucune navigation hors du lecteur : ni YouTube, ni le navigateur, ni une vidéo hors des chaînes choisies.
    controller.webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (_) => NavigationDecision.prevent,
      ),
    );
    controller.videoStateStream.listen((s) {
      final total = widget.video.seconds;
      if (total > 0 && s.position.inSeconds >= total * 0.6) _seen();
    });
    // Vidéo finie : vue, même si la durée du catalogue était mal connue.
    controller.listen((v) {
      if (v.playerState == PlayerState.ended) _seen();
      if (v.playerState != state) {
        if (mounted) setState(() => state = v.playerState);
        if (v.playerState == PlayerState.buffering ||
            v.playerState == PlayerState.playing ||
            v.playerState == PlayerState.unStarted) {
          _check();
        }
      }
    });
    controller.setFullScreenListener(_fullScreen);
  }

  /// Vérifie la vidéo réellement chargée dans le lecteur : hors de la liste de l'enfant, elle est arrêtée.
  Future<void> _check() async {
    final String id;
    try {
      id = (await controller.videoData).videoId;
    } catch (_) {
      return;
    }
    if (!mounted || id == widget.video.id || allowedVideo(id, widget.pool)) {
      return;
    }
    await controller.stopVideo();
    if (mounted) setState(() => blocked = true);
  }

  Future<void> _hide() async {
    await controller.pauseVideo();
    if (!mounted || !await askParent(context)) return;
    await hideVideo(app, widget.video.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _back() async {
    setState(() => blocked = false);
    await controller.loadVideoById(videoId: widget.video.id);
  }

  /// Plein écran : barres du système cachées, tablette en paysage ; au retour, tout redevient comme avant.
  void _fullScreen(bool on) {
    SystemChrome.setEnabledSystemUIMode(
      on ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setPreferredOrientations(
      on
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [],
    );
  }

  /// Par-dessus le lecteur (en ligne et en plein écran) : en pause, à la fin ou sur une vidéo bloquée, un écran de
  /// l'app cache les vidéos que YouTube propose ; on y relance la lecture, et on entre ou sort du plein écran.
  Widget _controls(BuildContext context, bool fullScreen) {
    final cover =
        blocked || state == PlayerState.paused || state == PlayerState.ended;
    final full = Semantics(
      button: true,
      label: fullScreen ? t('Quitter le plein écran') : t('Plein écran'),
      child: _RoundButton(
        icon: fullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
        onTap: controller.toggleFullScreen,
      ),
    );
    if (!cover) return const SizedBox.shrink();
    final (IconData icon, String label, VoidCallback onTap) = blocked
        ? (Icons.replay, t('Revenir à ma vidéo'), _back)
        : state == PlayerState.ended
        ? (Icons.replay, t('Revoir'), () => controller.seekTo(seconds: 0))
        : (Icons.play_arrow_rounded, t('Reprendre'), controller.playVideo);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ColoredBox(
        color: const Color(0xE6000000),
        child: Stack(
          children: [
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (blocked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            t('Cette vidéo n\'est pas dans ta liste.'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(64, 64),
                          backgroundColor: Colors.white,
                          foregroundColor: ink,
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: Icon(icon, size: 36),
                        label: Text(label),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(right: 8, bottom: 8, child: full),
          ],
        ),
      ),
    );
  }

  Future<void> _seen() async {
    if (marked) return;
    marked = true;
    await markSeen(app, widget.video.id);
    final now = await seenVideos(app);
    if (mounted) setState(() => seen = now);
  }

  @override
  void dispose() {
    _fullScreen(false);
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = more(widget.pool, widget.video, {...seen, widget.video.id});
    return Scaffold(
      body: UniverseBackground(
        universe: app.universe,
        child: SafeArea(
          child: Column(
            children: [
              pageHeader(context, widget.video.channel.name),
              Expanded(
                child: ListView(
                  padding: readablePadding(context),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: YoutubePlayer(
                        controller: controller,
                        aspectRatio: 16 / 9,
                        controlsBuilder: _controls,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: controller.enterFullScreen,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 52),
                            backgroundColor: app.universe.onBackground,
                            foregroundColor: app.universe.night
                                ? ink
                                : Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          icon: const Icon(Icons.fullscreen, size: 28),
                          label: Text(t('Plein écran')),
                        ),
                        const Spacer(),
                        // Pour les parents (porte parent) : cette vidéo ne sera plus proposée sur cette tablette.
                        TextButton.icon(
                          onPressed: _hide,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 52),
                            foregroundColor: app.universe.onBackground,
                          ),
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(t('Masquer')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.video.shownTitle,
                      // Sur le fond du monde, pas sur une carte : sa couleur de texte (sombre sur fond sombre sinon).
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: app.universe.onBackground,
                      ),
                    ),
                    if (next.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        t('D\'autres vidéos'),
                        style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: app.universe.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final v in next)
                        _VideoCard(
                          video: v,
                          seen: false,
                          onTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  VideoPlayerPage(video: v, pool: widget.pool),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Icon(icon, size: 34, color: ink),
      ),
    ),
  );
}

/// Une rangée d'une matière : son image et son nom, puis des vignettes qui défilent de côté ; « Tout voir » ouvre la matière.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.art,
    required this.title,
    required this.videos,
    required this.seen,
    required this.onPlay,
    required this.onAll,
  });
  final String art, title;
  final List<Video> videos;
  final Set<String> seen;
  final void Function(Video) onPlay;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) {
    final u = AppScope.of(context).universe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
            child: Row(
              children: [
                Art(art, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontFamily: 'Fredoka', fontSize: 26, fontWeight: FontWeight.w700, color: u.onBackground),
                  ),
                ),
                if (onAll != null)
                  TextButton(
                    onPressed: onAll,
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: u.onBackground),
                    child: Text(t('Tout voir ›'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          SizedBox(
            // Image (135) + deux lignes de titre à la taille de texte de la tablette (vu en paysage : titre coupé).
            height: 135 + 2 * MediaQuery.textScalerOf(context).scale(17) * 1.2 + 26,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _VideoTile(video: videos[i], seen: seen.contains(videos[i].id), onTap: () => onPlay(videos[i])),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une vignette de rangée : grande image (la durée dessus, « Vu » si elle a été regardée), puis le titre sur deux lignes.
class _VideoTile extends StatelessWidget {
  const _VideoTile({required this.video, required this.seen, required this.onTap});
  final Video video;
  final bool seen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${video.title}, ${video.channel.name}, ${video.length}${seen ? t(', déjà vue') : ''}',
        excludeSemantics: true,
        child: SizedBox(
          width: 240,
          child: Material(
            color: surface,
            elevation: 2,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 240,
                    height: 135,
                    child: Stack(fit: StackFit.expand, children: [
                      Image.network(video.thumbnail, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF1F3F2))),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Text(video.length, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                      if (seen)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(6)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                Text(t('Vu'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: Text(video.shownTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ink, height: 1.15)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Toute une matière : ses vidéos en liste, pas vues d'abord.
class _SubjectPage extends StatelessWidget {
  const _SubjectPage({required this.title, required this.videos, required this.seen, required this.onPlay});
  final String title;
  final List<Video> videos;
  final Set<String> seen;
  final Future<void> Function(Video) onPlay;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: UniverseBackground(
        universe: app.universe,
        child: SafeArea(
          child: Column(children: [
            pageHeader(context, title),
            Expanded(
              child: ListView(
                padding: readablePadding(context),
                children: [
                  for (final v in videos) _VideoCard(video: v, seen: seen.contains(v.id), onTap: () => onPlay(v)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
