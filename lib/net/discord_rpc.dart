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

  /// Discord apre fino a dieci socket, uno per istanza avviata.
  static const int _maxClients = 10;

  Socket? _socket;
  bool _handshaken = false;
  String? _clientId;
  Map<String, Object?>? _activity;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  bool _connecting = false;

  bool get isConnected => _handshaken && _socket != null;

  /// Collega (se serve) e imposta l'attivita'.
  ///
  /// Non solleva eccezioni: se Discord non e' aperto — il caso piu' comune —
  /// l'applicazione deve semplicemente non mostrare nulla.
  Future<void> update({
    required String clientId,
    required String details,
    required String state,
    String? startTimeIso,
  }) async {
    final String id = clientId.trim();
    if (id.isEmpty) {
      await shutdown();
      return;
    }

    _activity = <String, Object?>{
      'details': _clip(details, 128),
      'state': _clip(state, 128),
      'timestamps': <String, Object?>{
        'start': DateTime.tryParse(startTimeIso ?? '')?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
      },
      'assets': const <String, Object?>{
        'large_image': 'main',
        'large_text': 'Cyberpunk RED Visualizer',
      },
    };

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
      socket.listen(
        (_) {},
        onError: (Object _) => _disposeSocket(),
        onDone: _disposeSocket,
        cancelOnError: true,
      );
      _send(<String, Object?>{'v': 1, 'client_id': _clientId ?? ''}, opcode: _opHandshake);
      _handshaken = true;
      onConnectionChanged?.call(true);
      _sendActivity();
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
    final Socket? socket = _socket;
    if (socket == null) return;
    try {
      final List<int> body = utf8.encode(jsonEncode(payload));
      final BytesBuilder builder = BytesBuilder()
        ..add(_int32(opcode))
        ..add(_int32(body.length))
        ..add(body);
      socket.add(builder.takeBytes());
    } on SocketException {
      _disposeSocket();
    }
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
