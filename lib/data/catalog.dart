import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/catalog_item.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import '../domain/skills.dart';
import 'app_paths.dart';
import 'catalog_schema.dart';

/// Il catalogo oggetti, in sola lettura.
///
/// E' un database SQLite **spedito con l'app** e aperto in sola lettura. La
/// scelta di SQLite e non di un file JSON in memoria: il catalogo si
/// *interroga* (ricerca per nome, filtro per categoria e rarita', ordinamento
/// per prezzo), cresce nel tempo, e soprattutto resta ispezionabile con
/// qualunque strumento — se un giorno vuoi controllare un prezzo, apri il file.
///
/// Il database viaggia come asset e viene copiato una volta nella cartella di
/// configurazione, perche' l'FFI di SQLite vuole un percorso su disco e non
/// puo' aprire un array di byte. La copia e' identificata da un **checksum**:
/// se il catalogo spedito cambia, la copia vecchia viene sostituita invece di
/// essere usata a sorpresa.
class ItemCatalog {
  ItemCatalog._(
    this._db, {
    required this.version,
    required this.itemCount,
    this.loadError,
  });

  final Database _db;

  /// Versione dello schema del catalogo spedito.
  final int version;

  final int itemCount;

  /// Perche' il catalogo non si e' caricato, se non si e' caricato.
  ///
  /// Esiste per una ragione precisa: il ripiego (un catalogo vuoto) e' corretto
  /// — l'app deve partire comunque — ma se il motivo non viene conservato, il
  /// sintomo diventa "gli oggetti non si agganciano" senza nessun modo di
  /// capire cosa e' andato storto. Un fallimento silenzioso che nessuno puo'
  /// diagnosticare e' peggio di un errore.
  final String? loadError;

  static const String assetKey = 'assets/catalog/catalog.sqlite';

  static const String _metaVersion = 'catalog_version';
  static const String _metaChecksum = 'checksum';
  static const String _metaGenerated = 'generated_at';

  /// Un catalogo vuoto: utile ai test e allo stato iniziale prima del
  /// caricamento. Non e' un errore: senza catalogo gli oggetti sono tutti
  /// "personalizzati", che e' esattamente cio' che una scheda vuota contiene.
  factory ItemCatalog.empty({String? reason}) => ItemCatalog._(
        sqlite3.openInMemory(),
        version: CatalogSchema.version,
        itemCount: 0,
        loadError: reason,
      ).._prepare();

  /// Costruisce un catalogo in memoria, per i test.
  factory ItemCatalog.inMemory({List<CatalogItem> items = const <CatalogItem>[]}) {
    final Database db = sqlite3.openInMemory();
    final ItemCatalog catalog =
        ItemCatalog._(db, version: CatalogSchema.version, itemCount: items.length);
    catalog._prepare();
    if (items.isNotEmpty) catalog._insertAll(items);
    return catalog;
  }

  /// Apre un catalogo da un file su disco (usato dai test e dalla copia
  /// estratta dall'asset).
  static ItemCatalog openFile(String path, {bool readOnly = false}) {
    final Database db = sqlite3.open(path, mode: readOnly ? OpenMode.readOnly : OpenMode.readWrite);
    final int version = _readMetaInt(db, _metaVersion) ?? 0;
    final int count = _countItems(db);
    return ItemCatalog._(db, version: version, itemCount: count);
  }

  /// Carica il catalogo spedito con l'app.
  ///
  /// Se non riesce — asset mancante, cartella non scrivibile, database
  /// corrotto — restituisce un catalogo vuoto invece di far fallire l'avvio.
  /// Un'applicazione che non parte perche' *il catalogo* non si e' caricato
  /// sarebbe un pessimo scambio: senza catalogo non funzionano gli oggetti, ma
  /// il resto delle schede si'.
  static Future<ItemCatalog> loadBundled() async {
    try {
      final ByteData data = await rootBundle.load(assetKey);
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final int checksum = _fnv1a(bytes);

      final Directory dir = Directory(p.join(AppPaths.configDir().path, 'catalog'))
        ..createSync(recursive: true);
      final File target = File(p.join(dir.path, 'catalog.sqlite'));

      if (target.existsSync() && _readMetaIntFile(target.path, _metaChecksum) != checksum) {
        target.deleteSync();
      }
      if (!target.existsSync()) {
        // Scrittura su file temporaneo e rename: se l'app viene chiusa a meta'
        // copia non si ottiene un catalogo troncato che poi fallisce all'apertura.
        final File temp = File('${target.path}.tmp');
        temp.writeAsBytesSync(bytes, flush: true);
        temp.renameSync(target.path);
        // Il checksum si scrive *dopo*, cosi' una copia interrotta non viene
        // mai scambiata per una valida.
        final Database db = sqlite3.open(target.path);
        db.execute(
          'INSERT INTO ${CatalogSchema.metaTable} (key, value) VALUES (?, ?) '
          'ON CONFLICT(key) DO UPDATE SET value = excluded.value;',
          <Object?>[_metaChecksum, '$checksum'],
        );
        db.close();
      }

      return openFile(target.path, readOnly: true);
    } catch (error, stack) {
      final String reason = 'Catalogo non caricato: $error';
      // Non caricare il catalogo non deve impedire l'avvio — senza catalogo gli
      // oggetti sono tutti "personalizzati" e la scheda funziona lo stesso — ma
      // non deve nemmeno sparire nel silenzio: senza questa traccia l'unico
      // sintomo sarebbe "gli oggetti non si agganciano", senza sapere perche'.
      developer.log(reason, name: 'cpredux.catalog', error: error, stackTrace: stack);
      return ItemCatalog.empty(reason: reason);
    }
  }

  void _prepare() {
    for (final String statement in CatalogSchema.statements) {
      _db.execute(statement);
    }
  }

  void _insertAll(List<CatalogItem> items) {
    final String placeholders = List<String>.filled(CatalogSchema.columns.length, '?').join(', ');
    final PreparedStatement insert = _db.prepare(
      'INSERT OR REPLACE INTO ${CatalogSchema.itemsTable} '
      '(${CatalogSchema.columns.join(', ')}) VALUES ($placeholders);',
    );
    for (final CatalogItem item in items) {
      insert.execute(CatalogSchema.toRow(item));
    }
    insert.close();
  }

  /// La voce con questo identificativo, oppure null se non esiste.
  CatalogItem? byId(String id) {
    final ResultSet rows = _db.select(
      'SELECT * FROM ${CatalogSchema.itemsTable} WHERE id = ? LIMIT 1;',
      <Object?>[id],
    );
    return rows.isEmpty ? null : CatalogSchema.fromRow(_row(rows.first));
  }

  /// Ricerca per nome, categoria e rarita'.
  ///
  /// La ricerca per nome e' "contiene", non "inizia con": al tavolo si cerca
  /// "jack" e ci si aspetta anche "Armaturajack".
  List<CatalogItem> search({
    String query = '',
    ItemCategory? category,
    Rarity? rarity,
    int limit = 200,
  }) {
    final List<String> conditions = <String>[];
    final List<Object?> parameters = <Object?>[];

    final String needle = query.trim().toLowerCase();
    if (needle.isNotEmpty) {
      conditions.add('LOWER(name) LIKE ?');
      parameters.add('%$needle%');
    }
    if (category != null) {
      conditions.add('category = ?');
      parameters.add(category.id);
    }
    if (rarity != null) {
      conditions.add('rarity = ?');
      parameters.add(rarity.index);
    }

    final String where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    parameters.add(limit);
    final ResultSet rows = _db.select(
      'SELECT * FROM ${CatalogSchema.itemsTable} $where ORDER BY name COLLATE NOCASE ASC LIMIT ?;',
      parameters,
    );
    return <CatalogItem>[for (final Row row in rows) CatalogSchema.fromRow(_row(row))];
  }

  /// Cerca la voce che corrisponde a un nome, per riconoscere gli oggetti
  /// delle schede scritte prima del catalogo.
  ///
  /// Prima si prova la corrispondenza esatta (normalizzata) nella stessa
  /// categoria; se non c'e', si ripiega sul nome soltanto. La categoria come
  /// secondo criterio serve a non confondere fra loro oggetti che si chiamano
  /// allo stesso modo ma non sono la stessa cosa.
  CatalogItem? matchByName(String name, {ItemCategory? category}) {
    final String key = CatalogItem.matchKey(name);
    if (key.isEmpty) return null;

    // Il prefiltro usa il **token piu' lungo** del nome normalizzato, non il
    // nome cosi' com'e'.
    //
    // Usare il nome grezzo era un bug silenzioso: `LIKE '%armorjack leggero !%'`
    // non trova "Armorjack leggero", perche' il punto interrogativo e il
    // apostrofo del vecchio dato non sono nel catalogo. Il risultato non era un
    // errore ma la cosa peggiore: l'oggetto diventava silenziosamente
    // "personalizzato" e smetteva di seguire il catalogo, esattamente cio' che
    // questa funzione esiste per evitare. Un token lungo e' anche selettivo
    // abbastanza da non riportare mezzo catalogo come candidati.
    final String needle = _longestToken(key);
    final List<CatalogItem> candidates = search(query: needle, limit: 120);
    for (final CatalogItem candidate in candidates) {
      if (CatalogItem.matchKey(candidate.name) != key) continue;
      if (category == null || candidate.category == category) return candidate;
    }
    for (final CatalogItem candidate in candidates) {
      if (CatalogItem.matchKey(candidate.name) == key) return candidate;
    }
    return null;
  }

  /// Il token piu' lungo di una chiave normalizzata.
  ///
  /// Se ogni token e' di una sola lettera (un nome tipo "A B") si ripiega
  /// sull'intera chiave: un `LIKE` su una lettera sola non filtra niente.
  static String _longestToken(String key) {
    String best = '';
    for (final String token in key.split(' ')) {
      if (token.length > best.length) best = token;
    }
    return best.length > 1 ? best : key;
  }

  /// Tutte le voci, per gli usi che non hanno filtri (esportazione, test).
  List<CatalogItem> all({int limit = 5000}) => search(limit: limit);

  /// Le categorie presenti nel catalogo, con quante voci hanno.
  Map<ItemCategory, int> categories() {
    final ResultSet rows = _db.select(
      'SELECT category, COUNT(*) AS total FROM ${CatalogSchema.itemsTable} GROUP BY category;',
    );
    final Map<ItemCategory, int> result = <ItemCategory, int>{};
    for (final Row row in rows) {
      final ItemCategory? category = ItemCategory.fromId(row['category'] as int);
      if (category != null) result[category] = row['total'] as int;
    }
    return result;
  }

  /// Da quale fonte vengono le voci, con quante voci per fonte.
  Map<String, int> sources() {
    final ResultSet rows = _db.select(
      'SELECT source, COUNT(*) AS total FROM ${CatalogSchema.itemsTable} GROUP BY source;',
    );
    return <String, int>{
      for (final Row row in rows) '${row['source']}': row['total'] as int,
    };
  }

  DateTime? get generatedAt {
    final String? value = _readMetaString(_db, _metaGenerated);
    return value == null ? null : DateTime.tryParse(value);
  }

  /// Verifica di integrita': serve sia ai test sia a chi vuole assicurarsi che
  /// il catalogo spedito sia coerente.
  List<String> validate() {
    final List<String> problems = <String>[];
    final Map<String, int> seen = <String, int>{};

    for (final CatalogItem item in all(limit: 100000)) {
      if (item.id.trim().isEmpty) problems.add('Voce senza identificativo: ${item.name}');
      seen.update(item.id, (int v) => v + 1, ifAbsent: () => 1);
      if (item.name.trim().isEmpty) problems.add('Voce senza nome: ${item.id}');
      if (item.cost < 0) problems.add('Costo negativo: ${item.id}');
      if (item.weight < 0) problems.add('Peso negativo: ${item.id}');
      if (item.isWeapon) {
        final WeaponData weapon = item.weapon!;
        if (weapon.damage.trim().isEmpty) problems.add('Arma senza danno: ${item.id}');
        if (weapon.maxAmmo < 0) problems.add('Caricatore negativo: ${item.id}');
        if (Skill.fromId(weapon.skillId) == null) {
          problems.add('Arma con abilita inesistente (${weapon.skillId}): ${item.id}');
        }
      }
      if (item.isArmor) {
        final ArmorData armor = item.armor!;
        if (armor.sp < 0) problems.add('SP negativa: ${item.id}');
        // La penalita' e' una **grandezza** positiva, come nel vecchio
        // database. Un valore negativo non e' un bonus: il motore lo ignora
        // (`armorPenalties > 0`), quindi un'armatura pesante finirebbe per non
        // penalizzare nulla. E' un errore di dati silenzioso, ed e' esattamente
        // il tipo di cosa che va intercettata qui e non al tavolo.
        if (armor.penalties < 0) {
          problems.add('Penalita di armatura negativa (${armor.penalties}): ${item.id}');
        }
      }
    }

    for (final MapEntry<String, int> entry in seen.entries) {
      if (entry.value > 1) problems.add('Identificativo duplicato: ${entry.key}');
    }
    return problems;
  }

  void close() => _db.close();

  // --- interni -------------------------------------------------------------

  static Map<String, Object?> _row(Row row) => <String, Object?>{
        for (final String column in row.keys) column: row[column],
      };

  static int _countItems(Database db) {
    try {
      final ResultSet rows = db.select('SELECT COUNT(*) AS total FROM ${CatalogSchema.itemsTable};');
      return rows.isEmpty ? 0 : rows.first['total'] as int;
    } catch (_) {
      return 0;
    }
  }

  static int? _readMetaInt(Database db, String key) {
    final String? value = _readMetaString(db, key);
    return value == null ? null : int.tryParse(value);
  }

  static String? _readMetaString(Database db, String key) {
    try {
      final ResultSet rows = db.select(
        'SELECT value FROM ${CatalogSchema.metaTable} WHERE key = ? LIMIT 1;',
        <Object?>[key],
      );
      return rows.isEmpty ? null : rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  static int? _readMetaIntFile(String path, String key) {
    try {
      final Database db = sqlite3.open(path, mode: OpenMode.readOnly);
      try {
        return _readMetaInt(db, key);
      } finally {
        db.close();
      }
    } catch (_) {
      return null;
    }
  }

  /// FNV-1a a 32 bit: non e' crittografico e non deve esserlo. Serve a capire
  /// se il catalogo spedito e' diverso da quello gia' estratto, non a
  /// difendersi da qualcuno.
  static int _fnv1a(Uint8List bytes) {
    int hash = 0x811c9dc5;
    for (final int byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
