#!/usr/bin/env python3
"""Essais et vidéos de démonstration, ÉMULATEUR SEULEMENT : fabrique une base « un enfant de 8 ans qui joue depuis une
semaine » (révisions dues, série de jours, une notion acquise, une notion difficile) et l'écrit dans l'app de
l'émulateur. Demande `adb root`, donc impossible sur une vraie tablette : aucune donnée d'enfant n'est touchée.

    python3 tool/demo_seed.py emulator-5554
"""
import json, os, sqlite3, subprocess, sys, tempfile, time

serial = sys.argv[1]
assert serial.startswith('emulator-'), "émulateur seulement"
adb = ['adb', '-s', serial]
pkg = 'mg.zanakiantsa.app'
now = int(subprocess.check_output(adb + ['shell', 'date', '+%s']).strip())
day = 86400
noon = now - now % day + 10 * 3600  # 10 h UTC du jour de l'émulateur

path = os.path.join(tempfile.mkdtemp(), 'zanakiantsa.db')
db = sqlite3.connect(path)
db.executescript("""
CREATE TABLE answers (id INTEGER PRIMARY KEY, skill TEXT, attempts INTEGER, correct INTEGER, demonstrated INTEGER,
  millis INTEGER, at INTEGER, child INTEGER NOT NULL DEFAULT 1, errors TEXT NOT NULL DEFAULT '', challenge INTEGER NOT NULL DEFAULT 0);
CREATE TABLE sessions (id INTEGER PRIMARY KEY, started INTEGER, ended INTEGER, theme TEXT NOT NULL DEFAULT 'compter',
  complete INTEGER NOT NULL DEFAULT 1, child INTEGER NOT NULL DEFAULT 1);
CREATE TABLE settings (k TEXT PRIMARY KEY, v TEXT);
PRAGMA user_version = 4;
""")

def answer(skill, days_ago, ok=True, attempts=1, error=''):
    db.execute('INSERT INTO answers (skill, attempts, correct, demonstrated, millis, at, errors) VALUES (?,?,?,0,4000,?,?)',
               (skill, attempts, 1 if ok else 0, (noon - days_ago * day) * 1000, error))

for skill, ago in [('doubles', 9), ('moities', 9), ('tables-2-5-10', 8), ('lire-phrases', 8), ('classes-de-mots', 6),
                   ('plante-besoins', 6), ('weather', 5), ('food', 5), ('sujet-et-verbe', 2)]:
    for _ in range(5):
        answer(skill, ago)
answer('fractions-comparer', 1, ok=False, attempts=3, error='Regarde le nombre du bas : plus il est grand, plus les parts sont petites.')
answer('fractions-comparer', 1, ok=False, attempts=3, error='Regarde le nombre du bas : plus il est grand, plus les parts sont petites.')
answer('fractions-comparer', 1)
for ago, theme in [(6, 'compter'), (5, 'lire'), (4, 'nature'), (2, 'lire'), (1, 'compter')]:
    start = noon - ago * day
    db.execute('INSERT INTO sessions (started, ended, theme) VALUES (?,?,?)', (start * 1000, (start + (18 + 3 * ago) * 60) * 1000, theme))
for k, v in {'profils': json.dumps([{'id': 1, 'nom': 'Aina'}]), 'profil_actif': '1', 'langue': 'fr', 'c1.age': '8',
             'c1.genre': 'garcon', 'c1.minutes_jour': '45'}.items():
    db.execute('INSERT INTO settings VALUES (?,?)', (k, v))
db.commit()
db.close()

run = lambda *a: subprocess.run(adb + list(a), check=True, capture_output=True)
run('root'); time.sleep(2)
run('shell', 'am', 'force-stop', pkg)
owner = subprocess.check_output(adb + ['shell', 'stat', '-c', '%U', f'/data/data/{pkg}']).decode().strip()
run('shell', 'rm', '-f', f'/data/data/{pkg}/databases/zanakiantsa.db-journal', f'/data/data/{pkg}/databases/zanakiantsa.db-wal')
run('push', path, f'/data/data/{pkg}/databases/zanakiantsa.db')
run('shell', 'chown', f'{owner}:{owner}', f'/data/data/{pkg}/databases/zanakiantsa.db')
run('shell', 'restorecon', '-R', f'/data/data/{pkg}/databases')
print('base de démonstration installée :', serial)
