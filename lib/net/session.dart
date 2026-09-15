/// Protocollo della sessione condivisa.
///
/// Scelte, e perche':
///
/// * **Una riga di JSON per messaggio.** Il vecchio progetto usava un frame
///   `lunghezza + SHA-256 + Base64(JSON)`: il checksum su un socket TCP e'
///   ridondante (TCP ha gia' i suoi controlli) e l'incapsulamento Base64
///   gonfiava ogni messaggio di un terzo. Una riga di JSON si legge con
///   `netcat`, si registra in un file di log e si ispeziona senza strumenti.
/// * **Il master e' l'autorita'.** Il giocatore non scrive mai lo stato degli
///   altri: manda *intenzioni* e il master decide. E' l'unico modo per evitare
///   che due client mostrino due verita' diverse.
/// * **Nessuna dipendenza.** `dart:io` basta: la sessione e' un socket TCP e
///   le regole stanno nel dominio, gia' testato.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Tipi di messaggio. Stringhe brevi: viaggiano in ogni riga.
abstract final class SessionMessage {
  // Giocatore -> master
  static const String hello = 'hello';
  static const String chat = 'chat';
  static const String roll = 'roll';
  static const String intent = 'intent';
  static const String snapshot = 'snapshot';
  static const String ping = 'ping';

  /// Invio peer-to-peer di file o immagini tramite la sessione del tavolo.
  static const String attachment = 'attachment';

  /// Un waypoint che il giocatore propone al master. Il master decide: fino a
  /// quando non lo accetta, quel segno esiste solo sulla mappa di chi l'ha
  /// messo. Non e' burocrazia — e' cio' che impedisce a un giocatore di
  /// scrivere sulla mappa che tutti stanno guardando mentre il master parla.
  static const String mapProposal = 'mapProposal';

  // Master -> giocatore
  static const String welcome = 'welcome';
  static const String rejected = 'rejected';
  static const String players = 'players';
  static const String event = 'event';
  static const String kicked = 'kicked';
  static const String pong = 'pong';

  /// Trasmissione diretta di uno stato aggiornato della scheda da parte del master.
  static const String sheetSync = 'sheetSync';

  /// La mappa condivisa, mandata al momento del collegamento: senza, un
  /// giocatore che rientra a meta' serata vedrebbe una mappa vuota mentre al
  /// tavolo ne stanno parlando.
  static const String mapSync = 'mapSync';

  /// Un waypoint che il master ha accettato: da questo momento e' sulla mappa
  /// di tutti.
  static const String mapWaypoint = 'mapWaypoint';

  /// Un waypoint rimosso (o rifiutato).
  static const String mapRemove = 'mapRemove';

  /// L'aspetto della mappa scelto dal master. Viaggia con il resto dello stato
  /// del tavolo: se il master passa alla mappa realistica, la passano tutti.
  static const String mapStyle = 'mapStyle';

  /// Un veicolo in strada, con la sua posizione **adesso**.
  ///
  /// La posizione viaggia nel messaggio invece di essere ricalcolata dal
  /// giocatore: l'orologio dei trasporti gira solo dal master, e un client che
  /// calcolasse da solo dove si trova il taxi mostrerebbe un taxi in un posto
  /// diverso da quello che il master sta descrivendo. Se la connessione cade,
  /// il veicolo si ferma dove era: un mezzo fermo e' meglio di un mezzo che
  /// arriva a destinazione da solo mentre nessuno lo sta guardando.
  static const String transport = 'transport';

  /// Un veicolo tolto dalla strada.
  static const String transportRemove = 'transportRemove';

  /// Comando del Master a tutti i client di terminare la registrazione audio,
  /// avviare il voice-to-text ed esportare la trascrizione al tavolo.
  static const String sessionEndRequest = 'sessionEndRequest';

  /// Invio dal client al master della trascrizione vocale del singolo giocatore.
  static const String sessionPlayerTranscript = 'sessionPlayerTranscript';
}

/// Una connessione in stile "un messaggio JSON per riga".
class LineChannel {
  LineChannel(this._socket) {
    _subscription = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      _onLine,
      onError: _fail,
      onDone: _done,
      cancelOnError: true,
    );
  }

  final Socket _socket;
  late final StreamSubscription<String> _subscription;

  void Function(Map<String, Object?> message)? onMessage;
  void Function(Object error)? onError;
  void Function()? onClose;

  bool _closed = false;
  bool get isClosed => _closed;

  void _onLine(String line) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      // Una riga illeggibile non deve abbattere la sessione: si ignora. Se il
      // peer mandasse spazzatura di continuo il socket si chiuderebbe da solo.
      return;
    }
    if (decoded is! Map<Object?, Object?>) return;
    onMessage?.call(decoded.map((Object? k, Object? v) => MapEntry(k.toString(), v)));
  }

  void _fail(Object error) {
    if (_closed) return;
    _closed = true;
    onError?.call(error);
  }

  void _done() {
    if (_closed) return;
    _closed = true;
    onClose?.call();
  }

  void send(Map<String, Object?> message) {
    if (_closed) return;
    try {
      _socket.write('${jsonEncode(message)}\n');
    } on SocketException {
      _fail('Connessione interrotta');
    }
  }

  Future<void> close() async {
    _closed = true;
    await _subscription.cancel();
    try {
      await _socket.flush();
    } catch (_) {
      // Il peer potrebbe essere gia' andato via: la chiusura resta un'operazione
      // best-effort.
    }
    try {
      _socket.destroy();
    } catch (_) {
      // idem
    }
  }

  String get remoteAddress {
    try {
      return '${_socket.remoteAddress.address}:${_socket.remotePort}';
    } catch (_) {
      return '';
    }
  }
}

/// Chi sta parlando con il master.
class HostedPlayer {
  HostedPlayer({required this.id, this.channel});

  final String id;

  /// Non `final`: una riconnessione sostituisce il socket mantenendo la stessa
  /// identita' di giocatore, cosi' il master non vede due volte lo stesso
  /// personaggio dopo una caduta di rete.
  LineChannel? channel;

  String characterName = '';
  String playerName = '';
  String address = '';

  /// L'ultima istantanea che il giocatore ha comunicato (punti vita, umanita',
  /// ecc.). E' il materiale su cui il master mostra e modifica lo stato.
  final Map<String, Object?> state = <String, Object?>{};

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'characterName': characterName,
        'playerName': playerName,
        'address': address,
      };
}

/// Lato master: ascolta, accetta giocatori e trasmette lo stato.
///
/// La classe non contiene regole di gioco: espone callback e lascia al
/// chiamante (lo stato dell'applicazione) il compito di decidere cosa fare con
/// un'intenzione. Cosi' la rete resta testabile senza Schermo ne' dominio.
class CampaignHost {
  CampaignHost._(this._server);

  final ServerSocket _server;
  final Map<String, HostedPlayer> players = <String, HostedPlayer>{};

  /// Password richiesta ai giocatori. Vuota significa "tavolo aperto".
  String password = '';

  void Function(HostedPlayer player)? onPlayerHello;
  void Function(HostedPlayer player)? onPlayerLeft;
  void Function(HostedPlayer player, Map<String, Object?> message)? onMessage;
  void Function(Object error)? onError;

  int get port => _server.port;
  bool get isRunning => true;
  int get playerCount => players.length;

  static Future<CampaignHost> start({
    required int port,
    String? bindAddress,
  }) async {
    final ServerSocket server = await ServerSocket.bind(
      bindAddress ?? InternetAddress.anyIPv4,
      port,
      shared: false,
    );
    final CampaignHost host = CampaignHost._(server);
    server.listen(host._accept, onError: (Object e) => host.onError?.call(e));
    return host;
  }

  void _accept(Socket socket) {
    final LineChannel channel = LineChannel(socket);
    HostedPlayer? player;

    channel.onMessage = (Map<String, Object?> message) {
      final String type = '${message['t']}';
      if (player == null) {
        // Prima di qualsiasi altra cosa deve arrivare l'identificazione: un
        // socket anonimo non puo' toccare nulla.
        if (type != SessionMessage.hello) {
          channel.send(<String, Object?>{'t': SessionMessage.rejected, 'reason': 'Nessuna identificazione.'});
          channel.close();
          return;
        }
        if (password.isNotEmpty && '${message['password']}' != password) {
          channel.send(<String, Object?>{
            't': SessionMessage.rejected,
            'reason': 'Password errata.',
          });
          channel.close();
          return;
        }
        final String id = '${message['playerId']}';
        if (id.isEmpty) {
          channel.send(<String, Object?>{'t': SessionMessage.rejected, 'reason': 'Scheda senza identificativo.'});
          channel.close();
          return;
        }
        final HostedPlayer created = players[id] ?? HostedPlayer(id: id, channel: channel);

        // Riconnessione: lo stesso identificativo sostituisce il socket
        // precedente invece di creare un doppione (succede ogni volta che cade
        // il wifi e il giocatore rientra). Il vecchio socket si chiude **prima**
        // di sovrascrivere il riferimento: dopo la sovrascrittura non si
        // saprebbe piu' quale fosse, e resterebbe aperto a tempo indefinito.
        final LineChannel? previousChannel = created.channel;
        if (previousChannel != null && previousChannel != channel) {
          previousChannel.close();
        }

        created
          ..channel = channel
          ..characterName = '${message['characterName'] ?? ''}'
          ..playerName = '${message['playerName'] ?? ''}'
          ..address = channel.remoteAddress;
        created.state
          ..clear()
          ..addAll(message)
          ..remove('password')
          ..remove('t');

        players[id] = created;
        player = created;
        onPlayerHello?.call(created);
        return;
      }

      onMessage?.call(player!, message);
    };

    channel.onError = (Object e) => onError?.call(e);
    channel.onClose = () {
      final HostedPlayer? me = player;
      if (me == null) return;
      // Se questa connessione e' stata sostituita da una riconnessione, la sua
      // chiusura non deve togliere dal tavolo il giocatore che sta giocando:
      // senza questo controllo, rientrare dopo una caduta di rete espelleva
      // dal tavolo il giocatore appena rientrato.
      if (players[me.id]?.channel != channel) return;
      players.remove(me.id);
      onPlayerLeft?.call(me);
    };
  }

  /// Manda un messaggio a un giocatore.
  void sendTo(String playerId, Map<String, Object?> message) {
    players[playerId]?.channel?.send(message);
  }

  /// Manda un messaggio a tutti.
  void broadcast(Map<String, Object?> message) {
    for (final HostedPlayer p in players.values) {
      p.channel?.send(message);
    }
  }

  /// Aggiunge una riga al log condiviso e la trasmette.
  void broadcastEvent({required String description, String delta = '', String playerId = ''}) {
    broadcast(<String, Object?>{
      't': SessionMessage.event,
      'id': '${DateTime.now().microsecondsSinceEpoch}',
      'timestamp': DateTime.now().toIso8601String(),
      'playerId': playerId,
      'description': description,
      'delta': delta,
    });
  }

  /// Espelle un giocatore, spiegandogli il motivo prima di chiudere.
  void kick(String playerId, String reason, {bool ban = false}) {
    final HostedPlayer? player = players.remove(playerId);
    if (player == null) return;
    player.channel?.send(<String, Object?>{
      't': SessionMessage.kicked,
      'reason': reason,
      'ban': ban,
    });
    player.channel?.close();
  }

  Future<void> stop() async {
    for (final HostedPlayer p in players.values.toList()) {
      p.channel?.send(<String, Object?>{'t': SessionMessage.kicked, 'reason': 'Il master ha chiuso il tavolo.'});
      await p.channel?.close();
    }
    players.clear();
    await _server.close();
  }
}

/// Lato giocatore: si collega a un master e riceve lo stato deciso da lui.
class CampaignClient {
  CampaignClient._(this.channel);

  final LineChannel channel;

  bool _welcomed = false;
  bool get isConnected => _welcomed;

  String campaignName = '';
  String gameDate = '';

  void Function(Map<String, Object?> message)? onMessage;
  void Function(String reason)? onRejected;
  void Function(String reason)? onClosed;
  void Function(String reason)? onKicked;

  static Future<CampaignClient> connect({
    required String address,
    required int port,
    required String playerId,
    required String characterName,
    required String playerName,
    required Map<String, Object?> characterState,
    Map<String, Object?>? fullSheet,
    String password = '',
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final Socket socket = await Socket.connect(address, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);

    final CampaignClient client = CampaignClient._(LineChannel(socket));
    final LineChannel c = client.channel;

    c.onMessage = (Map<String, Object?> message) {
      final String type = '${message['t']}';
      switch (type) {
        case SessionMessage.welcome:
          client._welcomed = true;
          client.campaignName = '${message['campaignName'] ?? ''}';
          client.gameDate = '${message['gameDate'] ?? ''}';
        case SessionMessage.rejected:
          client.onRejected?.call('${message['reason'] ?? 'Collegamento rifiutato.'}');
        case SessionMessage.kicked:
          client._welcomed = false;
          client.onKicked?.call('${message['reason'] ?? 'Sei stato allontanato dal tavolo.'}');
      }
      client.onMessage?.call(message);
    };

    c.onError = (Object e) => client.onClosed?.call('$e');
    c.onClose = () {
      if (client._welcomed) {
        client._welcomed = false;
        client.onClosed?.call('Il tavolo si e\' chiuso.');
      }
    };

    c.send(<String, Object?>{
      't': SessionMessage.hello,
      'playerId': playerId,
      'characterName': characterName,
      'playerName': playerName,
      'password': password,
      'sheet': ?fullSheet,
      ...characterState,
    });

    return client;
  }

  void sendChat(String text, {String? gifUrl, String? whisperTo}) => channel.send(<String, Object?>{
        't': SessionMessage.chat,
        'text': text,
        if (gifUrl != null && gifUrl.isNotEmpty) 'gifUrl': gifUrl,
        if (whisperTo != null && whisperTo.isNotEmpty) 'whisperTo': whisperTo,
      });

  /// Invia un file o un'immagine in peer-to-peer tramite la sessione del tavolo.
  void sendAttachment({
    required String fileName,
    required int size,
    required String mimeType,
    required String base64Data,
    String? caption,
  }) =>
      channel.send(<String, Object?>{
        't': SessionMessage.attachment,
        'fileName': fileName,
        'size': size,
        'mimeType': mimeType,
        'data': base64Data,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
      });

  void sendRoll({
    required String label,
    required String detail,
    required int total,
    bool isCritical = false,
    bool isFumble = false,
  }) =>
      channel.send(<String, Object?>{
        't': SessionMessage.roll,
        'label': label,
        'detail': detail,
        'total': total,
        'isCritical': isCritical,
        'isFumble': isFumble,
      });

  /// Comunica un'intenzione: il master decide se applicarla.
  void sendIntent(String action, {String detail = ''}) =>
      channel.send(<String, Object?>{'t': SessionMessage.intent, 'action': action, 'detail': detail});

  /// Aggiorna la propria istantanea (dopo che il master ha applicato qualcosa).
  void sendSnapshot(Map<String, Object?> state) =>
      channel.send(<String, Object?>{'t': SessionMessage.snapshot, ...state});

  /// Propone un waypoint al master.
  ///
  /// Si manda il waypoint per intero e non solo la posizione: il master deve
  /// poter vedere "pericolo, imboscata sotto il ponte" prima di decidere se
  /// metterlo sulla mappa di tutti, e non solo un puntino da qualche parte.
  void sendMapProposal(Map<String, Object?> waypoint) =>
      channel.send(<String, Object?>{'t': SessionMessage.mapProposal, 'waypoint': waypoint});

  Future<void> close() => channel.close();
}

/// Indirizzi IPv4 della macchina, per dire al master cosa comunicare ai
/// giocatori. Si escludono loopback e interfacce virtuali: elencare
/// `127.0.0.1` a chi deve condividere un indirizzo e' il modo piu' rapido per
/// far perdere dieci minuti a un tavolo.
Future<List<String>> localIPv4Addresses() async {
  final List<String> addresses = <String>[];
  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final NetworkInterface i in interfaces) {
      for (final InternetAddress a in i.addresses) {
        addresses.add(a.address);
      }
    }
  } on SocketException {
    // Nessuna interfaccia: non e' un errore fatale, il master vedra' solo la
    // nota che invita a controllare la rete.
  }
  return addresses;
}
