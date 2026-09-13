import 'dart:io';

import 'package:path/path.dart' as p;

/// Come questa copia del programma puo' essere sostituita.
enum SelfInstallKind {
  /// macOS: un bundle `.app`, che si sostituisce per intero.
  macosBundle,

  /// Windows portable: si scompatta l'archivio sopra la cartella di
  /// installazione. E' il formato che la CI produce di serie, perche' un
  /// installer silenzioso chiama in causa un secondo programma che puo' fallire
  /// per conto suo.
  windowsPortable,

  /// Windows con installer Inno Setup: l'installer sa come aggiornare i propri
  /// file e chiudere le copie aperte.
  windowsInstaller,

  /// Linux: un AppImage, cioe' un file singolo eseguibile.
  linuxAppImage,
}

/// Dove vive questa copia e come si aggiorna.
class SelfInstall {
  const SelfInstall({
    required this.kind,
    required this.path,
    required this.executable,
  });

  final SelfInstallKind kind;

  /// Cio' che l'aggiornamento sostituisce: la cartella `.app`, l'installer da
  /// eseguire (per Windows il percorso e' quello dell'eseguibile installato), o
  /// il file AppImage.
  final String path;

  /// L'eseguibile da rilanciare dopo l'aggiornamento.
  final String executable;

  /// Riconosce se questa copia e' installata, o se e' una copia di sviluppo.
  ///
  /// E' il controllo piu' importante di tutto il meccanismo. Durante lo
  /// sviluppo il programma gira dentro `build/`, e un aggiornatore che provasse
  /// a "sostituirsi" li' dentro cancellerebbe il risultato di una compilazione
  /// o, peggio, un bundle aperto a meta'. Qui si restituisce `null` e si spiega
  /// perche', invece di tentare e rovinare qualcosa.
  static SelfInstall? detect({
    String? executable,
    Map<String, String>? environment,
  }) {
    final String exe = executable ?? Platform.resolvedExecutable;
    final Map<String, String> env = environment ?? Platform.environment;

    if (Platform.isMacOS) {
      final String? bundle = _enclosingBundle(exe);
      if (bundle == null) return null;
      if (bundle.contains('${p.separator}build${p.separator}')) return null;
      return SelfInstall(kind: SelfInstallKind.macosBundle, path: bundle, executable: exe);
    }

    if (Platform.isWindows) {
      if (exe.contains('${p.separator}build${p.separator}')) return null;
      return SelfInstall(kind: SelfInstallKind.windowsPortable, path: exe, executable: exe);
    }

    // Su Linux il percorso dell'eseguibile in esecuzione e' dentro una cartella
    // temporanea creata dal runtime dell'AppImage: il file vero e' quello in
    // `APPIMAGE`. Senza quella variabile il programma non e' un AppImage, quindi
    // viene da un pacchetto della distribuzione o da una build locale, e in
    // entrambi i casi sostituirsi da solo sarebbe sbagliato: nel primo il file
    // appartiene al gestore di pacchetti, nel secondo e' il risultato di una
    // compilazione.
    final String? appImage = env['APPIMAGE'];
    if (appImage == null || appImage.trim().isEmpty) return null;
    return SelfInstall(
      kind: SelfInstallKind.linuxAppImage,
      path: appImage,
      executable: appImage,
    );
  }

  /// Perche' questa copia non si aggiorna da sola, in una frase comprensibile.
  static String reasonNotSelfInstallable() {
    if (Platform.isMacOS) {
      return 'Questa copia non e\' dentro un bundle applicativo: sembra una build di sviluppo, '
          'quindi non viene aggiornata automaticamente.';
    }
    if (Platform.isWindows) {
      return 'Questa copia gira da una cartella di compilazione: sembra una build di sviluppo, '
          'quindi non viene aggiornata automaticamente.';
    }
    return 'Questa copia non e\' un AppImage: se l\'hai installata con il gestore di pacchetti '
        'della tua distribuzione, aggiornala da li\'.';
  }

  static String? _enclosingBundle(String executable) {
    Directory dir = File(executable).parent;
    while (true) {
      if (p.extension(dir.path) == '.app') return dir.path;
      final Directory parent = dir.parent;
      // La radice del filesystem e' il proprio genitore: senza questa
      // condizione il ciclo non finirebbe mai.
      if (parent.path == dir.path) return null;
      dir = parent;
    }
  }
}

/// Un comando che l'installazione esegue.
///
/// L'installazione e' descritta come **una lista di comandi** e non come una
/// sequenza di chiamate a `Process.start`. Il motivo e' che qui dentro si
/// sostituisce il programma in esecuzione: e' l'unica operazione di tutta
/// l'applicazione che, sbagliata, lascia l'utente senza niente. Una lista si
/// puo' verificare in un test senza eseguirla, e si puo' mostrare all'utente
/// prima di eseguirla.
class InstallStep {
  const InstallStep(
    this.label,
    this.executable,
    this.arguments, {
    this.successCodes = const <int>{0},
  });

  final String label;
  final String executable;
  final List<String> arguments;

  /// Quali codici di uscita significano "fatto".
  ///
  /// Non e' un dettaglio: `robocopy`, `tar` e gli installer non usano tutti la
  /// convenzione "zero e' successo", e trattare un 1 legittimo come un errore
  /// farebbe abortire un aggiornamento che stava andando bene — lasciando
  /// l'utente con meta' dei file nuovi e meta' dei vecchi.
  final Set<int> successCodes;

  bool accepts(int exitCode) => successCodes.contains(exitCode);

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

/// Pianifica l'installazione di [archive] su [target].
///
/// Non tocca il disco: restituisce cosa andrebbe eseguito.
List<InstallStep> planInstall(
  SelfInstall target,
  File archive, {
  String? stagingDir,
}) {
  switch (target.kind) {
    case SelfInstallKind.macosBundle:
      final String stage = stagingDir ?? '${p.dirname(target.path)}/.cpredux-update';
      return <InstallStep>[
        InstallStep('Pulizia dell area di lavoro', 'rm', <String>['-rf', stage]),
        InstallStep('Scompattazione del nuovo pacchetto', 'ditto',
            <String>['-x', '-k', archive.path, stage]),
        InstallStep('Sostituzione del bundle applicativo', 'mv',
            <String>[p.join(stage, p.basename(target.path)), target.path]),
      ];

    case SelfInstallKind.linuxAppImage:
      // `cp` sul file che si sta eseguendo fallisce con ETXTBSY, e comunque
      // lasciare il programma a meta' scrittura sarebbe la fine: si copia
      // accanto e si rinomina, che su Unix e' atomico.
      return <InstallStep>[
        InstallStep('Sostituzione dell AppImage', 'cp', <String>[archive.path, '${target.path}.new']),
        InstallStep('Attivazione del nuovo file', 'mv', <String>['${target.path}.new', target.path]),
        InstallStep('Permesso di esecuzione', 'chmod', <String>['755', target.path]),
      ];

    case SelfInstallKind.windowsInstaller:
      // L'installer Inno Setup chiude da solo le copie aperte e sostituisce i
      // file. `/SILENT` mostra l'avanzamento senza chiedere nulla, perche' la
      // scelta l'utente l'ha gia' fatta.
      return <InstallStep>[
        InstallStep('Installazione del nuovo pacchetto', archive.path,
            <String>['/SILENT', '/NORESTART', '/SUPPRESSMSGBOXES', '/CLOSEAPPLICATIONS']),
      ];

    case SelfInstallKind.windowsPortable:
      // Si scompatta **sopra** la cartella di installazione, senza area di
      // lavoro intermedia: l'applicazione e' gia' uscita, quindi nessun file e'
      // bloccato, e `tar` di Windows 10 e successivi legge anche gli zip. In
      // caso di interruzione a meta' l'utente reinstalla dall'archivio, che e'
      // comunque scaricabile.
      return <InstallStep>[
        InstallStep(
          'Scompattazione del nuovo pacchetto',
          'tar',
          <String>[
            '-xf',
            archive.path,
            '-C',
            // `p.windows` e non `p`: un percorso con `C:\...` va interpretato
            // con le regole di Windows anche se questo codice gira su un altro
            // sistema (nei test, o in una futura interfaccia che pianifica un
            // aggiornamento per un'altra macchina). Con il contesto del sistema
            // ospite la cartella di destinazione risulterebbe `.`.
            p.windows.dirname(target.executable),
          ],
        ),
      ];
  }
}

/// Esegue un comando e restituisce il codice di uscita.
///
/// E' iniettabile perche' i test devono poter verificare **cosa** verrebbe
/// eseguito senza eseguirlo: un test che lancia davvero `mv` sul bundle
/// applicativo non e' un test, e' un incidente.
typedef ProcessRunner = Future<int> Function(String executable, List<String> arguments);

Future<int> runProcess(String executable, List<String> arguments) async {
  final ProcessResult result = await Process.run(executable, arguments);
  return result.exitCode;
}

/// L'esito dell'installazione.
class InstallResult {
  const InstallResult.ok(this.commands)
      : error = null;

  const InstallResult.failed(this.error, this.commands);

  final List<String> commands;
  final String? error;

  bool get success => error == null;
}

/// Applica l'aggiornamento ed esegue il rilancio.
///
/// Si ferma al primo comando che fallisce: proseguire dopo un `mv` non riuscito
/// significherebbe cancellare il programma vecchio senza aver messo al suo posto
/// quello nuovo.
Future<InstallResult> applyUpdate(
  SelfInstall target,
  File archive, {
  ProcessRunner runner = runProcess,
  void Function(InstallStep step)? onStep,
}) async {
  final List<InstallStep> steps = planInstall(target, archive);
  final List<String> executed = <String>[];

  for (final InstallStep step in steps) {
    onStep?.call(step);
    final int code = await runner(step.executable, step.arguments);
    executed.add(step.label);
    if (!step.accepts(code)) {
      return InstallResult.failed(
        'Passo "${step.label}" non riuscito (codice $code). '
        'Il programma precedente e\' ancora al suo posto.',
        executed,
      );
    }
  }

  return InstallResult.ok(executed);
}

/// Rilancia il programma.
///
/// Su macOS passa da `open`, non dall'eseguibile dentro il bundle: lanciare
/// direttamente il binario funziona ma crea un processo che non fa parte
/// dell'applicazione registrata, con la conseguenza che la finestra non sale in
/// primo piano e il Dock mostra un'icona generica.
Future<void> relaunch(SelfInstall target, {List<String> arguments = const <String>[]}) async {
  if (target.kind == SelfInstallKind.macosBundle) {
    await Process.start(
      'open',
      <String>[target.path, if (arguments.isNotEmpty) '--args', ...arguments],
      mode: ProcessStartMode.detached,
    );
    return;
  }
  await Process.start(
    target.executable,
    arguments,
    mode: ProcessStartMode.detached,
  );
}

/// Avvia una copia del programma in modalita' aggiornamento e termina.
///
/// E' il modo con cui l'aggiornamento "alla chiusura" mantiene la sua promessa:
/// il programma in esecuzione **esce subito** — quindi non tocca mai da solo i
/// propri file — e una copia nuova esegue l'installazione e poi rilancia.
Future<void> spawnUpdateHelper({
  required String executable,
  required File archive,
  required String version,
  ProcessRunnerStarter? starter,
}) async {
  final List<String> args = <String>[
    '--apply-update',
    archive.path,
    '--version',
    version,
  ];
  if (starter != null) {
    await starter(executable, args);
    return;
  }
  await Process.start(executable, args, mode: ProcessStartMode.detached);
}

typedef ProcessRunnerStarter = Future<void> Function(String executable, List<String> arguments);
