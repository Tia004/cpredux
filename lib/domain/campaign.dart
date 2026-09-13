import 'enums.dart';
import 'json_support.dart';
import 'sheet.dart';
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
  });

  final String id;
  final String timestamp;
  final String playerId;
  final String description;

  /// Variazione in forma leggibile ("PV -12", "Oggetto rimosso").
  final String delta;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'timestamp': timestamp,
        'playerId': playerId,
        'description': description,
        'delta': delta,
      };

  static SessionEvent fromJson(Map<String, Object?> json) => SessionEvent(
        id: readString(json['id']),
        timestamp: readString(json['timestamp']),
        playerId: readString(json['playerId']),
        description: readString(json['description']),
        delta: readString(json['delta']),
      );
}

/// La campagna: un documento con i giocatori, il quaderno, il log di sessione e
/// la mappa condivisa.
class Campaign {
  Campaign({
    required this.meta,
    this.gameDate = '',
    this.description = '',
    this.port = 21099,
    this.password = '',
    this.advertisedAddress = '',
    this.mapStyle = MapStyle.digital,
    MapBackground? mapBackground,
    List<CampaignPlayer>? players,
    List<SessionEvent>? events,
    List<MapWaypoint>? waypoints,
  })  : players = players ?? <CampaignPlayer>[],
        events = events ?? <SessionEvent>[],
        waypoints = waypoints ?? <MapWaypoint>[],
        mapBackground = mapBackground ?? MapBackground();

  final DocumentMeta meta;
  String gameDate;
  String description;

  /// Aspetto della mappa scelto dal master: e' lui che disegna il tavolo, e
  /// l'aspetto viaggia con la campagna quindi tutti vedono la stessa cosa.
  MapStyle mapStyle;

  /// Sfondo della mappa: geometria spedita, oppure un'immagine del master.
  MapBackground mapBackground;

  /// I waypoint della campagna.
  ///
  /// Vivono nel documento e non nella sessione perche' sono **preparazione**:
  /// i waypoint di una serata si ritrovano in quella successiva, ed e' quello
  /// che li distingue da una chat. Le posizioni private del master restano qui
  /// dentro e non vengono trasmesse.
  final List<MapWaypoint> waypoints;

  /// Porta di ascolto per la sessione condivisa.
  int port;

  /// Password del tavolo. Vuota significa tavolo aperto a chi ha l'indirizzo.
  String password;

  /// Indirizzo di rete da comunicare ai giocatori (facoltativo: il master puo'
  /// anche solo copiare quello rilevato automaticamente).
  String advertisedAddress;

  final List<CampaignPlayer> players;
  final List<SessionEvent> events;

  factory Campaign.fresh({required String id, required String name, required String now}) => Campaign(
        meta: DocumentMeta(id: id, name: name, kind: DocumentKind.campaign, createdAt: now, updatedAt: now),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'meta': meta.toJson(),
        'gameDate': gameDate,
        'description': description,
        'port': port,
        'password': password,
        'advertisedAddress': advertisedAddress,
        'mapStyle': mapStyle.name,
        'mapBackground': mapBackground.toJson(),
        'waypoints': waypoints.map((MapWaypoint w) => w.toJson()).toList(),
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
        gameDate: readString(json['gameDate']),
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
        players: readObjectList(json['players']).map(CampaignPlayer.fromJson).toList(),
        events: readObjectList(json['events']).map(SessionEvent.fromJson).toList(),
        // Una campagna salvata prima che la mappa esistesse apre senza problemi:
        // `waypoints` assente vale elenco vuoto, non errore.
        waypoints: readObjectList(json['waypoints']).map(MapWaypoint.fromJson).toList(),
      );
}
