import '../domain/items.dart';
import 'catalog.dart';
import 'legacy_item.dart';

/// Esito dell'aggiornamento di un documento.
class DocumentUpgradeResult {
  const DocumentUpgradeResult({
    required this.payload,
    required this.fromVersion,
    required this.toVersion,
    this.notes = const <String>[],
    this.counts = const <String, int>{},
  });

  final Map<String, Object?> payload;
  final int fromVersion;
  final int toVersion;

  /// Cosa e' cambiato, in forma leggibile.
  final List<String> notes;

  /// Quanti elementi sono finiti in ciascuna categoria.
  final Map<String, int> counts;

  bool get upgraded => toVersion > fromVersion;
  bool get hasNotes => notes.isNotEmpty;
}

/// Aggiorna un documento da una versione di formato a quella corrente.
///
/// Regola: **non si perde nulla e non si sovrascrive il passato**. Ogni
/// passaggio e' una funzione pura da documento a documento, quindi si puo'
/// testare senza aprire l'interfaccia e senza toccare il disco; chi la chiama
/// decide se e quando scrivere (e il chiamante, nell'app, fa prima un backup).
///
/// I passaggi sono cumulativi: un file v1 su un'app che parla v3 passa da v1 a
/// v2 e poi da v2 a v3, nell'ordine. Cosi' ogni passaggio si occupa di una sola
/// differenza e non serve scrivere una conversione per ogni coppia di versioni.
abstract final class DocumentUpgrade {
  static DocumentUpgradeResult upgrade(
    Map<String, Object?> payload, {
    required int fromVersion,
    required int toVersion,
    ItemCatalog? catalog,
  }) {
    final List<String> notes = <String>[];
    final Map<String, int> counts = <String, int>{};

    Map<String, Object?> current = payload;
    int version = fromVersion;

    // Limite di sicurezza: se un passaggio non avanza la versione si esce
    // invece di restare in un ciclo infinito su un file malformato.
    int guard = 0;
    while (version < toVersion && guard < 10) {
      guard++;
      switch (version) {
        case 1:
          current = _v1ToV2(current, catalog: catalog, notes: notes, counts: counts);
          version = 2;
        default:
          version = toVersion;
      }
    }

    return DocumentUpgradeResult(
      payload: current,
      fromVersion: fromVersion,
      toVersion: version,
      notes: notes,
      counts: counts,
    );
  }

  /// v1 → v2: le voci d'inventario contenevano l'oggetto per intero.
  ///
  /// Adesso contengono il riferimento a una voce di catalogo piu' le
  /// personalizzazioni. La conversione riconosce le voci per nome e categoria:
  /// quello che riconosce diventa un riferimento (e da quel momento segue gli
  /// aggiornamenti del catalogo), quello che non riconosce resta una voce
  /// personalizzata con i propri dati.
  ///
  /// Il conteggio delle voci **non cambia**, e nessun campo viene buttato: e' la
  /// proprieta' che rende sicuro aggiornare un documento dell'utente.
  static Map<String, Object?> _v1ToV2(
    Map<String, Object?> payload, {
    required ItemCatalog? catalog,
    required List<String> notes,
    required Map<String, int> counts,
  }) {
    final Object? rawInventory = payload['inventory'];
    if (rawInventory is! List) return <String, Object?>{...payload, 'formatVersion': 2};

    final List<Map<String, Object?>> entries = rawInventory
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> m) => m.map((Object? k, Object? v) => MapEntry(k.toString(), v)))
        .toList();

    final List<Map<String, Object?>> upgraded = <Map<String, Object?>>[];
    int matched = 0;
    int custom = 0;
    int personalised = 0;

    for (int i = 0; i < entries.length; i++) {
      final Map<String, Object?> legacy = entries[i];
      final String id = (legacy['id'] as String?)?.trim().isNotEmpty == true
          ? legacy['id']! as String
          : 'item-$i';

      final LegacyItemResult result = LegacyItemConverter.convert(
        legacy,
        entryId: id,
        catalog: catalog,
      );
      if (result.matched) {
        matched++;
        if (result.personalisationCount > 0) personalised++;
      } else {
        custom++;
      }
      upgraded.add(result.entry.toJson());
    }

    counts['riconosciuti dal catalogo'] = matched;
    if (personalised > 0) counts['con personalizzazioni'] = personalised;
    counts['oggetti personalizzati'] = custom;

    if (matched > 0) {
      notes.add(
        '$matched oggetti sono stati agganciati al catalogo: da ora seguono gli aggiornamenti '
        'e non vengono piu\' duplicati dentro la scheda.',
      );
    }
    if (custom > 0) {
      notes.add(
        '$custom oggetti non sono nel catalogo e restano definiti dentro la scheda, '
        'con tutti i loro dati.',
      );
    }
    if (personalised > 0) {
      notes.add(
        '$personalised oggetti hanno modifiche tue: sono state conservate come personalizzazioni, '
        'e continuerai a vederle anche se il catalogo cambia.',
      );
    }

    return <String, Object?>{
      ...payload,
      'inventory': upgraded,
      'formatVersion': 2,
    };
  }

  /// True se il documento contiene voci con il vecchio formato "grasso".
  ///
  /// Serve a riconoscere i file scritti prima del catalogo anche quando la
  /// versione dichiarata nel file e' sbagliata o assente, che e' il caso dei
  /// documenti prodotti durante lo sviluppo.
  static bool looksLikeV1(Map<String, Object?> payload) {
    final Object? rawInventory = payload['inventory'];
    if (rawInventory is! List) return false;
    for (final Object? entry in rawInventory) {
      if (entry is! Map) continue;
      if (entry['name'] != null && entry['catalogId'] == null) return true;
    }
    return false;
  }
}

/// Utile per i test e per la diagnostica: la versione dichiarata nel payload.
int declaredVersion(Map<String, Object?> payload) {
  final Object? meta = payload['meta'];
  if (meta is Map && meta['formatVersion'] is num) {
    return (meta['formatVersion']! as num).toInt();
  }
  if (payload['formatVersion'] is num) return (payload['formatVersion']! as num).toInt();
  return 0;
}

/// Un documento v1 ha le voci "grasse": qui si espone il conteggio, che serve a
/// dire all'utente quante voci verranno toccate prima di toccarle.
int inventoryCount(Map<String, Object?> payload) {
  final Object? rawInventory = payload['inventory'];
  return rawInventory is List ? rawInventory.length : 0;
}

/// Le voci d'inventario di un payload, qualunque sia il formato.
List<InventoryEntry> readInventory(Map<String, Object?> payload) {
  final Object? rawInventory = payload['inventory'];
  if (rawInventory is! List) return <InventoryEntry>[];
  return <InventoryEntry>[
    for (final Object? entry in rawInventory)
      if (entry is Map)
        InventoryEntry.fromJson(
          (entry as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v)),
        ),
  ];
}
