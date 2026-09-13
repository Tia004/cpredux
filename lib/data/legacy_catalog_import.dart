import 'package:sqlite3/sqlite3.dart';

import '../domain/catalog_item.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import '../domain/skills.dart';

/// La lettura di un vecchio `.cpred_sheet` come **sorgente di catalogo**.
///
/// Perche' esiste: nel vecchio progetto il catalogo non c'era. Ogni scheda si
/// portava dentro i propri oggetti, nelle tabelle `items`, `weapons`, `armors`
/// e `clothing`, con gli identificativi numerici delle enumerazioni. Quegli
/// oggetti sono l'unico insieme di dati di gioco che esista davvero: il resto
/// (categorie, rarita', slot, stili, abilita') e' vocabolario, non contenuto.
///
/// Questo codice non indovina niente e non completa niente: legge quello che
/// c'e' e **dice cosa non ha potuto leggere**, perche' un import silenzioso che
/// perde una riga e' peggio di un import che fallisce.
///
/// Sta in `lib/` e non in `tool/` per due motivi: non dipende da Flutter, e
/// cosi' lo usano lo stesso script, i test, e domani anche l'applicazione se
/// servisse importare da dentro l'interfaccia.
abstract final class LegacyCatalogImporter {
  /// La versione scritta dal vecchio progetto in `key_parameters.db_version`.
  static const String legacyVersion = 'cpred_sheet_1.0';

  /// Legge una scheda e restituisce gli oggetti come voci di catalogo.
  ///
  /// Non solleva per dati discutibili (una categoria fuori scala, un'abilita'
  /// sconosciuta): li annota e prosegue. Solleva solo quando il file **non si
  /// puo' leggere** — non e' un database, oppure non e' una scheda.
  static LegacyCatalogRead read(String path) {
    final List<String> notes = <String>[];

    final Database db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
    } on SqliteException catch (error) {
      throw LegacyCatalogException(
        'Il file non e\' un database leggibile.',
        detail: error.message,
      );
    }

    try {
      final String? version = _key(db, 'db_version');
      if (version == null) {
        throw LegacyCatalogException(
          'Il file non e\' una scheda CPRED: manca la versione nelle chiavi.',
          detail: path,
        );
      }
      if (version != legacyVersion) {
        notes.add(
          'Versione dichiarata "$version", attesa "$legacyVersion": si procede lo stesso.',
        );
      }

      if (!_hasTable(db, 'items')) {
        notes.add('La scheda non ha una tabella "items": non c\'e\' nulla da importare.');
        return LegacyCatalogRead(
          path: path,
          version: version,
          items: const <CatalogItem>[],
          notes: notes,
        );
      }

      final List<CatalogItem> items = <CatalogItem>[];
      final Set<String> ids = <String>{};
      final Map<ItemCategory, int> counts = <ItemCategory, int>{};
      int skipped = 0;
      bool sawWeaponAmmo = false;
      bool sawImage = false;

      final ResultSet rows = db.select(
        'SELECT id, name, cost, description, rarity, weight, category, '
        'base64image, image_extension FROM items ORDER BY id;',
      );

      for (final Row row in rows) {
        final int itemId = _int(row['id']);
        final String name = '${row['name'] ?? ''}'.trim();
        if (name.isEmpty) {
          notes.add('Oggetto #$itemId senza nome: saltato.');
          skipped++;
          continue;
        }

        final int categoryId = _int(row['category']);
        final ItemCategory? category = ItemCategory.fromId(categoryId);
        if (category == null) {
          notes.add('Oggetto "$name": categoria $categoryId inesistente, trattata come "Oggetto".');
        }

        final String? image = row['base64image'] as String?;
        if (image != null && image.isNotEmpty) sawImage = true;

        final WeaponData? weapon = _weapon(db, itemId, name, notes, () => sawWeaponAmmo = true);
        final ArmorData? armor = _armor(db, itemId, name, notes);
        final ClothingData? clothing = _clothing(db, itemId, name, notes);

        final ItemCategory effective = category ?? ItemCategory.item;
        final String id = _uniqueId('legacy-${_slug(name)}', ids, name, notes);

        items.add(
          CatalogItem(
            id: id,
            name: name,
            category: effective,
            rarity: Rarity.fromOrdinal(_int(row['rarity'])),
            cost: _int(row['cost']),
            description: '${row['description'] ?? ''}',
            weight: _double(row['weight']),
            // L'immagine della scheda **non** entra nel catalogo: e' un dato
            // dell'utente (spesso un artwork che non possiamo ridistribuire) e
            // nel nuovo formato vive nelle personalizzazioni della scheda.
            source: 'legacy',
            weapon: weapon,
            armor: armor,
            clothing: clothing,
          ),
        );
        counts.update(effective, (int v) => v + 1, ifAbsent: () => 1);
      }

      if (sawImage) {
        notes.add(
          'Le immagini degli oggetti restano nella scheda: il catalogo non '
          'spedisce artwork, e quelle scelte sono un dato dell\'utente.',
        );
      }
      if (sawWeaponAmmo) {
        notes.add(
          'Le munizioni caricate non entrano nel catalogo: sono stato di una '
          'singola arma in una singola scheda, non una proprieta\' dell\'oggetto.',
        );
      }

      return LegacyCatalogRead(
        path: path,
        version: version,
        items: items,
        notes: notes,
        counts: counts,
        skipped: skipped,
      );
    } finally {
      db.close();
    }
  }

  // --- sottotipi -------------------------------------------------------------

  static WeaponData? _weapon(
    Database db,
    int itemId,
    String name,
    List<String> notes,
    void Function() sawAmmo,
  ) {
    final ResultSet rows = db.select(
      'SELECT * FROM weapons WHERE item_id = ? LIMIT 1;',
      <Object?>[itemId],
    );
    if (rows.isEmpty) return null;
    final Row w = rows.first;

    // `weapon_skill` e' un riferimento a `skills.id`: gli stessi
    // identificativi stabili del vecchio database, che le abilita' del nuovo
    // dominio hanno conservato. Se punta fuori scala si annota e si ripiega
    // sulla mischia, che e' il valore predefinito del vecchio progetto.
    final int skillId = _int(w['weapon_skill'], Skill.meleeWeapon.id);
    final Skill? skill = Skill.fromId(skillId);
    if (skill == null) {
      notes.add('Arma "$name": abilita\' $skillId inesistente, trattata come Armi da Mischia.');
    }

    if (_int(w['current_ammo']) != 0) sawAmmo();

    final String damage = '${w['damage'] ?? ''}'.trim();
    if (damage.isEmpty) {
      notes.add('Arma "$name" senza danno: la voce entra nel catalogo senza dati d\'arma.');
    }

    return WeaponData(
      skillId: skill?.id ?? Skill.meleeWeapon.id,
      handsRequired: '${w['hands_required'] ?? '1'}',
      damage: damage,
      // Il catalogo descrive l'oggetto, non l'esemplare: il caricatore parte
      // vuoto e le munizioni caricate restano dov'erano, cioe' nella scheda.
      currentAmmo: 0,
      maxAmmo: _positive(_int(w['max_ammo'])),
      rof: _int(w['rof'], 1),
      isConcealable: _int(w['is_concealable']) != 0,
      properties: '${w['properties'] ?? ''}',
    );
  }

  static ArmorData? _armor(Database db, int itemId, String name, List<String> notes) {
    final ResultSet rows = db.select(
      'SELECT * FROM armors WHERE item_id = ? LIMIT 1;',
      <Object?>[itemId],
    );
    if (rows.isEmpty) return null;
    final Row a = rows.first;

    final int slotId = _int(a['slot'], ArmorSlot.body.id);
    final ArmorSlot? slot = ArmorSlot.fromId(slotId);
    if (slot == null) {
      notes.add('Armatura "$name": slot $slotId inesistente, trattato come Corpo.');
    }

    final int sp = _int(a['sp']);
    final int penalties = _int(a['penalties']);
    if (sp < 0 || penalties < 0) {
      notes.add('Armatura "$name": SP o penalita\' negativa, riportata a zero.');
    }

    return ArmorData(
      slot: slot ?? ArmorSlot.body,
      sp: _positive(sp),
      penalties: _positive(penalties),
    );
  }

  static ClothingData? _clothing(Database db, int itemId, String name, List<String> notes) {
    final ResultSet rows = db.select(
      'SELECT * FROM clothing WHERE item_id = ? LIMIT 1;',
      <Object?>[itemId],
    );
    if (rows.isEmpty) return null;
    final Row c = rows.first;

    final int slot = _int(c['slot']);
    final int style = _int(c['style']);
    if (slot < 0 || slot >= ClothingSlot.values.length) {
      notes.add('Capo "$name": slot $slot inesistente, trattato come "Sopra".');
    }
    if (style < 0 || style >= ClothingStyle.values.length) {
      notes.add('Capo "$name": stile $style inesistente, trattato come "Generic Chic".');
    }

    return ClothingData(
      slot: ClothingSlot.fromOrdinal(slot),
      style: ClothingStyle.fromOrdinal(style),
    );
  }

  // --- utilità ---------------------------------------------------------------

  static bool _hasTable(Database db, String table) {
    final ResultSet rows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?;",
      <Object?>[table],
    );
    return rows.isNotEmpty;
  }

  static String? _key(Database db, String key) {
    if (!_hasTable(db, 'key_parameters')) return null;
    final ResultSet rows = db.select(
      'SELECT param_value FROM key_parameters WHERE param_key = ? LIMIT 1;',
      <Object?>[key],
    );
    if (rows.isEmpty) return null;
    final Object? value = rows.first['param_value'];
    final String text = value == null ? '' : '$value';
    return text.isEmpty ? null : text;
  }

  static String _uniqueId(String candidate, Set<String> taken, String name, List<String> notes) {
    if (taken.add(candidate)) return candidate;
    for (int suffix = 2; suffix < 10000; suffix++) {
      final String next = '$candidate-$suffix';
      if (taken.add(next)) {
        notes.add('Oggetto "$name": due voci con lo stesso identificativo, la seconda e\' $next.');
        return next;
      }
    }
    final String fallback = '$candidate-${taken.length}';
    taken.add(fallback);
    return fallback;
  }

  /// Uno slug leggibile e stabile: stesso nome, stesso identificativo.
  ///
  /// Gli accenti si trasliterano invece di sparire, altrimenti "Citta'" e
  /// "Citta" produrrebbero lo stesso identificativo per due oggetti diversi.
  static String _slug(String name) {
    const Map<String, String> accents = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final StringBuffer buffer = StringBuffer();
    for (final int code in name.toLowerCase().runes) {
      final String char = String.fromCharCode(code);
      final String? plain = accents[char];
      buffer.write(plain ?? char);
    }
    final String slug = buffer
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'voce' : slug;
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

  static int _positive(int value) => value < 0 ? 0 : value;
}

/// Cosa e' stato letto da una scheda.
class LegacyCatalogRead {
  const LegacyCatalogRead({
    required this.path,
    required this.version,
    required this.items,
    required this.notes,
    this.counts = const <ItemCategory, int>{},
    this.skipped = 0,
  });

  final String path;
  final String? version;
  final List<CatalogItem> items;

  /// Cosa non e' passato e perche'. Vuoto non significa "tutto bene": significa
  /// che non c'era niente da segnalare.
  final List<String> notes;

  final Map<ItemCategory, int> counts;

  /// Quante righe sono state scartate del tutto.
  final int skipped;

  int get itemCount => items.length;
}

/// Un file che non si puo' leggere come scheda.
class LegacyCatalogException implements Exception {
  const LegacyCatalogException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message ($detail)';
}
