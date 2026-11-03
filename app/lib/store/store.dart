/// Stockage local (SQLite) : journal des réponses en ajout seul, séances, réglages. Rien ne quitte l'appareil.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/events.dart';

class Store {
  Store._(this._db);
  final Database _db;

  static Future<Store> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'zanakiantsa.db'),
      version: 2,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE answers (id INTEGER PRIMARY KEY, skill TEXT, attempts INTEGER, correct INTEGER, '
            'demonstrated INTEGER, millis INTEGER, at INTEGER)');
        await db.execute("CREATE TABLE sessions (id INTEGER PRIMARY KEY, started INTEGER, ended INTEGER, "
            "theme TEXT NOT NULL DEFAULT 'compter', complete INTEGER NOT NULL DEFAULT 1)");
        await db.execute('CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT)');
      },
      // v2 (ADR 0018) : domaine de la séance et séances interrompues ; les anciennes étaient toutes « compter », finies.
      onUpgrade: (db, from, _) async {
        if (from < 2) {
          await db.execute("ALTER TABLE sessions ADD COLUMN theme TEXT NOT NULL DEFAULT 'compter'");
          await db.execute('ALTER TABLE sessions ADD COLUMN complete INTEGER NOT NULL DEFAULT 1');
        }
      },
    );
    return Store._(db);
  }

  Future<void> add(Answer a) => _db.insert('answers', a.toMap());

  Future<List<Answer>> answers() async =>
      [for (final m in await _db.query('answers', orderBy: 'id')) Answer.fromMap(m)];

  Future<void> addSession(SessionLog s) => _db.insert('sessions', {
        'started': s.started.millisecondsSinceEpoch,
        'ended': s.ended.millisecondsSinceEpoch,
        'theme': s.theme,
        'complete': s.complete ? 1 : 0,
      });

  Future<List<SessionLog>> sessions() async => [
        for (final m in await _db.query('sessions', orderBy: 'id'))
          SessionLog(
            theme: m['theme']! as String,
            started: DateTime.fromMillisecondsSinceEpoch(m['started']! as int),
            ended: DateTime.fromMillisecondsSinceEpoch(m['ended']! as int),
            complete: m['complete'] == 1,
          )
      ];

  Future<String?> get(String k) async =>
      (await _db.query('settings', where: 'k = ?', whereArgs: [k])).firstOrNull?['v'] as String?;

  Future<void> set(String k, String v) =>
      _db.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
}
