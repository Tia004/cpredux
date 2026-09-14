import 'dart:convert';
import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/campaign.dart';
import 'package:cpredux/domain/night_city.dart';
import 'package:cpredux/domain/world_map.dart';
import 'package:cpredux/features/map/map_canvas.dart';
import 'package:cpredux/features/map/map_geometry.dart';
import 'package:cpredux/features/map/map_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 6),
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
  // --- Geometria -----------------------------------------------------------

  group('geometria di Night City', () {
    test('tutti i punti stanno dentro la mappa e i distretti hanno un nome', () {
      // Un vertice fuori scala non fa fallire niente: disegna semplicemente un
      // distretto fuori dallo schermo, e ce se ne accorge solo guardando.
      expect(NightCity.validate(), isEmpty);
    });

    test('i distretti non hanno identificativi duplicati', () {
      final Set<String> ids = <String>{};
      for (final MapDistrict d in NightCity.districts) {
        expect(ids.add(d.id), isTrue, reason: 'Distretto ripetuto: ${d.id}');
      }
      expect(ids.length, greaterThanOrEqualTo(7));
    });

    test("l'etichetta di un distretto cade dentro il distretto", () {
      for (final MapDistrict d in NightCity.districts) {
        final Offset at = NightCity.labelPosition(d);
        bool inside = false;
        for (int i = 0, j = d.border.length - 1; i < d.border.length; j = i++) {
          final Offset a = d.border[i];
          final Offset b = d.border[j];
          if ((a.dy > at.dy) != (b.dy > at.dy) &&
              at.dx < (b.dx - a.dx) * (at.dy - a.dy) / (b.dy - a.dy) + a.dx) {
            inside = !inside;
          }
        }
        expect(inside, isTrue, reason: 'Il nome di ${d.name} finirebbe fuori dal distretto');
      }
    });
  });

  group('conversione di coordinate', () {
    test('il rettangolo della mappa e quadrato anche in una finestra larga', () {
      final Rect rect = mapRectIn(const Size(1200, 500));
      expect(rect.width, closeTo(rect.height, 0.001));
    });

    test('andata e ritorno fra coordinate mappa e canvas non perde nulla', () {
      final Rect rect = mapRectIn(const Size(800, 600));
      const Offset original = Offset(0.42, 0.77);
      final Offset back = localToMap(mapToLocal(original, rect), rect);
      expect(back.dx, closeTo(original.dx, 1e-9));
      expect(back.dy, closeTo(original.dy, 1e-9));
    });

    test('un clic fuori dalla mappa non viene arrotondato dentro', () {
      // Saturebbe a 0 o a 1, e "ho cliccato fuori" diventerebbe indistinguibile
      // da "ho cliccato sull'angolo".
      final Rect rect = mapRectIn(const Size(600, 600));
      final Offset outside = localToMap(const Offset(-50, 300), rect);
      expect(isInsideMap(outside), isFalse);
    });
  });

  // --- Modello -------------------------------------------------------------

  group('waypoint', () {
    test('sopravvive al giro completo di serializzazione', () {
      final MapWaypoint w = MapWaypoint(
        id: 'wp-1',
        label: 'Imboscata',
        note: 'Sotto il ponte, due sentinelle',
        x: 0.31,
        y: 0.78,
        kind: WaypointKind.danger,
        visibility: WaypointVisibility.private,
        status: WaypointStatus.proposed,
        authorId: 'master',
        authorName: 'Master',
        createdAt: '2077-01-01',
      );

      final MapWaypoint back = MapWaypoint.fromJson(w.toJson());
      expect(back.id, 'wp-1');
      expect(back.label, 'Imboscata');
      expect(back.note, 'Sotto il ponte, due sentinelle');
      expect(back.kind, WaypointKind.danger);
      expect(back.visibility, WaypointVisibility.private);
      expect(back.status, WaypointStatus.proposed);
      expect(back.x, closeTo(0.31, 1e-9));
      expect(back.y, closeTo(0.78, 1e-9));
    });

    test('un file incompleto non fa esplodere la lettura', () {
      final MapWaypoint w = MapWaypoint.fromJson(<String, Object?>{
        'id': 'wp-2',
        'label': 'Bo',
      });
      expect(w.label, 'Bo');
      expect(w.kind, WaypointKind.location);
      expect(w.visibility, WaypointVisibility.table);
      expect(w.status, WaypointStatus.accepted);
      expect(w.x, 0);
    });

    test('una coordinata fuori scala viene riportata dentro', () {
      // Puo' arrivare da un file modificato a mano: un waypoint a x=4,2 sarebbe
      // invisibile e nessuno capirebbe perche'.
      final MapWaypoint w = MapWaypoint.fromJson(<String, Object?>{
        'id': 'wp-3',
        'label': 'Fuori',
        'x': 4.2,
        'y': -3,
      });
      expect(w.x, 1);
      expect(w.y, 0);
    });

    test('solo i waypoint condivisi sono pubblicabili', () {
      final MapWaypoint privato = MapWaypoint(
        id: 'a',
        label: 'Preparazione',
        x: 0.1,
        y: 0.1,
        visibility: WaypointVisibility.private,
      );
      final MapWaypoint pubblico =
          MapWaypoint(id: 'b', label: 'Bar', x: 0.2, y: 0.2);

      expect(privato.isShareable, isFalse);
      expect(pubblico.isShareable, isTrue);
    });
  });

  group('sfondo importato', () {
    test('quattro angoli incompleti tornano al rettangolo pieno', () {
      final MapBackground bg = MapBackground.fromJson(<String, Object?>{
        'imagePath': 'mappa.png',
        'corners': <Object?>[
          <String, Object?>{'x': 0.1, 'y': 0.1},
        ],
      });
      expect(bg.corners.length, 4);
      expect(bg.corners.first, const Offset(0, 0));
      expect(bg.corners[2], const Offset(1, 1));
      expect(bg.corners.last, const Offset(0, 1));
    });

    test('gli angoli scelti sopravvivono al salvataggio', () {
      final MapBackground bg = MapBackground(
        imagePath: 'night-city-scan.jpg',
        corners: <Offset>[
          const Offset(0.05, 0.02),
          const Offset(0.98, 0.07),
          const Offset(0.94, 0.99),
          const Offset(0.03, 0.95),
        ],
        opacity: 0.6,
      );

      final MapBackground back = MapBackground.fromJson(bg.toJson());
      expect(back.imagePath, 'night-city-scan.jpg');
      expect(back.corners[1].dx, closeTo(0.98, 1e-9));
      expect(back.opacity, closeTo(0.6, 1e-9));
    });
  });

  group('la campagna porta la mappa', () {
    test('una campagna salvata prima della mappa si apre lo stesso', () {
      final Campaign c = Campaign.fromJson(<String, Object?>{
        'meta': <String, Object?>{'id': 'c1', 'name': 'Prova', 'kind': 'campaign'},
        'players': <Object?>[],
      });
      expect(c.waypoints, isEmpty);
      expect(c.mapStyle, MapStyle.digital);
      expect(c.mapBackground.hasImage, isFalse);
    });

    test('waypoint, aspetto e sfondo fanno il giro completo', () {
      final Campaign c = Campaign.fromJson(<String, Object?>{
        'meta': <String, Object?>{'id': 'c1', 'name': 'Prova', 'kind': 'campaign'},
        'mapStyle': 'realistic',
        'mapBackground': <String, Object?>{'imagePath': 'x.png', 'opacity': 0.4},
        'waypoints': <Object?>[
          MapWaypoint(
            id: 'wp-1',
            label: 'Dopolavoro',
            x: 0.4,
            y: 0.6,
            visibility: WaypointVisibility.private,
          ).toJson(),
        ],
      });

      expect(c.mapStyle, MapStyle.realistic);
      expect(c.mapBackground.imagePath, 'x.png');
      expect(c.waypoints.single.label, 'Dopolavoro');
      expect(c.waypoints.single.visibility, WaypointVisibility.private);
    });
  });

  // --- Il tavolo vero ------------------------------------------------------

  group('mappa condivisa al tavolo', () {
    late Directory temp;
    late Directory masterDocs;
    late Directory playerDocs;
    late AppState master;
    late AppState player;
    late AppState lateJoiner;

    setUp(() async {
      temp = Directory.systemTemp.createTempSync('cpredux_map_test');
      masterDocs = Directory(p.join(temp.path, 'master'))..createSync(recursive: true);
      playerDocs = Directory(p.join(temp.path, 'giocatori'))..createSync(recursive: true);
      AppPaths.overrideForTesting(config: temp.path, data: temp.path);

      master = AppState();
      player = AppState();
      lateJoiner = AppState();

      await master.createCampaign(name: 'Night City', directory: masterDocs.path);
      await player.createSheet(name: 'Jackie', directory: playerDocs.path);
      await lateJoiner.createSheet(name: 'V', directory: playerDocs.path);

      await master.startHosting(port: 0);
      await player.joinSession(address: '127.0.0.1', port: master.campaign!.port);
      await _waitUntil(() => player.isJoined, reason: 'Il giocatore non si e collegato');
    });

    tearDown(() async {
      master.dispose();
      player.dispose();
      lateJoiner.dispose();
      AppPaths.clearOverrides();
      SettingsStore.save(AppSettings());
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('un waypoint del master arriva al giocatore', () async {
      master.addWaypoint(
        label: 'Mercato di Kabuki',
        position: const Offset(0.44, 0.24),
        kind: WaypointKind.shop,
      );

      await _waitUntil(
        () => player.mapWaypoints.any((MapWaypoint w) => w.label == 'Mercato di Kabuki'),
        reason: 'Il waypoint non e arrivato al giocatore',
      );
      final MapWaypoint seen =
          player.mapWaypoints.firstWhere((MapWaypoint w) => w.label == 'Mercato di Kabuki');
      expect(seen.kind, WaypointKind.shop);
      expect(seen.status, WaypointStatus.accepted);
      expect(seen.visibility, WaypointVisibility.table);
    });

    test('un waypoint privato non lascia mai la macchina del master', () async {
      master.addWaypoint(label: 'Base dei nomadi', position: const Offset(0.8, 0.8));

      master.addWaypoint(
        label: 'Imboscata preparata',
        position: const Offset(0.2, 0.3),
        kind: WaypointKind.danger,
        visibility: WaypointVisibility.private,
      );

      // Il segno di controllo e' un **altro** waypoint del tavolo: quando il
      // secondo condiviso arriva, il primo c'e' per forza, e l'assenza di quello
      // privato diventa un'affermazione vera invece di un'attesa troppo corta.
      master.addWaypoint(label: 'Dopolavoro', position: const Offset(0.6, 0.5));
      await _waitUntil(
        () => player.mapWaypoints.any((MapWaypoint w) => w.label == 'Dopolavoro'),
        reason: 'La mappa del tavolo non e arrivata al giocatore',
      );

      expect(
        player.mapWaypoints.map((MapWaypoint w) => w.label).toList(),
        <String>['Base dei nomadi', 'Dopolavoro'],
        reason: 'Una posizione privata e finita sulla mappa del giocatore',
      );
      expect(master.mapWaypoints.length, 3);
      expect(master.privateWaypointCount, 1);
      expect(master.sharedWaypoints.length, 2);
    });

    test('chi rientra a meta serata riceve la mappa gia fatta', () async {
      master.addWaypoint(label: 'Dopolavoro', position: const Offset(0.4, 0.6));
      master.addWaypoint(
        label: 'Trappola',
        position: const Offset(0.7, 0.2),
        visibility: WaypointVisibility.private,
      );
      await _waitUntil(() => player.mapWaypoints.length == 1);

      await lateJoiner.joinSession(address: '127.0.0.1', port: master.campaign!.port);
      await _waitUntil(() => lateJoiner.isJoined);
      await _waitUntil(
        () => lateJoiner.mapWaypoints.any((MapWaypoint w) => w.label == 'Dopolavoro'),
        reason: 'La mappa non e arrivata al secondo giocatore',
      );

      expect(lateJoiner.mapWaypoints.length, 1);
      expect(lateJoiner.mapWaypoints.single.label, 'Dopolavoro');
    });

    test('il waypoint di un giocatore e una proposta, e non va agli altri', () async {
      await lateJoiner.joinSession(address: '127.0.0.1', port: master.campaign!.port);
      await _waitUntil(() => lateJoiner.isJoined);

      player.addWaypoint(
        label: 'Tetto di Vik',
        position: const Offset(0.35, 0.42),
        kind: WaypointKind.person,
      );

      // Il giocatore lo vede subito: e' suo.
      expect(player.mapWaypoints.single.status, WaypointStatus.proposed);

      await _waitUntil(
        () => master.mapProposals.any((MapWaypoint w) => w.label == 'Tetto di Vik'),
        reason: 'La proposta non e arrivata al master',
      );

      // Il terzo giocatore non sa nemmeno che esiste.
      master.masterChat('Controllo');
      await _waitUntil(() => lateJoiner.sessionLog.isNotEmpty);
      expect(
        lateJoiner.mapWaypoints.any((MapWaypoint w) => w.label == 'Tetto di Vik'),
        isFalse,
        reason: 'Una proposta non accettata e finita sulla mappa di tutti',
      );

      // Il master accetta: adesso si.
      master.masterAcceptWaypoint(master.mapProposals.single.id);
      await _waitUntil(
        () => player.mapWaypoints.isNotEmpty && player.mapWaypoints.single.status == WaypointStatus.accepted,
        reason: 'Lo stato della proposta non si e aggiornato sul giocatore',
      );
      await _waitUntil(
        () => lateJoiner.mapWaypoints.any((MapWaypoint w) => w.label == 'Tetto di Vik'),
        reason: 'La condivisione non e stata trasmessa',
      );
      expect(player.mapWaypoints.single.status, WaypointStatus.accepted);
    });

    test('una proposta rifiutata sparisce anche da chi l\'ha messa', () async {
      player.addWaypoint(label: 'Scorciatoia', position: const Offset(0.5, 0.5));
      await _waitUntil(() => master.mapProposals.length == 1);

      master.masterRejectWaypoint(master.mapProposals.single.id);

      await _waitUntil(
        () => player.mapWaypoints.isEmpty,
        reason: 'La proposta rifiutata e rimasta sulla mappa del giocatore',
      );
      expect(master.mapProposals, isEmpty);
    });

    test('un giocatore non puo cancellare la mappa di un altro', () async {
      await lateJoiner.joinSession(address: '127.0.0.1', port: master.campaign!.port);
      await _waitUntil(() => lateJoiner.isJoined);

      master.addWaypoint(label: 'Dopolavoro', position: const Offset(0.4, 0.6));
      await _waitUntil(() => lateJoiner.mapWaypoints.length == 1);
      final String id = lateJoiner.mapWaypoints.single.id;

      // Un client ostile manda la rimozione di un waypoint che non e' suo.
      lateJoiner.deleteWaypoint(id);
      player.deleteWaypoint(id);

      master.masterChat('Controllo');
      await _waitUntil(() => player.sessionLog.any((dynamic e) => '${e.description}' == 'Controllo'));

      expect(
        master.mapWaypoints.any((MapWaypoint w) => w.label == 'Dopolavoro'),
        isTrue,
        reason: 'Un giocatore e riuscito a cancellare un waypoint del tavolo',
      );
    });

    test('con la password sbagliata non si e mai "in sessione"', () async {
      // Il difetto che questo test blocca: `isJoined` era vero appena il socket
      // si apriva, prima che il master rispondesse. La schermata diceva "in
      // sessione" a chi aveva sbagliato la password, e tutto cio' che veniva
      // trasmesso in quella finestra spariva senza avviso — perche' il master
      // non aveva ancora registrato il giocatore.
      await master.stopHosting();
      master.mutateCampaign((Campaign c) => c.password = 'night-city');
      await master.startHosting(port: 0);

      final AppState intruder = AppState();
      addTearDown(intruder.dispose);
      await intruder.createSheet(name: 'Intruso', directory: playerDocs.path);
      await intruder.joinSession(
        address: '127.0.0.1',
        port: master.campaign!.port,
        password: 'sbagliata',
      );

      await _waitUntil(
        () => intruder.sessionError != null,
        reason: 'Il rifiuto non e arrivato',
      );
      expect(intruder.isJoined, isFalse);
      expect(intruder.sessionError, contains('Password'));
    });

    test('il master trasmette solo a chi ha accettato', () async {
      // Il collegamento e' aperto (il socket c'e') ma il tavolo deve ancora
      // rispondere: in quella finestra il master non deve poter mandare nulla,
      // perche' il giocatore non e' ancora suo.
      final AppState arriving = AppState();
      addTearDown(arriving.dispose);
      await arriving.createSheet(name: 'In arrivo', directory: playerDocs.path);

      await arriving.joinSession(address: '127.0.0.1', port: master.campaign!.port);
      expect(arriving.isJoined, isFalse, reason: 'Accettato prima della risposta del master');

      await _waitUntil(() => arriving.isJoined);
      master.addWaypoint(label: 'Punto di ritrovo', position: const Offset(0.3, 0.7));
      await _waitUntil(
        () => arriving.mapWaypoints.any((MapWaypoint w) => w.label == 'Punto di ritrovo'),
        reason: 'Accettato ma non raggiunto',
      );
    });

    test('l\'aspetto scelto dal master vale per tutto il tavolo', () async {
      expect(player.mapStyle, MapStyle.digital);

      master.setMapStyle(MapStyle.realistic);

      await _waitUntil(
        () => player.mapStyle == MapStyle.realistic,
        reason: "L'aspetto non e stato trasmesso",
      );
    });

    test('rendere privato un waypoint lo toglie dal tavolo', () async {
      master.addWaypoint(label: 'Rifugio', position: const Offset(0.6, 0.3));
      await _waitUntil(() => player.mapWaypoints.length == 1);

      master.updateWaypoint(
        master.mapWaypoints.single.id,
        visibility: WaypointVisibility.private,
      );

      await _waitUntil(
        () => player.mapWaypoints.isEmpty,
        reason: 'Il waypoint reso privato e rimasto sul tavolo',
      );
      expect(master.mapWaypoints.length, 1);
    });

    test('chiudendo il tavolo la mappa del giocatore si svuota', () async {
      master.addWaypoint(label: 'Dopolavoro', position: const Offset(0.4, 0.6));
      await _waitUntil(() => player.mapWaypoints.length == 1);

      await master.stopHosting();

      await _waitUntil(
        () => player.mapWaypoints.isEmpty,
        reason: 'Il giocatore e rimasto attaccato alla mappa di un tavolo chiuso',
      );
    });
  });

  // --- La sezione disegnata ------------------------------------------------
  //
  // Il painter non e' mai stato eseguito finche' non lo si disegna davvero:
  // una coordinata sbagliata o un'API usata male non le vede nessun analizzatore
  // statico, si vedono solo guardando lo schermo.

  group('sezione mappa', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('cpredux_map_widget');
      AppPaths.overrideForTesting(config: temp.path, data: temp.path);
    });

    tearDown(() {
      AppPaths.clearOverrides();
      SettingsStore.save(AppSettings());
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<AppState> openMap(
      WidgetTester tester, {
      required bool asGameMaster,
    }) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      if (asGameMaster) {
        await state.createCampaign(name: 'Tavolo', directory: temp.path);
      } else {
        await state.createSheet(name: 'Prova', directory: temp.path);
      }

      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: Scaffold(body: MapSection(asGameMaster: asGameMaster)),
          ),
        ),
      );
      // Niente `pumpAndSettle`: la mappa ha un'animazione che si ripete, e
      // aspettare che "tutto si fermi" non finirebbe mai.
      await tester.pump(const Duration(milliseconds: 400));
      return state;
    }

    Future<void> closeTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
    }

    /// Fa scorrere qualche fotogramma.
    ///
    /// Il caricamento di un'immagine parte da un `addPostFrameCallback` e
    /// finisce un microtask dopo: un solo `pump` non basta a vederne il
    /// risultato, e un `pumpAndSettle` non tornerebbe mai per via
    /// dell'animazione che si ripete.
    Future<void> settleMap(WidgetTester tester) async {
      for (int i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    testWidgets('la mappa si disegna senza errori', (WidgetTester tester) async {
      final AppState state = await openMap(tester, asGameMaster: true);
      state.addWaypoint(label: 'Mercato di Kabuki', position: const Offset(0.44, 0.24));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('MAPPA DEL TAVOLO'), findsOneWidget);
      expect(find.text('Mercato di Kabuki'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await closeTree(tester);
    });

    testWidgets('anche l aspetto realistico si disegna', (WidgetTester tester) async {
      final AppState state = await openMap(tester, asGameMaster: true);
      state.setMapStyle(MapStyle.realistic);
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.mapStyle, MapStyle.realistic);
      expect(tester.takeException(), isNull);

      await closeTree(tester);
    });

    testWidgets('un immagine importata si disegna senza rompersi',
        (WidgetTester tester) async {
      final AppState state = await openMap(tester, asGameMaster: true);

      // Un PNG 1x1 vero, scritto su disco: il percorso dell'immagine passa da
      // una decodifica e da un `drawVertices`, ed e' il pezzo che nessun test
      // poteva coprire senza un file reale.
      final File png = File(p.join(temp.path, 'mappa.png'))
        ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
        ));
      state.setMapImage(png.path);
      await settleMap(tester);

      expect(find.text('mappa.png'), findsOneWidget);
      expect(find.textContaining('Non riesco a leggere'), findsNothing);
      expect(tester.takeException(), isNull);

      await closeTree(tester);
    });

    testWidgets('un immagine illeggibile lo dice invece di sparire',
        (WidgetTester tester) async {
      final AppState state = await openMap(tester, asGameMaster: true);

      state.setMapImage(p.join(temp.path, 'non-esiste.png'));
      await settleMap(tester);

      expect(find.textContaining('Non riesco a leggere'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await closeTree(tester);
    });

    testWidgets('cliccare la mappa mette il waypoint dove si e cliccato',
        (WidgetTester tester) async {
      final AppState state = await openMap(tester, asGameMaster: true);

      await tester.tap(find.text('AGGIUNGI UN WAYPOINT'));
      await tester.pump(const Duration(milliseconds: 200));

      // Il centro del riquadro della mappa e' il centro della mappa: se la
      // conversione fra schermo e coordinate fosse sbagliata, il segno
      // comparirebbe altrove — che e' esattamente il difetto piu' fastidioso
      // possibile in una mappa.
      await tester.tap(find.byType(MapCanvas));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('NUOVO WAYPOINT'), findsOneWidget);

      // I campi si cercano **dentro** il dialogo: sotto c'e' la sezione, che ha
      // un proprio campo di ricerca, e prenderne uno a caso scriverebbe nel
      // posto sbagliato.
      final Finder dialog = find.byType(Dialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)).first,
        'Imboscata',
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.descendant(of: dialog, matching: find.text('SALVA')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(state.mapWaypoints.length, 1);
      final MapWaypoint placed = state.mapWaypoints.single;
      expect(placed.label, 'Imboscata');
      expect(placed.x, closeTo(0.5, 0.02));
      expect(placed.y, closeTo(0.5, 0.02));
      expect(tester.takeException(), isNull);

      await closeTree(tester);
    });

    testWidgets('il giocatore non vede il selettore dell aspetto',
        (WidgetTester tester) async {
      await openMap(tester, asGameMaster: false);

      expect(find.text('DIGITALE'), findsNothing);
      expect(find.textContaining('Chi decide la mappa'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await closeTree(tester);
    });
  });
}
