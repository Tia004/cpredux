import 'dart:convert';

/// Un aggiornamento pubblicato: quello che il programma legge per decidere se
/// c'e' qualcosa di nuovo da installare.
///
/// Il formato e' un **manifesto statico** servito da un URL fisso, non una
/// chiamata alle API di GitLab o GitHub. Le ragioni, in ordine di importanza:
///
/// * **nessun token** — le API di un repository privato richiedono
///   l'autenticazione, e mettere un token dentro un'applicazione desktop
///   significa distribuirlo a ogni utente. Un file statico si legge
///   anonimamente;
/// * **nessun limite di frequenza** — le API rispondono 429 a chi controlla
///   spesso, e un aggiornatore che ogni tanto non risponde e' peggio di nessun
///   aggiornatore;
/// * **un solo percorso per due repository** — il manifesto e' lo stesso se
///   domani il progetto si sposta da GitLab a GitHub;
/// * **il controllo di integrita' e' coerente per costruzione** — il file e i
///   suoi `sha256` vengono generati **dalla stessa esecuzione della CI** che
///   costruisce gli archivi. Non possono riferirsi a una versione diversa da
///   quella che stanno descrivendo.
class UpdateManifest {
  const UpdateManifest({
    required this.version,
    required this.assets,
    this.releasedAt,
    this.notes = const <String>[],
    this.url,
  });

  /// La versione pubblicata, es. `0.3.0`.
  final String version;

  /// Le note di rilascio, una riga per punto.
  final List<String> notes;

  final DateTime? releasedAt;

  /// La pagina da aprire per leggere tutto (rilascio, changelog).
  final String? url;

  /// Gli archivi disponibili, per piattaforma.
  final Map<UpdatePlatform, UpdateAsset> assets;

  /// Una piattaforma che non compare nel manifesto non e' un errore: significa
  /// che quel pacchetto non e' stato pubblicato, e il programma deve dirlo
  /// invece di scaricare l'archivio di un altro sistema operativo.
  UpdateAsset? assetFor(UpdatePlatform platform) => assets[platform];

  static const String versionKey = 'manifestVersion';

  /// La versione dello schema del manifesto.
  ///
  /// Esiste perche' il manifesto lo pubblica la CI e lo legge un'applicazione
  /// gia' installata: se un giorno il formato cambia, la versione vecchia
  /// dell'app deve poterlo riconoscere e dire "serve un aggiornamento manuale"
  /// invece di leggere male i campi o ignorare l'aggiornamento per sempre.
  static const int schemaVersion = 1;

  Map<String, Object?> toJson() => <String, Object?>{
        versionKey: schemaVersion,
        'version': version,
        'releasedAt': releasedAt?.toUtc().toIso8601String(),
        if (url != null) 'url': url,
        'notes': notes,
        'assets': <String, Object?>{
          for (final MapEntry<UpdatePlatform, UpdateAsset> entry in assets.entries)
            entry.key.id: entry.value.toJson(),
        },
      };

  /// Legge un manifesto, o restituisce `null` se non e' leggibile.
  ///
  /// Non solleva eccezioni di proposito: un manifesto corrotto — un deploy a
  /// meta', un proxy che inietta una pagina di errore, un file troncato — deve
  /// diventare "nessun aggiornamento disponibile", non un errore che l'utente
  /// vede all'avvio senza poterci fare nulla.
  static UpdateManifest? tryParse(String body, {String? baseUrl}) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<Object?, Object?>) return null;
      final Map<String, Object?> json =
          decoded.map((Object? k, Object? v) => MapEntry(k.toString(), v));

      final int schema = json[versionKey] is num ? (json[versionKey]! as num).toInt() : 1;
      if (schema > 1) return null;

      final String version = '${json['version'] ?? ''}'.trim();
      if (version.isEmpty) return null;

      final Uri? base = baseUrl == null ? null : Uri.tryParse(baseUrl);

      final Object? rawAssets = json['assets'];
      final Map<UpdatePlatform, UpdateAsset> assets = <UpdatePlatform, UpdateAsset>{};
      if (rawAssets is Map<Object?, Object?>) {
        for (final MapEntry<Object?, Object?> entry in rawAssets.entries) {
          final UpdatePlatform? platform = UpdatePlatform.fromId('${entry.key}');
          if (platform == null) continue;
          if (entry.value is! Map<Object?, Object?>) continue;
          final Map<String, Object?> assetJson = (entry.value! as Map<Object?, Object?>)
              .map((Object? k, Object? v) => MapEntry(k.toString(), v));
          final UpdateAsset? asset = UpdateAsset.tryParse(assetJson, base: base);
          if (asset != null) assets[platform] = asset;
        }
      }

      final Object? rawNotes = json['notes'];
      final List<String> notes = rawNotes is List
          ? rawNotes.map((Object? n) => '$n').where((String n) => n.trim().isNotEmpty).toList()
          : <String>[];

      return UpdateManifest(
        version: version,
        notes: notes,
        releasedAt: json['releasedAt'] is String ? DateTime.tryParse(json['releasedAt']! as String) : null,
        url: json['url'] is String ? json['url']! as String : null,
        assets: assets,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Le piattaforme per cui si pubblica un pacchetto.
///
/// L'identificativo e' una stringa stabile (`macos`, `windows`, `linux`) e non
/// l'indice dell'enum: finisce in un file generato dalla CI e letto da
/// applicazioni gia' installate, quindi riordinare l'enum non deve essere un
/// cambiamento di formato.
enum UpdatePlatform {
  macos('macos', 'macOS'),
  windows('windows', 'Windows'),
  linux('linux', 'Linux');

  const UpdatePlatform(this.id, this.label);

  final String id;
  final String label;

  static UpdatePlatform? fromId(String id) {
    final String clean = id.trim().toLowerCase();
    for (final UpdatePlatform platform in UpdatePlatform.values) {
      if (platform.id == clean) return platform;
    }
    return null;
  }

  /// La piattaforma su cui gira il programma adesso.
  static UpdatePlatform current(String operatingSystem) {
    if (operatingSystem.contains('win')) return UpdatePlatform.windows;
    if (operatingSystem.contains('mac')) return UpdatePlatform.macos;
    return UpdatePlatform.linux;
  }
}

/// Un archivio scaricabile per una piattaforma.
class UpdateAsset {
  const UpdateAsset({
    required this.url,
    this.sha256,
    this.size,
    this.fileName,
  });

  final String url;

  /// L'impronta del file, in esadecimale minuscolo.
  ///
  /// Serve a distinguere "il download si e' interrotto" da "il download e'
  /// finito". Su un archivio da cento megabyte un troncamento e' probabile, e
  /// installarlo al posto del programma buono e' l'unico esito davvero
  /// irreversibile di tutta questa funzione. Se il manifesto non porta
  /// l'impronta, il download viene comunque accettato ma **segnalato come non
  /// verificato**: e' una scelta consapevole, non una svista.
  final String? sha256;

  /// La dimensione attesa in byte, se nota.
  final int? size;

  /// Il nome del file da usare su disco. Si ricava dall'URL se assente.
  final String? fileName;

  String get resolvedFileName {
    final String fromJson = (fileName ?? '').trim();
    if (fromJson.isNotEmpty) return fromJson;
    final Uri? uri = Uri.tryParse(url);
    final String last = uri == null || uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    return last.isEmpty ? 'cpredux-update' : last;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'url': url,
        if (sha256 != null) 'sha256': sha256,
        if (size != null) 'size': size,
        if (fileName != null) 'fileName': fileName,
      };

  static UpdateAsset? tryParse(Map<String, Object?> json, {Uri? base}) {
    final String raw = '${json['url'] ?? ''}'.trim();
    if (raw.isEmpty) return null;

    // Un URL relativo nel manifesto e' comodo (la CI non deve sapere su che
    // dominio verra' pubblicato) e va risolto rispetto alla posizione del
    // manifesto stesso.
    String url = raw;
    if (base != null) {
      final Uri? relative = Uri.tryParse(raw);
      if (relative != null && !relative.hasScheme) {
        url = base.resolveUri(relative).toString();
      }
    }

    final String? sha = json['sha256'] is String ? (json['sha256']! as String).trim() : null;
    return UpdateAsset(
      url: url,
      sha256: sha == null || sha.isEmpty ? null : sha.toLowerCase(),
      size: json['size'] is num ? (json['size']! as num).toInt() : null,
      fileName: json['fileName'] is String ? json['fileName']! as String : null,
    );
  }
}

/// Confronta due versioni `x.y.z`.
///
/// **Non** si usa il confronto fra stringhe: `'0.10.0'.compareTo('0.9.0')` e'
/// negativo, quindi un aggiornamento 0.9 → 0.10 verrebbe ignorato per sempre.
/// E' il tipo di errore che non si nota finche' non si arriva alla decima
/// revisione, quando improvvisamente "non ci sono aggiornamenti".
int compareVersions(String a, String b) {
  final List<int> left = _parts(a);
  final List<int> right = _parts(b);
  final int length = left.length > right.length ? left.length : right.length;
  for (int i = 0; i < length; i++) {
    final int l = i < left.length ? left[i] : 0;
    final int r = i < right.length ? right[i] : 0;
    if (l != r) return l < r ? -1 : 1;
  }
  return 0;
}

/// Estrae i numeri di una versione, ignorando prefissi come `v` e suffissi come
/// `-beta.1` (che non partecipano al confronto: una prerelease si pubblica con
/// una versione piu' alta, non con un suffisso).
List<int> _parts(String version) => RegExp(r'\d+')
    .allMatches(version.split('-').first.split('+').first)
    .map((RegExpMatch m) => int.parse(m.group(0)!))
    .toList();
