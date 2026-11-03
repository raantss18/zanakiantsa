/// Stockage local (SQLite) : journal des réponses en ajout seul, séances, réglages. Rien ne quitte l'appareil.
/// Plusieurs enfants (ADR 0034) : chaque réponse, séance et réglage appartient à l'enfant actif [child] ; seuls les
/// réglages de [globalKeys] sont communs.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/events.dart';

class Store {
  Store._(this._db);
  final Database _db;

  /// Enfant actif : toutes les lectures et écritures le concernent.
  int child = 1;

  /// Réglages communs à la famille (les autres sont rangés sous `c<n>.`).
  static const globalKeys = {'profils', 'profil_actif'};

  String _k(String k) => globalKeys.contains(k) ? k : 'c$child.$k';

  static Future<Store> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'zanakiantsa.db'),
      version: 3,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE answers (id INTEGER PRIMARY KEY, skill TEXT, attempts INTEGER, correct INTEGER, '
            'demonstrated INTEGER, millis INTEGER, at INTEGER, child INTEGER NOT NULL DEFAULT 1)');
        await db.execute("CREATE TABLE sessions (id INTEGER PRIMARY KEY, started INTEGER, ended INTEGER, "
            "theme TEXT NOT NULL DEFAULT 'compter', complete INTEGER NOT NULL DEFAULT 1, child INTEGER NOT NULL DEFAULT 1)");
        await db.execute('CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT)');
      },
      // v2 (ADR 0018) : domaine de la séance et séances interrompues ; les anciennes étaient toutes « compter », finies.
      onUpgrade: (db, from, _) async {
        if (from < 2) {
          await db.execute("ALTER TABLE sessions ADD COLUMN theme TEXT NOT NULL DEFAULT 'compter'");
          await db.execute('ALTER TABLE sessions ADD COLUMN complete INTEGER NOT NULL DEFAULT 1');
        }
        // v3 (ADR 0034) : plusieurs enfants ; tout ce qui existait devient celui du premier enfant.
        if (from < 3) {
          await db.execute('ALTER TABLE answers ADD COLUMN child INTEGER NOT NULL DEFAULT 1');
          await db.execute('ALTER TABLE sessions ADD COLUMN child INTEGER NOT NULL DEFAULT 1');
          await db.execute("UPDATE settings SET k = 'c1.' || k");
        }
      },
    );
    return Store._(db);
  }

  Future<void> add(Answer a) => _db.insert('answers', {...a.toMap(), 'child': child});

  Future<List<Answer>> answers() async =>
      [for (final m in await _db.query('answers', where: 'child = ?', whereArgs: [child], orderBy: 'id')) Answer.fromMap(m)];

  Future<void> addSession(SessionLog s) => _db.insert('sessions', {
        'started': s.started.millisecondsSinceEpoch,
        'ended': s.ended.millisecondsSinceEpoch,
        'theme': s.theme,
        'complete': s.complete ? 1 : 0,
        'child': child,
      });

  Future<List<SessionLog>> sessions() async => [
        for (final m in await _db.query('sessions', where: 'child = ?', whereArgs: [child], orderBy: 'id'))
          SessionLog(
            theme: m['theme']! as String,
            started: DateTime.fromMillisecondsSinceEpoch(m['started']! as int),
            ended: DateTime.fromMillisecondsSinceEpoch(m['ended']! as int),
            complete: m['complete'] == 1,
          )
      ];

  Future<String?> get(String k) async =>
      (await _db.query('settings', where: 'k = ?', whereArgs: [_k(k)])).firstOrNull?['v'] as String?;

  Future<void> set(String k, String v) =>
      _db.insert('settings', {'k': _k(k), 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
}
