import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/campaign.dart';
import '../domain/enums.dart';
import '../domain/sheet.dart';

/// Errore leggibile per l'utente, con un messaggio in italiano.
class CpreduxException implements Exception {
  CpreduxException(this.message, {this.detail});

  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message\n$detail';
}

/// Riepilogo di un documento, per il browser dei file e l'elenco dei recenti.
class DocumentSummary {
  const DocumentSummary({
    required this.path,
    required this.id,
    required this.name,
    required this.kind,
    required this.formatVersion,
    required this.updatedAt,
    required this.sizeBytes,
  });

  final String path;
  final String id;
  final String name;
  final DocumentKind kind;
  final int formatVersion;
  final String updatedAt;
  final int sizeBytes;

  String get fileName => p.basename(path);
}

/// Il contenitore `.cpredux`.
///
/// E' un file SQLite con una sola tabella di contenuto, che tiene il documento
/// come JSON. Le ragioni di questa scelta, in breve:
///
/// * **SQLite come contenitore** — un file singolo, scritture atomiche,
///   resistente a chiusure improvvise, e leggibile da qualunque linguaggio:
///   se domani vuoi esportare i dati, non serve codice nostro.
/// * **JSON come contenuto** — una scheda e' un aggregato che si carica e si
///   salva sempre per intero, quindi normalizzarla in venti tabelle non
///   portava vantaggi: portava tabelle ponte, cascade e ricostruzione a ogni
///   apertura. Il JSON rende anche banale l'export parziale di un singolo
///   oggetto, funzione che il progetto originale gia' aveva.
/// * **journal DELETE, non WAL** — in WAL SQLite crea due file affiancati
///   (`-wal` e `-shm`). Per un documento che l'utente copia, sposta e manda a
///   un amico, quello e' un problema: copiando solo il `.cpredux` si copia un
///   database senza le ultime scritture. In modalita' DELETE il file e'
///   autosufficiente, che per un documento portatile vale piu' della velocita'
///   di scrittura.
class CpreduxFile {
  CpreduxFile._(this.path, this._db);

  /// Estensione dei documenti del nuovo formato.
  static const String extension = 'cpredux';

  /// Formato completo: l'utente vede `Nome.cpredux`, la finestra di
  /// salvataggio chiede `Nome`.
  static const String filePattern = '*.cpredux';

  static const String _metaFormatVersion = 'format_version';
  static const String _metaDocumentId = 'document_id';
  static const String _metaName = 'name';
  static const String _metaKind = 'kind';
  static const String _metaCreatedAt = 'created_at';

  final String path;
  Database? _db;

  bool get isOpen => _db != null;

  /// Crea un nuovo documento vuoto.
  static CpreduxFile create(
    String path, {
    required DocumentKind kind,
    required String name,
    required String documentId,
    required String now,
  }) {
    final File file = File(path);
    if (file.existsSync() && file.lengthSync() > 0) {
      throw CpreduxException('Esiste gia\' un file in questa posizione.', detail: path);
    }
    file.parent.createSync(recursive: true);

    final CpreduxFile doc = CpreduxFile._(path, sqlite3.open(path));
    doc._db!.execute('PRAGMA journal_mode = DELETE;');
    doc._db!.execute('''
      CREATE TABLE IF NOT EXISTS cpredux_meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    doc._db!.execute('''
      CREATE TABLE IF NOT EXISTS document (
        id         INTEGER PRIMARY KEY CHECK (id = 1),
        payload    TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    doc._setMeta(_metaFormatVersion, cpreduxFormatVersion.toString());
    doc._setMeta(_metaDocumentId, documentId);
    doc._setMeta(_metaName, name);
    doc._setMeta(_metaKind, kind.name);
    doc._setMeta(_metaCreatedAt, now);
    return doc;
  }

  /// Apre un documento esistente.
  ///
  /// Se il file non e' un `.cpredux` valido solleva `CpreduxException` con un
  /// messaggio comprensibile: il caso realistico e' l'utente che seleziona il
  /// file sbagliato, e non deve vedere uno stack trace di SQLite.
  static CpreduxFile open(String path) {
    final File file = File(path);
    if (!file.existsSync()) {
      throw CpreduxException('Il file non esiste.', detail: path);
    }

    final Database db;
    try {
      db = sqlite3.open(path);
    } on SqliteException catch (e) {
      throw CpreduxException(
        'Il file non e\' un documento leggibile.',
        detail: e.message,
      );
    }

    try {
      final ResultSet tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('cpredux_meta','document');",
      );
      if (tables.length < 2) {
        db.close();
        throw CpreduxException(
          'Il file non e\' un documento CPRED Visualizer.',
          detail: 'Struttura interna non riconosciuta: $path',
        );
      }
      db.execute('PRAGMA journal_mode = DELETE;');
    } on CpreduxException {
      rethrow;
    } catch (e) {
      db.close();
      throw CpreduxException('Impossibile leggere il documento.', detail: e.toString());
    }

    return CpreduxFile._(path, db);
  }

  /// Legge il documento. Restituisce una mappa vuota se non e' ancora stato
  /// scritto nulla (documento appena creato).
  Map<String, Object?> readPayload() {
    final ResultSet rows = _require().select('SELECT payload FROM document WHERE id = 1;');
    if (rows.isEmpty) return <String, Object?>{};
    final String raw = rows.first['payload'] as String;
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<Object?, Object?>) {
      throw CpreduxException('Il contenuto del documento e\' danneggiato.');
    }
    return decoded.map((Object? k, Object? v) => MapEntry(k.toString(), v));
  }

  /// Scrive il documento e aggiorna nome e data di modifica.
  void writePayload(Map<String, Object?> payload, {String? name, required String now}) {
    final String encoded = jsonEncode(payload);
    _require().execute(
      'INSERT INTO document (id, payload, updated_at) VALUES (1, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET payload = excluded.payload, updated_at = excluded.updated_at;',
      <Object?>[encoded, now],
    );
    if (name != null) _setMeta(_metaName, name);
  }

  /// Deserializza direttamente una scheda personaggio.
  CharacterSheet readSheet() => CharacterSheet.fromJson(readPayload());

  /// Deserializza direttamente un documento campagna.
  Campaign readCampaign() => Campaign.fromJson(readPayload());

  /// Scrive direttamente una scheda personaggio.
  void writeSheet(CharacterSheet sheet, {String? now}) {
    writePayload(
      sheet.toJson(),
      name: sheet.meta.name,
      now: now ?? DateTime.now().toIso8601String(),
    );
  }

  /// Scrive direttamente un documento campagna.
  void writeCampaign(Campaign campaign, {String? now}) {
    writePayload(
      campaign.toJson(),
      name: campaign.meta.name,
      now: now ?? DateTime.now().toIso8601String(),
    );
  }

  String? readMeta(String key) {
    final ResultSet rows = _require().select(
      'SELECT value FROM cpredux_meta WHERE key = ?;',
      <Object?>[key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  void _setMeta(String key, String value) {
    _require().execute(
      'INSERT INTO cpredux_meta (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value;',
      <Object?>[key, value],
    );
  }

  DocumentSummary summary() {
    final File file = File(path);
    return DocumentSummary(
      path: path,
      id: readMeta(_metaDocumentId) ?? '',
      name: readMeta(_metaName) ?? p.basenameWithoutExtension(path),
      kind: DocumentKind.values.firstWhere(
        (DocumentKind k) => k.name == readMeta(_metaKind),
        orElse: () => DocumentKind.sheet,
      ),
      formatVersion: int.tryParse(readMeta(_metaFormatVersion) ?? '') ?? cpreduxFormatVersion,
      updatedAt: _readUpdatedAt(),
      sizeBytes: file.existsSync() ? file.lengthSync() : 0,
    );
  }

  String _readUpdatedAt() {
    final ResultSet rows = _require().select('SELECT updated_at FROM document WHERE id = 1;');
    return rows.isEmpty ? '' : (rows.first['updated_at'] as String? ?? '');
  }

  Database _require() {
    final Database? db = _db;
    if (db == null) throw CpreduxException('Il documento e\' stato chiuso.');
    return db;
  }

  void close() {
    _db?.close();
    _db = null;
  }

  /// Crea una copia di sicurezza accanto all'originale.
  ///
  /// Il migratore la usa prima di convertire: convertire un formato e'
  /// un'operazione che, se sbagliata, distrugge dati a cui l'utente tiene.
  static String backup(String path, {String suffix = 'backup'}) {
    final File source = File(path);
    if (!source.existsSync()) return '';
    String candidate = '$path.$suffix';
    int counter = 1;
    while (File(candidate).existsSync()) {
      candidate = '$path.$suffix$counter';
      counter++;
    }
    source.copySync(candidate);
    return candidate;
  }
}
