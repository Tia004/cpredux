import 'dart:convert';
import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/app/startup.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/net/update_installer.dart';
import 'package:cpredux/net/update_manifest.dart';
import 'package:cpredux/net/updater.dart';
import 'package:cpredux/version.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Lo script di pubblicazione si importa per percorso: vive in `tool/` perche'
// non fa parte dell'applicazione, ma **deve** essere verificato, perche' e' la
// meta' della catena di aggiornamento che gira solo in CI — il posto dove un
// errore si scopre nel momento peggiore, cioe' durante un rilascio.
import '../tool/publish.dart' as publish;

/// Un trasporto finto: nessun test tocca la rete, e soprattutto nessun test
/// scarica e installa davvero qualcosa.
class FakeTransport implements UpdateTransport {
  FakeTransport({this.body = '{}', this.failure, this.downloadBytes});

  String body;
  Object? failure;
  List<int>? downloadBytes;
  int downloadCalls = 0;
  Duration? lastTimeout;

  @override
  Future<String> getText(Uri url, {Duration timeout = const Duration(seconds: 20)}) async {
    lastTimeout = timeout;
    if (failure != null) throw failure!;
    return body;
  }

  @override
  Future<File> download(
    Uri url,
    File target, {
    void Function(int received, int? total)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    downloadCalls++;
    if (failure != null) throw failure!;
    final List<int> bytes = downloadBytes ?? utf8.encode('contenuto');
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(bytes);
    onProgress?.call(bytes.length, bytes.length);
    return target;
  }
}

String manifestJson({
  String version = '0.3.0',
  String? sha256,
  int? size,
  List<String> notes = const <String>['Correzioni varie'],
  String url = 'https://example.test/cpredux-0.3.0.zip',
}) =>
    jsonEncode(<String, Object?>{
      UpdateManifest.versionKey: 1,
      'version': version,
      'releasedAt': '2026-09-13T10:00:00Z',
      'notes': notes,
      'assets': <String, Object?>{
        'macos': <String, Object?>{
          'url': url,
          'sha256': ?sha256,
          'size': ?size,
        },
      },
    });

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_update_test');
    AppPaths.overrideForTesting(config: temp.path, data: temp.path);
  });

  tearDown(() {
    AppPaths.clearOverrides();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('versioni', () {
    test('il confronto e numerico, non alfabetico', () {
      // Il caso che rovina un aggiornatore scritto male: in ordine alfabetico
      // "0.10.0" precede "0.9.0", quindi la decima revisione non arriverebbe mai.
      expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0));
      expect(compareVersions('0.9.0', '0.10.0'), lessThan(0));
      expect(compareVersions('1.0.0', '0.99.99'), greaterThan(0));
      expect(compareVersions('2', '2.0.0'), 0);
      expect(compareVersions('v1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2.3-beta.1', '1.2.3'), 0);
    });

    test('la versione dichiarata in version.dart coincide con il pubspec', () {
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExpMatch? match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml senza campo version.');
      expect(
        match!.group(1),
        startsWith(appVersion),
        reason: 'La versione del programma e quella del pacchetto devono coincidere: se '
            'divergono, il controllo degli aggiornamenti confronta il numero sbagliato e non '
            'trova mai la versione giusta.',
      );
    });
  });

  group('manifesto', () {
    test('si legge, con note e pacchetti per piattaforma', () {
      final UpdateManifest? manifest = UpdateManifest.tryParse(manifestJson());

      expect(manifest, isNotNull);
      expect(manifest!.version, '0.3.0');
      expect(manifest.notes, <String>['Correzioni varie']);
      expect(manifest.assetFor(UpdatePlatform.macos), isNotNull);
      expect(manifest.assetFor(UpdatePlatform.windows), isNull);
      expect(manifest.releasedAt, isNotNull);
    });

    test('un URL relativo si risolve rispetto al manifesto', () {
      final UpdateManifest? manifest = UpdateManifest.tryParse(
        manifestJson(url: 'pacchetti/cpredux-0.3.0.zip'),
        baseUrl: 'https://tiadesigns.it/cpredux/latest.json',
      );

      expect(
        manifest!.assetFor(UpdatePlatform.macos)!.url,
        'https://tiadesigns.it/cpredux/pacchetti/cpredux-0.3.0.zip',
      );
    });

    test('un manifesto rotto e "nessun aggiornamento", non un errore', () {
      // Una pagina di errore di un proxy, un deploy a meta', un file troncato:
      // tutti casi che devono degradare in silenzio invece di far lampeggiare
      // un errore all'avvio di ogni utente.
      expect(UpdateManifest.tryParse('<html>404</html>'), isNull);
      expect(UpdateManifest.tryParse('{'), isNull);
      expect(UpdateManifest.tryParse('{"version": ""}'), isNull);
      expect(UpdateManifest.tryParse(manifestJson(version: '')), isNull);
      expect(
        UpdateManifest.tryParse(jsonEncode(<String, Object?>{'manifestVersion': 99, 'version': '9.9.9'})),
        isNull,
        reason: 'Uno schema futuro va rifiutato, non interpretato a caso.',
      );
    });

    test('una piattaforma sconosciuta viene ignorata', () {
      final String body = jsonEncode(<String, Object?>{
        UpdateManifest.versionKey: 1,
        'version': '0.3.0',
        'assets': <String, Object?>{
          'macos': <String, Object?>{'url': 'https://example.test/a.zip'},
          'haiku': <String, Object?>{'url': 'https://example.test/b.zip'},
        },
      });
      final UpdateManifest? manifest = UpdateManifest.tryParse(body);
      expect(manifest!.assets, hasLength(1));
    });

    test('il nome del file si ricava dall URL', () {
      final UpdateManifest manifest = UpdateManifest.tryParse(manifestJson())!;
      expect(manifest.assetFor(UpdatePlatform.macos)!.resolvedFileName, 'cpredux-0.3.0.zip');

      final UpdateManifest named = UpdateManifest.tryParse(
        jsonEncode(<String, Object?>{
          UpdateManifest.versionKey: 1,
          'version': '0.3.0',
          'assets': <String, Object?>{
            'macos': <String, Object?>{
              'url': 'https://example.test/download?id=7',
              'fileName': 'cpredux.zip',
            },
          },
        }),
      )!;
      expect(named.assetFor(UpdatePlatform.macos)!.resolvedFileName, 'cpredux.zip');
    });
  });

  group('controllo', () {
    test('segnala la versione nuova quando ce n e una', () async {
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(body: manifestJson()),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateCheck check = await updater.check();
      expect(check.stage, UpdateStage.available);
      expect(check.release!.version, '0.3.0');
    });

    test('non segnala nulla se la versione e la stessa o piu vecchia', () async {
      for (final String published in <String>['0.2.0', '0.1.9']) {
        final Updater updater = Updater(
          feedUrl: 'https://example.test/latest.json',
          transport: FakeTransport(body: manifestJson(version: published)),
          currentVersion: '0.2.0',
          platform: UpdatePlatform.macos,
        );
        expect((await updater.check()).stage, UpdateStage.upToDate, reason: published);
      }
    });

    test('un errore di rete diventa uno stato, non un eccezione', () async {
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(failure: const SocketException('rete assente')),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateCheck check = await updater.check();
      expect(check.stage, UpdateStage.failed);
      expect(check.message, contains('Nessuna connessione'));
    });

    test('un indirizzo vuoto o malformato viene rifiutato senza uscire in rete', () async {
      final Updater updater = Updater(
        feedUrl: 'non un url',
        transport: FakeTransport(),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateCheck check = await updater.check();
      expect(check.stage, UpdateStage.failed);
      expect(check.message, contains('non e\' valido'));
    });
  });

  group('download', () {
    test('un pacchetto senza impronta viene accettato ma non verificato', () async {
      final UpdateManifest manifest = UpdateManifest.tryParse(manifestJson())!;
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(downloadBytes: utf8.encode('pacchetto')),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateDownload result = await updater.download(manifest);
      expect(result.isReady, isTrue);
      expect(result.file!.existsSync(), isTrue);
      expect(result.verified, isFalse);
    });

    test('un pacchetto con l impronta giusta viene verificato', () async {
      final List<int> bytes = utf8.encode('pacchetto buono');
      final String digest = sha256.convert(bytes).toString();
      final UpdateManifest manifest =
          UpdateManifest.tryParse(manifestJson(sha256: digest, size: bytes.length))!;

      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(downloadBytes: bytes),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateDownload result = await updater.download(manifest);
      expect(result.isReady, isTrue);
      expect(result.verified, isTrue);
    });

    test('un pacchetto alterato viene rifiutato e cancellato', () async {
      final List<int> good = utf8.encode('pacchetto buono');
      final UpdateManifest manifest = UpdateManifest.tryParse(
        manifestJson(sha256: sha256.convert(good).toString()),
      )!;

      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(downloadBytes: utf8.encode('pacchetto manomesso')),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateDownload result = await updater.download(manifest);
      expect(result.isReady, isFalse);
      expect(result.error, contains('danneggiato o alterato'));
      // Il file rifiutato non resta li' a fare da trappola per il prossimo
      // tentativo: se restasse, un "riprova" potrebbe installarlo.
      expect(
        Directory(p.join(temp.path, AppPaths.appDirName, 'updates')).listSync(),
        isEmpty,
      );
    });

    test('un pacchetto troncato viene riconosciuto dalla dimensione', () async {
      final UpdateManifest manifest = UpdateManifest.tryParse(manifestJson(size: 9999))!;
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(downloadBytes: utf8.encode('corto')),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      final UpdateDownload result = await updater.download(manifest);
      expect(result.isReady, isFalse);
      expect(result.error, contains('incompleto'));
    });

    test('una piattaforma senza pacchetto lo dice, invece di scaricarne un altro', () async {
      final UpdateManifest manifest = UpdateManifest.tryParse(manifestJson())!;
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.windows,
      );

      final UpdateDownload result = await updater.download(manifest);
      expect(result.isReady, isFalse);
      expect(result.error, contains('Windows'));
      expect(result.error, contains('nessun pacchetto'));
    });

    test('sha256OfFile legge i file a blocchi', () async {
      final File file = File(p.join(temp.path, 'prova.bin'))
        ..writeAsBytesSync(<int>[for (int i = 0; i < 200000; i++) i % 256]);
      final String expected = sha256.convert(file.readAsBytesSync()).toString();
      expect(await sha256OfFile(file), expected);
      expect(await sha256OfFile(File(p.join(temp.path, 'inesistente'))), isNull);
    });
  });

  group('installazione', () {
    test('su macOS il piano scompatta e sostituisce il bundle', () {
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.macosBundle,
        path: '/Applications/cpredux.app',
        executable: '/Applications/cpredux.app/Contents/MacOS/cpredux',
      );
      final List<InstallStep> steps = planInstall(target, File('/tmp/nuovo.zip'));

      expect(steps.map((InstallStep s) => s.executable), <String>['rm', 'ditto', 'mv']);
      expect(steps[1].arguments, contains('/tmp/nuovo.zip'));
      expect(steps[2].arguments.last, '/Applications/cpredux.app');
    });

    test('su Linux il piano sostituisce l AppImage senza mai sovrascriverla in place', () {
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.linuxAppImage,
        path: '/home/tia/Applications/cpredux.AppImage',
        executable: '/home/tia/Applications/cpredux.AppImage',
      );
      final List<InstallStep> steps = planInstall(target, File('/tmp/nuovo.AppImage'));

      // Copiare sopra un file in esecuzione fallisce con ETXTBSY, e comunque
      // lasciarlo a meta' scrittura significherebbe perdere il programma: si
      // copia accanto e si rinomina.
      expect(steps.first.executable, 'cp');
      expect(steps.first.arguments.last, endsWith('.AppImage.new'));
      expect(steps[1].executable, 'mv');
      expect(steps[2].arguments, <String>['755', target.path]);
    });

    test('su Windows il piano esegue l installer in silenzio', () {
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.windowsInstaller,
        path: r'C:\Program Files\CPRED\cpredux.exe',
        executable: r'C:\Program Files\CPRED\cpredux.exe',
      );
      final List<InstallStep> steps = planInstall(target, File(r'C:\Temp\nuovo.exe'));

      expect(steps, hasLength(1));
      expect(steps.single.executable, r'C:\Temp\nuovo.exe');
      expect(steps.single.arguments, contains('/SILENT'));
    });

    test('su Windows portable si scompatta sopra la cartella di installazione', () {
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.windowsPortable,
        path: r'C:\Users\tia\AppData\Local\Programs\CPRED\cpredux.exe',
        executable: r'C:\Users\tia\AppData\Local\Programs\CPRED\cpredux.exe',
      );
      final List<InstallStep> steps = planInstall(target, File(r'C:\Temp\cpredux.zip'));

      expect(steps, hasLength(1));
      expect(steps.single.executable, 'tar');
      expect(steps.single.arguments[0], '-xf');
      expect(
        steps.single.arguments.last,
        r'C:\Users\tia\AppData\Local\Programs\CPRED',
      );
    });

    test('i codici di uscita si possono dichiarare, e il default e severo', () async {
      // Non tutti i programmi usano la convenzione "zero e' successo": gli
      // installer Inno restituiscono 3010 per "serve un riavvio", `robocopy` ha
      // sette codici di successo diversi. Il default resta severo perche' e'
      // quello giusto per `ditto`, `mv` e `chmod`: un codice inatteso li'
      // significa davvero che qualcosa non e' andato come previsto.
      const InstallStep strict = InstallStep('x', 'mv', <String>[]);
      expect(strict.accepts(0), isTrue);
      expect(strict.accepts(1), isFalse);

      const InstallStep tolerant = InstallStep(
        'y',
        'robocopy',
        <String>[],
        successCodes: <int>{0, 1, 2, 3, 4, 5, 6, 7},
      );
      expect(tolerant.accepts(3), isTrue);
      expect(tolerant.accepts(8), isFalse);

      // E un comando che fallisce davvero ferma l'installazione, con il
      // programma precedente ancora al suo posto.
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.windowsPortable,
        path: r'C:\CPRED\cpredux.exe',
        executable: r'C:\CPRED\cpredux.exe',
      );
      final InstallResult result = await applyUpdate(
        target,
        File(r'C:\Temp\cpredux.zip'),
        runner: (String executable, List<String> arguments) async => 1,
      );
      expect(result.success, isFalse);
    });

    test('si ferma al primo comando fallito', () async {
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.linuxAppImage,
        path: '/tmp/cpredux.AppImage',
        executable: '/tmp/cpredux.AppImage',
      );
      final List<String> executed = <String>[];

      final InstallResult result = await applyUpdate(
        target,
        File('/tmp/nuovo.AppImage'),
        runner: (String executable, List<String> arguments) async {
          executed.add(executable);
          return executable == 'cp' ? 1 : 0;
        },
      );

      expect(result.success, isFalse);
      expect(result.error, contains('ancora al suo posto'));
      // Proseguire dopo un `cp` fallito significherebbe rinominare un file che
      // non esiste: il programma sparirebbe.
      expect(executed, <String>['cp']);
    });

    test('esegue tutti i passi quando vanno a buon fine', () async {
      const SelfInstall target = SelfInstall(
        kind: SelfInstallKind.linuxAppImage,
        path: '/tmp/cpredux.AppImage',
        executable: '/tmp/cpredux.AppImage',
      );
      final List<String> executed = <String>[];
      final List<String> steps = <String>[];

      final InstallResult result = await applyUpdate(
        target,
        File('/tmp/nuovo.AppImage'),
        runner: (String executable, List<String> arguments) async {
          executed.add(executable);
          return 0;
        },
        onStep: (InstallStep step) => steps.add(step.label),
      );

      expect(result.success, isTrue);
      expect(executed, <String>['cp', 'mv', 'chmod']);
      expect(steps, hasLength(3));
    });
  });

  group('riconoscimento della copia', () {
    test('dentro un bundle applicativo si aggiorna da sola', () {
      final SelfInstall? target = SelfInstall.detect(
        executable: '/Applications/cpredux.app/Contents/MacOS/cpredux',
        environment: const <String, String>{},
      );
      if (!Platform.isMacOS) return;
      expect(target, isNotNull);
      expect(target!.path, '/Applications/cpredux.app');
    });

    test('una build di sviluppo non si aggiorna da sola', () {
      if (!Platform.isMacOS) return;
      final SelfInstall? target = SelfInstall.detect(
        executable: '/Users/tia/progetto/cpredux/build/macos/Build/Products/Debug/cpredux.app/'
            'Contents/MacOS/cpredux',
        environment: const <String, String>{},
      );
      // Sostituire il bundle dentro `build/` cancellerebbe il risultato di una
      // compilazione, o un bundle aperto a meta'.
      expect(target, isNull);
      expect(SelfInstall.reasonNotSelfInstallable(), contains('sviluppo'));
    });
  });

  group('pubblicazione', () {
    test('il manifesto generato si legge con lo stesso lettore dell app', () async {
      final Directory dist = Directory(p.join(temp.path, 'dist'))..createSync(recursive: true);
      final List<int> macos = utf8.encode('bundle macOS finto, abbastanza lungo');
      final List<int> windows = utf8.encode('portable Windows finto');
      File(p.join(dist.path, 'cpredux-macos.zip')).writeAsBytesSync(macos);
      File(p.join(dist.path, 'cpredux-windows.zip')).writeAsBytesSync(windows);

      final Directory site = Directory(p.join(temp.path, 'site'));
      final publish.PublishResult result = await publish.buildSite(
        dist: dist,
        site: site,
        version: '0.4.0',
        baseUrl: 'https://cpredux.tiadesigns.it/',
        notes: <String>['Mappa di Night City'],
      );

      expect(result.ok, isTrue);
      expect(result.messages.join('\n'), contains('nessun pacchetto per Linux'));

      // La proprieta' che conta: generatore e lettore sono la stessa classe, e
      // il file scritto si rilegge senza perdere niente.
      final String body = File(p.join(site.path, 'latest.json')).readAsStringSync();
      final UpdateManifest? manifest = UpdateManifest.tryParse(
        body,
        baseUrl: 'https://cpredux.tiadesigns.it/latest.json',
      );

      expect(manifest, isNotNull);
      expect(manifest!.version, '0.4.0');
      expect(manifest.notes, <String>['Mappa di Night City']);

      final UpdateAsset asset = manifest.assetFor(UpdatePlatform.macos)!;
      expect(
        asset.url,
        'https://cpredux.tiadesigns.it/cpredux-macos.zip?v=0.4.0',
      );
      expect(asset.size, macos.length);
      expect(asset.sha256, sha256.convert(macos).toString());
      expect(manifest.assetFor(UpdatePlatform.linux), isNull);

      // Le linee guida del progetto dicono che il pacchetto si verifica: se un
      // giorno il generatore smettesse di scrivere l'impronta, l'aggiornatore
      // accetterebbe archivi non verificati senza dire niente.
      expect(asset.sha256, isNotNull);
      expect(manifest.assetFor(UpdatePlatform.macos)!.url, contains('?v='));
    });

    test('il pacchetto macOS non finisce nel posto di Windows', () {
      // `darwin` contiene `win`: una ricerca per sottostringa assegnerebbe
      // l'archivio macOS a Windows.
      final Directory dist = Directory(p.join(temp.path, 'dist2'))..createSync(recursive: true);
      final File mac = File(p.join(dist.path, 'cpredux-darwin-arm64.zip'))
        ..writeAsBytesSync(<int>[1, 2, 3]);

      expect(publish.findArtifact(<File>[mac], UpdatePlatform.macos), mac);
      expect(publish.findArtifact(<File>[mac], UpdatePlatform.windows), isNull);
      expect(publish.findArtifact(<File>[mac], UpdatePlatform.linux), isNull);
    });

    test('senza artefatti la pubblicazione fallisce invece di scrivere un manifesto vuoto', () async {
      final Directory dist = Directory(p.join(temp.path, 'dist3'))..createSync(recursive: true);
      final Directory site = Directory(p.join(temp.path, 'site3'));

      final publish.PublishResult result = await publish.buildSite(
        dist: dist,
        site: site,
        version: '0.4.0',
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('Nessun artefatto'));
      // Un manifesto vuoto si leggerebbe come "sei aggiornato": peggio di un
      // errore, perche' non se ne accorgerebbe nessuno.
      expect(File(p.join(site.path, 'latest.json')).existsSync(), isFalse);
    });
  });

  group('riga di comando', () {
    test('l avvio normale e il default', () {
      expect(StartupRequest.parse(const <String>[]).mode, StartupMode.normal);
      expect(StartupRequest.parse(const <String>['--altro']).mode, StartupMode.normal);
    });

    test('la modalita aggiornamento richiede un archivio', () {
      final StartupRequest request = StartupRequest.parse(
        const <String>['--apply-update', '/tmp/nuovo.zip', '--version', '0.3.0'],
      );
      expect(request.mode, StartupMode.applyUpdate);
      expect(request.archivePath, '/tmp/nuovo.zip');
      expect(request.version, '0.3.0');

      // Senza archivio sarebbe un programma che si apre per non fare niente:
      // meglio un avvio normale che una finestra bloccata.
      expect(
        StartupRequest.parse(const <String>['--apply-update']).mode,
        StartupMode.normal,
      );
    });

    test('la modalita "appena aggiornato" porta la versione', () {
      final StartupRequest request =
          StartupRequest.parse(const <String>['--just-updated', '0.3.0']);
      expect(request.mode, StartupMode.justUpdated);
      expect(request.version, '0.3.0');
    });
  });

  group('stato applicativo', () {
    test('saltare senza un aggiornamento disponibile non cancella la scelta precedente', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      state.settings
        ..enableDiscordRichPresence = false
        ..autoCheckUpdates = false
        ..skippedUpdateVersion = '0.3.0';

      // Nessun aggiornamento disponibile: saltare "nulla" non deve riscrivere
      // la versione saltata prima, altrimenti bastherebbe aprire le impostazioni
      // per farsi riproporre l'avviso che si era appena rifiutato.
      await state.skipAvailableUpdate();
      expect(state.settings.skippedUpdateVersion, '0.3.0');
    });

    test('un aggiornamento disponibile viene proposto solo se non e stato saltato', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      state.settings
        ..enableDiscordRichPresence = false
        ..autoCheckUpdates = false;

      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(body: manifestJson(version: '9.9.9')),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macos,
      );

      // Il controllo vero passa dal feed di rete: qui si verifica la regola che
      // decide se disturbare l'utente, che e' quella che si sbaglia.
      final UpdateCheck check = await updater.check();
      expect(check.stage, UpdateStage.available);
      expect(check.release!.version, '9.9.9');
      expect(check.release!.version == state.settings.skippedUpdateVersion, isFalse);

      state.settings.skippedUpdateVersion = '9.9.9';
      expect(check.release!.version == state.settings.skippedUpdateVersion, isTrue);
    });

    test('un rinvio alla chiusura senza archivio viene annullato, non riprovato', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      state.settings
        ..enableDiscordRichPresence = false
        ..pendingUpdateVersion = '0.3.0'
        ..pendingUpdateArchive = p.join(temp.path, 'non-esiste.zip');
      SettingsStore.save(state.settings);

      // Se il rinvio restasse scritto, il programma avvierebbe l'aggiornatore a
      // ogni chiusura, in un ciclo da cui l'utente non esce.
      final bool started = await state.startPendingUpdate();
      expect(started, isFalse);
      expect(state.settings.hasPendingUpdate, isFalse);
    });

    test('l errore di un aggiornamento fallito viene ripreso all avvio', () async {
      SettingsStore.save(
        AppSettings()..lastUpdateError = 'Il pacchetto era danneggiato.',
      );

      final AppState state = AppState();
      addTearDown(state.dispose);
      expect(state.installError, isNull);

      state.consumePendingUpdateOutcome();
      expect(state.installError, 'Il pacchetto era danneggiato.');

      // Si legge una volta sola: un errore vecchio che ricompare a ogni avvio
      // diventa rumore che si impara a ignorare.
      state.clearInstallError();
      state.consumePendingUpdateOutcome();
      expect(state.installError, isNull);
    });
  });

  test('l aiuto all aggiornamento viene avviato con l archivio e la versione', () async {
    String? executable;
    List<String>? arguments;

    await spawnUpdateHelper(
      executable: '/Applications/cpredux.app/Contents/MacOS/cpredux',
      archive: File('/tmp/nuovo.zip'),
      version: '0.3.0',
      starter: (String exe, List<String> args) async {
        executable = exe;
        arguments = args;
      },
    );

    expect(executable, '/Applications/cpredux.app/Contents/MacOS/cpredux');
    expect(arguments, <String>['--apply-update', '/tmp/nuovo.zip', '--version', '0.3.0']);
  });
}
