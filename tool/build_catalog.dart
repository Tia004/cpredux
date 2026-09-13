// Genera `assets/catalog/catalog.sqlite` dal seed leggibile
// `tool/catalog_seed.json`.
//
// Perche' non spedire direttamente il JSON: il catalogo si interroga (ricerca
// per nome, filtri per categoria, ordinamenti) e cresce; un database indicizzato
// fa quel lavoro meglio e resta ispezionabile con qualunque strumento. Perche'
// non scrivere il database a mano: perche' il seed in JSON e' **revisionabile
// in una diff**, e un catalogo binario modificato a mano non lo e'.
//
// La lettura del seed sta in `lib/data/catalog_seed.dart` e non qui: lo stesso
// formato lo usa anche `tool/import_legacy_catalog.dart`, e due copie del
// formato significherebbero un catalogo scritto con una struttura e letto con
// un'altra.
//
// Uso:
//   dart run tool/build_catalog.dart
//
// Il file generato va committato: e' un asset spedito con l'app.

import 'dart:io';

import 'package:cpredux/data/catalog_seed.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/data/catalog_schema.dart';
import 'package:sqlite3/sqlite3.dart';

const String _outputPath = 'assets/catalog/catalog.sqlite';

void main(List<String> arguments) {
  final File seed = File(CatalogSeed.path);
  if (!seed.existsSync()) {
    stderr.writeln('Seed non trovato: ${CatalogSeed.path}');
    exitCode = 1;
    return;
  }

  final List<String> problems = <String>[];
  final List<CatalogItem> items = CatalogSeed.parse(seed.readAsStringSync(), problems: problems);

  if (problems.isNotEmpty) {
    stderr.writeln('Il catalogo non e\' valido:');
    for (final String problem in problems) {
      stderr.writeln('  - $problem');
    }
    exitCode = 1;
    return;
  }

  final File output = File(_outputPath);
  output.parent.createSync(recursive: true);
  if (output.existsSync()) output.deleteSync();

  final Database db = sqlite3.open(output.path);
  for (final String statement in CatalogSchema.statements) {
    db.execute(statement);
  }

  final String placeholders = List<String>.filled(CatalogSchema.columns.length, '?').join(', ');
  final PreparedStatement insert = db.prepare(
    'INSERT OR REPLACE INTO ${CatalogSchema.itemsTable} '
    '(${CatalogSchema.columns.join(', ')}) VALUES ($placeholders);',
  );
  for (final CatalogItem item in items) {
    insert.execute(CatalogSchema.toRow(item));
  }
  insert.close();

  db.execute(
    'INSERT OR REPLACE INTO ${CatalogSchema.metaTable} (key, value) VALUES (?, ?);',
    <Object?>['catalog_version', '${CatalogSchema.version}'],
  );
  db.execute(
    'INSERT OR REPLACE INTO ${CatalogSchema.metaTable} (key, value) VALUES (?, ?);',
    <Object?>['generated_at', DateTime.now().toIso8601String()],
  );
  db.execute(
    'INSERT OR REPLACE INTO ${CatalogSchema.metaTable} (key, value) VALUES (?, ?);',
    <Object?>['item_count', '${items.length}'],
  );
  // Compatta il file: un catalogo spedito con pagine libere e' piu' grande del
  // necessario, e viene copiato su disco a ogni installazione.
  db.execute('VACUUM;');
  db.close();

  final Map<String, int> byCategory = <String, int>{};
  for (final CatalogItem item in items) {
    byCategory.update(item.category.label, (int v) => v + 1, ifAbsent: () => 1);
  }

  stdout.writeln('Catalogo generato: $_outputPath');
  stdout.writeln('  ${items.length} voci, ${(output.lengthSync() / 1024).toStringAsFixed(1)} KB');
  for (final MapEntry<String, int> entry in byCategory.entries) {
    stdout.writeln('    ${entry.key}: ${entry.value}');
  }
}
