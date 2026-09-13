import '../domain/catalog_item.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import '../domain/skills.dart';

/// Schema del catalogo oggetti.
///
/// Vive in un file separato e **senza dipendenze da Flutter** per una ragione
/// precisa: lo usano sia l'applicazione sia lo script che genera il catalogo
/// (`tool/build_catalog.dart`, che gira sulla VM Dart). Se lo schema stesse
/// dentro il codice dell'app, lo script dovrebbe duplicarlo, e prima o poi le
/// due copie divergerebbero — con l'effetto che il catalogo si genera con una
/// struttura e l'app ne legge un'altra.
abstract final class CatalogSchema {
  /// Versione dello schema. Va alzata quando cambia la struttura delle tabelle
  /// (non quando cambiano i dati: per quelli c'e' il checksum).
  static const int version = 1;

  static const String metaTable = 'catalog_meta';
  static const String itemsTable = 'catalog_items';

  static const List<String> statements = <String>[
    '''
    CREATE TABLE IF NOT EXISTS $metaTable (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT
    );
    ''',
    '''
    CREATE TABLE IF NOT EXISTS $itemsTable (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      category INTEGER NOT NULL,
      rarity INTEGER NOT NULL,
      cost INTEGER NOT NULL DEFAULT 0,
      description TEXT NOT NULL DEFAULT '',
      weight REAL NOT NULL DEFAULT 0,
      image_asset TEXT,
      source TEXT NOT NULL DEFAULT '',
      weapon_skill INTEGER,
      weapon_hands TEXT,
      weapon_damage TEXT,
      weapon_max_ammo INTEGER,
      weapon_rof INTEGER,
      weapon_concealable INTEGER,
      weapon_properties TEXT,
      armor_slot INTEGER,
      armor_sp INTEGER,
      armor_penalties INTEGER,
      clothing_slot TEXT,
      clothing_style TEXT
    );
    ''',
    'CREATE INDEX IF NOT EXISTS idx_catalog_items_name ON $itemsTable(name);',
    'CREATE INDEX IF NOT EXISTS idx_catalog_items_category ON $itemsTable(category);',
    'CREATE INDEX IF NOT EXISTS idx_catalog_items_key ON $itemsTable(name, category);',
  ];

  /// Le colonne, in ordine, per le `INSERT`.
  static const List<String> columns = <String>[
    'id',
    'name',
    'category',
    'rarity',
    'cost',
    'description',
    'weight',
    'image_asset',
    'source',
    'weapon_skill',
    'weapon_hands',
    'weapon_damage',
    'weapon_max_ammo',
    'weapon_rof',
    'weapon_concealable',
    'weapon_properties',
    'armor_slot',
    'armor_sp',
    'armor_penalties',
    'clothing_slot',
    'clothing_style',
  ];

  /// Converte una voce nei valori delle [columns].
  ///
  /// Le enumerazioni sono salvate con i loro identificativi numerici stabili
  /// (gli stessi usati dal vecchio progetto e dai documenti), non con i nomi
  /// Dart: rinominare una costante in codice non deve invalidare un catalogo
  /// gia' spedito.
  static List<Object?> toRow(CatalogItem item) => <Object?>[
        item.id,
        item.name,
        item.category.id,
        _rarityIndex(item.rarity),
        item.cost,
        item.description,
        item.weight,
        item.imageAsset,
        item.source,
        item.weapon?.skillId,
        item.weapon?.handsRequired,
        item.weapon?.damage,
        item.weapon?.maxAmmo,
        item.weapon?.rof,
        item.weapon == null ? null : (item.weapon!.isConcealable ? 1 : 0),
        item.weapon?.properties,
        item.armor?.slot.id,
        item.armor?.sp,
        item.armor?.penalties,
        item.clothing?.slot.name,
        item.clothing?.style.name,
      ];

  /// Ricostruisce una voce da una riga letta dal database.
  ///
  /// Accetta `Map<String, Object?>` e non il tipo `Row` di `sqlite3` perche'
  /// cosi' e' verificabile senza aprire un database.
  static CatalogItem fromRow(Map<String, Object?> row) {
    final int? weaponSkill = _intOrNull(row['weapon_skill']);
    final int? weaponMaxAmmo = _intOrNull(row['weapon_max_ammo']);
    final String? weaponDamage = _stringOrNull(row['weapon_damage']);

    final int? armorSp = _intOrNull(row['armor_sp']);
    final int? armorSlot = _intOrNull(row['armor_slot']);

    final String? clothingSlot = _stringOrNull(row['clothing_slot']);
    final String? clothingStyle = _stringOrNull(row['clothing_style']);

    return CatalogItem(
      id: '${row['id']}',
      name: '${row['name']}',
      category: ItemCategory.fromId(_intOrNull(row['category']) ?? 0) ?? ItemCategory.item,
      rarity: _rarityFromIndex(_intOrNull(row['rarity']) ?? 0),
      cost: _intOrNull(row['cost']) ?? 0,
      description: _stringOrNull(row['description']) ?? '',
      weight: _doubleOrNull(row['weight']) ?? 0,
      imageAsset: _stringOrNull(row['image_asset']),
      source: _stringOrNull(row['source']) ?? '',
      weapon: weaponDamage == null
          ? null
          : WeaponData(
              skillId: weaponSkill ?? Skill.meleeWeapon.id,
              handsRequired: _stringOrNull(row['weapon_hands']) ?? '1',
              damage: weaponDamage,
              currentAmmo: 0,
              maxAmmo: weaponMaxAmmo ?? 0,
              rof: _intOrNull(row['weapon_rof']) ?? 1,
              isConcealable: (_intOrNull(row['weapon_concealable']) ?? 0) != 0,
              properties: _stringOrNull(row['weapon_properties']) ?? '',
            ),
      armor: armorSp == null
          ? null
          : ArmorData(
              slot: ArmorSlot.fromId(armorSlot ?? ArmorSlot.body.id) ?? ArmorSlot.body,
              sp: armorSp,
              penalties: _intOrNull(row['armor_penalties']) ?? 0,
            ),
      clothing: clothingSlot == null
          ? null
          : ClothingData(
              slot: ClothingSlot.values.firstWhere(
                (ClothingSlot s) => s.name == clothingSlot,
                orElse: () => ClothingSlot.top,
              ),
              style: ClothingStyle.values.firstWhere(
                (ClothingStyle s) => s.name == clothingStyle,
                orElse: () => ClothingStyle.genericChic,
              ),
            ),
    );
  }

  /// La rarita' e' salvata come ordinale, come nel vecchio database.
  static int _rarityIndex(Rarity rarity) => rarity.index;

  static Rarity _rarityFromIndex(int index) =>
      index >= 0 && index < Rarity.values.length ? Rarity.values[index] : Rarity.common;

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _doubleOrNull(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final String text = value.toString();
    return text.isEmpty ? null : text;
  }
}
