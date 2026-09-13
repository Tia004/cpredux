// Prepara la cartella da pubblicare: manifesto degli aggiornamenti, archivi
// rinominati in modo stabile e pagina di download.
//
// La pagina non si genera: e' un file sorgente del repository che legge il
// manifesto a runtime, e qui viene solo copiata accanto agli archivi.
//
// Uso:
//   dart run tool/publish.dart --dist dist --site site --version 0.3.0 \
//       --notes "Correzioni" --notes "Mappa di Night City" \
//       --base-url https://cpredux.tiadesigns.it
//
// Il numero di pacchetti non e' fisso: si pubblica quello che la CI ha saputo
// costruire, e una piattaforma mancante viene **detta** invece di far fallire
// l'intero rilascio. Un rilascio per tre piattaforme su quattro e' meglio di
// nessun rilascio, a patto che il manifesto elenchi quelle vere.
//
// Perche' uno script Dart e non un `jq` in una pipe: lo stesso linguaggio del
// programma significa che il manifesto viene generato con **la stessa classe**
// che lo legge l'applicazione (`UpdateManifest`). Un generatore scritto in un
// altro linguaggio puo' divergere in silenzio — un campo rinominato, un numero
// scritto come stringa — e il sintomo sarebbe "gli aggiornamenti non arrivano
// piu'", che nessuno collega a una modifica fatta mesi prima nella CI.
//
// Perche' i nomi dei file sono **stabili** (`cpredux-macos-arm64.zip`) e non
// contengono la versione: cosi' il link che hai mandato a qualcuno resta valido
// per sempre. La versione viaggia nel manifesto e in un parametro di cache
// (`?v=0.3.0`), che e' l'unico modo di avere entrambe le cose.

import 'dart:convert';
import 'dart:io';

import 'package:cpredux/net/update_manifest.dart';
import 'package:cpredux/version.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Il nome stabile con cui ogni pacchetto viene pubblicato.
///
/// Stabile significa senza il numero di versione: il link che hai mandato a
/// qualcuno resta valido per sempre, e la versione viaggia nel manifesto e in un
/// parametro di cache.
///
/// I due macOS puntano allo **stesso** file, e non e' pigrizia: il bundle che
/// Flutter produce e' universale — ogni eseguibile dentro di esso ha le due
/// slice, `x86_64` e `arm64` (verificato con `lipo -archs`) — quindi due
/// archivi separati sarebbero lo stesso contenuto due volte, e ottenerli
/// davvero richiederebbe di assottigliare e ri-firmare ogni file del bundle
/// per risparmiare una decina di megabyte su venti.
///
/// Le due chiavi restano due perche' la differenza esiste: il programma chiede
/// il pacchetto della **propria** architettura, e se un giorno si pubblicassero
/// build separate — che `findArtifact` e `publishedNameFor` gia' sanno
/// distinguere — il manifesto sarebbe gia' quello giusto.
const Map<UpdatePlatform, String> publishedNames = <UpdatePlatform, String>{
  UpdatePlatform.macosArm: 'cpredux-macos.zip',
  UpdatePlatform.macosIntel: 'cpredux-macos.zip',
  UpdatePlatform.windows: 'cpredux-windows.zip',
  UpdatePlatform.linux: 'cpredux-linux.AppImage',
};

/// Il nome con cui si pubblica un artefatto trovato.
///
/// Normalmente e' quello stabile qui sopra. Se pero' l'artefatto **dichiara**
/// l'architettura (`...-arm64.zip`, `...-x64.zip`) si tiene il suo nome: sono
/// due build separate, e rinominarle entrambe `cpredux-macos.zip` farebbe
/// sovrascrivere l'una con l'altra — cioe' pubblicare un pacchetto Intel sotto
/// il nome che il Mac Apple Silicon sta per scaricare. Meglio due link stabili
/// distinti che un link solo e sbagliato.
String publishedNameFor(UpdatePlatform platform, File artifact) {
  final String base = p.basename(artifact.path).toLowerCase();
  if (platform.isMacos && _declaresArchitecture(base)) return base;
  return publishedNames[platform]!;
}

/// True se il nome del file dichiara un'architettura.
bool _declaresArchitecture(String name) {
  final String flat = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return flat.contains('arm64') ||
      flat.contains('aarch64') ||
      flat.contains('x64') ||
      flat.contains('x8664') ||
      flat.contains('amd64') ||
      flat.contains('intel');
}

/// La pagina di download, che viene copiata accanto agli archivi.
///
/// E' un file **sorgente** del repository e non viene generata: legge
/// `latest.json` a runtime e si riempie da sola, quindi non puo' annunciare una
/// versione diversa da quella pubblicata. Questo percorso esiste perche' la
/// copia non si dimentichi: senza, il sito pubblicato conterrebbe gli archivi e
/// il manifesto ma **nessuna pagina** che li elenca, e il link da mandare in giro
/// sarebbe l'URL di un archivio.
const String defaultPagePath = 'site/index.html';

/// I pacchetti che si pubblicano, in ordine di presentazione.
///
/// `unsupported` non c'e': non e' una piattaforma per cui si costruisce, e' il
/// modo in cui il programma dice "per questa macchina non c'e' niente".
Iterable<UpdatePlatform> get publishedPlatforms =>
    UpdatePlatform.values.where((UpdatePlatform p) => publishedNames.containsKey(p));

/// L'esito della preparazione.
class PublishResult {
  const PublishResult({this.manifest, this.error, this.messages = const <String>[]});

  final UpdateManifest? manifest;
  final String? error;
  final List<String> messages;

  bool get ok => error == null && manifest != null;
}

/// Copia gli archivi con un nome stabile, ne calcola impronta e dimensione, e
/// scrive `latest.json` in [site].
Future<PublishResult> buildSite({
  required Directory dist,
  required Directory site,
  required String version,
  String baseUrl = '',
  List<String> notes = const <String>[],
  File? page,
}) async {
  final List<String> log = <String>[];

  if (!dist.existsSync()) {
    return PublishResult(error: 'Cartella degli artefatti non trovata: ${dist.path}');
  }

  final String base = baseUrl.replaceAll(RegExp(r'/+$'), '');

  final List<File> artifacts = dist
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => !p.basename(f.path).startsWith('.'))
      .toList();

  final Map<UpdatePlatform, UpdateAsset> assets = <UpdatePlatform, UpdateAsset>{};
  final List<UpdatePlatform> missing = <UpdatePlatform>[];

  /// Gli asset gia' pubblicati, per nome del file: lo stesso archivio non si
  /// copia e non si calcola due volte.
  final Map<String, UpdateAsset> byName = <String, UpdateAsset>{};

  for (final UpdatePlatform platform in publishedPlatforms) {
    final File? artifact = findArtifact(artifacts, platform);
    if (artifact == null) {
      missing.add(platform);
      continue;
    }

    final String published = publishedNameFor(platform, artifact);

    // Due piattaforme finiscono sullo stesso nome solo quando e' lo **stesso**
    // file: su macOS perche' il bundle e' universale, ed e' l'unico caso in cui
    // `publishedNameFor` da' lo stesso nome a due piattaforme (un archivio che
    // dichiara l'architettura tiene il proprio nome, che e' diverso dall'altro
    // per costruzione). Copiarlo e calcolarne l'impronta due volte sarebbe solo
    // lavoro ripetuto, quindi si riusa il primo esito.
    final UpdateAsset? already = byName[published];
    if (already != null) {
      assets[platform] = already;
      log.add("$platform: stesso archivio gia' pubblicato ($published)");
      continue;
    }

    final File target = File(p.join(site.path, published));
    site.createSync(recursive: true);
    if (artifact.absolute.path != target.absolute.path) {
      artifact.copySync(target.path);
    }

    final List<int> bytes = target.readAsBytesSync();
    final UpdateAsset asset = UpdateAsset(
      url: base.isEmpty ? published : '$base/$published?v=$version',
      sha256: sha256.convert(bytes).toString(),
      size: bytes.length,
      fileName: published,
    );
    assets[platform] = asset;
    byName[published] = asset;
    log.add('$platform: ${p.basename(artifact.path)} -> $published '
        '(${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)');
  }

  if (assets.isEmpty) {
    return PublishResult(
      error: 'Nessun artefatto riconosciuto in ${dist.path}: niente da pubblicare.',
      messages: log,
    );
  }

  // Una piattaforma mancante non blocca il rilascio — un runner macOS puo'
  // essere in manutenzione — ma va **detta**: il sintomo per l'utente sarebbe
  // "su Linux non si aggiorna", e senza questo avviso la causa resterebbe
  // invisibile per settimane.
  for (final UpdatePlatform platform in missing) {
    log.add('Attenzione: nessun pacchetto per ${platform.label}.');
  }

  final UpdateManifest manifest = UpdateManifest(
    version: version,
    notes: notes,
    releasedAt: DateTime.now().toUtc(),
    url: base.isEmpty ? null : '$base/',
    assets: assets,
  );

  File(p.join(site.path, 'latest.json')).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    flush: true,
  );
  log.add('Manifesto scritto: ${p.join(site.path, 'latest.json')}');

  // La pagina va **nello stesso posto** del manifesto: e' quello che le permette
  // di chiedere `latest.json` con un percorso relativo, e quindi di funzionare
  // sia sul dominio di Pages sia aperta da disco.
  final File source = page ?? File(defaultPagePath);
  if (!source.existsSync()) {
    log.add('Attenzione: pagina di download non trovata (${source.path}), '
        'il sito pubblica gli archivi senza pagina.');
  } else {
    final File target = File(p.join(site.path, 'index.html'));
    if (source.absolute.path != target.absolute.path) {
      site.createSync(recursive: true);
      source.copySync(target.path);
    }
    log.add('Pagina di download: ${target.path}');
  }

  return PublishResult(manifest: manifest, messages: log);
}

/// Trova il pacchetto di una piattaforma fra gli artefatti prodotti dalla CI.
///
/// Il confronto e' per **token** e non per sottostringa, e non e' pedanteria:
/// `darwin` contiene `win`, quindi una ricerca per sottostringa assegnerebbe il
/// pacchetto macOS a Windows e il manifesto punterebbe "Windows" a un archivio
/// di macOS. Un utente Windows installerebbe un bundle macOS e l'esito piu'
/// probabile e' un'applicazione che non parte piu'.
///
/// Su macOS l'architettura e' un secondo filtro, e il caso da evitare e' quello
/// simmetrico: pubblicare un build arm64 come "Intel" significa consegnare a un
/// Mac Intel un'applicazione che non parte, e l'aggiornamento automatico lo fa
/// senza che l'utente possa accorgersene prima di aver perso l'installazione
/// funzionante. Se l'archivio non dichiara l'architettura si assume
/// **universale**, e viene accettato da entrambe: e' il caso di un build `lipo`,
/// che per definizione gira su tutte e due.
File? findArtifact(List<File> files, UpdatePlatform platform) {
  File? best;

  for (final File file in files) {
    final String name = p.basename(file.path).toLowerCase();
    final Set<String> tokens =
        name.split(RegExp(r'[^a-z0-9]+')).where((String t) => t.isNotEmpty).toSet();
    // L'estensione spezza `x86_64` in `x86` + `64`: l'architettura si cerca
    // anche nella stringa intera, altrimenti quei due token non bastano a
    // riconoscere un build Intel.
    final String flat = name.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final String ext = p.extension(name);

    final bool isMacos = tokens.contains('macos') ||
        tokens.contains('darwin') ||
        tokens.contains('osx');
    final bool isArm =
        tokens.contains('arm64') || tokens.contains('aarch64') || flat.contains('arm64');
    final bool isIntel = tokens.contains('x64') ||
        tokens.contains('intel') ||
        tokens.contains('amd64') ||
        flat.contains('x8664');

    final bool matches = switch (platform) {
      UpdatePlatform.macosArm || UpdatePlatform.macosIntel =>
        isMacos &&
            ext == '.zip' &&
            // Nessun token di architettura: build universale, va bene per
            // entrambe. Con un token esplicito, deve essere quello giusto.
            (!isArm && !isIntel ||
                (platform == UpdatePlatform.macosArm ? isArm : isIntel)),
      UpdatePlatform.windows =>
        (tokens.contains('windows') || tokens.contains('win') || tokens.contains('win64')) &&
            (ext == '.zip' || ext == '.exe'),
      UpdatePlatform.linux =>
        (tokens.contains('appimage') || tokens.contains('linux')) &&
            (ext == '.appimage' || ext == '.gz' || ext == '.zip'),
      UpdatePlatform.unsupported => false,
    };
    if (!matches) continue;

    // Se la CI produce piu' varianti (un build con i simboli di debug e uno
    // senza) si pubblica il piu' grande: e' quello che l'utente vuole scaricare.
    if (best == null || file.lengthSync() > best.lengthSync()) best = file;
  }

  return best;
}

Future<void> main(List<String> arguments) async {
  final Map<String, String> options = <String, String>{};
  final List<String> notes = <String>[];

  for (int i = 0; i < arguments.length; i++) {
    final String arg = arguments[i];
    final String value = i + 1 < arguments.length ? arguments[i + 1] : '';
    switch (arg) {
      case '--dist':
        options['dist'] = value;
        i++;
      case '--site':
        options['site'] = value;
        i++;
      case '--version':
        options['version'] = value;
        i++;
      case '--base-url':
        options['base'] = value;
        i++;
      case '--notes':
        notes.add(value);
        i++;
      case '--page':
        options['page'] = value;
        i++;
    }
  }

  final PublishResult result = await buildSite(
    dist: Directory(options['dist'] ?? 'dist'),
    site: Directory(options['site'] ?? 'site'),
    version: options['version'] ?? appVersion,
    baseUrl: options['base'] ?? '',
    notes: notes,
    page: options['page'] == null ? null : File(options['page']!),
  );

  for (final String message in result.messages) {
    stdout.writeln(message);
  }

  if (!result.ok) {
    stderr.writeln(result.error);
    exitCode = 1;
    return;
  }

  stdout.writeln('  versione ${result.manifest!.version}, '
      '${result.manifest!.assets.length} pacchetti');
}
