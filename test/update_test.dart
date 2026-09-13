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
        'macos-arm64': <String, Object?>{
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

  group('architettura', () {
    test('un Mac Intel e un Mac Apple Silicon non sono la stessa macchina', () {
      expect(
        UpdatePlatform.forSystem(operatingSystem: 'macos', abi: 'macosArm64'),
        UpdatePlatform.macosArm,
      );
      expect(
        UpdatePlatform.forSystem(operatingSystem: 'macos', abi: 'macosX64'),
        UpdatePlatform.macosIntel,
      );
    });

    test('un processo x64 su un Mac Apple Silicon e Intel, e giusto cosi', () {
      // E' il caso di Rosetta: quel processo **e'** x64, quindi il pacchetto che
      // puo' sostituirlo e' quello Intel. Trattarlo come Apple Silicon
      // significherebbe consegnargli un archivio che non sa aprire.
      expect(
        UpdatePlatform.forSystem(operatingSystem: 'macos', abi: 'macosX64'),
        isNot(UpdatePlatform.macosArm),
      );
    });

    test('Windows riceve il pacchetto x64 anche su ARM, per emulazione', () {
      expect(UpdatePlatform.forSystem(operatingSystem: 'windows', abi: 'windowsX64'),
          UpdatePlatform.windows);
      expect(UpdatePlatform.forSystem(operatingSystem: 'windows', abi: 'windowsArm64'),
          UpdatePlatform.windows);
    });

    test('Linux su ARM non riceve un AppImage x64', () {
      // Sarebbe un archivio che non parte, e l'aggiornamento automatico non
      // lascerebbe una copia funzionante da riaprire. Meglio dirlo.
      expect(UpdatePlatform.forSystem(operatingSystem: 'linux', abi: 'linuxX64'),
          UpdatePlatform.linux);
      expect(UpdatePlatform.forSystem(operatingSystem: 'linux', abi: 'linuxArm64'),
          UpdatePlatform.unsupported);
      expect(publish.publishedNames.containsKey(UpdatePlatform.unsupported), isFalse);
    });

    test('un sistema sconosciuto non prende il pacchetto di un altro', () {
      expect(UpdatePlatform.forSystem(operatingSystem: 'fuchsia', abi: 'fuchsiaArm64'),
          UpdatePlatform.unsupported);
    });
  });

  group('manifesto', () {
    test('si legge, con note e pacchetti per piattaforma', () {
      final UpdateManifest? manifest = UpdateManifest.tryParse(manifestJson());

      expect(manifest, isNotNull);
      expect(manifest!.version, '0.3.0');
      expect(manifest.notes, <String>['Correzioni varie']);
      expect(manifest.assetFor(UpdatePlatform.macosArm), isNotNull);
      expect(manifest.assetFor(UpdatePlatform.macosIntel), isNull);
      expect(manifest.assetFor(UpdatePlatform.windows), isNull);
      expect(manifest.releasedAt, isNotNull);
    });

    test('un URL relativo si risolve rispetto al manifesto', () {
      final UpdateManifest? manifest = UpdateManifest.tryParse(
        manifestJson(url: 'pacchetti/cpredux-0.3.0.zip'),
        baseUrl: 'https://tiadesigns.it/cpredux/latest.json',
      );

      expect(
        manifest!.assetFor(UpdatePlatform.macosArm)!.url,
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
          'windows': <String, Object?>{'url': 'https://example.test/a.zip'},
          'haiku': <String, Object?>{'url': 'https://example.test/b.zip'},
        },
      });
      final UpdateManifest? manifest = UpdateManifest.tryParse(body);
      expect(manifest!.assets, hasLength(1));
    });

    test('un pacchetto macOS universale vale per tutte e due le architetture', () {
      // La chiave `macos` e' quella di un build unico (arm64 + x86_64). Accettarla
      // in lettura significa che una pipeline che pubblica un archivio solo
      // continua ad aggiornare anche i Mac Intel, invece di lasciarli indietro
      // senza che nessuno se ne accorga.
      final UpdateManifest? manifest = UpdateManifest.tryParse(
        jsonEncode(<String, Object?>{
          UpdateManifest.versionKey: 1,
          'version': '0.3.0',
          'assets': <String, Object?>{
            'macos': <String, Object?>{'url': 'https://example.test/universale.zip'},
          },
        }),
      );
      expect(manifest!.assetFor(UpdatePlatform.macosArm), isNotNull);
      expect(manifest.assetFor(UpdatePlatform.macosIntel), isNotNull);
      expect(
        manifest.assetFor(UpdatePlatform.macosIntel)!.url,
        manifest.assetFor(UpdatePlatform.macosArm)!.url,
      );
    });

    test('la chiave specifica vince su quella universale', () {
      // Un manifesto che pubblica sia il build unico sia quello Intel: chi ha un
      // Mac Intel deve ricevere il secondo, che e' quello costruito per la sua
      // macchina, e non il primo — che comunque partirebbe, perche' e'
      // universale, ma e' piu' grande del necessario.
      final String body = jsonEncode(<String, Object?>{
        UpdateManifest.versionKey: 1,
        'version': '0.3.0',
        'assets': <String, Object?>{
          'macos': <String, Object?>{'url': 'https://example.test/universale.zip'},
          'macos-x64': <String, Object?>{'url': 'https://example.test/intel.zip'},
        },
      });
      final UpdateManifest? manifest = UpdateManifest.tryParse(body);
      expect(manifest!.assetFor(UpdatePlatform.macosIntel)!.url, 'https://example.test/intel.zip');
      expect(manifest.assetFor(UpdatePlatform.macosArm)!.url, 'https://example.test/universale.zip');
    });

    test('il nome del file si ricava dall URL', () {
      final UpdateManifest manifest = UpdateManifest.tryParse(manifestJson())!;
      expect(manifest.assetFor(UpdatePlatform.macosArm)!.resolvedFileName, 'cpredux-0.3.0.zip');

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
      expect(named.assetFor(UpdatePlatform.macosArm)!.resolvedFileName, 'cpredux.zip');
    });
  });

  group('controllo', () {
    test('segnala la versione nuova quando ce n e una', () async {
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(body: manifestJson()),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macosArm,
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
          platform: UpdatePlatform.macosArm,
        );
        expect((await updater.check()).stage, UpdateStage.upToDate, reason: published);
      }
    });

    test('un errore di rete diventa uno stato, non un eccezione', () async {
      final Updater updater = Updater(
        feedUrl: 'https://example.test/latest.json',
        transport: FakeTransport(failure: const SocketException('rete assente')),
        currentVersion: '0.2.0',
        platform: UpdatePlatform.macosArm,
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
        platform: UpdatePlatform.macosArm,
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
        platform: UpdatePlatform.macosArm,
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
        platform: UpdatePlatform.macosArm,
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
        platform: UpdatePlatform.macosArm,
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
        platform: UpdatePlatform.macosArm,
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
      // Senza architettura nel nome: e' il bundle universale, cioe' quello che
      // la pipeline pubblica davvero.
      File(p.join(dist.path, 'cpredux-macos.zip')).writeAsBytesSync(macos);
      File(p.join(dist.path, 'cpredux-windows.zip')).writeAsBytesSync(windows);

      final Directory site = Directory(p.join(temp.path, 'site'));
      final publish.PublishResult result = await publish.buildSite(
        dist: dist,
        site: site,
        version: '0.4.0',
        baseUrl: 'https://cpredux.tiadesigns.it/',
        notes: <String>['Mappa di Night City'],
        page: File(p.join(temp.path, 'pagina.html'))..writeAsStringSync('<html>pagina</html>'),
      );

      expect(result.ok, isTrue);
      // Le mancanti si dicono una per una: con quattro piattaforme sono tre, e
      // un avviso generico ("qualche pacchetto manca") obbligherebbe a dedurre
      // quale — cioe' esattamente il lavoro che il messaggio deve risparmiare.
      expect(result.messages.join('\n'), contains('nessun pacchetto per Linux'));
      // Un solo archivio macOS serve entrambe le architetture: la nota lo dice,
      // cosi' chi legge il registro del rilascio non crede che Intel manchi.
      expect(result.messages.join('\n'), contains('stesso archivio'));

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

      final UpdateAsset asset = manifest.assetFor(UpdatePlatform.macosArm)!;
      expect(
        asset.url,
        'https://cpredux.tiadesigns.it/cpredux-macos.zip?v=0.4.0',
      );
      expect(asset.size, macos.length);
      expect(asset.sha256, sha256.convert(macos).toString());
      expect(manifest.assetFor(UpdatePlatform.linux), isNull);

      // Lo stesso file per le due architetture dei Mac: chi ha un Mac Intel
      // trova una voce nel manifesto e non "nessun pacchetto pubblicato".
      expect(
        manifest.assetFor(UpdatePlatform.macosIntel)!.url,
        manifest.assetFor(UpdatePlatform.macosArm)!.url,
      );

      // E nel sito c'e' **un** archivio macOS, non due copie identiche.
      final List<String> zips = site
          .listSync()
          .whereType<File>()
          .map((File f) => p.basename(f.path))
          .where((String n) => n.endsWith('.zip'))
          .toList()
        ..sort();
      expect(zips, <String>['cpredux-macos.zip', 'cpredux-windows.zip']);

      // Le linee guida del progetto dicono che il pacchetto si verifica: se un
      // giorno il generatore smettesse di scrivere l'impronta, l'aggiornatore
      // accetterebbe archivi non verificati senza dire niente.
      expect(asset.sha256, isNotNull);
      expect(manifest.assetFor(UpdatePlatform.macosArm)!.url, contains('?v='));

      // La pagina di download finisce accanto al manifesto. Senza questa copia
      // il sito pubblicato conterrebbe gli archivi ma nessuna pagina da mandare
      // a qualcuno, e il link da condividere sarebbe l'URL di uno zip.
      expect(File(p.join(site.path, 'index.html')).existsSync(), isTrue);
    });

    test('il pacchetto macOS non finisce nel posto di Windows', () {
      // `darwin` contiene `win`: una ricerca per sottostringa assegnerebbe
      // l'archivio macOS a Windows.
      final Directory dist = Directory(p.join(temp.path, 'dist2'))..createSync(recursive: true);
      final File mac = File(p.join(dist.path, 'cpredux-darwin-arm64.zip'))
        ..writeAsBytesSync(<int>[1, 2, 3]);

      expect(publish.findArtifact(<File>[mac], UpdatePlatform.macosArm), mac);
      expect(publish.findArtifact(<File>[mac], UpdatePlatform.windows), isNull);
      expect(publish.findArtifact(<File>[mac], UpdatePlatform.linux), isNull);
    });

    test('un Mac Intel non riceve l archivio Apple Silicon, ne il contrario', () {
      // L'errore simmetrico di quello qui sopra, e il piu' grave dei due: un
      // aggiornamento che consegna l'archivio dell'altra architettura lascia
      // l'utente con un'applicazione che non parte e quella vecchia sostituita.
      final Directory dist = Directory(p.join(temp.path, 'dist-arch'))..createSync(recursive: true);
      final File arm = File(p.join(dist.path, 'cpredux-macos-arm64.zip'))
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final File intel = File(p.join(dist.path, 'cpredux-macos-x64.zip'))
        ..writeAsBytesSync(<int>[4, 5, 6]);
      final File universal = File(p.join(dist.path, 'cpredux-macos-universal.zip'))
        ..writeAsBytesSync(<int>[7, 8, 9]);

      final List<File> both = <File>[arm, intel];
      expect(publish.findArtifact(both, UpdatePlatform.macosArm), arm);
      expect(publish.findArtifact(both, UpdatePlatform.macosIntel), intel);

      // Un archivio che non dichiara l'architettura e' un build universale: va
      // bene per tutte e due le macchine.
      expect(publish.findArtifact(<File>[universal], UpdatePlatform.macosArm), universal);
      expect(publish.findArtifact(<File>[universal], UpdatePlatform.macosIntel), universal);

      // E i nomi con `x86_64` invece di `x64`, che l'estensione spezza in due
      // token: se il riconoscimento si fermasse ai token, l'archivio verrebbe
      // assegnato anche ad Apple Silicon.
      final File underscore = File(p.join(dist.path, 'cpredux-macos-x86_64.zip'))
        ..writeAsBytesSync(<int>[1]);
      expect(publish.findArtifact(<File>[underscore], UpdatePlatform.macosIntel), underscore);
      expect(publish.findArtifact(<File>[underscore], UpdatePlatform.macosArm), isNull);
    });

    test('un archivio che dichiara l architettura tiene il suo nome', () {
      // Se un giorno si pubblicassero due build macOS separate, rinominarle
      // entrambe `cpredux-macos.zip` farebbe sovrascrivere l'una con l'altra:
      // pubblicare il pacchetto Intel sotto il nome che il Mac Apple Silicon sta
      // per scaricare. Meglio due link stabili distinti che un link sbagliato.
      expect(
        publish.publishedNameFor(
            UpdatePlatform.macosArm, File('dist/cpredux-macos-arm64.zip')),
        'cpredux-macos-arm64.zip',
      );
      expect(
        publish.publishedNameFor(
            UpdatePlatform.macosIntel, File('dist/cpredux-macos-x86_64.zip')),
        'cpredux-macos-x86_64.zip',
      );
      // E senza architettura nel nome si usa il nome stabile del progetto.
      expect(
        publish.publishedNameFor(UpdatePlatform.macosArm, File('dist/cpredux-macos.zip')),
        'cpredux-macos.zip',
      );
      // Windows e Linux non hanno un nome che dipende dall'artefatto.
      expect(
        publish.publishedNameFor(UpdatePlatform.windows, File('dist/qualsiasi.zip')),
        'cpredux-windows.zip',
      );
    });

    test('la pagina di download ha un riquadro per ogni pacchetto pubblicato', () {
      // La pagina si riempie leggendo il manifesto a runtime, quindi non puo'
      // annunciare una versione diversa. Puo' invece **non avere** il riquadro
      // di una piattaforma: il pacchetto esisterebbe e nessuno saprebbe dove
      // prenderlo. Questo test tiene allineate le due liste.
      final String page = File(publish.defaultPagePath).readAsStringSync();
      for (final UpdatePlatform platform in publish.publishedPlatforms) {
        expect(
          page,
          contains('id="${platform.id}"'),
          reason: '${platform.label} viene pubblicato ma la pagina non lo mostra.',
        );
        expect(
          page,
          contains("'${platform.id}':"),
          reason: '${platform.label} non ha un\'etichetta nella pagina.',
        );
      }
      expect(
        RegExp(r'\{\{').hasMatch(page),
        isFalse,
        reason: 'La pagina contiene un segnaposto mai sostituito.',
      );
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
        platform: UpdatePlatform.macosArm,
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
