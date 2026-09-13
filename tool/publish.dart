// Prepara la cartella da pubblicare: manifesto degli aggiornamenti, archivi
// rinominati in modo stabile e pagina di download.
//
// Uso:
//   dart run tool/publish.dart --dist dist --site site --version 0.3.0 \
//       --notes "Correzioni" --notes "Mappa di Night City" \
//       --base-url https://cpredux.tiadesigns.it
//
// Perche' uno script Dart e non un `jq` in una pipe: lo stesso linguaggio del
// programma significa che il manifesto viene generato con **la stessa classe**
// che lo legge l'applicazione (`UpdateManifest`). Un generatore scritto in un
// altro linguaggio puo' divergere in silenzio — un campo rinominato, un numero
// scritto come stringa — e il sintomo sarebbe "gli aggiornamenti non arrivano
// piu'", che nessuno collega a una modifica fatta mesi prima nella CI.
//
// Perche' i nomi dei file sono **stabili** (`cpredux-macos.zip`) e non
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
const Map<UpdatePlatform, String> publishedNames = <UpdatePlatform, String>{
  UpdatePlatform.macos: 'cpredux-macos.zip',
  UpdatePlatform.windows: 'cpredux-windows.zip',
  UpdatePlatform.linux: 'cpredux-linux.AppImage',
};

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

  for (final UpdatePlatform platform in UpdatePlatform.values) {
    final File? artifact = findArtifact(artifacts, platform);
    if (artifact == null) {
      missing.add(platform);
      continue;
    }

    final String published = publishedNames[platform]!;
    final File target = File(p.join(site.path, published));
    site.createSync(recursive: true);
    artifact.copySync(target.path);

    final List<int> bytes = target.readAsBytesSync();
    assets[platform] = UpdateAsset(
      url: base.isEmpty ? published : '$base/$published?v=$version',
      sha256: sha256.convert(bytes).toString(),
      size: bytes.length,
      fileName: published,
    );
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

  return PublishResult(manifest: manifest, messages: log);
}

/// Trova il pacchetto di una piattaforma fra gli artefatti prodotti dalla CI.
///
/// Il confronto e' per **token** e non per sottostringa, e non e' pedanteria:
/// `darwin` contiene `win`, quindi una ricerca per sottostringa assegnerebbe il
/// pacchetto macOS a Windows e il manifesto punterebbe "Windows" a un archivio
/// di macOS. Un utente Windows installerebbe un bundle macOS e l'esito piu'
/// probabile e' un'applicazione che non parte piu'.
File? findArtifact(List<File> files, UpdatePlatform platform) {
  File? best;

  for (final File file in files) {
    final String name = p.basename(file.path).toLowerCase();
    final Set<String> tokens =
        name.split(RegExp(r'[^a-z0-9]+')).where((String t) => t.isNotEmpty).toSet();
    final String ext = p.extension(name);

    final bool matches = switch (platform) {
      UpdatePlatform.macos =>
        (tokens.contains('macos') || tokens.contains('darwin') || tokens.contains('osx')) &&
            ext == '.zip',
      UpdatePlatform.windows =>
        (tokens.contains('windows') || tokens.contains('win') || tokens.contains('win64')) &&
            (ext == '.zip' || ext == '.exe'),
      UpdatePlatform.linux =>
        (tokens.contains('appimage') || tokens.contains('linux')) &&
            (ext == '.appimage' || ext == '.gz' || ext == '.zip'),
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
    }
  }

  final PublishResult result = await buildSite(
    dist: Directory(options['dist'] ?? 'dist'),
    site: Directory(options['site'] ?? 'site'),
    version: options['version'] ?? appVersion,
    baseUrl: options['base'] ?? '',
    notes: notes,
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
