import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../data/catalog.dart';
import '../data/cpredux_file.dart';
import '../data/document_upgrade.dart';
import '../data/migrator.dart';
import '../data/settings_store.dart';
import '../domain/campaign.dart';
import '../domain/catalog_item.dart';
import '../domain/items.dart';
import '../domain/enums.dart';
import '../domain/rules.dart';
import '../domain/sheet.dart';
import '../domain/world_map.dart';
import '../net/session.dart';
import '../net/discord_rpc.dart';
import '../net/update_installer.dart';
import '../net/update_manifest.dart';
import '../net/updater.dart';

enum AppScreen { home, sheet, campaign, settings }

/// Rende [AppState] disponibile a tutto l'albero dei widget.
///
/// Si usa `InheritedNotifier` e non una variabile globale: i test possono
/// costruire un albero con uno stato diverso, e i widget che leggono lo stato
/// si ricostruiscono automaticamente quando cambia, senza dover passare
/// manualmente il notifier a ogni livello.
///
/// Vive qui e non in `app.dart` perche' e' il contratto con cui *ogni*
/// schermata accede allo stato: tenerlo nel file che definisce lo stato evita
/// che una feature debba importare la radice dell'app (e con essa tutte le
/// altre schermate) solo per leggere un valore.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope non trovato: manca sopra questo widget.');
    return scope!.notifier!;
  }
}

/// Stato dell'applicazione.
///
/// Un solo oggetto mutabile che notifica i cambiamenti, invece di uno store
/// normalizzato: l'app tiene aperto *un* documento per volta, quindi la
/// complessita' non ripagherebbe. La coerenza e' garantita da un vincolo di
/// disciplina: ogni modifica passa da [mutate] o [mutateCampaign], che sono
/// gli unici punti in cui i valori derivati vengono ricalcolati e il
/// salvataggio automatico viene programmato. Dimenticarsi di ricalcolare dopo
/// una modifica e' l'errore piu' facile in un'applicazione a schede, e questo
/// lo rende impossibile.
class AppState extends ChangeNotifier {
  AppState({ItemCatalog? catalog}) : _catalog = catalog ?? ItemCatalog.empty();

  /// Il catalogo oggetti spedito con l'app, in sola lettura.
  ///
  /// Si inietta nel costruttore invece di leggerlo da un globale: i test
  /// costruiscono un catalogo con due voci e verificano il comportamento della
  /// scheda senza dipendere dal contenuto spedito.
  final ItemCatalog _catalog;
  ItemCatalog get catalog => _catalog;

  /// Il risolutore da passare al calcolo dei valori derivati.
  CatalogLookup get catalogLookup => _catalog.byId;

  /// L'inventario risolto: catalogo + personalizzazioni, gia' unite.
  ///
  /// La UI legge questo e mai `sheet.inventory` direttamente, altrimenti
  /// mostrerebbe il peso di catalogo ignorando la personalizzazione o
  /// viceversa.
  List<ResolvedItem> get resolvedInventory =>
      ResolvedItem.resolveAll(_sheet?.inventory ?? <InventoryEntry>[], catalogLookup);

  late AppSettings settings = SettingsStore.load();

  // --- Navigazione ---------------------------------------------------------

  AppScreen _screen = AppScreen.home;
  AppScreen get screen => _screen;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void goHome() {
    _screen = AppScreen.home;
    notifyListeners();
    refreshPresence();
  }

  void goToSettings() {
    _screen = AppScreen.settings;
    notifyListeners();
  }

  void goToSheet() {
    if (_sheet == null) return;
    _screen = AppScreen.sheet;
    notifyListeners();
  }

  void goToCampaign() {
    if (_campaign == null) return;
    _screen = AppScreen.campaign;
    notifyListeners();
  }

  // --- Scheda --------------------------------------------------------------

  CharacterSheet? _sheet;
  CharacterSheet? get sheet => _sheet;

  /// Cosa e' cambiato aggiornando il formato di un documento.
  ///
  /// Si tiene a parte e si mostra **dopo** l'apertura: un aggiornamento di
  /// formato che avviene in silenzio e' la ricetta per la telefonata "mi hai
  /// cambiato i file senza dirmelo".
  List<String> _upgradeNotes = <String>[];
  Map<String, int> _upgradeCounts = <String, int>{};
  List<String> get upgradeNotes => List<String>.unmodifiable(_upgradeNotes);
  Map<String, int> get upgradeCounts => Map<String, int>.unmodifiable(_upgradeCounts);
  bool get hasUpgradeNotes => _upgradeNotes.isNotEmpty;

  void clearUpgradeNotes() {
    if (_upgradeNotes.isEmpty) return;
    _upgradeNotes = <String>[];
    _upgradeCounts = <String, int>{};
    notifyListeners();
  }

  SheetTotals? _totals;

  /// Valori derivati in cache. Ricalcolarli a ogni lettura sarebbe comunque
  /// economico, ma tenerli in cache permette ai widget di confrontare i totali
  /// precedenti con i nuovi per animare le variazioni.
  SheetTotals? get totals => _totals;

  bool get hasSheet => _sheet != null;

  // --- Campagna ------------------------------------------------------------

  Campaign? _campaign;
  Campaign? get campaign => _campaign;
  bool get hasCampaign => _campaign != null;

  // --- Sessione ------------------------------------------------------------

  CampaignHost? _host;
  CampaignHost? get host => _host;
  bool get isHosting => _host != null;

  CampaignClient? _client;
  CampaignClient? get client => _client;
  bool get isJoined => _client != null;

  /// Log della sessione in corso: chat, tiri, eventi applicati dal master.
  ///
  /// Vive **fuori** dal documento: una chat di tre ore non appartiene alla
  /// campagna come i suoi giocatori, e salvarla gonfierebbe il file di ogni
  /// sessione. Gli eventi che contano si salvano a parte, in [Campaign.events].
  final List<SessionEvent> sessionLog = <SessionEvent>[];

  /// Stato dei personaggi visti dal giocatore, deciso dal master.
  final List<CampaignPlayer> remotePlayers = <CampaignPlayer>[];

  List<String> _localAddresses = <String>[];
  List<String> get localAddresses => _localAddresses;

  String? _sessionError;
  String? get sessionError => _sessionError;

  /// Contatore che cambia a ogni messaggio di sessione.
  ///
  /// I widget ascoltano lo stato e si ricostruiscono quando notifica cambia;
  /// senza un valore che cambia anche a parita' di log, un widget che mostra
  /// "ultimo tiro" non avrebbe modo di accorgersi del nuovo messaggio.
  int _sessionTick = 0;
  int get sessionTick => _sessionTick;

  Timer? _snapshotTimer;

  // --- Mappa ----------------------------------------------------------------

  /// Waypoint visto dal giocatore: quelli che il master ha condiviso piu' i
  /// propri, che il master non ha ancora accettato.
  ///
  /// Vive **fuori** dal documento, come il log della sessione: chi gioca non
  /// possiede la mappa del tavolo. I waypoint che contano si salvano nella
  /// campagna del master, che e' l'unico posto in cui una mappa preparata ha
  /// senso di esistere.
  final List<MapWaypoint> _tableWaypoints = <MapWaypoint>[];

  /// L'aspetto scelto dal master, quando si e' al tavolo come giocatore.
  MapStyle _remoteMapStyle = MapStyle.digital;

  /// Waypoint il cui posizionamento e' in corso.
  bool _placingWaypoint = false;
  bool get isPlacingWaypoint => _placingWaypoint;

  void beginPlacingWaypoint() {
    if (_placingWaypoint) return;
    _placingWaypoint = true;
    notifyListeners();
  }

  void cancelPlacingWaypoint() {
    if (!_placingWaypoint) return;
    _placingWaypoint = false;
    notifyListeners();
  }

  /// True se questa copia e' quella che decide la mappa del tavolo.
  ///
  /// Il criterio e' "c'e' una campagna aperta", non "il socket e' in
  /// ascolto": il master prepara la mappa anche con il tavolo chiuso, ed e' lì
  /// che la preparazione va fatta. Al contrario un giocatore ha una scheda
  /// aperta e nessuna campagna.
  bool get isMapMaster => _campaign != null;

  MapStyle get mapStyle => _campaign?.mapStyle ?? _remoteMapStyle;

  /// I waypoint da disegnare in questo momento.
  List<MapWaypoint> get mapWaypoints {
    final Campaign? campaign = _campaign;
    return campaign != null ? campaign.waypoints : _tableWaypoints;
  }

  /// Le proposte ricevute dai giocatori, in attesa di una decisione.
  ///
  /// Sono separate dagli altri waypoint perche' chiedono un'azione: il master
  /// deve poterle vedere tutte insieme invece di cercarle sulla mappa.
  List<MapWaypoint> get mapProposals => <MapWaypoint>[
        for (final MapWaypoint w in mapWaypoints)
          if (w.status == WaypointStatus.proposed) w,
      ];

  /// Waypoint che il tavolo vede (o vedrebbe, se il tavolo fosse aperto).
  List<MapWaypoint> get sharedWaypoints => <MapWaypoint>[
        for (final MapWaypoint w in mapWaypoints)
          if (w.isShareable) w,
      ];

  /// Quanti waypoint non stanno uscendo da questa macchina.
  int get privateWaypointCount =>
      mapWaypoints.where((MapWaypoint w) => w.visibility == WaypointVisibility.private).length;

  void setMapStyle(MapStyle style) {
    if (_campaign == null) {
      _remoteMapStyle = style;
      notifyListeners();
      return;
    }
    if (_campaign!.mapStyle == style) return;
    mutateCampaign((Campaign c) => c.mapStyle = style);
    _host?.broadcast(<String, Object?>{
      't': SessionMessage.mapStyle,
      'style': style.name,
    });
  }

  /// Mette un segno sulla mappa.
  ///
  /// Restituisce il waypoint creato. Se a chiedere e' un giocatore, nasce come
  /// **proposta**: visibile subito a lui, in attesa che il master lo accetti.
  MapWaypoint addWaypoint({
    required String label,
    required Offset position,
    String note = '',
    WaypointKind kind = WaypointKind.location,
    WaypointVisibility visibility = WaypointVisibility.table,
  }) {
    final Campaign? campaign = _campaign;
    if (campaign != null) {
      final MapWaypoint w = MapWaypoint(
        id: newWaypointId(campaign.waypoints.length + 1),
        label: label.trim(),
        note: note.trim(),
        x: position.dx,
        y: position.dy,
        kind: kind,
        visibility: visibility,
        status: WaypointStatus.accepted,
        authorId: 'master',
        authorName: 'Master',
        createdAt: _now(),
      );
      campaign.waypoints.add(w);
      _placingWaypoint = false;
      _publishWaypoint(w);
      _appendSession(
        description: visibility == WaypointVisibility.private
            ? 'Waypoint privato: ${w.label}'
            : 'Waypoint sulla mappa: ${w.label}',
        delta: 'MAPPA',
      );
      _scheduleSave();
      return w;
    }

    final CharacterSheet? sheet = _sheet;
    final bool joined = _client != null;
    final MapWaypoint w = MapWaypoint(
      id: newWaypointId(_tableWaypoints.length + 1),
      label: label.trim(),
      note: note.trim(),
      x: position.dx,
      y: position.dy,
      kind: kind,
      // Una proposta puo' chiedere di essere privata, ma non puo' essere
      // mandata come privata: il senso del campo e' l'opposto.
      visibility: WaypointVisibility.table,
      status: joined ? WaypointStatus.proposed : WaypointStatus.accepted,
      authorId: sheet?.meta.id ?? 'locale',
      authorName: sheet?.meta.name ?? 'Tu',
      createdAt: _now(),
    );
    _tableWaypoints.add(w);
    _placingWaypoint = false;

    if (joined) {
      _client?.sendMapProposal(w.toJson());
      _appendSession(description: 'Waypoint proposto al master: ${w.label}', delta: 'MAPPA', persist: false);
    } else {
      _appendSession(
        description: 'Waypoint locale: ${w.label}',
        delta: 'MAPPA',
        persist: false,
      );
    }
    _sessionChanged();
    return w;
  }

  /// Modifica un waypoint esistente.
  ///
  /// Un giocatore puo' toccare solo le **proprie** proposte: un waypoint gia'
  /// accettato e' sulla mappa di tutti, e cambiarlo da li' significherebbe
  /// modificare la mappa che il master sta descrivendo mentre la descrive.
  void updateWaypoint(
    String id, {
    String? label,
    String? note,
    WaypointKind? kind,
    WaypointVisibility? visibility,
  }) {
    final Campaign? campaign = _campaign;
    if (campaign != null) {
      final MapWaypoint? w = _findWaypoint(campaign.waypoints, id);
      if (w == null) return;
      final WaypointVisibility previous = w.visibility;
      if (label != null) w.label = label.trim();
      if (note != null) w.note = note.trim();
      if (kind != null) w.kind = kind;
      if (visibility != null) w.visibility = visibility;

      if (previous == WaypointVisibility.table && w.visibility == WaypointVisibility.private) {
        // Da condiviso a privato: sparisce dal tavolo. Non basta smettere di
        // mandarlo aggiornato — chi lo sta gia' guardando se lo terrebbe.
        _host?.broadcast(<String, Object?>{'t': SessionMessage.mapRemove, 'id': id});
        _appendSession(description: 'Waypoint reso privato: ${w.label}', delta: 'MAPPA');
      } else {
        _publishWaypoint(w);
      }
      _scheduleSave();
      return;
    }

    final int index = _tableWaypoints.indexWhere((MapWaypoint w) => w.id == id);
    if (index < 0) return;
    final MapWaypoint w = _tableWaypoints[index];
    if (w.status != WaypointStatus.proposed) return;
    _tableWaypoints[index] = w.copyWith(
      label: label?.trim(),
      note: note?.trim(),
      kind: kind,
    );
    if (_client != null) _client?.sendMapProposal(_tableWaypoints[index].toJson());
    _sessionChanged();
  }

  void deleteWaypoint(String id) {
    final Campaign? campaign = _campaign;
    if (campaign != null) {
      final MapWaypoint? w = _findWaypoint(campaign.waypoints, id);
      if (w == null) return;
      campaign.waypoints.remove(w);
      if (w.isShareable && w.status == WaypointStatus.accepted) {
        _host?.broadcast(<String, Object?>{'t': SessionMessage.mapRemove, 'id': id});
      }
      _appendSession(description: 'Waypoint rimosso: ${w.label}', delta: 'MAPPA');
      _scheduleSave();
      return;
    }

    _tableWaypoints.removeWhere((MapWaypoint w) => w.id == id);
    // Ritirare una proposta e' diverso da cancellare un waypoint del tavolo,
    // ma per il master l'effetto e' lo stesso: quel segno non c'e' piu'.
    _client?.channel.send(<String, Object?>{'t': SessionMessage.mapRemove, 'id': id});
    _sessionChanged();
  }

  /// Il master accetta la proposta di un giocatore: il segno entra nella mappa
  /// di tutti.
  void masterAcceptWaypoint(String id) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    final MapWaypoint? w = _findWaypoint(campaign.waypoints, id);
    if (w == null) return;
    w
      ..status = WaypointStatus.accepted
      ..visibility = WaypointVisibility.table;
    _publishWaypoint(w);
    _appendSession(description: 'Waypoint condiviso con il tavolo: ${w.label}', delta: 'MAPPA');
    _scheduleSave();
  }

  /// Il master rifiuta la proposta: sparisce, e chi l'ha messa lo scopre.
  void masterRejectWaypoint(String id) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    final MapWaypoint? w = _findWaypoint(campaign.waypoints, id);
    if (w == null) return;
    campaign.waypoints.remove(w);
    if (w.authorId.isNotEmpty && w.authorId != 'master') {
      _host?.sendTo(w.authorId, <String, Object?>{'t': SessionMessage.mapRemove, 'id': id});
    }
    _appendSession(description: 'Waypoint rifiutato: ${w.label}', delta: 'MAPPA');
    _scheduleSave();
  }

  /// Manda a un singolo giocatore la mappa condivisa e l'aspetto scelti.
  ///
  /// Si manda al collegamento e non solo alla modifica: un giocatore che
  /// rientra a meta' serata deve ritrovare la mappa com'e' adesso, non com'era
  /// quando e' caduta la connessione.
  void _sendMapTo(String playerId) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    _host?.sendTo(playerId, <String, Object?>{
      't': SessionMessage.mapSync,
      'style': campaign.mapStyle.name,
      'waypoints': <Object?>[
        for (final MapWaypoint w in campaign.waypoints)
          if (w.isShareable && w.status == WaypointStatus.accepted) w.toJson(),
      ],
    });
  }

  /// Manda un waypoint al tavolo, se e' il caso.
  void _publishWaypoint(MapWaypoint w) {
    // Una posizione privata **non lascia questa macchina**. Non e' un filtro
    // applicato dalla UI: non c'e' proprio nessun percorso che la mandi fuori,
    // ed e' la differenza fra una promessa e una garanzia.
    if (!w.isShareable || w.status != WaypointStatus.accepted) {
      _sessionChanged();
      return;
    }
    _host?.broadcast(<String, Object?>{'t': SessionMessage.mapWaypoint, 'waypoint': w.toJson()});
    _sessionChanged();
  }

  static MapWaypoint? _findWaypoint(List<MapWaypoint> list, String id) {
    for (final MapWaypoint w in list) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Waypoint dello sfondo importato: e' del master e resta suo.
  MapBackground get mapBackground =>
      _campaign?.mapBackground ?? MapBackground();

  void setMapImage(String path) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    mutateCampaign((Campaign c) => c.mapBackground.imagePath = path);
    _appendSession(description: 'Mappa importata: $path', delta: 'MAPPA');
  }

  void clearMapImage() {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    mutateCampaign((Campaign c) => c.mapBackground.imagePath = '');
    _appendSession(description: 'Mappa importata rimossa', delta: 'MAPPA');
  }

  void setMapCorner(int index, Offset corner) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    if (index < 0 || index > 3) return;
    mutateCampaign((Campaign c) => c.mapBackground.corners[index] = corner);
  }

  void resetMapCorners() {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    mutateCampaign((Campaign c) => c.mapBackground.corners = MapBackground.defaultCorners);
  }

  void setMapImageOpacity(double value) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    mutateCampaign((Campaign c) => c.mapBackground.opacity = value.clamp(0, 1).toDouble());
  }

  // --- Presenza Discord -----------------------------------------------------

  final DiscordRpc _discord = DiscordRpc();
  DiscordRpc get discord => _discord;

  final DateTime _sessionStartedAt = DateTime.now();

  /// Aggiorna la presenza Discord.
  ///
  /// Si manda solo cio' che si vedrebbe a colpo d'occhio sulla propria scheda
  /// Discord: cosa si sta facendo e con chi. Nessun percorso di file, nessun
  /// nome di personaggio se non c'e' un documento aperto: la presenza e'
  /// pubblica, e chi la guarda non ha chiesto di vedere gli altri.
  Future<void> refreshPresence() async {
    if (!settings.enableDiscordRichPresence) {
      await _discord.shutdown();
      return;
    }

    final String? id = settings.discordClientId.trim().isEmpty ? null : settings.discordClientId.trim();
    if (id == null) return;

    final String details;
    final String state;
    if (_sheet != null) {
      details = 'Scheda: ${_sheet!.meta.name}';
      state = _sheet!.identity.role.trim().isEmpty
          ? 'Gestione personaggio'
          : _sheet!.identity.role;
    } else if (_campaign != null) {
      final int connected = _campaign!.players.where((CampaignPlayer p) => p.isConnected).length;
      details = 'Campagna: ${_campaign!.meta.name}';
      state = isHosting ? 'Master · $connected al tavolo' : 'Giocatore';
    } else {
      details = 'Menu principale';
      state = 'Cyberpunk RED';  
    }

    await _discord.update(
      clientId: id,
      details: details,
      state: state,
      startTimeIso: _sessionStartedAt.toIso8601String(),
    );
  }

  // --- Aggiornamenti --------------------------------------------------------

  Updater? _updater;

  Updater get updater => _updater ??= Updater(feedUrl: settings.updateFeedUrl);

  UpdateStage _updateStage = UpdateStage.idle;
  UpdateStage get updateStage => _updateStage;

  UpdateManifest? _availableUpdate;
  UpdateManifest? get availableUpdate => _availableUpdate;

  String? _updateError;
  String? get updateError => _updateError;

  /// L'errore dell'ultimo tentativo di **installazione**, che e' cosa diversa da
  /// un controllo non riuscito: quello riguarda la rete, questo riguarda il file
  /// scaricato, e si risolve ritentando.
  String? _installError;
  String? get installError => _installError;

  double _updateProgress = 0;
  double get updateProgress => _updateProgress;

  File? _downloadedUpdate;
  File? get downloadedUpdate => _downloadedUpdate;

  bool _updateVerified = false;
  bool get updateVerified => _updateVerified;

  bool get hasUpdatePending => settings.hasPendingUpdate;

  /// La piattaforma di questa copia: decide quale pacchetto si scarica.
  UpdatePlatform get updatePlatform => updater.platform;

  /// Recupera l'esito di un aggiornamento avvenuto in un'altra esecuzione.
  ///
  /// La finestra dell'aggiornatore vive pochi secondi e sparisce: un errore
  /// mostrato solo li' dentro non lo vedrebbe nessuno. Lo legge qui, all'avvio,
  /// una volta sola.
  void consumePendingUpdateOutcome() {
    final String error = settings.lastUpdateError.trim();
    if (error.isEmpty) return;
    settings.lastUpdateError = '';
    SettingsStore.save(settings);
    _installError = error;
    notifyListeners();
  }

  /// True se c'e' una versione nuova che l'utente non ha ancora deciso di
  /// saltare.
  bool get updateWorthAsking =>
      _availableUpdate != null && _availableUpdate!.version != settings.skippedUpdateVersion;

  /// Controlla se esiste una versione nuova.
  ///
  /// [silent] distingue il controllo automatico all'avvio da quello chiesto a
  /// mano: il primo non deve produrre errori visibili quando la rete non c'e'
  /// (un avviso rosso a ogni avvio senza connessione e' rumore), il secondo deve
  /// dire chiaramente cosa non ha funzionato.
  Future<void> checkForUpdates({bool silent = false}) async {
    if (_updateStage == UpdateStage.checking || _updateStage == UpdateStage.downloading) return;

    _updateStage = UpdateStage.checking;
    _updateError = null;
    notifyListeners();

    final UpdateCheck result = await updater.check();
    switch (result.stage) {
      case UpdateStage.upToDate:
        _availableUpdate = null;
        _updateStage = UpdateStage.upToDate;
      case UpdateStage.available:
        _availableUpdate = result.release;
        _updateStage = UpdateStage.available;
        // Un aggiornamento segnalato ma non installabile (build di sviluppo)
        // resta visibile come informazione: e' il caso di chi sta lavorando al
        // programma e non deve vedersi proporre di sostituirsi.
      default:
        _updateError = result.message;
        _updateStage = silent ? UpdateStage.idle : UpdateStage.failed;
    }
    notifyListeners();
  }

  /// Scarica l'aggiornamento disponibile e ne verifica l'impronta.
  Future<bool> downloadUpdate() async {
    final UpdateManifest? manifest = _availableUpdate;
    if (manifest == null) return false;

    _updateStage = UpdateStage.downloading;
    _updateProgress = 0;
    _updateError = null;
    notifyListeners();

    final UpdateDownload result = await updater.download(
      manifest,
      onProgress: (double value) {
        _updateProgress = value;
        notifyListeners();
      },
    );

    if (!result.isReady) {
      _updateError = result.error;
      _updateStage = UpdateStage.failed;
      notifyListeners();
      return false;
    }

    _downloadedUpdate = result.file;
    _updateVerified = result.verified;
    _updateStage = UpdateStage.ready;
    notifyListeners();
    return true;
  }

  /// Rimanda l'aggiornamento alla chiusura del programma.
  ///
  /// Scarica **subito** e applica dopo: se il download avvenisse alla chiusura,
  /// l'utente che chiude e va via resterebbe col programma vecchio e senza
  /// sapere perche'. Scaricando adesso, cio' che accade alla chiusura e' un
  /// `mv` locale, che non puo' fallire per la rete.
  Future<bool> scheduleUpdateOnClose() async {
    final UpdateManifest? manifest = _availableUpdate;
    if (manifest == null) return false;

    if (_downloadedUpdate == null && !await downloadUpdate()) return false;

    await updateSettings((AppSettings s) {
      s.pendingUpdateVersion = manifest.version;
      s.pendingUpdateArchive = _downloadedUpdate!.path;
    });
    return true;
  }

  /// Salta questa versione, non gli aggiornamenti in generale.
  Future<void> skipAvailableUpdate() async {
    final UpdateManifest? manifest = _availableUpdate;
    if (manifest == null) return;
    await updateSettings((AppSettings s) => s.skippedUpdateVersion = manifest.version);
  }

  /// Annulla un aggiornamento rimandato alla chiusura.
  Future<void> cancelScheduledUpdate() async {
    await updateSettings((AppSettings s) {
      s.pendingUpdateVersion = '';
      s.pendingUpdateArchive = '';
    });
  }

  /// Applica l'aggiornamento rimandato, avviando una copia del programma che
  /// installa e poi riapre l'applicazione.
  ///
  /// Restituisce true se ha davvero avviato l'aggiornatore, cosi' chi chiude la
  /// finestra sa se puo' uscire subito o deve aspettare.
  Future<bool> startPendingUpdate() async {
    if (!settings.hasPendingUpdate) return false;

    final File archive = File(settings.pendingUpdateArchive);
    if (!archive.existsSync()) {
      // L'archivio e' stato cancellato (pulizia della cache, cartella rimossa):
      // si annulla il rinvio e si riprovera' al prossimo controllo, invece di
      // avviare un aggiornatore che non ha niente da installare.
      await cancelScheduledUpdate();
      return false;
    }

    await spawnUpdateHelper(
      executable: Platform.resolvedExecutable,
      archive: archive,
      version: settings.pendingUpdateVersion,
    );
    return true;
  }

  /// Registra che l'aggiornamento non e' riuscito.
  ///
  /// Lo chiama la copia in modalita' aggiornamento: l'errore dev'essere visibile
  /// **dopo**, nell'applicazione riaperta, perche' la finestra che lo ha
  /// prodotto sparisce subito dopo.
  Future<void> reportUpdateFailure(String message) async {
    await updateSettings((AppSettings s) {
      s.pendingUpdateVersion = '';
      s.pendingUpdateArchive = '';
    });
    _installError = message;
    notifyListeners();
  }

  /// Conferma un aggiornamento riuscito e dimentica il rinvio.
  Future<void> confirmUpdateApplied() async {
    await updateSettings((AppSettings s) {
      s.pendingUpdateVersion = '';
      s.pendingUpdateArchive = '';
      s.skippedUpdateVersion = '';
    });
    _installError = null;
    _availableUpdate = null;
    _updateStage = UpdateStage.upToDate;
    notifyListeners();
  }

  void clearInstallError() {
    if (_installError == null) return;
    _installError = null;
    notifyListeners();
  }

  void _sessionChanged() {
    _sessionTick++;
    notifyListeners();
  }

  void clearSessionError() {
    if (_sessionError == null) return;
    _sessionError = null;
    _sessionChanged();
  }

  // --- Master ---------------------------------------------------------------

  /// Apre il tavolo e mette il master in ascolto.
  Future<void> startHosting({int? port}) async {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    await stopHosting();

    final int wanted = port ?? campaign.port;
    try {
      final CampaignHost host = await CampaignHost.start(port: wanted);
      host.password = campaign.password;
      if (campaign.port != host.port) campaign.port = host.port;
      _localAddresses = await localIPv4Addresses();

      host
        ..onPlayerHello = _onPlayerHello
        ..onMessage = _onHostMessage
        ..onPlayerLeft = _onPlayerLeft
        ..onError = (Object e) {
          _sessionError = 'Problema di rete: $e';
          _sessionChanged();
        };

      _host = host;
      _sessionError = null;
      _appendSession(
        description: "Tavolo aperto sulla porta ${host.port}",
        delta: 'SESSIONE',
      );
      _scheduleSave();
    } on SocketException catch (e) {
      // La porta occupata e' l'errore piu' comune e ha una causa precisa:
      // quasi sempre il tavolo e' gia' aperto in un'altra finestra.
      _sessionError = "Non riesco ad aprire la porta $wanted: ${e.osError?.message ?? e.message}."
          ' Controlla che il tavolo non sia gia\' aperto altrove.';
      _sessionChanged();
    }
  }

  Future<void> stopHosting() async {
    final CampaignHost? host = _host;
    if (host == null) return;
    _host = null;
    await host.stop();
    _appendSession(description: 'Tavolo chiuso', delta: 'SESSIONE');
  }

  void _onPlayerHello(HostedPlayer player) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;

    CampaignPlayer? entry = _findPlayer(campaign, player.id);
    if (entry == null) {
      entry = CampaignPlayer(id: player.id);
      campaign.players.add(entry);
    }
    entry
      ..characterName = '${player.state['characterName'] ?? player.characterName}'
      ..playerName = '${player.state['playerName'] ?? player.playerName}'
      ..role = '${player.state['role'] ?? ''}'
      ..roleAbility = '${player.state['roleAbility'] ?? ''}'
      ..roleRank = '${player.state['roleRank'] ?? ''}'
      ..reputation = '${player.state['reputation'] ?? ''}'
      ..hitPoints = '${player.state['hitPoints'] ?? ''}'
      ..humanity = '${player.state['humanity'] ?? ''}'
      ..empathy = '${player.state['empathy'] ?? ''}'
      ..luck = '${player.state['luck'] ?? ''}'
      ..severeInjuries = '${player.state['severeInjuries'] ?? ''}'
      ..addictions = '${player.state['addictions'] ?? ''}'
      ..isConnected = true;

    if (entry.isBanned) {
      // Il ban e' persistente: e' il motivo per cui vive nella campagna e non
      // in memoria. Chi e' stato allontanato non rientra riavviando l'app.
      _host?.kick(player.id, 'Sei stato allontanato da questa campagna.', ban: true);
      _sessionChanged();
      return;
    }

    _host?.sendTo(player.id, <String, Object?>{
      't': SessionMessage.welcome,
      'campaignName': campaign.meta.name,
      'gameDate': campaign.gameDate,
      'motd': campaign.description,
      'port': campaign.port,
    });
    _sendMapTo(player.id);
    _broadcastPlayers();
    _appendSession(
      description: '${entry.characterName} si e\' collegato',
      delta: 'ENTRATA',
      playerId: player.id,
    );
    _scheduleSave();
  }

  void _onPlayerLeft(HostedPlayer player) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    final CampaignPlayer? entry = _findPlayer(campaign, player.id);
    if (entry == null) return;
    entry.isConnected = false;
    _broadcastPlayers();
    _appendSession(
      description: '${entry.characterName} si e\' disconnesso',
      delta: 'USCITA',
      playerId: player.id,
      persist: false,
    );
    _scheduleSave();
  }

  void _onHostMessage(HostedPlayer player, Map<String, Object?> message) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    final CampaignPlayer? entry = _findPlayer(campaign, player.id);
    final String name = entry?.characterName ?? player.characterName;
    player.state
      ..addAll(message)
      ..remove('t');

    switch ('${message['t']}') {
      case SessionMessage.chat:
        final String text = '${message['text'] ?? ''}'.trim();
        if (text.isEmpty) return;
        _host?.broadcast(<String, Object?>{
          't': SessionMessage.chat,
          'playerId': player.id,
          'name': name,
          'text': text,
          'at': DateTime.now().toIso8601String(),
        });
        _appendSession(description: text, delta: name, playerId: player.id, persist: false);

      case SessionMessage.roll:
        _host?.broadcast(<String, Object?>{
          't': SessionMessage.roll,
          'playerId': player.id,
          'name': name,
          'label': '${message['label'] ?? ''}',
          'detail': '${message['detail'] ?? ''}',
          'total': message['total'],
          'isCritical': message['isCritical'] == true,
          'isFumble': message['isFumble'] == true,
          'at': DateTime.now().toIso8601String(),
        });
        _appendSession(
          description: '${message['label'] ?? ''}: ${message['total']}'
              '${message['detail'] == null ? '' : ' (${message['detail']})'}',
          delta: name,
          playerId: player.id,
          persist: false,
        );

      case SessionMessage.intent:
        _applyIntent(player, entry, '${message['action'] ?? ''}', '${message['detail'] ?? ''}');

      case SessionMessage.snapshot:
        if (entry != null) {
          entry
            ..hitPoints = '${message['hitPoints'] ?? entry.hitPoints}'
            ..humanity = '${message['humanity'] ?? entry.humanity}'
            ..luck = '${message['luck'] ?? entry.luck}'
            ..empathy = '${message['empathy'] ?? entry.empathy}';
          _broadcastPlayers();
          _scheduleSave();
        }

      case SessionMessage.mapProposal:
        _onMapProposal(player, entry, message['waypoint']);

      case SessionMessage.mapRemove:
        // Un giocatore puo' ritirare solo le proprie proposte: senza questo
        // controllo, chiunque al tavolo potrebbe cancellare la mappa.
        final String id = '${message['id'] ?? ''}';
        final MapWaypoint? w = _findWaypoint(campaign.waypoints, id);
        if (w == null || w.authorId != player.id || w.status != WaypointStatus.proposed) return;
        campaign.waypoints.remove(w);
        _appendSession(description: 'Proposta ritirata: ${w.label}', delta: 'MAPPA', persist: false);
        _scheduleSave();

      case SessionMessage.ping:
        _host?.sendTo(player.id, <String, Object?>{'t': SessionMessage.pong});
    }
  }

  /// Riceve la proposta di un waypoint da un giocatore.
  ///
  /// La proposta **non** viene trasmessa: resta sul tavolo del master finche'
  /// lui non decide. E' l'unico modo perche' "condivido un punto" non diventi
  /// "scrivo sulla mappa di tutti senza chiedere".
  void _onMapProposal(HostedPlayer player, CampaignPlayer? entry, Object? raw) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    if (raw is! Map<Object?, Object?>) return;

    final MapWaypoint proposed = MapWaypoint.fromJson(
      raw.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
    );
    if (proposed.label.trim().isEmpty) return;

    final MapWaypoint w = MapWaypoint(
      id: proposed.id.isEmpty ? newWaypointId(campaign.waypoints.length + 1) : proposed.id,
      label: proposed.label.trim(),
      note: proposed.note.trim(),
      x: proposed.x,
      y: proposed.y,
      kind: proposed.kind,
      visibility: WaypointVisibility.table,
      status: WaypointStatus.proposed,
      authorId: player.id,
      authorName: entry?.characterName.isNotEmpty == true
          ? entry!.characterName
          : (entry?.playerName ?? player.characterName),
      createdAt: proposed.createdAt.isEmpty ? _now() : proposed.createdAt,
    );

    final MapWaypoint? existing = _findWaypoint(campaign.waypoints, w.id);
    if (existing != null) {
      // Un giocatore che modifica la propria proposta la rimanda con lo stesso
      // id: e' un aggiornamento, non un doppione.
      if (existing.authorId != player.id) return;
      existing
        ..label = w.label
        ..note = w.note
        ..x = w.x
        ..y = w.y
        ..kind = w.kind;
    } else {
      campaign.waypoints.add(w);
    }

    _appendSession(
      description: '${w.authorName} propone un waypoint: ${w.label}'.trim(),
      delta: 'MAPPA',
      playerId: player.id,
      persist: false,
    );
    _scheduleSave();
  }

  /// Applica l'intenzione di un giocatore.
  ///
  /// Il master e' l'autorita', ma le azioni banali non devono costringere il
  /// master a fare da collo di bottiglia: qui si applicano direttamente e si
  /// registrano nel log, cosi' restano visibili e annullabili come tutto il
  /// resto. Solo cio' che e' ambiguo finisce sul tavolo del master come
  /// richiesta.
  void _applyIntent(HostedPlayer player, CampaignPlayer? entry, String action, String detail) {
    if (entry == null) return;
    switch (action) {
      case 'medkit':
        masterHeal(player.id, 20, reason: 'Medkit usato da ${entry.characterName}');
      case 'firstAid':
        masterHeal(player.id, 10, reason: 'Pronto soccorso (${entry.characterName})');
      case 'rest':
        masterRestoreAll(player.id, reason: 'Riposo (${entry.characterName})');
      case 'therapy':
        masterRestoreHumanity(player.id, 6, reason: 'Terapia (${entry.characterName})');
      default:
        _appendSession(
          description: detail.isEmpty ? 'Richiesta: $action' : 'Richiesta: $action — $detail',
          delta: entry.characterName,
          playerId: player.id,
          persist: false,
        );
    }
  }

  void _broadcastPlayers() {
    final Campaign? campaign = _campaign;
    final CampaignHost? host = _host;
    if (campaign == null || host == null) return;
    host.broadcast(<String, Object?>{
      't': SessionMessage.players,
      'players': <Object?>[for (final CampaignPlayer p in campaign.players) p.toJson()],
    });
  }

  // --- Comandi del master ---------------------------------------------------

  /// Il master scrive i punti vita di un giocatore.
  ///
  /// E' l'operazione che rende utile tutto il resto: in sessione il master
  /// decide un danno e *lo applica*, invece di chiedere al giocatore di
  /// modificare la propria scheda e sperare che lo faccia.
  void masterSetHitPoints(String playerId, int current, {String reason = 'Punti vita impostati'}) {
    _updatePlayer(playerId, (CampaignPlayer p) {
      final int max = _maxOf(p.hitPoints) ?? current;
      p.hitPoints = '${current.clamp(0, 999)}/$max';
    }, reason: reason, delta: 'PV $current');
  }

  void masterDamage(String playerId, int amount, {String reason = 'Danno'}) {
    _updatePlayer(playerId, (CampaignPlayer p) {
      final int current = _currentOf(p.hitPoints) ?? 0;
      final int max = _maxOf(p.hitPoints) ?? current;
      p.hitPoints = '${(current - amount).clamp(0, 999)}/$max';
    }, reason: reason, delta: 'PV -$amount', damage: amount);
  }

  void masterHeal(String playerId, int amount, {String reason = 'Cura'}) {
    _updatePlayer(playerId, (CampaignPlayer p) {
      final int current = _currentOf(p.hitPoints) ?? 0;
      final int max = _maxOf(p.hitPoints) ?? current;
      p.hitPoints = '${(current + amount).clamp(0, max > 0 ? max : 999)}/$max';
    }, reason: reason, delta: 'PV +$amount');
  }

  void masterRestoreAll(String playerId, {String reason = 'Riposo completo'}) {
    _updatePlayer(playerId, (CampaignPlayer p) {
      final int max = _maxOf(p.hitPoints) ?? _currentOf(p.hitPoints) ?? 0;
      p.hitPoints = '$max/$max';
      p.severeInjuries = '';
    }, reason: reason, delta: 'PV MAX');
  }

  void masterRestoreHumanity(String playerId, int amount, {String reason = 'Terapia'}) {
    _updatePlayer(playerId, (CampaignPlayer p) {
      final int current = _currentOf(p.humanity) ?? 0;
      final int max = _maxOf(p.humanity) ?? current;
      p.humanity = '${(current + amount).clamp(0, max > 0 ? max : 999)}/$max';
    }, reason: reason, delta: 'UM +$amount');
  }

  void masterSetLuck(String playerId, int value, {String reason = 'Fortuna impostata'}) {
    _updatePlayer(playerId, (CampaignPlayer p) => p.luck = _withCurrent(p.luck, value),
        reason: reason, delta: 'FORTUNA $value');
  }

  void masterAddInjury(String playerId, String injury) {
    if (injury.trim().isEmpty) return;
    _updatePlayer(playerId, (CampaignPlayer p) {
      p.severeInjuries = p.severeInjuries.trim().isEmpty
          ? injury.trim()
          : '${p.severeInjuries.trim()}, ${injury.trim()}';
    }, reason: 'Ferita grave inflitta dal master', delta: 'FERITA');
  }

  void masterClearInjuries(String playerId) {
    _updatePlayer(playerId, (CampaignPlayer p) => p.severeInjuries = '',
        reason: 'Ferite curate dal master', delta: 'GUARIGIONE');
  }

  void masterSetBanned(String playerId, bool banned) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    final CampaignPlayer? entry = _findPlayer(campaign, playerId);
    if (entry == null) return;
    entry.isBanned = banned;
    if (banned) {
      entry.isConnected = false;
      _host?.kick(playerId, 'Sei stato allontanato da questa campagna.', ban: true);
    }
    _broadcastPlayers();
    _appendSession(
      description: banned ? '${entry.characterName} allontanato' : '${entry.characterName} riammesso',
      delta: banned ? 'BAN' : 'UNBAN',
      playerId: playerId,
    );
    _scheduleSave();
  }

  void masterRemovePlayer(String playerId) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    _host?.kick(playerId, 'Il master ha rimosso il personaggio dal tavolo.');
    campaign.players.removeWhere((CampaignPlayer p) => p.id == playerId);
    remotePlayers.removeWhere((CampaignPlayer p) => p.id == playerId);
    _broadcastPlayers();
    _scheduleSave();
  }

  void masterNote(String playerId, String note) {
    _updatePlayer(playerId, (CampaignPlayer p) => p.notes = note,
        reason: 'Nota del master', delta: 'NOTA', persistOnly: true);
  }

  /// Il master parla a tutto il tavolo.
  void masterChat(String text) {
    final String clean = text.trim();
    if (clean.isEmpty) return;
    _host?.broadcast(<String, Object?>{
      't': SessionMessage.chat,
      'playerId': 'master',
      'name': 'MASTER',
      'text': clean,
      'at': DateTime.now().toIso8601String(),
    });
    _appendSession(description: clean, delta: 'MASTER', playerId: 'master', persist: false);
  }

  void masterBroadcastRoll({
    required String label,
    required String detail,
    required int total,
    bool isCritical = false,
    bool isFumble = false,
  }) {
    _host?.broadcast(<String, Object?>{
      't': SessionMessage.roll,
      'playerId': 'master',
      'name': 'MASTER',
      'label': label,
      'detail': detail,
      'total': total,
      'isCritical': isCritical,
      'isFumble': isFumble,
      'at': DateTime.now().toIso8601String(),
    });
    _appendSession(description: '$label: $total', delta: 'MASTER', playerId: 'master', persist: false);
  }

  // --- Giocatore ------------------------------------------------------------

  /// Si collega al tavolo di un master.
  Future<void> joinSession({
    required String address,
    required int port,
    String password = '',
  }) async {
    final CharacterSheet? sheet = _sheet;
    final SheetTotals? totals = _totals;
    if (sheet == null || totals == null) return;
    await leaveSession();

    // La mappa del tavolo precedente non deve sopravvivere al collegamento
    // nuovo: sarebbe la mappa di un'altra campagna disegnata sopra questa.
    _tableWaypoints.clear();

    try {
      final CampaignClient client = await CampaignClient.connect(
        address: address,
        port: port,
        password: password,
        playerId: sheet.meta.id,
        characterName: sheet.meta.name,
        playerName: sheet.identity.playerName,
        characterState: _characterState(sheet, totals),
      );
      client
        ..onMessage = _onServerMessage
        ..onRejected = (String reason) {
          _sessionError = reason;
          _client = null;
          _tableWaypoints.clear();
          _sessionChanged();
        }
        ..onKicked = (String reason) {
          _sessionError = reason;
          _client = null;
          _tableWaypoints.clear();
          _sessionChanged();
        }
        ..onClosed = (String reason) {
          if (_client == client) {
            _client = null;
            _sessionError = reason;
            // Restare attaccati alla mappa di un tavolo caduto farebbe
            // credere di essere ancora collegati, che e' peggio di una mappa
            // vuota: quella almeno dice la verita'.
            _tableWaypoints.clear();
            _sessionChanged();
          }
        };
      _client = client;
      _sessionError = null;
      _sessionChanged();
    } on SocketException catch (e) {
      _sessionError = 'Collegamento non riuscito: ${e.osError?.message ?? e.message}';
      _sessionChanged();
    } on TimeoutException {
      _sessionError = 'Il master non risponde su $address:$port.';
      _sessionChanged();
    }
  }

  Future<void> leaveSession() async {
    final CampaignClient? client = _client;
    if (client == null) return;
    _client = null;
    await client.close();
    _tableWaypoints.clear();
    _appendSession(description: 'Hai lasciato il tavolo', delta: 'SESSIONE', persist: false);
    _sessionChanged();
  }

  void _onServerMessage(Map<String, Object?> message) {
    switch ('${message['t']}') {
      case SessionMessage.welcome:
        _appendSession(
          description: 'Collegato a "${message['campaignName'] ?? ''}"',
          delta: 'BENVENUTO',
          persist: false,
        );

      case SessionMessage.players:
        remotePlayers
          ..clear()
          ..addAll(
            (message['players'] is List ? message['players']! as List<Object?> : const <Object?>[])
                .whereType<Map<Object?, Object?>>()
                .map((Map<Object?, Object?> m) => CampaignPlayer.fromJson(
                      m.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
                    )),
          );

      case SessionMessage.chat:
        _appendSession(
          description: '${message['text'] ?? ''}',
          delta: '${message['name'] ?? ''}',
          playerId: '${message['playerId'] ?? ''}',
          persist: false,
        );

      case SessionMessage.roll:
        _appendSession(
          description: '${message['label'] ?? ''}: ${message['total'] ?? ''}'
              '${message['detail'] == null ? '' : ' (${message['detail']})'}',
          delta: '${message['name'] ?? ''}',
          playerId: '${message['playerId'] ?? ''}',
          persist: false,
        );

      case SessionMessage.event:
        _appendSession(
          description: '${message['description'] ?? ''}',
          delta: '${message['delta'] ?? ''}',
          playerId: '${message['playerId'] ?? ''}',
          persist: false,
        );

      case SessionMessage.mapSync:
        _remoteMapStyle = MapStyle.fromName(readString(message['style']));
        _tableWaypoints
          ..clear()
          ..addAll(<MapWaypoint>[
            for (final Map<String, Object?> raw in readObjectList(message['waypoints']))
              MapWaypoint.fromJson(raw),
          ]);

      case SessionMessage.mapWaypoint:
        _upsertTableWaypoint(message['waypoint']);

      case SessionMessage.mapRemove:
        final String id = '${message['id'] ?? ''}';
        _tableWaypoints.removeWhere((MapWaypoint w) => w.id == id);

      case SessionMessage.mapStyle:
        _remoteMapStyle = MapStyle.fromName(readString(message['style']));
    }
    _sessionChanged();
  }

  /// Inserisce o aggiorna un waypoint arrivato dal master.
  ///
  /// La visibilita' viene **forzata** a `table`: un client che si fidasse del
  /// campo ricevuto potrebbe disegnare come privato un waypoint che il master
  /// ha mandato a tutti, o viceversa. Il master manda solo cio' che vuole
  /// mostrare, quindi cio' che arriva e' per definizione condiviso.
  void _upsertTableWaypoint(Object? raw) {
    if (raw is! Map<Object?, Object?>) return;
    final MapWaypoint w = MapWaypoint.fromJson(
      raw.map((Object? k, Object? v) => MapEntry(k.toString(), v)),
    );
    if (w.id.isEmpty) return;
    w
      ..visibility = WaypointVisibility.table
      ..status = WaypointStatus.accepted;

    final int index = _tableWaypoints.indexWhere((MapWaypoint o) => o.id == w.id);
    if (index >= 0) {
      _tableWaypoints[index] = w;
    } else {
      _tableWaypoints.add(w);
    }
  }

  /// Manda al master la proprio istantanea, con un ritardo di accorpamento.
  void syncToSession() {
    if (_client == null) return;
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(const Duration(milliseconds: 600), () {
      final CharacterSheet? sheet = _sheet;
      final SheetTotals? totals = _totals;
      if (sheet == null || totals == null) return;
      _client?.sendSnapshot(_characterState(sheet, totals));
    });
  }

  void sendChat(String text) {
    final String clean = text.trim();
    if (clean.isEmpty) return;
    _client?.sendChat(clean);
    _appendSession(description: clean, delta: 'TU', persist: false);
    _sessionChanged();
  }

  void requestIntent(String action, {String detail = ''}) {
    _client?.sendIntent(action, detail: detail);
    _appendSession(
      description: detail.isEmpty ? 'Richiesta: $action' : 'Richiesta: $action — $detail',
      delta: 'TU',
      persist: false,
    );
    _sessionChanged();
  }

  void sendRollToSession({
    required String label,
    required String detail,
    required int total,
    bool isCritical = false,
    bool isFumble = false,
  }) {
    _client?.sendRoll(
      label: label,
      detail: detail,
      total: total,
      isCritical: isCritical,
      isFumble: isFumble,
    );
    _appendSession(description: '$label: $total', delta: 'TU', persist: false);
    _sessionChanged();
  }

  // --- Interni di sessione --------------------------------------------------

  Map<String, Object?> _characterState(CharacterSheet sheet, SheetTotals totals) => <String, Object?>{
        'characterName': sheet.meta.name,
        'playerName': sheet.identity.playerName,
        'role': sheet.identity.role,
        'roleAbility': sheet.identity.roleAbility,
        'roleRank': sheet.identity.roleRank,
        'reputation': sheet.identity.reputation,
        'hitPoints': '${sheet.identity.currentHp}/${totals.maxHitPoints}',
        'humanity': '${sheet.identity.currentHumanity}/${totals.maxHumanity}',
        'empathy': '${sheet.identity.currentEmpathy}/${totals.maxEmpathy}',
        'luck': '${sheet.identity.currentLuck}',
        'inspirationPoints': sheet.identity.inspirationPoints,
        'severeInjuries': sheet.identity.severeInjuries,
        'addictions': sheet.identity.addictions,
      };

  void _updatePlayer(
    String playerId,
    void Function(CampaignPlayer player) change, {
    required String reason,
    required String delta,
    bool persistOnly = false,
    int damage = 0,
  }) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    final CampaignPlayer? entry = _findPlayer(campaign, playerId);
    if (entry == null) return;

    change(entry);
    if (!persistOnly) _broadcastPlayers();
    _appendSession(description: reason, delta: delta, playerId: playerId);
    _scheduleSave();
  }

  void _appendSession({
    required String description,
    String delta = '',
    String playerId = '',
    bool persist = true,
  }) {
    final SessionEvent event = SessionEvent(
      id: 'evt-${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now().toIso8601String(),
      playerId: playerId,
      description: description,
      delta: delta,
    );
    sessionLog.insert(0, event);
    if (sessionLog.length > 400) sessionLog.removeLast();

    // Nel documento finiscono solo gli eventi che vale la pena ritrovare: la
    // chat di una serata non deve gonfiare la campagna salvata.
    if (persist) {
      _campaign?.events.insert(0, event);
      if ((_campaign?.events.length ?? 0) > 200) _campaign!.events.removeLast();
    }
    _sessionChanged();
  }

  static CampaignPlayer? _findPlayer(Campaign campaign, String id) {
    for (final CampaignPlayer p in campaign.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  static int? _currentOf(String value) {
    final List<String> parts = value.split('/');
    return parts.isEmpty ? null : int.tryParse(parts.first.trim());
  }

  static int? _maxOf(String value) {
    final List<String> parts = value.split('/');
    return parts.length < 2 ? int.tryParse(parts.first.trim()) : int.tryParse(parts[1].trim());
  }

  static String _withCurrent(String value, int current) {
    final int? max = _maxOf(value);
    return max == null ? '$current' : '$current/$max';
  }

  // --- Documento corrente --------------------------------------------------

  String? _documentPath;
  String? get documentPath => _documentPath;

  bool _dirty = false;
  bool get isDirty => _dirty;

  Timer? _autosaveTimer;

  String get documentTitle => _sheet?.meta.name ?? _campaign?.meta.name ?? 'Nessun documento';

  bool get hasDocument => _sheet != null || _campaign != null;

  // --- Creazione -----------------------------------------------------------

  /// Crea una nuova scheda e la apre.
  Future<void> createSheet({required String name, required String directory}) async {
    final String now = _now();
    final String cleanName = sanitizeName(name);
    final String path = p.join(directory, '$cleanName.${CpreduxFile.extension}');

    if (File(path).existsSync()) {
      throw CpreduxException('Esiste gia\' una scheda con questo nome.', detail: path);
    }

    final String id = _newDocumentId('sheet');
    final CpreduxFile doc = CpreduxFile.create(
      path,
      kind: DocumentKind.sheet,
      name: cleanName,
      documentId: id,
      now: now,
    );
    final CharacterSheet sheet;
    try {
      sheet = CharacterSheet.fresh(id: id, name: cleanName, now: now);
      doc.writePayload(sheet.toJson(), name: cleanName, now: now);
    } finally {
      doc.close();
    }

    _sheet = sheet;
    _campaign = null;
    _documentPath = path;
    _totals = computeTotals(sheet, lookup: catalogLookup);
    _afterOpen(path, AppScreen.sheet);
  }

  /// Crea una nuova campagna e la apre.
  Future<void> createCampaign({required String name, required String directory}) async {
    final String now = _now();
    final String cleanName = sanitizeName(name);
    final String path = p.join(directory, '$cleanName.${CpreduxFile.extension}');

    if (File(path).existsSync()) {
      throw CpreduxException('Esiste gia\' una campagna con questo nome.', detail: path);
    }

    final String id = _newDocumentId('campaign');
    final CpreduxFile doc = CpreduxFile.create(
      path,
      kind: DocumentKind.campaign,
      name: cleanName,
      documentId: id,
      now: now,
    );
    final Campaign campaign;
    try {
      campaign = Campaign.fresh(id: id, name: cleanName, now: now);
      doc.writePayload(campaign.toJson(), name: cleanName, now: now);
    } finally {
      doc.close();
    }

    _campaign = campaign;
    _sheet = null;
    _totals = null;
    _documentPath = path;
    _afterOpen(path, AppScreen.campaign);
  }

  /// Apre un documento, riconoscendo schede e campagne.
  ///
  /// Il riconoscimento avviene dal contenuto e non dall'estensione: entrambi i
  /// tipi usano `.cpredux`, e fidarsi del nome del file significherebbe
  /// aprire una campagna come scheda appena l'utente la rinomina.
  Future<void> openDocument(String path) async {
    final String extension = p.extension(path).replaceFirst('.', '').toLowerCase();

    if (extension == 'cpred_sheet') {
      throw CpreduxException(
        'Questa e\' una scheda nel formato vecchio.',
        detail: 'Usa "Converti scheda vecchia" per importarla.\n$path',
      );
    }

    final CpreduxFile doc = CpreduxFile.open(path);
    late final DocumentSummary summary;
    late final Map<String, Object?> payload;
    try {
      summary = doc.summary();
      if (summary.formatVersion > cpreduxFormatVersion) {
        throw CpreduxException(
          'Questo documento e\' stato creato con una versione piu\' recente dell\'app.',
          detail: 'Formato del file: v${summary.formatVersion} — supportato: v$cpreduxFormatVersion',
        );
      }
      payload = doc.readPayload();
    } finally {
      doc.close();
    }

    if (payload.isEmpty) {
      throw CpreduxException('Il documento e\' vuoto.');
    }

    _upgradeNotes = <String>[];
    _upgradeCounts = <String, int>{};
    Map<String, Object?> effective = payload;

    // Un documento scritto prima del catalogo ha le voci "grasse": si aggiorna
    // al formato corrente. Il controllo sulla versione dichiarata **e** sulla
    // forma dei dati: cosi' anche un file con la versione sbagliata (capita nei
    // documenti prodotti durante lo sviluppo) viene riconosciuto e sistemato.
    if (summary.formatVersion < cpreduxFormatVersion || DocumentUpgrade.looksLikeV1(payload)) {
      final DocumentUpgradeResult upgraded = DocumentUpgrade.upgrade(
        payload,
        fromVersion: summary.formatVersion == 0 ? 1 : summary.formatVersion,
        toVersion: cpreduxFormatVersion,
        catalog: _catalog,
      );
      if (upgraded.upgraded) {
        _writeUpgraded(path, upgraded.payload, summary);
        effective = upgraded.payload;
        _upgradeNotes = upgraded.notes;
        _upgradeCounts = upgraded.counts;
      }
    }

    if (summary.kind == DocumentKind.campaign) {
      _campaign = Campaign.fromJson(effective);
      _sheet = null;
      _totals = null;
      _afterOpen(path, AppScreen.campaign);
    } else {
      _sheet = CharacterSheet.fromJson(effective);
      _campaign = null;
      _totals = computeTotals(_sheet!, lookup: catalogLookup);
      _afterOpen(path, AppScreen.sheet);
    }
  }

  /// Scrive il documento aggiornato, **dopo** aver messo al sicuro l'originale.
  ///
  /// Il backup e' l'unico motivo per cui questa operazione e' accettabile fare
  /// a insaputa dell'utente: se l'aggiornamento sbagliasse qualcosa, la versione
  /// di prima esiste ancora, con il nome che dice cosa e'.
  void _writeUpgraded(String path, Map<String, Object?> payload, DocumentSummary summary) {
    try {
      CpreduxFile.backup(path, suffix: 'v${summary.formatVersion}backup');
      final CpreduxFile doc = CpreduxFile.open(path);
      try {
        doc.writePayload(payload, name: summary.name, now: _now());
      } finally {
        doc.close();
      }
    } catch (e) {
      // L'aggiornamento in memoria e' comunque valido: se la scrittura fallisce
      // si continua a lavorare, e il file resta come era. Perdere la scrittura
      // e' molto meglio che perdere il documento.
      _errorMessage = 'Non sono riuscito ad aggiornare il file su disco: $e';
    }
  }

  void _afterOpen(String path, AppScreen screen) {
    settings.rememberFile(path);
    SettingsStore.save(settings);
    _dirty = false;
    _errorMessage = null;
    _screen = screen;
    notifyListeners();
    refreshPresence();
  }

  // --- Conversione dal vecchio formato -------------------------------------

  /// Analizza una vecchia scheda **senza** convertire, per l'anteprima.
  MigrationReport analyseLegacySheet(String legacyPath) =>
      SheetMigrator.analyse(legacyPath, now: _now(), catalog: _catalog);

  /// Converte una vecchia `.cpred_sheet` e apre il risultato.
  ///
  /// Non sovrascrive mai l'originale: crea un `.cpredux` affiancato e lascia il
  /// file vecchio dov'e'. L'utente potra' cancellarlo quando si fidera'.
  MigrationReport migrateLegacySheet(String legacyPath) {
    String outputPath = '${p.withoutExtension(legacyPath)}.${CpreduxFile.extension}';
    int counter = 1;
    while (File(outputPath).existsSync()) {
      outputPath = '${p.withoutExtension(legacyPath)} ($counter).${CpreduxFile.extension}';
      counter++;
    }

    final MigrationReport report = SheetMigrator.convert(
      legacyPath,
      outputPath: outputPath,
      now: _now(),
      catalog: _catalog,
    );

    _sheet = report.sheet;
    _campaign = null;
    _documentPath = outputPath;
    _totals = computeTotals(report.sheet, lookup: catalogLookup);
    _afterOpen(outputPath, AppScreen.sheet);
    return report;
  }

  // --- Modifica e salvataggio ----------------------------------------------

  /// Unico punto di mutazione della scheda.
  void mutate(void Function(CharacterSheet sheet) change) {
    final CharacterSheet? sheet = _sheet;
    if (sheet == null) return;
    change(sheet);
    _totals = computeTotals(sheet, lookup: catalogLookup);
    _scheduleSave();

    // Se si e' al tavolo, il master deve vedere subito la variazione: e' la
    // differenza tra una sessione coordinata e tre persone che aggiornano a
    // mano i propri numeri sperando che gli altri facciano lo stesso.
    syncToSession();
  }

  /// Unico punto di mutazione della campagna.
  void mutateCampaign(void Function(Campaign campaign) change) {
    final Campaign? campaign = _campaign;
    if (campaign == null) return;
    change(campaign);
    _scheduleSave();
  }

  void _scheduleSave() {
    _dirty = true;
    notifyListeners();
    if (!settings.autosave) return;
    _autosaveTimer?.cancel();
    // 700 ms: abbastanza per accorpare una raffica di tasti, abbastanza poco
    // perche' l'utente non possa perdere nulla di significativo.
    _autosaveTimer = Timer(const Duration(milliseconds: 700), () => save(notify: false));
  }

  void save({bool notify = true}) {
    final String? path = _documentPath;
    if (path == null) return;

    _autosaveTimer?.cancel();
    final String now = _now();

    final Map<String, Object?>? payload;
    final String? name;
    if (_sheet != null) {
      _sheet!.meta.updatedAt = now;
      payload = _sheet!.toJson();
      name = _sheet!.meta.name;
    } else if (_campaign != null) {
      _campaign!.meta.updatedAt = now;
      payload = _campaign!.toJson();
      name = _campaign!.meta.name;
    } else {
      payload = null;
      name = null;
    }
    if (payload == null) return;

    try {
      final CpreduxFile doc = CpreduxFile.open(path);
      try {
        doc.writePayload(payload, name: name, now: now);
      } finally {
        doc.close();
      }
      _dirty = false;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Salvataggio non riuscito: $e';
    }
    if (notify) notifyListeners();
  }

  /// Chiude il documento corrente, salvando se necessario.
  void closeDocument() {
    if (_dirty) save(notify: false);
    _autosaveTimer?.cancel();
    _sheet = null;
    _campaign = null;
    _totals = null;
    _documentPath = null;
    _dirty = false;
    _screen = AppScreen.home;
    notifyListeners();
  }

  Future<void> updateSettings(void Function(AppSettings s) change) async {
    change(settings);
    SettingsStore.save(settings);
    notifyListeners();
    refreshPresence();
  }

  void reportError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _snapshotTimer?.cancel();
    _discord.shutdown();
    _host?.stop();
    _client?.close();
    super.dispose();
  }

  // --- Utilità -------------------------------------------------------------

  static String now() => DateTime.now().toIso8601String();

  static String _now() => now();

  /// Rimuove i caratteri che i sistemi operativi gestiscono male nei nomi di
  /// file. Non "corregge" il nome scelto dall'utente: elimina solo cio' che
  /// romperebbe il salvataggio.
  static String sanitizeName(String name) {
    final String cleaned = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '').trim();
    return cleaned.isEmpty ? 'Documento' : cleaned;
  }

  static String _newDocumentId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
