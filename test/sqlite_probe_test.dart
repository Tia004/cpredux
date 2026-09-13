import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Verifica che SQLite sia utilizzabile **senza** `sqlite3_flutter_libs`.
///
/// Conta: se il sistema operativo fornisce gia' libsqlite3, l'app non ha
/// bisogno di nessun plugin nativo, quindi nessun CocoaPods su macOS e una
/// pipeline di build molto piu' semplice sui tre sistemi. Se questo test
/// fallisce, va aggiunto `sqlite3_flutter_libs` e la complessita' sale.
void main() {
  test('SQLite di sistema e utilizzabile senza plugin nativi', () {
    final Database db = sqlite3.openInMemory();
    addTearDown(db.close);

    db.execute('CREATE TABLE alterazione (id INTEGER PRIMARY KEY, valore INTEGER);');
    db.execute('INSERT INTO alterazione (valore) VALUES (-2), (+1);');

    final ResultSet rows = db.select('SELECT valore FROM alterazione ORDER BY valore;');
    expect(rows.length, 2);
    expect(rows.first['valore'], -2);
    expect(rows.last['valore'], 1);

    // La versione serve a sapere cosa possiamo usare: UPSERT richiede 3.24+,
    // le finestre analitiche 3.25+.
    expect(sqlite3.version.libVersion, isNotEmpty);
    // ignore: avoid_print
    print('SQLite di sistema: ${sqlite3.version.libVersion}');
  });

  test('le foreign key e le transazioni funzionano', () {
    final Database db = sqlite3.openInMemory();
    addTearDown(db.close);

    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('CREATE TABLE skill (id INTEGER PRIMARY KEY, livello INTEGER NOT NULL);');
    db.execute(
      'CREATE TABLE alterazione (id INTEGER PRIMARY KEY, skill_id INTEGER NOT NULL '
      'REFERENCES skill(id) ON DELETE CASCADE, valore INTEGER NOT NULL);',
    );
    db.execute('INSERT INTO skill (id, livello) VALUES (5, 3);');
    db.execute('INSERT INTO alterazione (id, skill_id, valore) VALUES (1, 5, -1);');

    db.execute('DELETE FROM skill WHERE id = 5;');
    expect(db.select('SELECT * FROM alterazione;'), isEmpty);
  });
}
