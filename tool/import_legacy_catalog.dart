// Importa nel catalogo gli oggetti contenuti in vecchie schede `.cpred_sheet`.
//
// Perche' cosi' e non a mano: nel vecchio progetto il catalogo non esisteva —
// ogni scheda si portava dentro i propri oggetti — quindi l'unico insieme di
// dati di gioco *reale* sono le schede. Scriverli a mano significherebbe
// ricopiarli, e ogni ricopiatura e' un'occasione di sbagliare un prezzo. Qui la
// lettura e' meccanica e ripetibile: si rilancia e viene identica.
//
// Uso:
//   dart run tool/import_legacy_catalog.dart Scheda.cpred_sheet
//   dart run tool/import_legacy_catalog.dart --dry-run ~/schede
//   dart run tool/import_legacy_catalog.dart --seed tool/catalog_seed.json a.cpred_sheet b.cpred_sheet
//
// Dopo l'importazione il catalogo spedito va rigenerato:
//   dart run tool/build_catalog.dart
//
// Il file `catalog_seed.json` e' l'unico punto di verita': questo script ci
// aggiunge voci, non ne sostituisce nessuna.

import 'dart:io';

import 'package:cpredux/data/catalog_seed.dart';
import 'package:cpredux/data/legacy_catalog_import.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';

void main(List<String> arguments) {
  final _Options options = _Options.parse(arguments);
  if (options.paths.isEmpty) {
    stderr.writeln('Serve almeno una scheda da importare.\n');
    stderr.writeln(_Options.usage);
    exitCode = 2;
    return;
  }

  final List<File> sheets = _collectSheets(options.paths);
  if (sheets.isEmpty) {
    stderr.writeln('Nessuna scheda trovata in: ${options.paths.join(', ')}');
    exitCode = 1;
    return;
  }

  final File seedFile = File(options.seedPath);
  final List<String> problems = <String>[];
  final List<CatalogItem> existing = seedFile.existsSync()
      ? CatalogSeed.parse(seedFile.readAsStringSync(), problems: problems)
      : <CatalogItem>[];

  if (problems.isNotEmpty) {
    stderr.writeln('Il seed contiene voci che non si leggono:');
    for (final String problem in problems) {
      stderr.writeln('  - $problem');
    }
    stderr.writeln('Nessuna scrittura: un seed rotto non si corregge importando.');
    exitCode = 1;
    return;
  }

  stdout.writeln('Seed: ${options.seedPath} (${existing.length} voci)');
  stdout.writeln('');

  final List<CatalogItem> imported = <CatalogItem>[];
  bool failed = false;

  for (final File sheet in sheets) {
    final LegacyCatalogRead read;
    try {
      read = LegacyCatalogImporter.read(sheet.path);
    } on LegacyCatalogException catch (error) {
      stdout.writeln(sheet.path);
      stdout.writeln('  NON LETTA: $error');
      stdout.writeln('');
      failed = true;
      continue;
    }

    stdout.writeln(sheet.path);
    stdout.writeln('  versione dichiarata: ${read.version ?? '(assente)'}');
    stdout.writeln('  oggetti letti: ${read.itemCount}');
    for (final MapEntry<ItemCategory, int> entry in read.counts.entries) {
      stdout.writeln('    ${entry.key.label}: ${entry.value}');
    }
    if (read.skipped > 0) stdout.writeln('  righe scartate: ${read.skipped}');
    for (final String note in read.notes) {
      stdout.writeln('  nota: $note');
    }
    stdout.writeln('');
    imported.addAll(read.items);
  }

  final SeedMerge merge = CatalogSeed.merge(
    existing: existing,
    incoming: imported,
    problems: problems,
  );

  stdout.writeln('Fusione');
  stdout.writeln('  voci importate: ${merge.added.length}');
  stdout.writeln('  gia\' nel catalogo (riconosciute per nome): ${merge.alreadyPresent.length}');
  stdout.writeln('  totale nel seed: ${merge.items.length}');

  if (merge.alreadyPresent.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('  Riconosciute e non aggiunte:');
    for (final CatalogItem item in merge.alreadyPresent.take(40)) {
      stdout.writeln('    - ${item.name} (${item.category.label})');
    }
    if (merge.alreadyPresent.length > 40) {
      stdout.writeln('    ... e ${merge.alreadyPresent.length - 40} altre');
    }
  }

  if (problems.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('  Avvisi:');
    for (final String problem in problems) {
      stdout.writeln('    - $problem');
    }
  }

  if (options.dryRun) {
    stdout.writeln('');
    stdout.writeln('Prova a vuoto: il seed non e\' stato toccato.');
    if (failed) exitCode = 1;
    return;
  }

  if (merge.added.isEmpty) {
    stdout.writeln('');
    stdout.writeln('Niente da scrivere: il seed e\' gia\' aggiornato.');
    if (failed) exitCode = 1;
    return;
  }

  seedFile.writeAsStringSync(CatalogSeed.encodeAll(merge.items));
  stdout.writeln('');
  stdout.writeln('Seed aggiornato: ${options.seedPath}');
  stdout.writeln('Ora rigenera il catalogo spedito:');
  stdout.writeln('  dart run tool/build_catalog.dart');
  if (failed) exitCode = 1;
}

/// Espande gli argomenti: una cartella vale tutte le schede che contiene.
///
/// Le schede si cercano **solo** nella cartella indicata, non in tutto il
/// disco: un import deve toccare esattamente i file che hai nominato, e una
/// scansione ricorsiva finirebbe per importare anche le copie di backup.
List<File> _collectSheets(List<String> paths) {
  const String extension = '.cpred_sheet';
  final List<File> sheets = <File>[];
  for (final String path in paths) {
    final FileSystemEntityType type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      final List<FileSystemEntity> children = Directory(path).listSync();
      for (final FileSystemEntity child in children) {
        if (child is File && child.path.endsWith(extension)) sheets.add(child);
      }
      continue;
    }
    sheets.add(File(path));
  }
  return sheets;
}

class _Options {
  _Options({required this.paths, required this.seedPath, required this.dryRun});

  final List<String> paths;
  final String seedPath;
  final bool dryRun;

  static const String usage = '''
Uso:
  dart run tool/import_legacy_catalog.dart [opzioni] <scheda.cpred_sheet | cartella>...

Opzioni:
  --seed <percorso>   seed da aggiornare (predefinito: ${CatalogSeed.path})
  --dry-run           mostra cosa cambierebbe senza scrivere nulla
  --help              questo messaggio''';

  static _Options parse(List<String> arguments) {
    final List<String> paths = <String>[];
    String seedPath = CatalogSeed.path;
    bool dryRun = false;

    for (int i = 0; i < arguments.length; i++) {
      final String argument = arguments[i];
      switch (argument) {
        case '--help':
        case '-h':
          stdout.writeln(usage);
          exit(0);
        case '--dry-run':
        case '-n':
          dryRun = true;
        case '--seed':
          if (i + 1 >= arguments.length) {
            stderr.writeln('--seed vuole un percorso.');
            exit(2);
          }
          seedPath = arguments[++i];
        default:
          if (argument.startsWith('-')) {
            stderr.writeln('Opzione sconosciuta: $argument\n');
            stderr.writeln(usage);
            exit(2);
          }
          paths.add(argument);
      }
    }

    return _Options(paths: paths, seedPath: seedPath, dryRun: dryRun);
  }
}
