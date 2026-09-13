import 'dart:convert';

import '../domain/catalog_item.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import '../domain/skills.dart';

/// Il **seed** del catalogo: la forma leggibile in cui le voci esistono prima
/// di diventare un database.
///
/// Perche' non scrivere direttamente `catalog.sqlite` a mano: perche' un file
/// binario non si revisiona in una diff. Il seed e' testo, una voce per riga, e
/// si legge in una richiesta di modifica; il database si genera da li' con
/// `tool/build_catalog.dart` ed e' quello che viene spedito con l'app.
///
/// Questa libreria esiste perche' il formato ha **due utilizzatori**: chi
/// costruisce il catalogo e chi lo importa da una vecchia scheda
/// (`tool/import_legacy_catalog.dart`). Se ognuno avesse la propria copia del
/// formato, prima o poi le due divergerebbero — e il sintomo sarebbe un
/// catalogo generato con una struttura e letto con un'altra.
///
/// La regola di compatibilita': chi scrive emette **nomi** (di categoria, di
/// abilita', di slot). Chi legge accetta anche gli identificativi numerici del
/// vecchio database, cosi' un seed scritto a mano con `"skill": 10` non e' un
/// errore.
abstract final class CatalogSeed {
  /// Percorso del seed nel repository, relativo alla radice del progetto.
  static const String path = 'tool/catalog_seed.json';

  /// Interpreta il contenuto di un seed.
  ///
  /// Non solleva eccezioni sulle voci singole: le raccoglie in [problems] e
  /// continua. Un seed con una voce rotta deve dire *quale* voce e' rotta e
  /// quante altre sono sane, non fermarsi alla prima.
  static List<CatalogItem> parse(String source, {List<String>? problems}) {
    final List<String> report = problems ?? <String>[];
    final List<CatalogItem> items = <CatalogItem>[];

    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      report.add('Il seed non e\' JSON valido: ${error.message}');
      return items;
    }

    if (decoded is! List<Object?>) {
      report.add('Il seed deve essere una lista JSON di voci.');
      return items;
    }

    for (final Object? entry in decoded) {
      if (entry is! Map<Object?, Object?>) {
        report.add('Voce non valida: $entry');
        continue;
      }
      final CatalogItem? item = parseEntry(_stringMap(entry), report);
      if (item != null) items.add(item);
    }

    final Set<String> ids = <String>{};
    for (final CatalogItem item in items) {
      if (!ids.add(item.id)) report.add('Identificativo duplicato: ${item.id}');
    }
    return items;
  }

  /// Interpreta una singola voce. Pubblica perche' serve anche a chi legge un
  /// seed da un'altra fonte (un file esportato, un dataset esterno).
  static CatalogItem? parseEntry(Map<String, Object?> json, [List<String>? problems]) {
    final List<String> report = problems ?? <String>[];
    final String id = '${json['id'] ?? ''}'.trim();
    final String name = '${json['name'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty) {
      report.add('Voce senza id o senza nome: $json');
      return null;
    }

    final ItemCategory? category = _category(json['category']);
    if (category == null) {
      report.add('Categoria sconosciuta in $id: ${json['category']}');
      return null;
    }

    WeaponData? weapon;
    ArmorData? armor;
    ClothingData? clothing;

    final Map<String, Object?>? weaponJson = _map(json['weapon']);
    if (weaponJson != null) {
      final Skill? skill = skillFrom(weaponJson['skill']);
      if (skill == null) {
        report.add('Abilita sconosciuta in $id: ${weaponJson['skill']}');
        return null;
      }
      if ('${weaponJson['damage'] ?? ''}'.trim().isEmpty) {
        report.add('Arma senza danno: $id');
        return null;
      }
      weapon = WeaponData(
        skillId: skill.id,
        handsRequired: '${weaponJson['hands'] ?? '1'}',
        damage: '${weaponJson['damage']}',
        currentAmmo: 0,
        maxAmmo: _int(weaponJson['maxAmmo']),
        rof: _int(weaponJson['rof'], 1),
        isConcealable: weaponJson['concealable'] == true,
        properties: '${weaponJson['properties'] ?? ''}',
      );
    }

    final Map<String, Object?>? armorJson = _map(json['armor']);
    if (armorJson != null) {
      final ArmorSlot? slot = _armorSlot(armorJson['slot']);
      if (slot == null) {
        report.add('Slot armatura sconosciuto in $id: ${armorJson['slot']}');
        return null;
      }
      armor = ArmorData(
        slot: slot,
        sp: _int(armorJson['sp']),
        penalties: _int(armorJson['penalties']),
      );
    }

    final Map<String, Object?>? clothingJson = _map(json['clothing']);
    if (clothingJson != null) {
      final ClothingSlot? slot = _clothingSlot(clothingJson['slot']);
      if (slot == null) {
        report.add('Slot abbigliamento sconosciuto in $id: ${clothingJson['slot']}');
        return null;
      }
      clothing = ClothingData(slot: slot, style: _clothingStyle(clothingJson['style']));
    }

    final double weight = _double(json['weight']);
    if (weight < 0) report.add('Peso negativo in $id');

    return CatalogItem(
      id: id,
      name: name,
      category: category,
      rarity: _rarity(json['rarity']),
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

  /// Trasforma una voce nella sua forma da seed, **con le stesse chiavi** che
  /// [parseEntry] si aspetta.
  ///
  /// Le enumerazioni escono per nome e non per identificativo numerico per una
  /// ragione pratica: il seed lo leggono le persone. `"skill": "handgun"` si
  /// controlla a occhio, `"skill": 10` no.
  static Map<String, Object?> encode(CatalogItem item) {
    final Map<String, Object?> json = <String, Object?>{
      'id': item.id,
      'name': item.name,
      'category': item.category.name,
      'rarity': item.rarity.name,
      'cost': item.cost,
      'weight': item.weight,
      'description': item.description,
      'source': item.source,
    };

    final WeaponData? weapon = item.weapon;
    if (weapon != null) {
      json['weapon'] = <String, Object?>{
        'skill': constantName(Skill.fromId(weapon.skillId) ?? Skill.meleeWeapon),
        'hands': weapon.handsRequired,
        'damage': weapon.damage,
        'maxAmmo': weapon.maxAmmo,
        'rof': weapon.rof,
        'concealable': weapon.isConcealable,
        if (weapon.properties.trim().isNotEmpty) 'properties': weapon.properties,
      };
    }

    final ArmorData? armor = item.armor;
    if (armor != null) {
      json['armor'] = <String, Object?>{
        'slot': armor.slot.name,
        'sp': armor.sp,
        'penalties': armor.penalties,
      };
    }

    final ClothingData? clothing = item.clothing;
    if (clothing != null) {
      json['clothing'] = <String, Object?>{
        'slot': clothing.slot.name,
        'style': clothing.style.name,
      };
    }

    return json;
  }

  /// Il contenuto del file per una lista di voci: **una voce per riga**.
  ///
  /// Una voce su piu' righe rende illeggibile la diff proprio nel caso che
  /// conta, cioe' quando ne cambia una sola: con una voce per riga una modifica
  /// tocca una riga.
  static String encodeAll(List<CatalogItem> items) {
    final StringBuffer buffer = StringBuffer('[\n');
    for (int i = 0; i < items.length; i++) {
      buffer.write('  ${_compact(encode(items[i]))}');
      buffer.write(i == items.length - 1 ? '\n' : ',\n');
    }
    buffer.write(']\n');
    return buffer.toString();
  }

  /// Fonde le voci importate con quelle gia' presenti.
  ///
  /// Regole, in ordine di importanza:
  ///
  /// 1. **il seed esistente vince.** Le voci scritte a mano portano
  ///    descrizioni e prezzi verificati: un oggetto omonimo importato da una
  ///    vecchia scheda non li sovrascrive. Il catalogo si corregge in un posto
  ///    solo, e quel posto e' il seed;
  /// 2. **il confronto e' per nome normalizzato piu' categoria**, non per
  ///    identificativo: due schede diverse non hanno gli stessi identificativi,
  ///    e "Kevlar" e' lo stesso oggetto in tutte;
  /// 3. **niente identificativi doppi**: se lo slug di un nome e' gia' usato,
  ///    la voce nuova prende un suffisso invece di sostituire la precedente.
  static SeedMerge merge({
    required List<CatalogItem> existing,
    required List<CatalogItem> incoming,
    List<String>? problems,
  }) {
    final List<String> report = problems ?? <String>[];
    final List<CatalogItem> result = <CatalogItem>[...existing];
    final List<CatalogItem> added = <CatalogItem>[];
    final List<CatalogItem> alreadyPresent = <CatalogItem>[];

    final Set<String> keys = <String>{
      for (final CatalogItem item in existing) _key(item.category, item.name),
    };
    final Set<String> ids = <String>{for (final CatalogItem item in existing) item.id};

    for (final CatalogItem item in incoming) {
      final String key = _key(item.category, item.name);
      if (!keys.add(key)) {
        alreadyPresent.add(item);
        continue;
      }

      CatalogItem candidate = item;
      if (!ids.add(item.id)) {
        final String unique = _uniqueId(item, ids);
        report.add(
          'Identificativo ${item.id} gia\' usato: "${item.name}" importato come $unique.',
        );
        candidate = _withId(item, unique);
        ids.add(unique);
      }
      added.add(candidate);
      result.add(candidate);
    }

    return SeedMerge(items: result, added: added, alreadyPresent: alreadyPresent);
  }

  // --- tipi condivisi con chi legge un seed ---------------------------------

  /// L'abilita' di un'arma, accettata come identificativo numerico, come nome
  /// della costante Dart (`handgun`) o come nome mostrato (`Pistole`).
  ///
  /// Il nome della costante si ricava da `toString()`, non da `.name`: nel
  /// dominio `Skill.name` e' il **nome tradotto** dell'abilita', che ombreggia
  /// quello dell'enum. Usare `.name` confronterebbe "Pistole" con "handgun" e
  /// fallirebbe sempre.
  static Skill? skillFrom(Object? value) {
    final String name = '${value ?? ''}'.trim();
    if (name.isEmpty) return null;

    final int? id = int.tryParse(name);
    if (id != null) return Skill.fromId(id);

    for (final Skill skill in Skill.values) {
      if (constantName(skill) == name) return skill;
    }
    for (final Skill skill in Skill.values) {
      if (skill.name.toLowerCase() == name.toLowerCase()) return skill;
    }
    return null;
  }

  static String constantName(Object value) => value.toString().split('.').last;

  // --- interni ---------------------------------------------------------------

  /// La chiave di confronto fra due oggetti: nome normalizzato e categoria.
  static String _key(ItemCategory category, String name) =>
      '${category.id}|${CatalogItem.matchKey(name)}';

  static CatalogItem _withId(CatalogItem item, String id) => CatalogItem(
        id: id,
        name: item.name,
        category: item.category,
        rarity: item.rarity,
        cost: item.cost,
        description: item.description,
        weight: item.weight,
        imageAsset: item.imageAsset,
        source: item.source,
        weapon: item.weapon,
        armor: item.armor,
        clothing: item.clothing,
      );

  static String _uniqueId(CatalogItem item, Set<String> taken) {
    for (int suffix = 2; suffix < 10000; suffix++) {
      final String candidate = '${item.id}-$suffix';
      if (!taken.contains(candidate)) return candidate;
    }
    return '${item.id}-${DateTime.now().microsecondsSinceEpoch}';
  }

  /// JSON compatto ma con le virgole seguite da uno spazio, come il seed
  /// scritto a mano: e' la differenza fra una diff leggibile e una no.
  static String _compact(Object? value) {
    if (value is Map<Object?, Object?>) {
      final String body = value.entries
          .map((MapEntry<Object?, Object?> e) => '${jsonEncode('${e.key}')}: ${_compact(e.value)}')
          .join(', ');
      return '{ $body }';
    }
    if (value is List<Object?>) {
      return '[${value.map(_compact).join(', ')}]';
    }
    return jsonEncode(value);
  }

  static Map<String, Object?>? _map(Object? value) => value is Map
      ? (value as Map<Object?, Object?>)
          .map((Object? k, Object? v) => MapEntry(k.toString(), v))
      : null;

  static Map<String, Object?> _stringMap(Map<Object?, Object?> value) =>
      value.map((Object? k, Object? v) => MapEntry(k.toString(), v));

  static ItemCategory? _category(Object? value) {
    final String name = '${value ?? ''}';
    for (final ItemCategory category in ItemCategory.values) {
      if (category.name == name || category.label.toLowerCase() == name.toLowerCase()) {
        return category;
      }
    }
    final int? id = int.tryParse(name);
    return id == null ? null : ItemCategory.fromId(id);
  }

  static Rarity _rarity(Object? value) {
    final String name = '${value ?? ''}'.toLowerCase();
    for (final Rarity rarity in Rarity.values) {
      if (rarity.name.toLowerCase() == name || rarity.label.toLowerCase() == name) return rarity;
    }
    return Rarity.common;
  }

  static ArmorSlot? _armorSlot(Object? value) {
    final String name = '${value ?? ''}';
    for (final ArmorSlot slot in ArmorSlot.values) {
      if (slot.name == name || slot.label.toLowerCase() == name.toLowerCase()) return slot;
    }
    final int? id = int.tryParse(name);
    return id == null ? null : ArmorSlot.fromId(id);
  }

  static ClothingSlot? _clothingSlot(Object? value) {
    final String name = '${value ?? ''}';
    for (final ClothingSlot slot in ClothingSlot.values) {
      if (slot.name == name || slot.label.toLowerCase() == name.toLowerCase()) return slot;
    }
    final int? ordinal = int.tryParse(name);
    return ordinal == null ? null : ClothingSlot.fromOrdinal(ordinal);
  }

  static ClothingStyle _clothingStyle(Object? value) {
    final String name = '${value ?? ''}';
    for (final ClothingStyle style in ClothingStyle.values) {
      if (style.name == name || style.label.toLowerCase() == name.toLowerCase()) return style;
    }
    return ClothingStyle.genericChic;
  }

  static int _int(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _double(Object? value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}

/// Esito della fusione fra seed esistente e voci importate.
class SeedMerge {
  const SeedMerge({
    required this.items,
    required this.added,
    required this.alreadyPresent,
  });

  /// Il nuovo contenuto del seed, nell'ordine: prima le voci che c'erano,
  /// poi quelle importate. L'ordine conta, perche' e' quello che si vede in
  /// una diff.
  final List<CatalogItem> items;

  final List<CatalogItem> added;

  /// Voci importate che il catalogo conosceva gia': non sono un errore, sono
  /// il segno che il riconoscimento per nome funziona.
  final List<CatalogItem> alreadyPresent;
}
