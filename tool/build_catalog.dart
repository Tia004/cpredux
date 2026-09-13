// Genera `assets/catalog/catalog.sqlite` dal seed leggibile
// `tool/catalog_seed.json`.
//
// Perche' non spedire direttamente il JSON: il catalogo si interroga (ricerca
// per nome, filtri per categoria, ordinamenti) e cresce; un database indicizzato
// fa quel lavoro meglio e resta ispezionabile con qualunque strumento. Perche'
// non scrivere il database a mano: perche' il seed in JSON e' **revisionabile
// in una diff**, e un catalogo binario modificato a mano non lo e'.
//
// Uso:
//   dart run tool/build_catalog.dart
//
// Il file generato va committato: e' un asset spedito con l'app.

import 'dart:convert';
import 'dart:io';

import 'package:cpredux/data/catalog_schema.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/items.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:sqlite3/sqlite3.dart';

const String _seedPath = 'tool/catalog_seed.json';
const String _outputPath = 'assets/catalog/catalog.sqlite';

void main(List<String> arguments) {
  final File seed = File(_seedPath);
  if (!seed.existsSync()) {
    stderr.writeln('Seed non trovato: $_seedPath');
    exitCode = 1;
    return;
  }

  final Object? decoded = jsonDecode(seed.readAsStringSync());
  if (decoded is! List<Object?>) {
    stderr.writeln('Il seed deve essere una lista JSON di oggetti.');
    exitCode = 1;
    return;
  }

  final List<CatalogItem> items = <CatalogItem>[];
  final List<String> problems = <String>[];

  for (final Object? entry in decoded) {
    if (entry is! Map<Object?, Object?>) {
      problems.add('Voce non valida: $entry');
      continue;
    }
    final Map<String, Object?> json = entry.map((Object? k, Object? v) => MapEntry(k.toString(), v));
    final CatalogItem? item = _parse(json, problems);
    if (item != null) items.add(item);
  }

  // Duplicati: due voci con lo stesso identificativo significano che una
  // sovrascriverebbe l'altra in silenzio.
  final Set<String> ids = <String>{};
  for (final CatalogItem item in items) {
    if (!ids.add(item.id)) problems.add('Identificativo duplicato: ${item.id}');
  }

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

CatalogItem? _parse(Map<String, Object?> json, List<String> problems) {
  final String id = '${json['id'] ?? ''}'.trim();
  final String name = '${json['name'] ?? ''}'.trim();
  if (id.isEmpty || name.isEmpty) {
    problems.add('Voce senza id o senza nome: $json');
    return null;
  }

  final ItemCategory? category = _category(json['category']);
  if (category == null) {
    problems.add('Categoria sconosciuta in $id: ${json['category']}');
    return null;
  }

  final Rarity rarity = _rarity(json['rarity']);
  WeaponData? weapon;
  ArmorData? armor;
  ClothingData? clothing;

  if (json['weapon'] is Map<Object?, Object?>) {
    final Map<String, Object?> w =
        (json['weapon']! as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v));
    final Skill? skill = _skill(w['skill']);
    if (skill == null) {
      problems.add('Abilita sconosciuta in $id: ${w['skill']}');
      return null;
    }
    if ('${w['damage'] ?? ''}'.trim().isEmpty) {
      problems.add('Arma senza danno: $id');
      return null;
    }
    weapon = WeaponData(
      skillId: skill.id,
      handsRequired: '${w['hands'] ?? '1'}',
      damage: '${w['damage']}',
      currentAmmo: 0,
      maxAmmo: _int(w['maxAmmo']),
      rof: _int(w['rof'], 1),
      isConcealable: w['concealable'] == true,
      properties: '${w['properties'] ?? ''}',
    );
  }

  if (json['armor'] is Map<Object?, Object?>) {
    final Map<String, Object?> a =
        (json['armor']! as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v));
    final ArmorSlot? slot = _armorSlot(a['slot']);
    if (slot == null) {
      problems.add('Slot armatura sconosciuto in $id: ${a['slot']}');
      return null;
    }
    armor = ArmorData(slot: slot, sp: _int(a['sp']), penalties: _int(a['penalties']));
  }

  if (json['clothing'] is Map<Object?, Object?>) {
    final Map<String, Object?> c =
        (json['clothing']! as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v));
    final ClothingSlot? slot = _clothingSlot(c['slot']);
    final ClothingStyle style = _clothingStyle(c['style']);
    if (slot == null) {
      problems.add('Slot abbigliamento sconosciuto in $id: ${c['slot']}');
      return null;
    }
    clothing = ClothingData(slot: slot, style: style);
  }

  final double weight = _double(json['weight']);
  if (weight < 0) problems.add('Peso negativo in $id');

  return CatalogItem(
    id: id,
    name: name,
    category: category,
    rarity: rarity,
    cost: _int(json['cost']),
    description: '${json['description'] ?? ''}',
    weight: weight,
    imageAsset: json['image'] == null ? null : 'assets/catalog/images/${json['image']}',
    source: '${json['source'] ?? 'core'}',
    weapon: weapon,
    armor: armor,
    clothing: clothing,
  );
}

ItemCategory? _category(Object? value) {
  final String name = '${value ?? ''}';
  for (final ItemCategory category in ItemCategory.values) {
    if (category.name == name || category.label.toLowerCase() == name.toLowerCase()) return category;
  }
  return null;
}

Rarity _rarity(Object? value) {
  final String name = '${value ?? ''}'.toLowerCase();
  for (final Rarity rarity in Rarity.values) {
    if (rarity.name.toLowerCase() == name || rarity.label.toLowerCase() == name) return rarity;
  }
  return Rarity.common;
}

/// L'abilita' di un'arma, accettata come identificativo numerico, come nome
/// della costante (`handgun`) o come nome mostrato (`Pistole`).
///
/// Il nome della costante si ricava da `toString()`, non da `.name`: nel
/// dominio `Skill.name` e' il **nome tradotto** dell'abilita', che ombreggia
/// quello dell'enum. Usare `.name` qui confronterebbe "Pistole" con
/// "handgun" e fallirebbe sempre.
Skill? _skill(Object? value) {
  final String name = '${value ?? ''}'.trim();
  if (name.isEmpty) return null;

  final int? id = int.tryParse(name);
  if (id != null) return Skill.fromId(id);

  for (final Skill skill in Skill.values) {
    if (_constantName(skill) == name) return skill;
  }
  for (final Skill skill in Skill.values) {
    if (skill.name.toLowerCase() == name.toLowerCase()) return skill;
  }
  return null;
}

String _constantName(Object value) => value.toString().split('.').last;

ArmorSlot? _armorSlot(Object? value) {
  final String name = '${value ?? ''}';
  for (final ArmorSlot slot in ArmorSlot.values) {
    if (slot.name == name || slot.label.toLowerCase() == name.toLowerCase()) return slot;
  }
  return null;
}

ClothingSlot? _clothingSlot(Object? value) {
  final String name = '${value ?? ''}';
  for (final ClothingSlot slot in ClothingSlot.values) {
    if (slot.name == name || slot.label.toLowerCase() == name.toLowerCase()) return slot;
  }
  return null;
}

ClothingStyle _clothingStyle(Object? value) {
  final String name = '${value ?? ''}';
  for (final ClothingStyle style in ClothingStyle.values) {
    if (style.name == name || style.label.toLowerCase() == name.toLowerCase()) return style;
  }
  return ClothingStyle.genericChic;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double _double(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}
