import 'dart:io';

import 'package:path/path.dart' as p;

/// Percorsi dell'applicazione sulle tre piattaforme.
///
/// Implementato con `dart:io` e le variabili d'ambiente invece che con
/// `path_provider`: quel pacchetto e' un plugin nativo, quindi porterebbe
/// CocoaPods su macOS e configurazione aggiuntiva su Windows e Linux, per
/// risolvere qualcosa che si risolve in venti righe. Meno dipendenze native
/// significa anche build piu' riproducibili sulla CI dei tre sistemi.
///
/// Le directory di *configurazione* e di *dati* sono tenute separate perche'
/// hanno cicli di vita diversi: la configurazione si puo' cancellare senza
/// perdere nulla, i dati no. Su macOS coincidono, e va bene.
abstract final class AppPaths {
  static const String appDirName = 'CPREDVisualizer';

  /// Cartella delle impostazioni, cache e log.
  static Directory configDir() => _dir(
        override: _configOverride,
        macOs: () => _home('Library', 'Application Support'),
        windows: () => _env('APPDATA') ?? _home('AppData', 'Roaming'),
        linux: () => _env('XDG_CONFIG_HOME') ?? _home('.config'),
      );

  /// Cartella dei documenti dell'utente (schede e campagne).
  static Directory dataDir() => _dir(
        override: _dataOverride,
        macOs: () => _home('Library', 'Application Support'),
        windows: () => _env('APPDATA') ?? _home('AppData', 'Roaming'),
        linux: () => _env('XDG_DATA_HOME') ?? _home('.local', 'share'),
      );

  /// Cartella in cui proporre i salvataggi: i Documenti dell'utente, che e'
  /// dove l'utente si aspetta di ritrovare i propri file.
  static Directory documentsDir() {
    final String? override = _documentsOverride;
    if (override != null) return Directory(override);

    final String? home = _env('HOME') ?? _env('USERPROFILE');
    if (home != null) {
      final Directory docs = Directory(p.join(home, 'Documents'));
      if (docs.existsSync()) return docs;
    }
    return Directory.current;
  }

  // --- override per i test -------------------------------------------------

  static String? _configOverride;
  static String? _dataOverride;
  static String? _documentsOverride;

  /// Reindirizza le cartelle su una directory temporanea.
  ///
  /// Serve ai test: senza questo scriverebbero nella vera cartella
  /// dell'utente, che oltre a essere scortese renderebbe i test dipendenti
  /// dallo stato della macchina. Vale anche per i **Documenti**, che non sono
  /// una cartella dell'app ma vengono esplorati dall'elenco dei documenti:
  /// senza l'override un test finirebbe per leggere i file veri di chi lo
  /// esegue.
  static void overrideForTesting({String? config, String? data, String? documents}) {
    _configOverride = config;
    _dataOverride = data;
    _documentsOverride = documents;
  }

  static void clearOverrides() {
    _configOverride = null;
    _dataOverride = null;
    _documentsOverride = null;
  }

  // --- interni -------------------------------------------------------------

  static Directory _dir({
    required String? override,
    required String Function() macOs,
    required String Function() windows,
    required String Function() linux,
  }) {
    final String base = override ??
        (Platform.isWindows
            ? windows()
            : Platform.isMacOS
                ? macOs()
                : linux());
    final Directory dir = Directory(p.join(base, appDirName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static String? _env(String name) {
    final String? value = Platform.environment[name];
    return (value == null || value.isEmpty) ? null : value;
  }

  static String _home(String first, [String? second]) {
    final String home = _env('HOME') ?? _env('USERPROFILE') ?? Directory.current.path;
    return second == null ? p.join(home, first) : p.join(home, first, second);
  }
}
