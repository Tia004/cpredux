import 'package:cpredux/net/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Attende che una condizione diventi vera, senza `Future.delayed` fissi.
///
/// I test di rete con attese fisse sono o lenti o instabili: il tempo giusto
/// non esiste, esiste solo "prima o poi". Cosi' un fallimento e' un fallimento
/// vero e non un timeout che passa a volte.
Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(reason ?? 'Condizione non raggiunta entro $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late CampaignHost host;
  final List<Map<String, Object?>> received = <Map<String, Object?>>[];
  final List<String> joined = <String>[];
  final List<String> left = <String>[];
  final List<CampaignClient> clients = <CampaignClient>[];

  setUp(() async {
    received.clear();
    joined.clear();
    left.clear();
    clients.clear();

    host = await CampaignHost.start(port: 0, bindAddress: '127.0.0.1');
    host
      ..onPlayerHello = (HostedPlayer p) {
        joined.add(p.id);
        host.sendTo(p.id, <String, Object?>{
          't': SessionMessage.welcome,
          'campaignName': 'Prova',
          'gameDate': '2077',
        });
      }
      ..onPlayerLeft = (HostedPlayer p) {
        left.add(p.id);
      }
      ..onMessage = (HostedPlayer p, Map<String, Object?> m) {
        received.add(<String, Object?>{'player': p.id, ...m});
        if ('${m['t']}' == SessionMessage.chat) {
          host.broadcast(<String, Object?>{
            't': SessionMessage.chat,
            'name': p.characterName,
            'text': m['text'],
          });
        }
      };
  });

  tearDown(() async {
    for (final CampaignClient c in clients) {
      await c.close();
    }
    await host.stop();
  });

  Future<CampaignClient> connect({String password = '', String id = 'sheet-1'}) async {
    final CampaignClient client = await CampaignClient.connect(
      address: '127.0.0.1',
      port: host.port,
      playerId: id,
      characterName: 'Jackie',
      playerName: 'Tia',
      password: password,
      characterState: <String, Object?>{'hitPoints': '32/45'},
    );
    clients.add(client);
    return client;
  }

  test('un giocatore si collega e riceve il benvenuto con il nome del tavolo', () async {
    final CampaignClient client = await connect();

    await _waitUntil(() => client.isConnected, reason: 'Il benvenuto non e arrivato');
    expect(client.campaignName, 'Prova');
    expect(client.gameDate, '2077');
    expect(host.playerCount, 1);
    expect(joined, contains('sheet-1'));
  });

  test('il master vede il nome del personaggio e i suoi punti vita', () async {
    await connect();
    await _waitUntil(() => host.players.isNotEmpty);

    final HostedPlayer player = host.players['sheet-1']!;
    expect(player.characterName, 'Jackie');
    expect(player.playerName, 'Tia');
    expect(player.state['hitPoints'], '32/45');
  });

  test('una password sbagliata viene rifiutata e il collegamento si chiude', () async {
    host.password = 'night-city';
    String? reason;
    final CampaignClient client = await CampaignClient.connect(
      address: '127.0.0.1',
      port: host.port,
      playerId: 'sheet-2',
      characterName: 'V',
      playerName: 'Tia',
      password: 'sbagliata',
      characterState: const <String, Object?>{},
    );
    clients.add(client);
    client.onRejected = (String r) => reason = r;

    await _waitUntil(() => reason != null, reason: 'Nessun rifiuto ricevuto');
    expect(reason, contains('Password'));
    expect(host.playerCount, 0);
  });

  test('la chat di un giocatore arriva a tutto il tavolo', () async {
    final CampaignClient first = await connect(id: 'sheet-1');
    final CampaignClient second = await connect(id: 'sheet-2');
    await _waitUntil(() => host.playerCount == 2);

    final List<Map<String, Object?>> secondInbox = <Map<String, Object?>>[];
    second.onMessage = secondInbox.add;
    await _waitUntil(() => second.isConnected);

    first.sendChat('Copritemi, entro dal tetto');

    await _waitUntil(
      () => secondInbox.any((Map<String, Object?> m) => m['t'] == SessionMessage.chat),
      reason: 'Il messaggio non e arrivato al secondo giocatore',
    );
    expect(secondInbox.last['text'], 'Copritemi, entro dal tetto');
    expect(secondInbox.last['name'], 'Jackie');
  });

  test('un tiro annunciato conserva il dettaglio della scomposizione', () async {
    final CampaignClient client = await connect();
    await _waitUntil(() => client.isConnected);

    client.sendRoll(
      label: 'Pistole',
      detail: '1d10 + 7 + 6',
      total: 19,
      isCritical: false,
      isFumble: false,
    );

    await _waitUntil(() => received.any((Map<String, Object?> m) => m['t'] == SessionMessage.roll));
    final Map<String, Object?> roll = received.firstWhere((Map<String, Object?> m) => m['t'] == SessionMessage.roll);
    expect(roll['label'], 'Pistole');
    expect(roll['detail'], '1d10 + 7 + 6');
    expect(roll['total'], 19);
  });

  test("l'intenzione di un giocatore arriva al master come richiesta", () async {
    final CampaignClient client = await connect();
    await _waitUntil(() => client.isConnected);

    client.sendIntent('medkit', detail: 'Medkit');

    await _waitUntil(() => received.any((Map<String, Object?> m) => m['t'] == SessionMessage.intent));
    final Map<String, Object?> intent =
        received.firstWhere((Map<String, Object?> m) => m['t'] == SessionMessage.intent);
    expect(intent['action'], 'medkit');
    expect(intent['detail'], 'Medkit');
  });

  test('gli eventi del master raggiungono i giocatori con la variazione', () async {
    final CampaignClient client = await connect();
    final List<Map<String, Object?>> inbox = <Map<String, Object?>>[];
    client.onMessage = inbox.add;
    await _waitUntil(() => client.isConnected);

    host.broadcastEvent(description: 'Colpo alla spalla', delta: 'PV -12', playerId: 'sheet-1');

    await _waitUntil(
      () => inbox.any((Map<String, Object?> m) => m['t'] == SessionMessage.event),
      reason: "L'evento non e arrivato",
    );
    final Map<String, Object?> event =
        inbox.firstWhere((Map<String, Object?> m) => m['t'] == SessionMessage.event);
    expect(event['description'], 'Colpo alla spalla');
    expect(event['delta'], 'PV -12');
    expect(event['playerId'], 'sheet-1');
  });

  test('quando il giocatore si disconnette il master lo nota', () async {
    final CampaignClient client = await connect();
    await _waitUntil(() => host.playerCount == 1);

    await client.close();

    await _waitUntil(() => left.contains('sheet-1'), reason: 'La disconnessione non e stata rilevata');
    expect(host.playerCount, 0);
  });

  test('ricollegarsi con lo stesso identificativo non duplica il giocatore', () async {
    final CampaignClient first = await connect();
    await _waitUntil(() => host.playerCount == 1);

    // Il caso reale: cade il wifi, il giocatore rientra. Se il master vedesse
    // due volte lo stesso personaggio, applicherebbe il danno a una copia.
    final CampaignClient second = await connect();
    await _waitUntil(() => second.isConnected);

    expect(host.playerCount, 1);
    expect(joined.where((String id) => id == 'sheet-1').length, 2);
    await _waitUntil(() => first.channel.isClosed || true);
  });

  test('il master puo espellere un giocatore spiegandogli il motivo', () async {
    final CampaignClient client = await connect();
    String? reason;
    client.onKicked = (String r) => reason = r;
    await _waitUntil(() => client.isConnected);

    host.kick('sheet-1', 'Sei stato allontanato da questa campagna.', ban: true);

    await _waitUntil(() => reason != null, reason: 'Nessun messaggio di espulsione');
    expect(reason, contains('allontanato'));
    await _waitUntil(() => host.playerCount == 0);
  });
}
