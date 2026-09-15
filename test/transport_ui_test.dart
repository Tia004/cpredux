import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/map_token.dart';
import 'package:cpredux/domain/transport.dart';
import 'package:cpredux/features/gm/gm_screen.dart';
import 'package:cpredux/features/map/map_canvas.dart';
import 'package:cpredux/features/map/map_section.dart';
import 'package:cpredux/features/map/night_city_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// I trasporti visti dalla console e dalla mappa.
///
/// Il motore e' verificato in `transport_test.dart`. Qui si verifica la cosa che
/// il motore non puo' garantire: che i **pulsanti siano collegati** a quel
/// motore, e che il disegno riceva davvero i veicoli. Un pannello che mostra un
/// taxi e non lo muove, o che mostra gli eventi e non li scatena, e' la forma
/// di difetto piu' costosa di questa applicazione: non lancia niente, e il
/// Master se ne accorge a meta' sessione.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_transport_ui_test');
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

  /// Smonta l'albero **dopo aver fermato l'orologio dei trasporti**.
  ///
  /// L'ordine conta: l'orologio e' un `Timer.periodic` vero, e il framework di
  /// test rifiuta di chiudere un test con un timer ancora pendente. Fermarlo
  /// prima dell'ultimo `pump` e' anche la cosa giusta da verificare — se
  /// `clearTransports` non spegnesse l'orologio, l'applicazione resterebbe
  /// sveglia ogni cento millisecondi a tavolo fermo, e questo test lo
  /// scoprirebbe.
  Future<void> disposeTree(WidgetTester tester, AppState state) async {
    state.clearTransports();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 900));
  }

  /// Un tavolo con due fermate e un personaggio sulla mappa.
  Future<AppState> tableWithRoute() async {
    final AppState state = AppState();
    await state.createCampaign(name: 'Night City', directory: temp.path);
    state.addWaypoint(label: 'Afterlife', position: const Offset(0.3, 0.5));
    state.addWaypoint(label: 'Corpo Plaza', position: const Offset(0.6, 0.5));
    state.addTokens(tokens: <MapToken>[MapToken(id: '', name: 'V', x: 0.2, y: 0.2, hp: 40, maxHp: 40)]);
    return state;
  }

  Future<void> pumpConsole(WidgetTester tester, AppState state, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: CprTheme.dark(),
          home: const Scaffold(body: GmScreen()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));

    // Il pannello si apre sullo strumento dei dadi: si passa ai trasporti.
    final Finder tool = find.text(GmTool.trasporti.label);
    await tester.ensureVisible(tool);
    await tester.tap(tool);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Preme un pulsante per la sua etichetta.
  ///
  /// In maiuscolo perche' `TechButton` la trasforma da sola, e il percorso delle
  /// fermate antepone il numero d'ordine quando sono scelte: qui si cercano
  /// solo le etichette non ancora scelte, quindi senza numero.
  Future<void> tap(WidgetTester tester, String label) async {
    final Finder finder = find.text(label.toUpperCase());
    expect(finder, findsWidgets, reason: 'il pulsante "$label" non c\'è');
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 250));
  }

  for (final ({String name, Size size}) window in <({String name, Size size})>[
    (name: 'Desktop (1920x1080)', size: Size(1920, 1080)),
    (name: 'Compatto (800x600)', size: Size(800, 600)),
  ]) {
    testWidgets('la sezione dei trasporti si disegna a ${window.name}', (WidgetTester tester) async {
      final AppState state = await tableWithRoute();
      addTearDown(state.dispose);

      await pumpConsole(tester, state, window.size);

      expect(find.text('TRASPORTI IN TEMPO REALE'), findsWidgets);
      expect(find.text('Metti in strada'.toUpperCase()), findsOneWidget);
      // Senza percorso non si parte: il pulsante dice perche' e non finge.
      expect(tester.takeException(), isNull);

      await disposeTree(tester, state);
    });
  }

  testWidgets('il percorso si compone dalle fermate e il veicolo parte', (WidgetTester tester) async {
    final AppState state = await tableWithRoute();
    addTearDown(state.dispose);

    await pumpConsole(tester, state, const Size(1280, 1000));

    await tap(tester, 'Afterlife');
    await tap(tester, 'Corpo Plaza');
    await tap(tester, 'V'); // sale a bordo
    await tap(tester, 'METTI IN STRADA');

    expect(state.mapTransports, hasLength(1));
    final Transport t = state.mapTransports.single;
    expect(t.stops.map((RouteStop s) => s.name), <String>['Afterlife', 'Corpo Plaza']);
    expect(t.passengers, <String>['V']);
    expect(t.passengerTokenIds, hasLength(1));
    // Parte dalla prima fermata, non dal centro della mappa. Le coordinate si
    // confrontano con una tolleranza perche' l'orologio ha gia' battuto mentre
    // il test premeva i pulsanti: pretendere l'uguaglianza esatta vorrebbe dire
    // pretendere che il tempo si sia fermato durante il test.
    expect(t.position.dx, closeTo(0.3, 0.02), reason: 'parte dalla prima fermata');
    expect(t.position.dy, closeTo(0.5, 0.01));

    // Il personaggio e' salito: il suo token viaggia con il mezzo.
    expect(state.mapTokens.single.position, t.position);

    await disposeTree(tester, state);
  });

  testWidgets('dalla console si scatena un evento e il veicolo si ferma', (WidgetTester tester) async {
    final AppState state = await tableWithRoute();
    addTearDown(state.dispose);

    await pumpConsole(tester, state, const Size(1280, 1000));
    await tap(tester, 'Afterlife');
    await tap(tester, 'Corpo Plaza');
    await tap(tester, 'METTI IN STRADA');

    // Il veicolo e' selezionato appena parte: la sezione degli eventi e' li'.
    await tap(tester, 'Posto di blocco');

    expect(state.mapTransports.single.status, TransportStatus.fermo);
    expect(state.mapTransports.single.lastIncidentId, 'posto-di-blocco');
    expect(state.mapTransports.single.haltRemaining.inSeconds, 90);
    expect(state.mapTransports.single.statLine, contains('Posto di blocco'));

    // E il registro porta la scena, non "veicolo fermo".
    expect(state.sessionLog.first.description, contains('Posto di blocco'));
    expect(state.sessionLog.first.description, contains('bagagliaio'));

    // Il fermo tiene: l'orologio non lo muove. Non si pretende che il veicolo
    // sia a zero metri — ha viaggiato mentre il test premeva i pulsanti — ma
    // che da adesso non si muova piu'.
    final double atStop = state.mapTransports.single.progressMeters;
    state.advanceTransports(const Duration(seconds: 30));
    expect(state.mapTransports.single.progressMeters, atStop);

    await disposeTree(tester, state);
  });

  testWidgets('un fermo senza scadenza ha il pulsante per rilasciarlo', (WidgetTester tester) async {
    final AppState state = await tableWithRoute();
    addTearDown(state.dispose);

    await pumpConsole(tester, state, const Size(1280, 1000));
    await tap(tester, 'Afterlife');
    await tap(tester, 'Corpo Plaza');
    await tap(tester, 'METTI IN STRADA');
    await tap(tester, 'Agguato');

    expect(state.mapTransports.single.status, TransportStatus.fermo);
    expect(state.mapTransports.single.haltRemaining, Duration.zero);
    expect(state.mapTransports.single.isHeld, isTrue);

    // Il dialogo dell'evento va chiuso: sta sopra la console, ed e' giusto che
    // ci stia — racconta cosa e' successo e cosa rischia il tavolo.
    await tap(tester, 'Chiudi');
    await tap(tester, 'Rilascia');
    expect(state.mapTransports.single.status, TransportStatus.inViaggio);

    // E l'orologio riparte con lui: da qui in avanti si muove di nuovo.
    final double atRelease = state.mapTransports.single.progressMeters;
    state.advanceTransports(const Duration(seconds: 10));
    expect(state.mapTransports.single.progressMeters, greaterThan(atRelease));

    await disposeTree(tester, state);
  });

  testWidgets('la mappa riceve i veicoli e li disegna', (WidgetTester tester) async {
    final AppState state = await tableWithRoute();
    addTearDown(state.dispose);

    state.startTransport(
      name: 'Taxi di Jig-Jig',
      stops: const <RouteStop>[
        RouteStop('Afterlife', Offset(0.3, 0.5)),
        RouteStop('Corpo Plaza', Offset(0.6, 0.5)),
      ],
    );
    state.advanceTransports(const Duration(seconds: 5));

    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: CprTheme.dark(),
          home: const Scaffold(body: SingleChildScrollView(child: MapSection(asGameMaster: true))),
        ),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.byType(MapCanvas), findsOneWidget);
    final NightCityPainter painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((CustomPaint c) => c.painter)
        .whereType<NightCityPainter>()
        .first;
    expect(painter.transports, hasLength(1), reason: 'la mappa non ha ricevuto il veicolo');
    expect(painter.transports.single.name, 'Taxi di Jig-Jig');
    expect(painter.transports.single.x, greaterThan(0.3), reason: 'il veicolo deve essersi mosso');

    // E la lista della sezione mappa lo mostra con il suo tempo di arrivo.
    expect(find.text('IN STRADA'), findsOneWidget);
    expect(find.text('Taxi di Jig-Jig'), findsWidgets);
    expect(tester.takeException(), isNull);

    await disposeTree(tester, state);
  });
}
