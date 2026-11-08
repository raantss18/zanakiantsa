/// Vidéos éducatives (ADR 0068) : le catalogue publié chaque jour sur le site (tool/videos.py), filtré pour l'enfant.
/// Pur Dart, testé dans `test/videos_test.dart`. Les vidéos se lisent avec le lecteur officiel YouTube (ui/videos.dart).
library;

/// Adresse du catalogue, publié avec le site (ADR 0055).
/// Essais seulement : `--dart-define=VIDEOS_URL=…` lit un autre catalogue (jamais dans une version publiée).
const catalogueUrl = String.fromEnvironment('VIDEOS_URL', defaultValue: 'https://raantss18.github.io/zanakiantsa/videos.json');

// Pas de limite de durée, à aucun âge : les vidéos longues sont acceptées tant que la chaîne est éducative (choix
// d'Antsa, 2026-11-08, qui remplace la limite de 10 min avant le lycée). Le tri se fait par la liste blanche.

class Channel {
  Channel(Map<String, dynamic> j)
    : id = j['id'] as String,
      name = j['nom'] as String,
      lang = j['langue'] as String,
      minAge = (j['ages'] as List)[0] as int,
      maxAge = (j['ages'] as List)[1] as int,
      domains = [for (final d in j['domaines'] as List) d as String];
  final String id, name, lang;
  final int minAge, maxAge;
  final List<String> domains;

  /// Un maximum de 18 veut dire « 18 ans et plus » : l'app n'a pas d'âge maximum (ADR 0057).
  bool fits(int age) => age >= minAge && (maxAge >= 18 || age <= maxAge);
}

class Video {
  Video(Map<String, dynamic> j, this.channel)
    : id = j['id'] as String,
      title = j['t'] as String,
      seconds = j['d'] as int,
      published = j['p'] as String,
      words = j['m'] as String? ?? '';
  final String id, title, published, words;
  final int seconds;
  final Channel channel;

  String get thumbnail => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';

  /// « 7 min », « 1 h 05 ».
  String get length {
    final m = (seconds / 60).round();
    return m < 60
        ? '$m min'
        : '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}';
  }
}

class Catalogue {
  Catalogue(Map<String, dynamic> j)
    : generated = j['genere'] as String?,
      channels = [
        for (final c in j['chaines'] as List? ?? const [])
          Channel(Map<String, dynamic>.from(c as Map)),
      ] {
    videos = [
      for (final v in j['videos'] as List? ?? const [])
        if ((v as Map)['c'] is int && v['c'] < channels.length)
          Video(Map<String, dynamic>.from(v), channels[v['c'] as int]),
    ];
  }
  final String? generated;
  final List<Channel> channels;
  late final List<Video> videos;

  /// Les vidéos pour cet enfant : chaînes de son âge et de la langue de l'app, quelle que soit la durée.
  List<Video> forChild({required int age, required String lang}) => [
    for (final v in videos)
      if (v.channel.lang == lang && v.channel.fits(age)) v,
  ];
}

/// Minuscules sans accents, pour chercher « foret » et trouver « Forêt ».
String fold(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i < 0 ? c : to[i]);
  }
  return b.toString();
}

/// Recherche de l'enfant, seulement dans les vidéos permises : chaque mot doit être dans le titre ou ses mots-clés.
List<Video> search(List<Video> pool, String query) {
  final words = fold(query)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 1 || RegExp(r'\d').hasMatch(w))
      .toList();
  if (words.isEmpty) return const [];
  return [
    for (final v in pool)
      if (words.every((w) => fold('${v.title} ${v.words}').contains(w))) v,
  ];
}

/// La liste de départ : d'abord les matières du jour et celles qu'il apprend, les vidéos pas encore vues avant celles déjà
/// vues, les plus récentes d'abord ; une chaîne n'occupe pas toute la liste (une sur trois au plus dans les premières).
List<Video> suggestions(
  List<Video> pool, {
  required Set<String> seen,
  Set<String> domains = const {},
  int count = 30,
}) {
  int score(Video v) =>
      (seen.contains(v.id) ? 0 : 2) +
      (v.channel.domains.any(domains.contains) ? 1 : 0);
  final sorted = [...pool]
    ..sort((a, b) {
      final s = score(b).compareTo(score(a));
      return s != 0 ? s : b.published.compareTo(a.published);
    });
  final out = <Video>[];
  final perChannel = <String, int>{};
  final limit = (count / 3).ceil();
  for (final v in sorted) {
    if (out.length >= count) break;
    if ((perChannel[v.channel.id] ?? 0) >= limit) continue;
    perChannel[v.channel.id] = (perChannel[v.channel.id] ?? 0) + 1;
    out.add(v);
  }
  // Peu de chaînes : on complète sans la limite.
  for (final v in sorted) {
    if (out.length >= count) break;
    if (!out.contains(v)) out.add(v);
  }
  return out;
}

/// Après une vidéo, d'autres à proposer : même chaîne ou mêmes matières, pas encore vues.
List<Video> more(
  List<Video> pool,
  Video after,
  Set<String> seen, {
  int count = 6,
}) => [
  for (final v in pool)
    if (v.id != after.id &&
        !seen.contains(v.id) &&
        (v.channel.id == after.channel.id ||
            v.channel.domains.any(after.channel.domains.contains)))
      v,
].take(count).toList();

/// Le lecteur ne joue que les vidéos permises à cet enfant (liste blanche, son âge, sa durée) : toute autre vidéo
/// lancée depuis le lecteur YouTube (fin de vidéo, vidéo suggérée) est arrêtée aussitôt.
bool allowedVideo(String id, List<Video> pool) =>
    id.isEmpty || pool.any((v) => v.id == id);
