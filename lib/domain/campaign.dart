import 'campaign_ai.dart';
import 'campaign_combat.dart';
import 'enums.dart';
import 'json_support.dart';
import 'map_token.dart';
import 'net_architecture.dart';
import 'sheet.dart';
import 'transport.dart';
import 'world_map.dart';

/// Un giocatore collegato alla campagna.
///
/// Nel nuovo modello il master e' l'autorita' della sessione: il giocatore
/// invia *intenzioni* ("uso un Medkit su di me") e il master le applica
/// trasmettendo lo stato risultante. I campi qui sotto sono l'istantanea di
/// quello stato, che e' cio' che serve al master per vedere tutti i
/// personaggi in un colpo solo.
class CampaignPlayer {
  CampaignPlayer({
    required this.id,
    this.characterName = '',
    this.playerName = '',
    this.role = '',
    this.roleAbility = '',
    this.roleRank = '',
    this.reputation = '',
    this.hitPoints = '',
    this.humanity = '',
    this.empathy = '',
    this.luck = '',
    this.inspirationPoints = 0,
    this.severeInjuries = '',
    this.addictions = '',
    this.isBanned = false,
    this.isConnected = false,
    this.notes = '',
    this.mapX = 0.5,
    this.mapY = 0.5,
    this.mapDistrict = 'Little China',
    this.eurobucks = 0,
  });

  final String id;
  String characterName;
  String playerName;
  String role;
  String roleAbility;
  String roleRank;
  String reputation;
  String hitPoints;
  String humanity;
  String empathy;
  String luck;
  int inspirationPoints;
  String severeInjuries;
  String addictions;
  bool isBanned;
  bool isConnected;
  String notes;
  double mapX;
  double mapY;
  String mapDistrict;
  int eurobucks;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'characterName': characterName,
        'playerName': playerName,
        'role': role,
        'roleAbility': roleAbility,
        'roleRank': roleRank,
        'reputation': reputation,
        'hitPoints': hitPoints,
        'humanity': humanity,
        'empathy': empathy,
        'luck': luck,
        'inspirationPoints': inspirationPoints,
        'severeInjuries': severeInjuries,
        'addictions': addictions,
        'isBanned': isBanned,
        'isConnected': isConnected,
        'notes': notes,
        'mapX': mapX,
        'mapY': mapY,
        'mapDistrict': mapDistrict,
        'eurobucks': eurobucks,
      };

  static CampaignPlayer fromJson(Map<String, Object?> json) => CampaignPlayer(
        id: readString(json['id']),
        characterName: readString(json['characterName']),
        playerName: readString(json['playerName']),
        role: readString(json['role']),
        roleAbility: readString(json['roleAbility']),
        roleRank: readString(json['roleRank']),
        reputation: readString(json['reputation']),
        hitPoints: readString(json['hitPoints']),
        humanity: readString(json['humanity']),
        empathy: readString(json['empathy']),
        luck: readString(json['luck']),
        inspirationPoints: readInt(json['inspirationPoints']),
        severeInjuries: readString(json['severeInjuries']),
        addictions: readString(json['addictions']),
        isBanned: readBool(json['isBanned']),
        isConnected: readBool(json['isConnected']),
        notes: readString(json['notes']),
        mapX: readDouble(json['mapX'], 0.5),
        mapY: readDouble(json['mapY'], 0.5),
        mapDistrict: readString(json['mapDistrict'], 'Little China'),
        eurobucks: readInt(json['eurobucks']),
      );
}

/// Un evento della sessione.
///
/// Ogni modifica e' un evento e non una mutazione silenziosa: e' cio' che
/// permette il log di sessione, l'annullamento di un'azione del master, e
/// l'animazione delle variazioni sapendo *da dove* arrivano ("hai perso 12 PV"
/// invece di "i PV sono 26").
class SessionEvent {
  SessionEvent({
    required this.id,
    required this.timestamp,
    this.playerId = '',
    this.description = '',
    this.delta = '',
    this.gifUrl = '',
    this.attachmentName = '',
    this.attachmentSize = 0,
    this.attachmentType = '',
    this.attachmentData = '',
    this.whisperTo = '',
    this.isWhisper = false,
    this.isTransaction = false,
    this.isAlert = false,
    this.transactionAmount,
    this.senderName,
    this.recipientName,
  });

  final String id;
  final String timestamp;
  final String playerId;
  final String description;

  /// Variazione in forma leggibile ("PV -12", "Oggetto rimosso", "JACKIE").
  final String delta;

  /// Destinatari del sussurro privato (es. "Jackie", "Jackie, V").
  final String whisperTo;

  /// True se l'evento e' un messaggio privato / segreto.
  final bool isWhisper;

  /// Flag per transazione monetaria (evidenziata con sfondo verde trasparente in chat).
  final bool isTransaction;

  /// Flag per allarme, ban o evento punitivo (evidenziato in rosso in chat).
  final bool isAlert;

  final int? transactionAmount;
  final String? senderName;
  final String? recipientName;

  /// URL di una GIF animata (Tenor/Giphy).
  final String gifUrl;

  /// Metadati e dati di un allegato peer-to-peer (immagine o file).
  final String attachmentName;
  final int attachmentSize;
  final String attachmentType;
  final String attachmentData;

  bool get hasGif => gifUrl.isNotEmpty;
  bool get hasAttachment => attachmentData.isNotEmpty;
  bool get isImageAttachment =>
      attachmentType.startsWith('image/') ||
      attachmentName.endsWith('.png') ||
      attachmentName.endsWith('.jpg') ||
      attachmentName.endsWith('.jpeg') ||
      attachmentName.endsWith('.gif') ||
      attachmentName.endsWith('.webp');

  List<String> get whisperTargets => whisperTo
      .split(',')
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList();

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'timestamp': timestamp,
        'playerId': playerId,
        'description': description,
        'delta': delta,
        if (whisperTo.isNotEmpty) 'whisperTo': whisperTo,
        if (isWhisper) 'isWhisper': isWhisper,
        if (isTransaction) 'isTransaction': isTransaction,
        if (isAlert) 'isAlert': isAlert,
        if (transactionAmount != null) 'transactionAmount': transactionAmount,
        if (senderName != null) 'senderName': senderName,
        if (recipientName != null) 'recipientName': recipientName,
        if (gifUrl.isNotEmpty) 'gifUrl': gifUrl,
        if (attachmentName.isNotEmpty) 'attachmentName': attachmentName,
        if (attachmentSize > 0) 'attachmentSize': attachmentSize,
        if (attachmentType.isNotEmpty) 'attachmentType': attachmentType,
        if (attachmentData.isNotEmpty) 'attachmentData': attachmentData,
      };

  static SessionEvent fromJson(Map<String, Object?> json) => SessionEvent(
        id: readString(json['id']),
        timestamp: readString(json['timestamp']),
        playerId: readString(json['playerId']),
        description: readString(json['description']),
        delta: readString(json['delta']),
        whisperTo: readString(json['whisperTo']),
        isWhisper: json['isWhisper'] == true,
        isTransaction: json['isTransaction'] == true,
        isAlert: json['isAlert'] == true,
        transactionAmount: json['transactionAmount'] != null ? readInt(json['transactionAmount']) : null,
        senderName: readNullableString(json['senderName']),
        recipientName: readNullableString(json['recipientName']),
        gifUrl: readString(json['gifUrl']),
        attachmentName: readString(json['attachmentName']),
        attachmentSize: readInt(json['attachmentSize']),
        attachmentType: readString(json['attachmentType']),
        attachmentData: readString(json['attachmentData']),
      );
}

/// La campagna: un documento con i giocatori, il quaderno, il log di sessione e
/// la mappa condivisa.
class Campaign {
  Campaign({
    required this.meta,
    this.gameDate = '2045-05-14',
    this.gameTime = '22:00',
    this.description = '',
    this.port = 21099,
    this.password = '',
    this.advertisedAddress = '',
    this.mapStyle = MapStyle.digital,
    MapBackground? mapBackground,
    List<CampaignPlayer>? players,
    List<SessionEvent>? events,
    List<MapWaypoint>? waypoints,
    List<MapToken>? tokens,
    List<Transport>? transports,
    List<CampaignAiBot>? aiBots,
    List<PendingAiHack>? pendingHacks,
    List<CampaignSessionCommit>? sessionCommits,
    List<CombatInitiativeEntry>? initiativeOrder,
    this.currentInitiativeTurnIndex = 0,
    this.combatRound = 1,
    this.netArchitecture,
  })  : players = players ?? <CampaignPlayer>[],
        events = events ?? <SessionEvent>[],
        waypoints = waypoints ?? <MapWaypoint>[],
        tokens = tokens ?? <MapToken>[],
        transports = transports ?? <Transport>[],
        aiBots = aiBots ?? CampaignAiBot.defaultFleet(),
        pendingHacks = pendingHacks ?? <PendingAiHack>[],
        sessionCommits = sessionCommits ?? <CampaignSessionCommit>[],
        initiativeOrder = initiativeOrder ?? <CombatInitiativeEntry>[],
        mapBackground = mapBackground ?? MapBackground();

  final DocumentMeta meta;
  String gameDate;
  String gameTime;
  String description;

  /// Architettura NET della campagna per il Netrunner.
  NetArchitecture? netArchitecture;

  /// Flotta di Intelligenze Artificiali programmabili della campagna (Delamain, Broker, ecc.).
  final List<CampaignAiBot> aiBots;

  /// Richieste pendenti di hackeraggio illegale verso le IA.
  final List<PendingAiHack> pendingHacks;

  /// Archivio cronologico delle sessioni con trascrizioni e riassunti IA (stile commit).
  final List<CampaignSessionCommit> sessionCommits;

  /// Ordine di iniziativa e turni di combattimento del tavolo.
  final List<CombatInitiativeEntry> initiativeOrder;
  int currentInitiativeTurnIndex;
  int combatRound;

  /// Aspetto della mappa scelto dal master: e' lui che disegna il tavolo, e
  /// l'aspetto viaggia con la campagna quindi tutti vedono la stessa cosa.
  MapStyle mapStyle;

  /// Sfondo della mappa: geometria spedita, oppure un'immagine del master.
  MapBackground mapBackground;

  /// I waypoint della campagna.
  final List<MapWaypoint> waypoints;

  /// I token sulla mappa: chi c'e', dove, e in che stato.
  final List<MapToken> tokens;

  /// I trasporti in corso: un taxi che sta portando qualcuno in centro, una moto che scappa.
  final List<Transport> transports;

  /// Porta di ascolto per la sessione condivisa.
  int port;

  /// Password del tavolo. Vuota significa tavolo aperto a chi ha l'indirizzo.
  String password;

  /// Indirizzo di rete da comunicare ai giocatori (facoltativo).
  String advertisedAddress;

  final List<CampaignPlayer> players;
  final List<SessionEvent> events;

  factory Campaign.fresh({required String id, required String name, required String now}) => Campaign(
        meta: DocumentMeta(id: id, name: name, kind: DocumentKind.campaign, createdAt: now, updatedAt: now),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'meta': meta.toJson(),
        'gameDate': gameDate,
        'gameTime': gameTime,
        'description': description,
        'port': port,
        'password': password,
        'advertisedAddress': advertisedAddress,
        'mapStyle': mapStyle.name,
        'mapBackground': mapBackground.toJson(),
        if (netArchitecture != null) 'netArchitecture': netArchitecture!.toJson(),
        'aiBots': aiBots.map((CampaignAiBot b) => b.toJson()).toList(),
        'pendingHacks': pendingHacks.map((PendingAiHack h) => h.toJson()).toList(),
        'sessionCommits': sessionCommits.map((CampaignSessionCommit c) => c.toJson()).toList(),
        'initiativeOrder': initiativeOrder.map((CombatInitiativeEntry i) => i.toJson()).toList(),
        'currentInitiativeTurnIndex': currentInitiativeTurnIndex,
        'combatRound': combatRound,
        'waypoints': waypoints.map((MapWaypoint w) => w.toJson()).toList(),
        'tokens': tokens.map((MapToken t) => t.toJson()).toList(),
        'transports': transports.map((Transport t) => t.toJson()).toList(),
        'players': players.map((CampaignPlayer p) => p.toJson()).toList(),
        'events': events.map((SessionEvent e) => e.toJson()).toList(),
      };

  static Campaign fromJson(Map<String, Object?> json) => Campaign(
        meta: DocumentMeta.fromJson(
          json['meta'] is Map
              ? (json['meta']! as Map<Object?, Object?>)
                  .map((Object? k, Object? v) => MapEntry(k.toString(), v))
              : const <String, Object?>{},
        ),
        gameDate: readString(json['gameDate'], '2045-05-14'),
        gameTime: readString(json['gameTime'], '22:00'),
        description: readString(json['description']),
        port: readInt(json['port'], 21099),
        password: readString(json['password']),
        advertisedAddress: readString(json['advertisedAddress']),
        mapStyle: MapStyle.fromName(readString(json['mapStyle'])),
        mapBackground: MapBackground.fromJson(
          json['mapBackground'] is Map
              ? (json['mapBackground']! as Map<Object?, Object?>)
                  .map((Object? k, Object? v) => MapEntry(k.toString(), v))
              : const <String, Object?>{},
        ),
        netArchitecture: json['netArchitecture'] is Map
            ? NetArchitecture.fromJson(
                (json['netArchitecture']! as Map<Object?, Object?>)
                    .map((Object? k, Object? v) => MapEntry(k.toString(), v)),
              )
            : null,
        aiBots: json['aiBots'] != null
            ? readObjectList(json['aiBots']).map(CampaignAiBot.fromJson).toList()
            : CampaignAiBot.defaultFleet(),
        pendingHacks: readObjectList(json['pendingHacks']).map(PendingAiHack.fromJson).toList(),
        sessionCommits: readObjectList(json['sessionCommits']).map(CampaignSessionCommit.fromJson).toList(),
        initiativeOrder: readObjectList(json['initiativeOrder']).map(CombatInitiativeEntry.fromJson).toList(),
        currentInitiativeTurnIndex: readInt(json['currentInitiativeTurnIndex'], 0),
        combatRound: readInt(json['combatRound'], 1),
        players: readObjectList(json['players']).map(CampaignPlayer.fromJson).toList(),
        events: readObjectList(json['events']).map(SessionEvent.fromJson).toList(),
        waypoints: readObjectList(json['waypoints']).map(MapWaypoint.fromJson).toList(),
        tokens: readObjectList(json['tokens']).map(MapToken.fromJson).toList(),
        transports: readObjectList(json['transports']).map(Transport.fromJson).toList(),
      );
}
