import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/dice_expression.dart';
import 'app_paths.dart';

/// Impostazioni dell'applicazione.
class AppSettings {
  AppSettings({
    this.baseTheme = 'dark',
    this.subTheme = 'cyberpunk2077',
    this.customAccentColorValue = 0xFFFCEE0A,
    bool? enableDarkMode,
    this.enableLoad = true,
    this.enableDiscordRichPresence = true,
    this.autosave = true,
    this.autoCheckUpdates = true,
    this.showUpdateNotifications = true,
    this.discordClientId = defaultDiscordClientId,
    this.updateFeedUrl = defaultUpdateFeedUrl,
    this.skippedUpdateVersion = '',
    this.pendingUpdateVersion = '',
    this.pendingUpdateArchive = '',
    this.lastUpdateError = '',
    List<String>? recentFiles,
    Map<String, double>? gmRuleOverrides,
    List<DiceMacro>? gmMacros,
  })  : recentFiles = recentFiles ?? <String>[],
        gmRuleOverrides = gmRuleOverrides ?? <String, double>{},
        gmMacros = gmMacros ?? <DiceMacro>[] {
    if (enableDarkMode != null && !enableDarkMode) {
      baseTheme = 'light';
    }
  }

  /// Indirizzo predefinito del manifesto degli aggiornamenti su GitHub raw.
  static const String defaultUpdateFeedUrl = 'https://raw.githubusercontent.com/Tia004/cpredux/main/site/latest.json';

  /// Indirizzo mirror su GitLab Pages.
  static const String gitlabUpdateFeedUrl = 'https://tia004.gitlab.io/cpredux/latest.json';

  /// Indirizzo mirror su GitHub raw.
  static const String githubUpdateFeedUrl = 'https://raw.githubusercontent.com/Tia004/cpredux/main/site/latest.json';

  /// Application ID Discord ufficiale di CPRED Visualizer.
  static const String defaultDiscordClientId = '1548828729759899789';

  /// Tema base: 'dark' (predefinito), 'light', 'oled'.
  String baseTheme;

  /// Sottotema: 'cyberpunk2077' (predefinito), 'cyberpunkRed', 'militech', 'custom'.
  String subTheme;

  /// Valore ARGB del colore d'accento personalizzato.
  int customAccentColorValue;

  bool get enableDarkMode => baseTheme != 'light';
  set enableDarkMode(bool value) {
    baseTheme = value ? 'dark' : 'light';
  }

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

  /// Mostra il pulsante persistente di aggiornamento in alto a destra.
  bool showUpdateNotifications;

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

  /// True se c'e' un indirizzo su cui controllare gli aggiornamenti.
  bool get canCheckUpdates => updateFeedUrl.trim().isNotEmpty;

  /// Le schede e campagne aperte di recente, percorsi completi.
  final List<String> recentFiles;

  /// Le correzioni del tavolo ai numeri degli strumenti del Master.
  ///
  /// Stanno nelle impostazioni e non nella scheda perche' sono una proprieta'
  /// del **tavolo**, non di un personaggio: due giocatori alla stessa scrivania
  /// usano le stesse house rule, e cambiarle una volta deve bastare.
  final Map<String, double> gmRuleOverrides;

  /// Le macro di dado salvate dall'utente.
  ///
  /// Sono qui per lo stesso motivo: "1d10 + RIF + Pistole" e' un tiro che un
  /// giocatore rifa' per tutta la campagna, e riscriverlo ogni sessione e'
  /// esattamente il lavoro che l'app doveva togliere.
  final List<DiceMacro> gmMacros;

  void saveMacro(DiceMacro macro) {
    final int index = gmMacros.indexWhere((DiceMacro m) => m.id == macro.id);
    if (index >= 0) {
      gmMacros[index] = macro;
    } else {
      gmMacros.add(macro);
    }
  }

  void deleteMacro(String id) => gmMacros.removeWhere((DiceMacro m) => m.id == id);

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
        'baseTheme': baseTheme,
        'subTheme': subTheme,
        'customAccentColorValue': customAccentColorValue,
        'enableDarkMode': enableDarkMode,
        'enableLoad': enableLoad,
        'enableDiscordRichPresence': enableDiscordRichPresence,
        'discordClientId': discordClientId,
        'autosave': autosave,
        'autoCheckUpdates': autoCheckUpdates,
        'showUpdateNotifications': showUpdateNotifications,
        'updateFeedUrl': updateFeedUrl,
        'skippedUpdateVersion': skippedUpdateVersion,
        'pendingUpdateVersion': pendingUpdateVersion,
        'pendingUpdateArchive': pendingUpdateArchive,
        'lastUpdateError': lastUpdateError,
        'recentFiles': recentFiles,
        'gmRuleOverrides': gmRuleOverrides,
        'gmMacros': gmMacros.map((DiceMacro m) => m.toJson()).toList(),
      };

  static AppSettings fromJson(Map<String, Object?> json) {
    final Object? recent = json['recentFiles'];
    final bool? legacyDarkMode = json['enableDarkMode'] is bool ? json['enableDarkMode']! as bool : null;
    final String base = json['baseTheme'] is String
        ? (json['baseTheme']! as String)
        : (legacyDarkMode == false ? 'light' : 'dark');

    return AppSettings(
      baseTheme: base,
      subTheme: json['subTheme'] is String ? (json['subTheme']! as String) : 'cyberpunk2077',
      customAccentColorValue: json['customAccentColorValue'] is int
          ? (json['customAccentColorValue']! as int)
          : 0xFFFCEE0A,
      enableLoad: json['enableLoad'] is bool ? json['enableLoad']! as bool : true,
      enableDiscordRichPresence:
          json['enableDiscordRichPresence'] is bool ? json['enableDiscordRichPresence']! as bool : true,
      discordClientId: json['discordClientId'] is String && (json['discordClientId']! as String).trim().isNotEmpty
          ? (json['discordClientId']! as String).trim()
          : defaultDiscordClientId,
      autosave: json['autosave'] is bool ? json['autosave']! as bool : true,
      autoCheckUpdates: json['autoCheckUpdates'] is bool ? json['autoCheckUpdates']! as bool : true,
      showUpdateNotifications: json['showUpdateNotifications'] is bool
          ? json['showUpdateNotifications']! as bool
          : true,
      updateFeedUrl: json['updateFeedUrl'] is String && (json['updateFeedUrl']! as String).trim().isNotEmpty
          ? (json['updateFeedUrl']! as String).trim()
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
      gmRuleOverrides: _doubleMap(json['gmRuleOverrides']),
      gmMacros: _macros(json['gmMacros']),
    );
  }

  static Map<String, double> _doubleMap(Object? raw) {
    if (raw is! Map) return <String, double>{};
    final Map<String, double> parsed = <String, double>{};
    raw.forEach((Object? k, Object? v) {
      if (k is String && v is num) parsed[k] = v.toDouble();
    });
    return parsed;
  }

  static List<DiceMacro> _macros(Object? raw) {
    if (raw is! List) return <DiceMacro>[];
    return <DiceMacro>[
      for (final Object? item in raw)
        if (item is Map) DiceMacro.fromJson(Map<String, Object?>.from(item)),
    ];
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
    try {
      temp.renameSync(f.path);
    } catch (_) {
      try {
        temp.copySync(f.path);
        temp.deleteSync();
      } catch (_) {
        // Se anche la copia fallisce, proviamo la scrittura diretta
        f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(settings.toJson()), flush: true);
      }
    }
  }
}
