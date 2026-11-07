/// Vidéos éducatives (ADR 0068) : liste de départ, recherche dans les chaînes choisies, « Vu », lecteur officiel YouTube.
/// Demande internet ; le catalogue (site/videos.json, mis à jour chaque jour) est gardé pour s'afficher hors connexion.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../videos/catalog.dart';
import 'adaptive.dart';
import 'chess_play.dart' show pageHeader;
import 'theme.dart';
import 'universe.dart';

/// Charge le catalogue : celui du site, sinon celui gardé de la dernière fois (null : jamais chargé).
Future<Catalogue?> loadCatalogue(AppState app) async {
  try {
    final r = await http
        .get(Uri.parse(catalogueUrl))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode == 200) {
      final body = utf8.decode(r.bodyBytes);
      final c = Catalogue(jsonDecode(body) as Map<String, dynamic>);
      await app.store.set('videos_catalogue', body);
      return c;
    }
  } catch (_) {
    // Pas de connexion : on prend la copie gardée.
  }
  final kept = await app.store.get('videos_catalogue');
  return kept == null
      ? null
      : Catalogue(jsonDecode(kept) as Map<String, dynamic>);
}

Future<Set<String>> seenVideos(AppState app) async {
  final raw = await app.store.get('videos_vues');
  return raw == null ? {} : Set<String>.from(jsonDecode(raw) as List);
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
  Set<String> seen = {};
  String query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  Future<void> _load() async {
    await app.voice.stopAll();
    final c = await loadCatalogue(app);
    final s = await seenVideos(app);
    if (mounted) {
      setState(() {
        catalogue = c;
        seen = s;
        loading = false;
      });
    }
  }

  List<Video> get pool =>
      catalogue?.forChild(
        age: app.age,
        classe: app.schoolClass,
        lang: appLang,
      ) ??
      const [];

  Future<void> _play(Video v) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(video: v, pool: pool),
      ),
    );
    final s = await seenVideos(app);
    if (mounted) setState(() => seen = s);
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
                    ? const Center(child: CircularProgressIndicator())
                    : list.isEmpty
                    ? _empty()
                    : ListView(
                        padding: readablePadding(context),
                        children: [
                          if (query.trim().isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                              child: Text(
                                t('Pour toi'),
                                style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: u.onBackground,
                                ),
                              ),
                            ),
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
                        video.title,
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
          showFullscreenButton: false,
          playsInline: true,
          interfaceLanguage: appLang,
          captionLanguage: appLang,
        ),
      );
  bool marked = false;
  Set<String> seen = {};

  @override
  void initState() {
    super.initState();
    // Aucune navigation hors du lecteur : ni YouTube, ni le navigateur, ni une vidéo hors des chaînes choisies.
    controller.webViewController.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (_) => NavigationDecision.prevent,
      ),
    );
    controller.videoStateStream.listen((s) async {
      final total = widget.video.seconds;
      if (!marked && total > 0 && s.position.inSeconds >= total * 0.6) {
        marked = true;
        await markSeen(app, widget.video.id);
        final now = await seenVideos(app);
        if (mounted) setState(() => seen = now);
      }
    });
  }

  @override
  void dispose() {
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
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.video.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: ink,
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
