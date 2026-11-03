import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../books/books.dart';
import '../core/events.dart';
import 'theme.dart';
import 'universe.dart';

/// Icône de chaque étagère (Twemoji) ; l'étagère « Tout » a la pile de livres.
const shelfIcons = {
  'tout': '1f4da', 'apprendre': '1f4a1', 'nature': '1f331', 'vie': '1f3e0', 'contes': '1f3f0', 'curiosite': '1f52d', 'grands': '1f4dc',
};

/// Ma bibliothèque (docs/design.md § 6, ADR 0026) : étagères en puces, couvertures en grille, ✔ « Lu ».
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String shelf = 'tout';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.universe;
    final lib = app.library;
    final read = app.booksRead;
    final books = [for (final b in lib.books) if (shelf == 'tout' || b.shelf == shelf) b];
    final last = lib.books.where((b) => b.id == app.lastBook).firstOrNull;
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
                  child: IconButton(
                    tooltip: 'Retour',
                    iconSize: 32,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: PlayfulTitle('Ma bibliothèque'))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(999), boxShadow: cardShadow),
                  child: Text('${read.length} lu${read.length > 1 ? 's' : ''} / ${lib.books.length}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
                ),
              ]),
            ),
            // Étagères : icône + nom écrit ; celle choisie a un contour épais et une ✔. Toutes visibles (plusieurs
            // rangées au besoin) : rien de caché derrière un défilement.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  for (final (id, name) in [('tout', 'Tout'), ...lib.shelves.entries.map((e) => (e.key, e.value))])
                    ChoiceChip(
                      selected: shelf == id,
                      showCheckmark: true,
                      avatar: Art(shelfIcons[id] ?? '1f4da', size: 24),
                      label: Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      side: BorderSide(color: shelf == id ? (u.night ? u.primary : u.onCard) : const Color(0xFFD5DBD7), width: shelf == id ? 3 : 1),
                      backgroundColor: surface,
                      selectedColor: surface,
                      onSelected: (_) => setState(() => shelf = id),
                    ),
                ],
              ),
            ),
            if (last != null) _Continue(book: last, page: app.bookmarks[last.id], onDone: () => setState(() {})),
            Expanded(
              child: GridView.extent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.72,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [for (final b in books) _BookCover(book: b, read: read.contains(b.skillId), mark: app.bookmarks[b.id], onDone: () => setState(() {}))],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Ruban de marque-page qui dépasse du haut de la couverture, avec le numéro de page écrit.
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _RibbonClipper(),
        child: Container(
          width: 46,
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 16),
          color: const Color(0xFFD62828),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.bookmark_rounded, color: Colors.white, size: 18),
            Text('p. $page', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      );
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width / 2, s.height - 10)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_RibbonClipper old) => false;
}

/// « Niveau 2 » écrit + pastilles pleines (niveaux d'African Storybook : 1 premiers mots … 5 lecteurs autonomes).
class LevelLabel extends StatelessWidget {
  const LevelLabel(this.level, {super.key});
  final int level;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text('Niveau $level', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63))),
        const SizedBox(width: 4),
        for (var i = 1; i <= 5; i++)
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i <= level ? green : null, border: Border.all(color: i <= level ? green : const Color(0xFF8A948E), width: 1.5)),
          ),
      ]);
}

/// Ouvre la liseuse, puis rafraîchit la bibliothèque au retour (marque-pages, livres lus).
Future<void> openBook(BuildContext context, Book book, VoidCallback onDone) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(book: book)));
  onDone();
}

/// « Mon livre en cours » : le dernier livre ouvert, sa page marquée, et « Reprendre » (ou « Relire » s'il est fini).
class _Continue extends StatelessWidget {
  const _Continue({required this.book, required this.page, required this.onDone});
  final Book book;
  final int? page;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, k) => _build(context, compact: k.maxWidth < 560));

  /// [compact] (téléphone) : bouton rond ▶ au lieu de « Reprendre » écrit, pour laisser la place au titre.
  Widget _build(BuildContext context, {required bool compact}) {
    final u = AppScope.of(context).universe;
    final cover = book.cover;
    final resume = page == null ? 'Relire' : 'Reprendre';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: u.night ? u.primary : u.onCard, width: 4)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openBook(context, book, onDone),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(width: compact ? 64 : 84, height: compact ? 64 : 84, child: cover == null ? const ColoredBox(color: Color(0xFFF1F3F2)) : Image.asset(cover, fit: BoxFit.cover, cacheWidth: 200)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.bookmark_rounded, color: u.night ? u.primary : u.onCard, size: 22),
                    const SizedBox(width: 4),
                    const Text('Mon livre en cours', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF5F6B63))),
                  ]),
                  Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 19 : 22, fontWeight: FontWeight.w700, color: ink, height: 1.15)),
                  Text(page == null ? 'Fini — tu peux le relire' : 'Page ${page! + 1} sur ${book.pages.length}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                ]),
              ),
              const SizedBox(width: 8),
              IgnorePointer(
                child: compact
                    ? CircleAvatar(
                        radius: 32,
                        backgroundColor: u.primary,
                        child: Icon(page == null ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 40, color: u.onPrimary, semanticLabel: resume),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 64), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 20, fontWeight: FontWeight.w700)),
                        onPressed: () {},
                        icon: Icon(page == null ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 32),
                        label: Text(resume),
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book, required this.read, required this.mark, required this.onDone});
  final Book book;
  final bool read;

  /// Page marquée (livre commencé, pas fini) : un ruban « p. 4 ».
  final int? mark;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final cover = book.cover;
    return Semantics(
      button: true,
      label: '${book.title}, niveau ${book.level}${read ? ', lu' : ''}${mark != null ? ', marque-page page ${mark! + 1}' : ''}',
      excludeSemantics: true,
      child: Material(
        color: surface,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openBook(context, book, onDone),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                if (cover != null) Image.asset(cover, fit: BoxFit.cover, cacheWidth: 400) else const ColoredBox(color: Color(0xFFF1F3F2)),
                if (mark != null)
                  Positioned(
                    left: 10,
                    top: 0,
                    child: _Ribbon(page: mark! + 1),
                  ),
                if (read)
                  const Positioned(
                    right: 6,
                    top: 6,
                    child: Chip(
                      avatar: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      label: Text('Lu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      backgroundColor: green,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink, height: 1.15)),
                const SizedBox(height: 4),
                LevelLabel(book.level),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Liseuse : image, texte en grand, ◀ ▶ et glisser, « Lis-moi » (lecture à voix haute qui tourne les pages), page
/// « Fin » avec les crédits exigés par la licence CC BY 4.0.
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.book});
  final Book book;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late final AppState app = AppScope.of(context);
  late final int _startPage = (app.bookmarks[widget.book.id] ?? 0).clamp(0, widget.book.pages.length - 1);
  late final _pages = PageController(initialPage: _startPage);
  final _started = DateTime.now();
  late int page = _startPage;

  @override
  void initState() {
    super.initState();
    // Ouvrir un livre en fait le « dernier livre lu », à sa page marquée.
    WidgetsBinding.instance.addPostFrameCallback((_) => app.setBookmark(book.id, page));
  }
  bool reading = false, _finished = false;

  Book get book => widget.book;
  int get count => book.pages.length + 1; // + la page « Fin »

  @override
  void dispose() {
    reading = false;
    app.voice.stop();
    if (DateTime.now().difference(_started) > const Duration(seconds: 20)) {
      app.logSession(SessionLog(theme: 'lecture', started: _started, ended: DateTime.now(), complete: _finished));
    }
    _pages.dispose();
    super.dispose();
  }

  Future<void> _go(int p) => _pages.animateToPage(p.clamp(0, count - 1), duration: const Duration(milliseconds: 350), curve: Curves.easeOut);

  Future<void> _onPage(int p) async {
    setState(() => page = p);
    if (p < count - 1) await app.setBookmark(book.id, p);
    if (p == count - 1 && !_finished) {
      _finished = true;
      await app.clearBookmark(book.id);
      if (!app.booksRead.contains(book.skillId)) {
        await app.record(Answer(
          skill: book.skillId,
          attempts: 1,
          correct: true,
          demonstrated: false,
          millis: DateTime.now().difference(_started).inMilliseconds,
          at: DateTime.now(),
        ));
        app.voice.fanfare();
      }
    }
  }

  /// Lis-moi : dit la page, passe à la suivante, jusqu'à la fin ou un nouveau toucher.
  Future<void> _readAloud() async {
    if (reading) {
      setState(() => reading = false);
      await app.voice.stop();
      return;
    }
    setState(() => reading = true);
    if (page == 0) await app.voice.say(book.title, force: true);
    while (reading && mounted && page < count - 1) {
      await app.voice.say(book.pages[page].text, force: true);
      if (!reading || !mounted) break;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!reading || !mounted) break;
      await _go(page + 1);
    }
    if (mounted) setState(() => reading = false);
  }

  @override
  Widget build(BuildContext context) {
    final u = app.universe;
    return Scaffold(
      body: UniverseBackground(
        universe: u,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
              child: Row(children: [
                Material(
                  color: surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(tooltip: 'Retour', iconSize: 32, onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back_rounded, color: ink)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: u.onBackground, height: 1.1))),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56), textStyle: const TextStyle(fontFamily: 'Andika', fontSize: 20, fontWeight: FontWeight.w700)),
                  onPressed: _readAloud,
                  icon: Icon(reading ? Icons.stop_rounded : Icons.record_voice_over_rounded, size: 30),
                  label: Text(reading ? 'Stop' : 'Lis-moi'),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: _onPage,
                itemBuilder: (_, i) => i < book.pages.length ? _Page(book: book, page: book.pages[i]) : _End(book: book),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                _NavButton(icon: Icons.arrow_back_ios_new_rounded, label: 'Page précédente', onTap: page == 0 ? null : () => _go(page - 1)),
                Expanded(
                  child: Text(page < count - 1 ? '${page + 1} / ${book.pages.length}' : 'Fin',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: u.onBackground)),
                ),
                _NavButton(icon: Icons.arrow_forward_ios_rounded, label: 'Page suivante', onTap: page >= count - 1 ? null : () => _go(page + 1)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 72,
        height: 72,
        child: FilledButton(
          style: FilledButton.styleFrom(shape: const CircleBorder(), padding: EdgeInsets.zero, disabledBackgroundColor: const Color(0xFFBFC7C1)),
          onPressed: onTap,
          child: Icon(icon, size: 36, semanticLabel: label),
        ),
      );
}

class _Page extends StatelessWidget {
  const _Page({required this.book, required this.page});
  final Book book;
  final BookPage page;

  @override
  Widget build(BuildContext context) {
    final img = book.imagePath(page);
    return LayoutBuilder(builder: (_, k) {
      final wide = k.maxWidth > k.maxHeight * 1.1;
      final picture = img == null
          ? const SizedBox.shrink()
          : Container(
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
              clipBehavior: Clip.antiAlias,
              // Décodée à la largeur de l'écran, pas plus (ADR 0028).
              child: Image.asset(img, fit: BoxFit.contain, cacheWidth: (k.maxWidth * MediaQuery.devicePixelRatioOf(context)).round().clamp(240, 720)),
            );
      final text = page.text.isEmpty
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(24), boxShadow: cardShadow),
              child: Text(page.text, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: ink, height: 1.3)),
            );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: wide
            ? Row(children: [Expanded(child: Center(child: picture)), const SizedBox(width: 16), Expanded(child: Center(child: SingleChildScrollView(child: text)))])
            : Column(children: [
                Expanded(flex: 3, child: Center(child: picture)),
                const SizedBox(height: 12),
                Flexible(flex: 2, child: SingleChildScrollView(child: text)),
              ]),
      );
    });
  }
}

/// Page « Fin » : bravo, et les crédits du livre, toujours lisibles (licence CC BY 4.0).
class _End extends StatelessWidget {
  const _End({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 640),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(28), boxShadow: cardShadow),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Art('1f4da', size: 80),
              const SizedBox(height: 8),
              const PlayfulTitle('Fin', size: 44),
              const SizedBox(height: 4),
              const Text('Bravo, tu as lu tout le livre !', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ink)),
              const Divider(height: 32),
              Text(book.credits, style: const TextStyle(fontSize: 15, color: Color(0xFF5F6B63), height: 1.35)),
              const SizedBox(height: 6),
              Text('Licence ${book.licence} — ${book.source}', style: const TextStyle(fontSize: 14, color: Color(0xFF5F6B63))),
            ]),
          ),
        ),
      );
}
