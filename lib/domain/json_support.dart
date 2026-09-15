/// Helper di lettura JSON difensiva.
///
/// Un file `.cpredux` puo' arrivare da un'altra versione dell'app, da un
/// backup parziale o da un file modificato a mano. Un cast diretto
/// (`json['x'] as int`) trasformerebbe ognuno di questi casi in un crash con
/// stack trace; qui ogni lettura ha un valore di ripiego e la scheda si apre
/// comunque, con i campi mancanti a default. Per un file utente questo e'
/// sempre preferibile a un errore fatale.
library;

int readInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

double readDouble(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String readString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value == null) return fallback;
  return value.toString();
}

String? readNullableString(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

bool readBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final String v = value.toLowerCase();
    return v == 'true' || v == '1' || v == 'si' || v == 'sì';
  }
  return fallback;
}

/// Una lista di testi, ignorando il resto.
///
/// Serve a elenchi di nomi — i passeggeri di un veicolo, le righe del suo
/// registro — dove un elemento vuoto e' rumore e una virgola in piu' nel file
/// non deve far apparire una riga bianca nel diario della sessione.
/// Un oggetto JSON, senza sapere se il cast reggera'.
///
/// `message['x']` e' `Object?` e puo' essere qualsiasi cosa: un client di una
/// versione piu' vecchia, un campo mancante, un valore scritto a mano. Un cast
/// diretto trasformerebbe ognuno di questi casi in uno stack trace su un socket
/// condiviso, dove l'errore lo vede un giocatore e non chi ha scritto il codice.
Map<String, Object?> objectMap(Object? value) {
  if (value is Map<Object?, Object?>) {
    return value.map((Object? k, Object? v) => MapEntry(k.toString(), v));
  }
  return const <String, Object?>{};
}

List<String> readStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map((Object? e) => readString(e)).where((String s) => s.isNotEmpty).toList();
}

List<Map<String, Object?>> readObjectList(Object? value) {
  if (value is! List) return const <Map<String, Object?>>[];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((Map<Object?, Object?> e) => e.map((Object? k, Object? v) => MapEntry(k.toString(), v)))
      .toList(growable: false);
}
