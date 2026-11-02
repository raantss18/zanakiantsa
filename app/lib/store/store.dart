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
      version: 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE answers (id INTEGER PRIMARY KEY, skill TEXT, attempts INTEGER, correct INTEGER, '
            'demonstrated INTEGER, millis INTEGER, at INTEGER)');
        await db.execute('CREATE TABLE sessions (id INTEGER PRIMARY KEY, started INTEGER, ended INTEGER)');
        await db.execute('CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT)');
      },
    );
    return Store._(db);
  }

  Future<void> add(Answer a) => _db.insert('answers', a.toMap());

  Future<List<Answer>> answers() async =>
      [for (final m in await _db.query('answers', orderBy: 'id')) Answer.fromMap(m)];

  Future<void> sessionDone(DateTime started, DateTime ended) =>
      _db.insert('sessions', {'started': started.millisecondsSinceEpoch, 'ended': ended.millisecondsSinceEpoch});

  Future<List<(DateTime, DateTime)>> sessions() async => [
        for (final m in await _db.query('sessions', orderBy: 'id'))
          (
            DateTime.fromMillisecondsSinceEpoch(m['started']! as int),
            DateTime.fromMillisecondsSinceEpoch(m['ended']! as int),
          )
      ];

  Future<String?> get(String k) async =>
      (await _db.query('settings', where: 'k = ?', whereArgs: [k])).firstOrNull?['v'] as String?;

  Future<void> set(String k, String v) =>
      _db.insert('settings', {'k': k, 'v': v}, conflictAlgorithm: ConflictAlgorithm.replace);
}
