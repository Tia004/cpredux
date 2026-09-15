import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/domain/campaign.dart';
import 'package:cpredux/domain/gm/gm_rules.dart';
import 'package:cpredux/domain/map_token.dart';
import 'package:cpredux/domain/transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Il trasporto in tempo reale.
///
/// Questi test guardano la cosa che a un tavolo si scopre tardi e male: **dove
/// sara' il veicolo fra novanta secondi**. Un motore del movimento sbagliato non
/// lancia niente — il taxi si sposta, solo piu' piano o piu' veloce del dovuto,
/// e nessuno se ne accorge finche' una scena non finisce prima o dopo il momento
/// giusto. La matematica sta qui e si verifica in millisecondi.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_transport_test');
    AppPaths.overrideForTesting(
      config: temp.path,
      data: temp.path,
      documents: temp.path,
    );
  });

  tearDown(() {
    AppPaths.clearOverrides();
    SettingsStore.save(AppSettings());
    if (temp.existsSync()) {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  /// Un percorso largo un quarto di mappa: alla scala predefinita sono
  /// esattamente 3000 metri di linea d'aria.
  const RouteStop origine = RouteStop('Origine', Offset(0.25, 0.5));
  const RouteStop meta = RouteStop('Metà', Offset(0.5, 0.5));
  const RouteStop destinazione = RouteStop('Destinazione', Offset(0.75, 0.5));
  const double span = GmRules.transportMapSpanDefault;

  Transport taxi({
    List<RouteStop> stops = const <RouteStop>[origine, destinazione],
    double speed = 45,
    String id = 'trn-1',
  }) =>
      Transport(id: id, name: 'Taxi di Jig-Jig', mode: TransportMode.taxi, stops: stops, speedKmh: speed);

  group('La geometria del percorso', () {
    test('la lunghezza e\' la somma dei tratti, con l allungamento delle strade', () {
      final double straight = routeLengthMeters(
        const <RouteStop>[origine, destinazione],
        span,
        roadFactor: 1,
      );
      expect(straight, closeTo(0.5 * span, 0.001));

      final double real = routeLengthMeters(
        const <RouteStop>[origine, destinazione],
        span,
        roadFactor: 1.35,
      );
      expect(real, closeTo(straight * 1.35, 0.001));
    });

    test('un percorso con fermate intermedie e\' piu\' lungo della linea retta', () {
      final double direct = routeLengthMeters(const <RouteStop>[origine, destinazione], span, roadFactor: 1);
      final double through = routeLengthMeters(
        const <RouteStop>[origine, meta, destinazione],
        span,
        roadFactor: 1,
      );
      expect(through, closeTo(direct, 0.001), reason: 'le tre fermate sono sulla stessa retta');
    });

    test('a meta\' percorso il veicolo e\' a meta\' strada', () {
      final double total = routeLengthMeters(const <RouteStop>[origine, destinazione], span, roadFactor: 1);
      expect(positionAlong(const <RouteStop>[origine, destinazione], 0, span, roadFactor: 1), origine.position);
      expect(
        positionAlong(const <RouteStop>[origine, destinazione], total / 2, span, roadFactor: 1).dx,
        closeTo(0.5, 0.001),
      );
      expect(
        positionAlong(const <RouteStop>[origine, destinazione], total * 2, span, roadFactor: 1),
        destinazione.position,
        reason: 'oltre la fine resta all\'ultima fermata invece di proseguire nel vuoto',
      );
    });

    test('la direzione di marcia guarda verso dove si sta andando', () {
      final double east = headingAlong(const <RouteStop>[origine, destinazione], 100, span, roadFactor: 1);
      expect(east, closeTo(0, 0.001), reason: 'verso destra sono zero radianti');
    });

    test('un percorso di una fermata sola non e\' un errore', () {
      expect(routeLengthMeters(const <RouteStop>[origine], span), 0);
      expect(positionAlong(const <RouteStop>[origine], 500, span), origine.position);
      expect(headingAlong(const <RouteStop>[origine], 500, span), 0);
    });
  });

  group('Il movimento', () {
    test('dopo N secondi il veicolo ha fatto esattamente velocita\' per tempo', () {
      final Transport t = taxi();
      // 45 km/h = 12,5 m/s. Quaranta secondi veri, senza moltiplicatore.
      t.advance(const Duration(seconds: 40), mapSpanMeters: span, timeScale: 1);
      expect(t.progressMeters, closeTo(12.5 * 40, 1));
    });

    test('il moltiplicatore di tempo moltiplica la strada, non la velocita\' mostrata', () {
      final Transport t = taxi();
      t.advance(const Duration(seconds: 40), mapSpanMeters: span, timeScale: 12);
      expect(t.progressMeters, closeTo(12.5 * 40 * 12, 1));
      // E la velocita' resta quella vera: e' l'orologio a correre.
      expect(t.effectiveKmh, closeTo(45, 0.001));
    });

    test('un veicolo fermo non avanza e il fermo scende', () {
      final Transport t = taxi();
      t.halt('posto di blocco', hold: const Duration(seconds: 90));
      final TransportTick tick = t.advance(const Duration(seconds: 30), mapSpanMeters: span, timeScale: 12);

      expect(tick.movedMeters, 0);
      expect(tick.resumed, isFalse);
      expect(t.progressMeters, 0);
      expect(t.haltRemaining, const Duration(seconds: 60));
      expect(t.status, TransportStatus.fermo);
    });

    test('scaduto il fermo riparte, e il tempo avanzato non si perde', () {
      final Transport t = taxi();
      t.halt('ingorgo', hold: const Duration(seconds: 10));
      // Un battito da trenta secondi: dieci di fermo, venti di strada.
      final TransportTick tick = t.advance(const Duration(seconds: 30), mapSpanMeters: span, timeScale: 1);

      expect(tick.resumed, isTrue);
      expect(t.status, TransportStatus.inViaggio);
      expect(tick.movedMeters, closeTo(12.5 * 20, 1));
    });

    test('un fermo senza durata non riparte da solo', () {
      final Transport t = taxi();
      t.halt('agguato', incidentId: TransportIncidents.ambush.id);
      for (int i = 0; i < 100; i++) {
        t.advance(const Duration(seconds: 5), mapSpanMeters: span, timeScale: 12);
      }
      expect(t.status, TransportStatus.fermo);
      expect(t.progressMeters, 0);
    });

    test('arrivato all ultima fermata si ferma per sempre', () {
      final Transport t = taxi(stops: const <RouteStop>[origine, meta]);
      final double total = routeLengthMeters(t.stops, span);
      final TransportTick tick = t.advance(
        Duration(seconds: (total / 12.5).ceil() + 10),
        mapSpanMeters: span,
        timeScale: 1,
      );

      expect(tick.arrived, isTrue);
      expect(t.status, TransportStatus.arrivato);
      expect(t.position, meta.position);

      final TransportTick after = t.advance(const Duration(minutes: 5), mapSpanMeters: span, timeScale: 100);
      expect(after.movedMeters, 0);
      expect(after.arrived, isFalse);
    });

    test('il tempo di arrivo e\' quello che si aspetta al tavolo', () {
      final Transport t = taxi(stops: const <RouteStop>[origine, meta]);
      // Un quarto di mappa alla scala predefinita sono tremila metri di linea
      // d'aria, e con l'allungamento delle strade quattromilacinquanta.
      final double total = routeLengthMeters(t.stops, span);
      expect(total, closeTo(4050, 1));
      // 4050 metri a 12,5 m/s sono 324 secondi di strada; a dodici volte sono
      // ventisette secondi veri.
      expect(t.eta(span)!.inSeconds, closeTo(324, 2));
      expect(t.eta(span, timeScale: 12)!.inSeconds, closeTo(27, 2));
    });

    test('un passo a tempo zero non muove niente', () {
      final Transport t = taxi();
      expect(t.advance(Duration.zero, mapSpanMeters: span).movedMeters, 0);
      expect(t.progressMeters, 0);
    });
  });

  group('Gli eventi scatenabili', () {
    test('ogni evento ha un identificativo, un titolo e una riga per il registro', () {
      final Set<String> ids = <String>{};
      for (final TransportIncident i in TransportIncidents.all) {
        expect(i.id, isNotEmpty);
        expect(i.title, isNotEmpty);
        expect(i.description, isNotEmpty);
        expect(ids.add(i.id), isTrue, reason: 'l\'evento "${i.id}" e\' duplicato');
        expect(i.logLine, contains(i.title));
      }
      expect(TransportIncidents.all.length, greaterThanOrEqualTo(8));
    });

    test('gli eventi che si risolvono con una scena non hanno un cronometro', () {
      expect(TransportIncidents.ambush.holdUntilReleased, isTrue);
      expect(TransportIncidents.passengerStop.holdUntilReleased, isTrue);
      expect(TransportIncidents.checkpoint.holdUntilReleased, isFalse);
      expect(TransportIncidents.checkpoint.haltSeconds, 90);
    });

    test('un identificativo sconosciuto non e\' un errore', () {
      expect(TransportIncidents.byId('non-esiste'), isNull);
      expect(TransportIncidents.byId('agguato')?.title, 'Agguato');
    });
  });

  group('Il salvataggio', () {
    test('un veicolo si scrive e si rilegge identico', () {
      final Transport t = taxi();
      t.position = const Offset(0.4, 0.42);
      t.progressMeters = 1234;
      t.passengers = <String>['V', 'Jackie'];
      t.passengerTokenIds = <String>['tok-1', 'tok-2'];
      t.log.insert(0, 'Posto di blocco');
      t.halt('posto di blocco', hold: const Duration(seconds: 30), incidentId: 'posto-di-blocco', speedFactor: 0.75);

      final Transport back = Transport.fromJson(t.toJson());

      expect(back.id, t.id);
      expect(back.mode, t.mode);
      expect(back.stops.length, 2);
      expect(back.stops.last.name, 'Destinazione');
      expect(back.position.dx, closeTo(0.4, 0.0001));
      expect(back.progressMeters, closeTo(1234, 0.0001));
      expect(back.status, TransportStatus.fermo);
      expect(back.haltRemaining.inSeconds, 30);
      expect(back.lastIncidentId, 'posto-di-blocco');
      expect(back.speedFactor, closeTo(0.75, 0.0001));
      expect(back.passengers, <String>['V', 'Jackie']);
      expect(back.log.first, 'Posto di blocco');
    });

    test('un veicolo scritto da una versione che non conosceva i modi si apre lo stesso', () {
      final Transport back = Transport.fromJson(<String, Object?>{
        'id': 'trn-vecchio',
        'name': 'Furgone',
        'mode': 'carrozza',
        'stops': <Object?>[
          <String, Object?>{'name': 'Qui', 'x': 0.1, 'y': 0.1},
          <String, Object?>{'name': 'Là', 'x': 0.2, 'y': 0.2},
        ],
        'speedKmh': 'boh',
        'status': 'sconosciuto',
      });

      expect(back.mode, TransportMode.taxi);
      expect(back.status, TransportStatus.inViaggio);
      expect(back.stops, hasLength(2));
    });
  });

  group('Il veicolo dentro il tavolo', () {
    Future<AppState> withCampaign() async {
      final AppState state = AppState();
      await state.createCampaign(name: 'Night City', directory: temp.path);
      return state;
    }

    test('mettere in strada un taxi lo mette sulla mappa, alla prima fermata', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final Transport t = state.startTransport(
        name: 'Taxi per Corpo Plaza',
        mode: TransportMode.taxi,
        stops: const <RouteStop>[origine, meta],
        passengers: <String>['V'],
      );

      expect(state.mapTransports, hasLength(1));
      expect(state.transportsArePersisted, isTrue);
      expect(t.position, origine.position, reason: 'non deve comparire al centro della mappa');
      expect(state.sessionLog.first.delta, 'TRASPORTO');
      expect(state.sessionLog.first.description, contains('Taxi per Corpo Plaza'));
      expect(state.campaign?.transports, hasLength(1));
    });

    test('senza campagna il veicolo resta in memoria e non si finge che sia salvato', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      state.startTransport(name: 'Moto', mode: TransportMode.moto, stops: const <RouteStop>[origine, meta]);
      expect(state.mapTransports, hasLength(1));
      expect(state.transportsArePersisted, isFalse);
      expect(state.campaign, isNull);
    });

    test('i passeggeri si muovono con il veicolo', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final MapToken token = state
          .addTokens(tokens: <MapToken>[MapToken(id: '', name: 'V', x: 0.1, y: 0.9, hp: 40, maxHp: 40)])
          .single;

      state.startTransport(
        name: 'Taxi',
        stops: const <RouteStop>[origine, meta],
        passengerTokenIds: <String>[token.id],
        passengers: <String>['V'],
      );
      // Appena parte, il personaggio e' salito: il suo token e' alla partenza.
      expect(state.mapTokens.single.position, origine.position);

      state.advanceTransports(const Duration(seconds: 60));
      expect(
        state.mapTokens.single.position.dx,
        greaterThan(origine.position.dx),
        reason: 'il token deve viaggiare con il mezzo, non restare al punto di partenza',
      );
      expect(state.mapTokens.single.position, state.mapTransports.single.position);
    });

    test('l orologio non muove un veicolo fermato da un agguato', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final Transport t = state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Taxi');
      state.triggerTransportIncident(t.id, TransportIncidents.ambush);

      state.advanceTransports(const Duration(seconds: 30));
      expect(state.mapTransports.single.progressMeters, 0);
      expect(state.mapTransports.single.status, TransportStatus.fermo);

      // E il registro lo dice con le parole dell'evento, non con "veicolo fermo".
      expect(state.sessionLog.first.description, contains('Agguato'));
      expect(state.sessionLog.first.description, contains('prova di Concentrazione'));
      expect(state.sessionLog.first.description, contains('agisce per ultimo'));
    });

    test('scatenare un evento su un veicolo arrivato non fa niente', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final Transport t = state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Taxi');
      // Quattromilacinquanta metri a 150 m/s di tempo moltiplicato: ventisette
      // secondi veri. Sessanta bastano con margine.
      state.advanceTransports(const Duration(seconds: 60));
      expect(state.mapTransports.single.status, TransportStatus.arrivato);

      expect(state.triggerTransportIncident(t.id, TransportIncidents.crash), isFalse);
      expect(state.haltTransport(t.id), isFalse);
    });

    test('fermare e rilasciare a mano, senza un evento', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final Transport t = state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Taxi');
      expect(state.haltTransport(t.id, reason: 'il conducente vuole i soldi prima'), isTrue);
      expect(state.mapTransports.single.status, TransportStatus.fermo);
      expect(state.mapTransports.single.statLine, contains('soldi'));

      expect(state.resumeTransport(t.id), isTrue);
      expect(state.mapTransports.single.status, TransportStatus.inViaggio);
      expect(state.sessionLog.first.description, contains('ripartito'));
    });

    test('la velocita\' si corregge al tavolo senza toccare le regole', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final Transport t = state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Taxi');
      state.setTransportSpeed(t.id, 90);
      expect(state.mapTransports.single.speedKmh, 90);
      expect(state.mapTransports.single.mode.cruiseKmh, 45, reason: 'la regola del modo non cambia');
    });

    test('togliere un veicolo lo toglie dal tavolo e lo dice', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final Transport t = state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Taxi');
      state.removeTransport(t.id);

      expect(state.mapTransports, isEmpty);
      expect(state.campaign?.transports, isEmpty);
      expect(state.sessionLog.first.description, contains('tolto'));
    });

    test('clearTransports svuota la strada', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Uno');
      state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Due');
      state.clearTransports();
      expect(state.mapTransports, isEmpty);
    });

    test('senza veicoli l orologio non muove niente', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);
      expect(state.advanceTransports(const Duration(seconds: 10)), 0);
    });

    test('la scala della mappa cambia la distanza, e si puo\' correggere', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      expect(state.gmRuleBook.rule(GmRules.transportMapSpan).value, 12000);
      await state.setGmRule(GmRules.transportMapSpan.id, 24000);
      expect(state.gmRuleBook.rule(GmRules.transportMapSpan).value, 24000);
    });

    test('i trasporti sopravvivono al salvataggio della campagna', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      state.startTransport(
        name: 'Taxi di Viktor',
        mode: TransportMode.groundcar,
        stops: const <RouteStop>[origine, meta, destinazione],
        passengers: <String>['V'],
      );
      state.advanceTransports(const Duration(seconds: 5));

      final Campaign campaign = state.campaign!;
      final Campaign back = Campaign.fromJson(campaign.toJson());
      expect(back.transports, hasLength(1));
      expect(back.transports.single.name, 'Taxi di Viktor');
      expect(back.transports.single.mode, TransportMode.groundcar);
      expect(back.transports.single.stops, hasLength(3));
      expect(back.transports.single.passengers, <String>['V']);
    });

    test('un veicolo arrivato resta sulla mappa: e\' dove e\' finita la scena', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      state.startTransport(stops: const <RouteStop>[origine, meta], name: 'Taxi');
      state.advanceTransports(const Duration(seconds: 60));

      expect(state.mapTransports.single.status, TransportStatus.arrivato);
      expect(state.mapTransports, hasLength(1));
      expect(
        state.sessionLog.any((SessionEvent e) => e.description.contains('arrivato')),
        isTrue,
        reason: 'l\'arrivo e\' un fatto della serata e va nel registro',
      );
    });
  });
}
