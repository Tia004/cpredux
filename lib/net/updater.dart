import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../data/app_paths.dart';
import '../data/settings_store.dart';
import '../version.dart';
import 'update_manifest.dart';

/// A che punto e' il controllo degli aggiornamenti.
enum UpdateStage {
  /// Non e' ancora stato controllato nulla.
  idle,

  /// Controllo in corso.
  checking,

  /// Il programma e' aggiornato.
  upToDate,

  /// C'e' una versione nuova.
  available,

  /// Download in corso.
  downloading,

  /// L'archivio e' pronto per essere applicato.
  ready,

  /// Il controllo o il download non sono riusciti.
  failed,
}

/// Il risultato di un controllo.
class UpdateCheck {
  const UpdateCheck.upToDate(this.currentVersion)
      : stage = UpdateStage.upToDate,
        release = null,
        message = null,
        progress = 0;

  const UpdateCheck.available(this.release)
      : stage = UpdateStage.available,
        currentVersion = null,
        message = null,
        progress = 0;

  const UpdateCheck.failed(this.message)
      : stage = UpdateStage.failed,
        release = null,
        currentVersion = null,
        progress = 0;

  final UpdateStage stage;
  final UpdateManifest? release;
  final String? currentVersion;
  final String? message;
  final double progress;

  bool get canInstall => stage == UpdateStage.available || stage == UpdateStage.ready;
}

/// Il canale di rete usato dall'aggiornatore.
///
/// E' un'interfaccia e non una chiamata diretta a `HttpClient` per una ragione
/// pratica: il comportamento che conta — cosa succede con un manifesto corrotto,
/// un archivio troncato, un'impronta che non corrisponde — deve essere
/// verificabile senza dipendere dalla rete. Un updater che non si puo' testare
/// offline e' un updater che si scopre rotto quando serve.
abstract class UpdateTransport {
  Future<String> getText(Uri url, {Duration timeout});

  /// Scarica su [target] e restituisce il file. [onProgress] riceve i byte
  /// ricevuti e il totale atteso (null se il server non lo dichiara).
  Future<File> download(
    Uri url,
    File target, {
    void Function(int received, int? total)? onProgress,
    Duration timeout,
  });
}

/// L'implementazione reale, su `dart:io`.
class HttpUpdateTransport implements UpdateTransport {
  HttpUpdateTransport({HttpClient? client}) : _client = client ?? HttpClient() {
    _client
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = 'cpredux/$appVersion';
  }

  final HttpClient _client;

  @override
  Future<String> getText(Uri url, {Duration timeout = const Duration(seconds: 20)}) async {
    final HttpClientRequest request = await _client.getUrl(url).timeout(timeout);
    final HttpClientResponse response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Il server ha risposto ${response.statusCode}', uri: url);
    }
    return response.transform(utf8.decoder).join().timeout(timeout);
  }

  @override
  Future<File> download(
    Uri url,
    File target, {
    void Function(int received, int? total)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final HttpClientRequest request = await _client.getUrl(url).timeout(timeout);
    final HttpClientResponse response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Il server ha risposto ${response.statusCode}', uri: url);
    }

    final int? total = response.contentLength >= 0 ? response.contentLength : null;
    final IOSink sink = target.openWrite();
    int received = 0;
    try {
      await for (final List<int> chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return target;
  }
}

/// Controlla, scarica e applica gli aggiornamenti.
class Updater {
  Updater({
    required this.feedUrl,
    UpdateTransport? transport,
    String? currentVersion,
    UpdatePlatform? platform,
  })  : transport = transport ?? HttpUpdateTransport(),
        currentVersion = currentVersion ?? appVersion,
        platform = platform ?? platformOfThisMachine();

  /// La piattaforma di questa macchina, con l'architettura.
  ///
  /// L'architettura non e' un dettaglio: su macOS un archivio costruito per
  /// Apple Silicon non si apre su Intel, quindi indovinare il sistema operativo
  /// non basta piu' — servono entrambe le informazioni, e `Abi.current()`
  /// riporta l'architettura del **processo in esecuzione**, cioe' esattamente
  /// quella del pacchetto che deve sostituirlo.
  ///
  /// Si passa la stringa (`macos_arm64`) e non l'oggetto `Abi` per non
  /// trascinare `dart:ffi` dentro il formato del manifesto: li' la decisione si
  /// prende su due stringhe, e cosi' si puo' verificare.
  static UpdatePlatform platformOfThisMachine() => UpdatePlatform.forSystem(
        operatingSystem: Platform.operatingSystem,
        abi: '${Abi.current()}',
      );

  /// L'URL del manifesto degli aggiornamenti.
  ///
  /// Si puo' cambiare dalle impostazioni: serve a chi ospita i propri build, e
  /// serve a poter spegnere il controllo puntandolo a un file locale.
  final String feedUrl;

  final UpdateTransport transport;
  final String currentVersion;
  final UpdatePlatform platform;

  /// Dove si raccolgono gli archivi scaricati.
  static Directory downloadsDir() =>
      Directory(p.join(AppPaths.configDir().path, 'updates'));

  Future<UpdateCheck> check() async {
    final String urlStr = feedUrl.trim().isNotEmpty
        ? feedUrl.trim()
        : AppSettings.defaultUpdateFeedUrl;
    final Uri? uri = Uri.tryParse(urlStr);
    if (uri == null || !uri.hasScheme) {
      return const UpdateCheck.failed('L\'indirizzo degli aggiornamenti non e\' valido.');
    }

    Object? firstError;
    try {
      final String body = await transport.getText(uri);
      final UpdateManifest? manifest = UpdateManifest.tryParse(body, baseUrl: uri.toString());
      if (manifest != null) {
        if (compareVersions(manifest.version, currentVersion) <= 0) {
          return UpdateCheck.upToDate(currentVersion);
        }
        return UpdateCheck.available(manifest);
      }
    } catch (e) {
      firstError = e;
    }

    // Fallback automatico su GitHub raw se il feed principale fallisce o viene bloccato da bot protection
    if (urlStr != AppSettings.githubUpdateFeedUrl) {
      try {
        final Uri fallbackUri = Uri.parse(AppSettings.githubUpdateFeedUrl);
        final String fallbackBody = await transport.getText(fallbackUri);
        final UpdateManifest? fallbackManifest =
            UpdateManifest.tryParse(fallbackBody, baseUrl: fallbackUri.toString());
        if (fallbackManifest != null) {
          if (compareVersions(fallbackManifest.version, currentVersion) <= 0) {
            return UpdateCheck.upToDate(currentVersion);
          }
          return UpdateCheck.available(fallbackManifest);
        }
      } catch (_) {}
    }

    if (firstError is TimeoutException) {
      return const UpdateCheck.failed('Il server non ha risposto in tempo.');
    }
    if (firstError is SocketException) {
      return UpdateCheck.failed('Nessuna connessione: ${firstError.osError?.message ?? firstError.message}');
    }
    if (firstError != null) {
      return UpdateCheck.failed('Controllo non riuscito: $firstError');
    }

    return const UpdateCheck.failed(
      'Il file degli aggiornamenti non e\' leggibile. Riprova piu\' tardi.',
    );
  }

  /// Scarica l'archivio per la piattaforma corrente.
  ///
  /// Restituisce un esito esplicito anche nei casi in cui "non c'e' niente da
  /// fare" e' la risposta corretta: una piattaforma senza pacchetto pubblicato
  /// deve dire *quella* cosa, non fallire con un errore generico e nemmeno
  /// scaricare l'archivio di un altro sistema operativo.
  Future<UpdateDownload> download(
    UpdateManifest manifest, {
    void Function(double progress)? onProgress,
  }) async {
    final UpdateAsset? asset = manifest.assetFor(platform);
    if (asset == null) {
      return UpdateDownload.failed(
        'Per ${platform.label} non e\' stato pubblicato nessun pacchetto. '
        'Scarica la versione nuova dalla pagina dei rilasci.',
      );
    }

    final Uri? uri = Uri.tryParse(asset.url);
    if (uri == null || !uri.hasScheme) {
      return UpdateDownload.failed('L\'indirizzo del pacchetto non e\' valido.');
    }

    final Directory dir = downloadsDir()..createSync(recursive: true);
    final File target = File(p.join(dir.path, asset.resolvedFileName));

    try {
      await transport.download(
        uri,
        target,
        onProgress: (int received, int? total) {
          if (total == null || total <= 0) return;
          onProgress?.call((received / total).clamp(0, 1));
        },
      );
    } on TimeoutException {
      return UpdateDownload.failed('Il download non e\' terminato in tempo.');
    } catch (e) {
      return UpdateDownload.failed('Download non riuscito: $e');
    }

    // La dimensione dichiarata e' un controllo piu' debole dell'impronta ma
    // intercetta il caso piu' frequente, il troncamento, senza dover leggere
    // tutto il file.
    if (asset.size != null && asset.size! > 0) {
      final int actual = await target.length();
      if (actual != asset.size) {
        target.deleteSync();
        return UpdateDownload.failed(
          'Il pacchetto scaricato e\' incompleto ($actual byte su ${asset.size}). Riprova.',
        );
      }
    }

    if (asset.sha256 != null) {
      final String? digest = await sha256OfFile(target);
      if (digest == null || digest != asset.sha256) {
        target.deleteSync();
        return UpdateDownload.failed(
          'Il pacchetto scaricato e\' danneggiato o alterato (l\'impronta non corrisponde). '
          'Non e\' stato installato nulla.',
        );
      }
    }

    return UpdateDownload.ready(
      manifest: manifest,
      file: target,
      verified: asset.sha256 != null,
    );
  }
}

/// Esito di un download.
class UpdateDownload {
  const UpdateDownload.ready({
    required this.manifest,
    required this.file,
    required this.verified,
  }) : error = null;

  const UpdateDownload.failed(this.error)
      : manifest = null,
        file = null,
        verified = false;

  final UpdateManifest? manifest;
  final File? file;
  final String? error;

  /// True se il pacchetto e' stato verificato con l'impronta SHA-256.
  final bool verified;

  bool get isReady => file != null && manifest != null;
}

/// L'impronta SHA-256 di un file, letta a blocchi.
///
/// A blocchi e non tutto insieme: un pacchetto da cento megabyte letto in una
/// volta sola occupa cento megabyte di memoria per calcolare un numero.
Future<String?> sha256OfFile(File file) async {
  try {
    final DigestCollector collector = DigestCollector();
    final ByteConversionSink input = sha256.startChunkedConversion(collector);
    await for (final List<int> chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    return collector.value;
  } catch (_) {
    return null;
  }
}

/// Raccoglie il digest prodotto dal calcolo a blocchi.
class DigestCollector implements Sink<Digest> {
  String? value;

  @override
  void add(Digest data) => value = data.toString();

  @override
  void close() {}
}
