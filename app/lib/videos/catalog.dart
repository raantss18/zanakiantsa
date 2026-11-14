/// Vidéos éducatives (ADR 0068) : le catalogue publié chaque jour sur le site (tool/videos.py), filtré pour l'enfant.
/// Pur Dart, testé dans `test/videos_test.dart`. Les vidéos se lisent avec le lecteur officiel YouTube (ui/videos.dart).
library;

/// Dossier des catalogues, publiés avec le site (ADR 0055) : un petit fichier par langue et par âge (fr-10.json…), pour ne
/// télécharger que le sien (≈ 50 Ko compressés à 10 ans, au lieu de ≈ 850 Ko ; lent sur un téléphone, signalé le 2026-11-08).
/// Essais seulement : `--dart-define=VIDEOS_BASE=…` lit d'autres catalogues (jamais dans une version publiée).
const videosBase = String.fromEnvironment('VIDEOS_BASE', defaultValue: 'https://raantss18.github.io/zanakiantsa/videos/');

/// Le catalogue d'un enfant : sa langue et son âge (de 5 à 18 ; 18 vaut pour tous les plus grands).
String catalogueKey(String lang, int age) => '$lang-${age.clamp(5, 18)}';

Uri catalogueUri(String key) => Uri.parse('$videosBase$key.json');

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

  /// Un identifiant YouTube : 11 caractères parmi lettres, chiffres, « - » et « _ ». Le catalogue vient du réseau : une
  /// entrée qui n'y ressemble pas est ignorée (audit du 2026-11-14), elle ne finit ni dans une adresse ni dans le lecteur.
  static final _idShape = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static bool validId(Object? id) => id is String && _idShape.hasMatch(id);

  String get thumbnail => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';

  /// Le titre à montrer, sans les mots-dièse (« #science ») que certaines chaînes y ajoutent.
  String get shownTitle {
    final t = title.replaceAll(RegExp(r'\s*#[^\s#]+'), '').trim();
    return t.isEmpty ? title : t;
  }

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
        if ((v as Map)['c'] is int && v['c'] < channels.length && Video.validId(v['id']))
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

/// Mots qui disent la matière d'une vidéo (titre et mots-clés, sans accents), en français et en anglais.
const _subjectWords = <String, List<String>>{
  'compter': ['math', 'nombre', 'calcul', 'fraction', 'geometri', 'equation', 'fonction', 'multipli', 'addition', 'soustraction',
    'division', 'pourcentage', 'probabilit', 'statisti', 'theoreme', 'algebre', 'angle', 'triangle', 'derivee', 'number',
    'equation', 'geometry', 'algebra', 'multiply', 'counting', 'compter', 'tables de'],
  'lire': ['lecture', 'lire', 'conjugaison', 'grammaire', 'orthographe', 'verbe', 'poeme', 'poesie', 'roman', 'livre',
    'phonics', 'letter', 'reading', 'story', 'alphabet', 'mots ', 'syllabe', 'dictee', 'book'],
  'nature': ['science', 'physique', 'chimie', 'biolog', 'corps', 'animal', 'animaux', 'plante', 'cellule', 'energie',
    'electri', 'volcan', 'climat', 'atome', 'espece', 'dinosaure', 'insecte', 'ocean', 'physics', 'chemistry', 'animal',
    'plant', 'cell', 'energy', 'experience', 'experiment', 'biodivers', 'foret', 'jungle', 'nature', 'cerveau', 'brain', 'virus', 'adn', 'dna', 'evolution'],
  'explorer': ['histoire', 'guerre', 'roi ', 'revolution', 'geographi', 'pays', 'carte', 'monde', 'espace', 'planete',
    'etoile', 'univers', 'lune', 'soleil', 'philosoph', 'antiquite', 'moyen age', 'empire', 'history', 'war', 'country',
    'space', 'planet', 'star', 'universe', 'moon', 'ancient', 'galax', 'mars', 'nasa', 'mediev', 'chateau', 'chevalier',
    'pharaon', 'romain', 'gaulois', 'castle', 'medieval', 'knight', 'pharaoh', 'roman '],
  'anglais': ['english', 'anglais', 'vocabulary', 'pronunciation', 'learn english'],
  'code': ['code', 'coding', 'programm', 'informatique', 'algorithm', 'python', 'scratch', 'ordinateur', 'internet', 'cyber',
    'computer', 'robot', 'intelligence artificielle', 'hack'],
  'echecs': ['echec', 'chess', 'ouverture', 'gambit', 'partie'],
  'dessin': ['dessin', 'dessiner', 'peinture', 'peindre', 'tableau', 'draw', 'paint', 'art '],
  'sons': ['musique', 'chanson', 'instrument', 'rythme', 'music', 'song', 'orchestre', 'piano'],
  'motifs': ['enigme', 'logique', 'puzzle', 'casse-tete', 'riddle', 'sudoku', 'quiz', 'paradox'],
};

/// La matière d'une vidéo, parmi celles de sa chaîne : celle dont les mots reviennent le plus dans son titre et ses
/// mots-clés ; sans indice, la première de la chaîne. Une vidéo d'Alloprof sur les volcans va dans « Sciences », pas dans
/// toutes les matières de la chaîne.
String videoSubject(Video v) {
  final text = ' ${fold('${v.title} ${v.words}')} ';
  var best = v.channel.domains.isEmpty ? 'explorer' : v.channel.domains.first;
  var top = 0;
  for (final d in v.channel.domains) {
    final n = (_subjectWords[d] ?? const []).where(text.contains).length;
    if (n > top) {
      top = n;
      best = d;
    }
  }
  return best;
}

/// Une rangée de matière sous « Pour toi » : celles qui n'y sont pas d'abord (vu le 2026-11-13 : la même vidéo ouvrait
/// « Pour toi » et « Les sciences »), puis les autres, dans le même ordre. Rien n'est retiré : « Tout voir » reste complet.
List<Video> shownLast(List<Video> row, Set<String> shown) =>
    [for (final v in row) if (!shown.contains(v.id)) v, for (final v in row) if (shown.contains(v.id)) v];

/// Les vidéos rangées par matière, chaque rangée dans l'ordre de la liste de départ (pas vues d'abord, plus récentes).
Map<String, List<Video>> bySubject(List<Video> pool, {required Set<String> seen}) {
  final out = <String, List<Video>>{};
  for (final v in suggestions(pool, seen: seen, count: pool.length)) {
    out.putIfAbsent(videoSubject(v), () => []).add(v);
  }
  return out;
}
