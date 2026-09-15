import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Discord Rich Presence, parlando direttamente con il client Discord.
///
/// Non si usa una libreria di terze parti per una ragione precisa: quelle
/// disponibili sono wrapper attorno a *questo* protocollo, e il percorso del
/// socket cambia per sistema, per canale e per tipo di installazione (nativa,
/// Snap, Flatpak). Con poche righe di `dart:io` il percorso si prova in ordine
/// finche' uno risponde; con un pacchetto esterno si finisce per aspettare che
/// qualcun altro copra il caso che serve.
///
/// Protocollo: socket locale, frame `opcode int32 LE + lunghezza int32 LE +
/// JSON`. Handshake con opcode 0, aggiornamento presenza con opcode 1.
class DiscordRpc {
  static const int _opHandshake = 0;
  static const int _opFrame = 1;
  static const int _opClose = 2;
  static const int _opPing = 3;
  static const int _opPong = 4;

  /// Discord apre fino a dieci socket, uno per istanza avviata.
  static const int _maxClients = 10;

  Socket? _socket;
  final BytesBuilder _readBuffer = BytesBuilder(copy: false);
  bool _handshaken = false;
  String? _clientId;
  Map<String, Object?>? _activity;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _connecting = false;
  String? _discordUsername;

  bool get isConnected => _handshaken && _socket != null;
  String? get discordUsername => _discordUsername;

  /// Collega (se serve) e imposta l'attivita'.
  ///
  /// Non solleva eccezioni: se Discord non e' aperto — il caso piu' comune —
  /// l'applicazione deve semplicemente non mostrare nulla.
  Future<void> update({
    required String clientId,
    required String details,
    required String state,
    String? startTimeIso,
    String? largeImage,
    String? largeText,
    String? smallImage,
    String? smallText,
    int? partySize,
    int? partyMax,
    List<Map<String, String>>? buttons,
  }) async {
    final String id = clientId.trim();
    if (id.isEmpty) {
      await shutdown();
      return;
    }

    final Map<String, Object?> activityData = <String, Object?>{
      'details': _clip(details, 128),
      'state': _clip(state, 128),
      'timestamps': <String, Object?>{
        'start': DateTime.tryParse(startTimeIso ?? '')?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
      },
      'assets': <String, Object?>{
        'large_image': largeImage ?? 'main',
        'large_text': _clip(largeText ?? 'Cyberpunk RED Visualizer', 128),
        if (smallImage != null && smallImage.isNotEmpty) 'small_image': smallImage,
        if (smallText != null && smallText.isNotEmpty) 'small_text': _clip(smallText, 128),
      },
      if (partySize != null && partySize > 0)
        'party': <String, Object?>{
          'id': 'cpredux_party_$pid',
          'size': <int>[partySize, partyMax ?? partySize],
        },
      if (buttons != null && buttons.isNotEmpty)
        'buttons': buttons.take(2).map((b) => <String, String>{
          'label': _clip(b['label'] ?? 'CPRedux', 32),
          'url': b['url'] ?? 'https://tia004.github.io/cpredux/',
        }).toList(),
    };

    _activity = activityData;

    if (!isConnected || _clientId != id) {
      _clientId = id;
      await _connect();
      return;
    }

    // Discord applica un limite di un aggiornamento al secondo e chiude la
    // connessione se lo si supera: senza questa guardia, due cambi ravvicinati
    // sconnetterebbero la presenza invece di aggiornarla.
    if (DateTime.now().difference(_lastUpdate) < const Duration(seconds: 1)) return;
    _sendActivity();
  }

  void Function(bool connected)? onConnectionChanged;

  Future<void> _connect() async {
    if (_connecting) return;
    _connecting = true;
    _disposeSocket();

    try {
      final Socket socket = await _openSocket();
      if (_clientId == null) {
        socket.destroy();
        return;
      }
      _socket = socket;
      _readBuffer.clear();
      socket.listen(
        _onSocketData,
        onError: (Object _) => _disposeSocket(),
        onDone: _disposeSocket,
        cancelOnError: true,
      );
      _send(<String, Object?>{'v': 1, 'client_id': _clientId ?? ''}, opcode: _opHandshake);
    } catch (_) {
      // Discord chiuso: si resta in silenzio e si riprovera' al prossimo
      // aggiornamento.
      _handshaken = false;
      _socket = null;
      if (_clientId != null) {
        onConnectionChanged?.call(false);
      }
    } finally {
      _connecting = false;
    }
  }

  void _onSocketData(List<int> chunk) {
    _readBuffer.add(chunk);
    while (true) {
      final Uint8List bytes = _readBuffer.toBytes();
      if (bytes.length < 8) break;
      final ByteData bd = ByteData.sublistView(bytes);
      final int opcode = bd.getInt32(0, Endian.little);
      final int length = bd.getInt32(4, Endian.little);
      if (bytes.length < 8 + length) break;

      final Uint8List payloadBytes = bytes.sublist(8, 8 + length);
      final Uint8List remaining = bytes.sublist(8 + length);
      _readBuffer.clear();
      if (remaining.isNotEmpty) {
        _readBuffer.add(remaining);
      }

      _handleIncomingFrame(opcode, payloadBytes);
    }
  }

  void _handleIncomingFrame(int opcode, Uint8List payload) {
    if (opcode == _opPing) {
      _sendRaw(payload, opcode: _opPong);
      return;
    }
    if (opcode == _opClose) {
      _disposeSocket();
      return;
    }
    if (opcode != _opFrame) return;

    try {
      final String jsonStr = utf8.decode(payload);
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, Object?>) {
        final Object? evt = decoded['evt'];
        final Object? cmd = decoded['cmd'];
        if (evt == 'READY' || cmd == 'DISPATCH') {
          _handshaken = true;
          final dynamic data = decoded['data'];
          if (data is Map<String, Object?>) {
            final dynamic user = data['user'];
            if (user is Map<String, Object?>) {
              final String? globalName = user['global_name'] as String?;
              final String? username = user['username'] as String?;
              _discordUsername = globalName ?? username;
            }
          }
          onConnectionChanged?.call(true);
          _sendActivity();
        }
      }
    } catch (_) {}
  }

  void _sendRaw(List<int> body, {required int opcode}) {
    final Socket? socket = _socket;
    if (socket == null) return;
    try {
      final BytesBuilder builder = BytesBuilder()
        ..add(_int32(opcode))
        ..add(_int32(body.length))
        ..add(body);
      socket.add(builder.takeBytes());
    } on SocketException {
      _disposeSocket();
    }
  }

  Future<Socket> _openSocket() async {
    final Duration timeout = const Duration(milliseconds: 500);

    if (Platform.isWindows) {
      for (int i = 0; i < _maxClients; i++) {
        try {
          return await Socket.connect(r'\\.\pipe\discord-ipc-' '$i', 0, timeout: timeout);
        } catch (_) {}
      }
      throw const SocketException('Nessun pipe Discord disponibile su Windows');
    }

    for (final String path in _unixSocketCandidates()) {
      if (await FileSystemEntity.type(path) == FileSystemEntityType.notFound) continue;
      try {
        return await Socket.connect(
          InternetAddress(path, type: InternetAddressType.unix),
          0,
          timeout: timeout,
        );
      } catch (_) {
        // Il file esiste ma nessuno ascolta (Discord rimane aperto senza RPC
        // attivo): si passa al candidato successivo.
      }
    }
    throw const SocketException('Nessun socket Discord disponibile');
  }

  /// Percorsi dei socket, dal piu' probabile al meno.
  ///
  /// Include la cartella temporanea di sistema (fondamentale su macOS), le variabili
  /// d'ambiente Unix standard e le sandbox Snap e Flatpak su Linux.
  static List<String> _unixSocketCandidates() {
    final Map<String, String> env = Platform.environment;
    final List<String> roots = <String>[
      Directory.systemTemp.path,
      if (env['TMPDIR'] != null) env['TMPDIR']!,
      if (env['XDG_RUNTIME_DIR'] != null) env['XDG_RUNTIME_DIR']!,
      if (env['TMP'] != null) env['TMP']!,
      '/tmp',
      if (env['HOME'] != null) '${env['HOME']}/.cache/discord',
      if (env['HOME'] != null) '${env['HOME']}/snap.discord',
      if (env['HOME'] != null) '${env['HOME']}/.var/app/com.discordapp.Discord',
    ];

    final Set<String> seen = <String>{};
    final List<String> candidates = <String>[];
    for (final String root in roots) {
      final String cleanRoot = root.endsWith('/') ? root.substring(0, root.length - 1) : root;
      for (int i = 0; i < _maxClients; i++) {
        final String candidate = '$cleanRoot/discord-ipc-$i';
        if (seen.add(candidate)) {
          candidates.add(candidate);
        }
      }
    }
    return candidates;
  }

  void _sendActivity() {
    final Map<String, Object?>? activity = _activity;
    if (activity == null || !_handshaken) return;
    _lastUpdate = DateTime.now();
    _send(<String, Object?>{
      'cmd': 'SET_ACTIVITY',
      'args': <String, Object?>{'pid': pid, 'activity': activity},
      'nonce': '${DateTime.now().microsecondsSinceEpoch}',
    }, opcode: _opFrame);
  }

  void _send(Map<String, Object?> payload, {required int opcode}) {
    _sendRaw(utf8.encode(jsonEncode(payload)), opcode: opcode);
  }

  List<int> _int32(int value) =>
      (ByteData(4)..setInt32(0, value, Endian.little)).buffer.asUint8List();

  static String _clip(String value, int max) =>
      value.length <= max ? value : '${value.substring(0, max - 1)}…';

  void _disposeSocket() {
    _handshaken = false;
    final Socket? socket = _socket;
    _socket = null;
    if (socket == null) return;
    try {
      socket.destroy();
    } catch (_) {
      // Gia' chiuso dal peer.
    }
  }

  /// Toglie la presenza e chiude il collegamento.
  Future<void> shutdown() async {
    _activity = null;
    _clientId = null;
    onConnectionChanged = null;
    _disposeSocket();
  }
}
