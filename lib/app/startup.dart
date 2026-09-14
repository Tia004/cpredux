/// In che modo il programma e' stato avviato.
enum StartupMode {
  /// Avvio normale.
  normal,

  /// Avviato **da se stesso** per applicare un aggiornamento scaricato.
  ///
  /// E' la modalita' che mantiene la promessa "aggiorna alla chiusura": il
  /// programma in esecuzione esce e non tocca mai i propri file, una copia nuova
  /// esegue l'installazione e poi riapre l'applicazione.
  applyUpdate,

  /// Appena aggiornato: serve a dirlo all'utente, una volta sola.
  justUpdated,
}

/// Cosa chiede la riga di comando.
class StartupRequest {
  const StartupRequest({
    this.mode = StartupMode.normal,
    this.archivePath,
    this.version,
    this.initialFilePath,
  });

  final StartupMode mode;

  /// L'archivio da installare, in modalita' [StartupMode.applyUpdate].
  final String? archivePath;

  /// La versione installata, per il messaggio di [StartupMode.justUpdated].
  final String? version;

  /// Il percorso di un file .cpredux da aprire all'avvio (es. da doppio click nel sistema operativo).
  final String? initialFilePath;

  static StartupRequest parse(List<String> args) {
    String? archive;
    String? version;
    String? initialFile;
    StartupMode mode = StartupMode.normal;

    for (int i = 0; i < args.length; i++) {
      final String arg = args[i];
      String? valueOf() => i + 1 < args.length ? args[++i] : null;

      switch (arg) {
        case '--apply-update':
          mode = StartupMode.applyUpdate;
          archive = valueOf() ?? archive;
        case '--version':
          version = valueOf() ?? version;
        case '--just-updated':
          mode = StartupMode.justUpdated;
          version = valueOf() ?? version;
        default:
          if (!arg.startsWith('-') &&
              (arg.toLowerCase().endsWith('.cpredux') ||
                  arg.toLowerCase().endsWith('.cpred_sheet'))) {
            initialFile = arg;
          }
          break;
      }
    }

    // Un `--apply-update` senza archivio non e' un aggiornamento: sarebbe un
    // programma che si apre per non fare niente, restando aperto. Meglio
    // tornare all'avvio normale.
    if (mode == StartupMode.applyUpdate && (archive == null || archive.trim().isEmpty)) {
      return const StartupRequest();
    }

    return StartupRequest(
      mode: mode,
      archivePath: archive,
      version: version,
      initialFilePath: initialFile,
    );
  }
}
