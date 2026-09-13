import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

/// Impostazioni dell'applicazione.
class AppSettings {
  AppSettings({
    this.enableDarkMode = true,
    this.enableLoad = true,
    this.enableDiscordRichPresence = true,
    this.autosave = true,
    this.autoCheckUpdates = true,
    this.discordClientId = '',
    this.updateFeedUrl = defaultUpdateFeedUrl,
    this.skippedUpdateVersion = '',
    this.pendingUpdateVersion = '',
    this.pendingUpdateArchive = '',
    this.lastUpdateError = '',
    List<String>? recentFiles,
  }) : recentFiles = recentFiles ?? <String>[];

  /// Il manifesto degli aggiornamenti pubblicato dal rilascio.
  ///
  /// E' un file statico, non una chiamata alle API di GitLab o GitHub: vedi
  /// `UpdateManifest` per le ragioni. Si puo' cambiare dalle impostazioni sia
  /// perche' chi ospita i propri build deve poterlo fare, sia perche' un URL
  /// rotto deve essere correggibile senza ricompilare il programma.
  static const String defaultUpdateFeedUrl = 'https://tiadesigns.it/cpredux/latest.json';

  /// Tema scuro. Il progetto ha sempre avuto un tema chiaro alternativo, e
  /// vale la pena tenerlo: in una stanza illuminata una scheda chiara si legge
  /// meglio, anche se lo stile "cyber" e' scuro per natura.
  bool enableDarkMode;

  /// Calcolo automatico del carico e delle sue penalita'.
  bool enableLoad;

  bool enableDiscordRichPresence;

  /// Application ID dell'applicazione Discord che ospita la presenza.
  ///
  /// Non e' un segreto: e' l'identificativo pubblico di una applicazione
  /// creata su discord.com/developers. Senza, Discord non sa a nome di chi
  /// mostrare l'attivita', quindi il campo resta vuoto di default e la
  /// presenza si attiva solo quando l'utente lo inserisce.
  String discordClientId;

  /// Salvataggio automatico: il vecchio progetto lo faceva sempre, ed e' una
  /// promessa che gli utenti si aspettano ("non ti preoccupare, salva da solo").
  bool autosave;

  /// Controllo dell'esistenza di aggiornamenti all'avvio.
  ///
  /// Attivo di default perche' il controllo non scarica nulla e non blocca
  /// l'avvio: chiede un file di poche centinaia di byte e, se c'e' una versione
  /// nuova, **chiede** invece di installare.
  bool autoCheckUpdates;

  String updateFeedUrl;

  /// La versione che l'utente ha scelto di saltare.
  ///
  /// Salta *questa* versione, non gli aggiornamenti: un avviso che si ripresenta
  /// a ogni avvio viene ignorato per abitudine, ed e' cosi' che si perdono
  /// quelli importanti. Attraverso le impostazioni si puo' sempre controllare a
  /// mano.
  String skippedUpdateVersion;

  /// Un aggiornamento deciso ma rimandato alla chiusura.
  ///
  /// Sopravvive alla chiusura del programma perche' e' **scritto nelle
  /// impostazioni** e non tenuto in memoria: se l'utente sceglie "alla
  /// chiusura" e poi chiude, l'aggiornamento deve avvenire davvero. Se fosse
  /// solo in memoria, un arresto inatteso lo cancellerebbe in silenzio.
  String pendingUpdateVersion;
  String pendingUpdateArchive;

  /// L'esito dell'ultimo tentativo di installazione, quando e' avvenuto in
  /// un'altra esecuzione.
  ///
  /// Serve perche' la finestra dell'aggiornatore vive pochi secondi e sparisce:
  /// un errore mostrato solo li' dentro non lo vedrebbe nessuno. Scritto qui,
  /// l'applicazione riaperta lo trova e lo mostra nelle impostazioni.
  String lastUpdateError;

  bool get hasPendingUpdate =>
      pendingUpdateArchive.trim().isNotEmpty && pendingUpdateVersion.trim().isNotEmpty;

  final List<String> recentFiles;

  static const int maxRecentFiles = 12;

  void rememberFile(String path) {
    recentFiles.removeWhere((String f) => p.equals(f, path));
    recentFiles.insert(0, path);
    if (recentFiles.length > maxRecentFiles) {
      recentFiles.removeRange(maxRecentFiles, recentFiles.length);
    }
  }

  void forgetFile(String path) {
    recentFiles.removeWhere((String f) => p.equals(f, path));
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'enableDarkMode': enableDarkMode,
        'enableLoad': enableLoad,
        'enableDiscordRichPresence': enableDiscordRichPresence,
        'discordClientId': discordClientId,
        'autosave': autosave,
        'autoCheckUpdates': autoCheckUpdates,
        'updateFeedUrl': updateFeedUrl,
        'skippedUpdateVersion': skippedUpdateVersion,
        'pendingUpdateVersion': pendingUpdateVersion,
        'pendingUpdateArchive': pendingUpdateArchive,
        'lastUpdateError': lastUpdateError,
        'recentFiles': recentFiles,
      };

  static AppSettings fromJson(Map<String, Object?> json) {
    final Object? recent = json['recentFiles'];
    return AppSettings(
      enableDarkMode: json['enableDarkMode'] is bool ? json['enableDarkMode']! as bool : true,
      enableLoad: json['enableLoad'] is bool ? json['enableLoad']! as bool : true,
      enableDiscordRichPresence:
          json['enableDiscordRichPresence'] is bool ? json['enableDiscordRichPresence']! as bool : true,
      discordClientId: json['discordClientId'] is String ? json['discordClientId']! as String : '',
      autosave: json['autosave'] is bool ? json['autosave']! as bool : true,
      autoCheckUpdates: json['autoCheckUpdates'] is bool ? json['autoCheckUpdates']! as bool : true,
      updateFeedUrl: json['updateFeedUrl'] is String && (json['updateFeedUrl']! as String).trim().isNotEmpty
          ? json['updateFeedUrl']! as String
          : defaultUpdateFeedUrl,
      skippedUpdateVersion:
          json['skippedUpdateVersion'] is String ? json['skippedUpdateVersion']! as String : '',
      pendingUpdateVersion:
          json['pendingUpdateVersion'] is String ? json['pendingUpdateVersion']! as String : '',
      pendingUpdateArchive:
          json['pendingUpdateArchive'] is String ? json['pendingUpdateArchive']! as String : '',
      lastUpdateError: json['lastUpdateError'] is String ? json['lastUpdateError']! as String : '',
      recentFiles: recent is List
          ? recent.whereType<String>().toList()
          : <String>[],
    );
  }
}

/// Legge e scrive le impostazioni nella cartella di configurazione.
///
/// Le impostazioni stanno **fuori** dai documenti: sono preferenze della
/// macchina, non dati della scheda. Tenerle separate significa che copiare una
/// scheda su un altro computer non porta con se' il tema scelto, e che
/// cancellare i documenti non resetta l'applicazione.
abstract final class SettingsStore {
  static const String fileName = 'settings.json';

  static File file() => File(p.join(AppPaths.configDir().path, fileName));

  static AppSettings load() {
    final File f = file();
    if (!f.existsSync()) return AppSettings();
    try {
      final Object? decoded = jsonDecode(f.readAsStringSync());
      if (decoded is! Map<Object?, Object?>) return AppSettings();
      return AppSettings.fromJson(
        decoded.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
      );
    } catch (_) {
      // Impostazioni illeggibili non devono impedire l'avvio: si torna ai
      // default e si riscrive il file al primo salvataggio.
      return AppSettings();
    }
  }

  static void save(AppSettings settings) {
    final File f = file();
    f.parent.createSync(recursive: true);
    // Scrittura su file temporaneo e rename: se l'app viene chiusa a meta'
    // scrittura non si ottiene un settings.json troncato e illeggibile.
    final File temp = File('${f.path}.tmp');
    temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(settings.toJson()), flush: true);
    temp.renameSync(f.path);
  }
}
