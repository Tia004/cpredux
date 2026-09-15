import 'dart:io';
import 'dart:math' as math;

import 'package:cpredux/app/app.dart';
import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/gm/gm_generators.dart';
import 'package:cpredux/domain/map_token.dart';
import 'package:cpredux/features/gm/gm_panel.dart';
import 'package:cpredux/features/gm/gm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La console del Master **accanto al tavolo**, e quello che ci fa finire.
///
/// `gm_screen_test.dart` verifica che i tredici strumenti si disegnino. Qui c'e'
/// la parte che rende la console uno strumento di gioco invece di un generatore
/// di testi da copiare a mano: un incontro che diventa token sulla mappa, un
/// bottino che entra nell'inventario, un tiro che finisce nel registro.
///
/// E' la parte che si rompe in silenzio. Se `sendBandToTable` smettesse di
/// scrivere sulla campagna, o se il pulsante perdesse il collegamento con la
/// funzione, lo strumento continuerebbe a **mostrare** i nemici generati con
/// l'aria di funzionare: nessuna eccezione, nessun errore, solo un tavolo che
/// resta vuoto. Per questo la verifica guarda lo stato dopo il tocco, non il
/// testo sullo schermo.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_gm_panel_test');
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

  Future<AppState> withCampaign() async {
    final AppState state = AppState();
    await state.createCampaign(name: 'Night City 2045', directory: temp.path);
    return state;
  }

  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 900));
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> pumpPanel(WidgetTester tester, AppState state, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: CprTheme.dark(),
          // Il pannello vive **accanto** a qualcosa, non da solo: la larghezza
          // del resto della finestra e' quello che gli resta a disposizione.
          home: Scaffold(
            body: Row(
              children: <Widget>[
                const Expanded(child: SizedBox.expand()),
                GmPanel(onClose: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Sceglie uno strumento dalla striscia di icone del pannello.
  ///
  /// La striscia scorre in orizzontale, quindi `ensureVisible` non e' un
  /// dettaglio: senza, il tocco su uno degli ultimi tredici strumenti finirebbe
  /// fuori dalla ListView e il test direbbe "il pulsante non c'e'".
  Future<void> openTool(WidgetTester tester, GmTool tool) async {
    final Finder chip = find.byTooltip(tool.label);
    expect(chip, findsWidgets, reason: 'lo strumento "${tool.label}" non e\' nella striscia');
    await tester.ensureVisible(chip.first);
    await tester.pump();
    await tester.tap(chip.first);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Preme un pulsante per la sua etichetta **in maiuscolo**: `TechButton` la
  /// trasforma da sola, quindi cercare "Genera incontro" non troverebbe nulla.
  Future<void> tapButton(WidgetTester tester, String label) async {
    final Finder finder = find.text(label);
    expect(finder, findsWidgets, reason: 'il pulsante "$label" non c\'e\'');
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 250));
  }

  // ------------------------------------------------------------------------
  // Dal generatore al tavolo
  // ------------------------------------------------------------------------

  group('Un gruppo di nemici diventa token', () {
    test('un token per nemico, tutti nello stesso gruppo, con i loro numeri', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final List<Mook> band = MookGenerator.band(MookTier.scagnozzo, 4, math.Random(7));
      final int placed = sendBandToTable(state, band, groupLabel: 'Tyger Claws');

      expect(placed, 4);
      expect(state.mapTokens.length, 4);
      // Un gruppo solo: a fine scontro si tolgono insieme, e senza gruppo
      // bisognerebbe ritrovarli a mano uno per uno.
      expect(state.mapTokens.map((MapToken t) => t.groupId).toSet(), hasLength(1));
      expect(state.mapTokens.first.groupId, isNotEmpty);

      // I tre numeri del PNG rapido viaggiano con il token: ricopiarli a mano
      // dalla console sarebbe il lavoro che la funzione esiste per togliere.
      final MapToken first = state.mapTokens.firstWhere((MapToken t) => t.name == band.first.name);
      expect(first.hp, band.first.hitPoints);
      expect(first.maxHp, band.first.hitPoints);
      expect(first.sp, band.first.sp);
      expect(first.combat, band.first.combat);
      expect(first.defense, band.first.defense);
      expect(first.kind, TokenKind.nemico);

      // E sono nella campagna, non solo in memoria.
      expect(state.tokensArePersisted, isTrue);
      expect(state.campaign?.tokens.length, 4);
    });

    test('non finiscono impilati nello stesso pixel', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final List<Mook> band = MookGenerator.band(MookTier.professionista, 6, math.Random(3));
      sendBandToTable(state, band, groupLabel: 'Maelstrom');

      final Set<String> spots = state.mapTokens
          .map((MapToken t) => '${t.x.toStringAsFixed(4)},${t.y.toStringAsFixed(4)}')
          .toSet();
      expect(spots, hasLength(6), reason: 'sei token sono finiti uno sopra l\'altro');
    });

    test('un agguato sul bordo della mappa resta dentro la mappa', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final List<Mook> band = MookGenerator.band(MookTier.scagnozzo, 5, math.Random(11));
      sendBandToTable(state, band, groupLabel: 'Bozos', center: const Offset(0.01, 0.01));

      for (final MapToken t in state.mapTokens) {
        expect(t.x, inInclusiveRange(0, 1));
        expect(t.y, inInclusiveRange(0, 1));
      }
    });

    test('una banda vuota non tocca il tavolo e non sporca il registro', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final int placed = sendBandToTable(state, const <Mook>[], groupLabel: 'Nessuno');

      expect(placed, 0);
      expect(state.mapTokens, isEmpty);
      expect(state.campaign?.tokens, isEmpty);
      expect(state.sessionLog, isEmpty);
    });

    test('senza campagna i token restano in memoria e non si finge che siano salvati', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      final List<Mook> band = MookGenerator.band(MookTier.scagnozzo, 3, math.Random(5));
      final int placed = sendBandToTable(state, band, groupLabel: 'Bozos');

      expect(placed, 3);
      expect(state.mapTokens.length, 3);
      expect(state.tokensArePersisted, isFalse);
      expect(state.campaign, isNull);
    });
  });

  // ------------------------------------------------------------------------
  // Il pannello
  // ------------------------------------------------------------------------

  group('Il pannello laterale', () {
    for (final ({String name, Size size}) window in <({String name, Size size})>[
      (name: 'finestra alta', size: Size(1280, 900)),
      (name: 'finestra bassa', size: Size(800, 600)),
    ]) {
      testWidgets('si costruisce a ${window.name}', (WidgetTester tester) async {
        final AppState state = AppState();
        addTearDown(state.dispose);

        await pumpPanel(tester, state, window.size);

        expect(find.byType(GmPanel), findsOneWidget);
        expect(find.text('STRUMENTI DEL MASTER'), findsOneWidget);
        // La striscia parte dal primo strumento: gli altri li raggiunge lo
        // scorrimento, che e' la ragione per cui la striscia esiste.
        expect(find.byTooltip(GmTool.dadi.label), findsOneWidget);

        await disposeTree(tester);
      });
    }

    testWidgets('la linguetta sul bordo apre e chiude il pannello', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: Scaffold(body: GmFloatingTab(onTap: state.toggleGmPanel)),
          ),
        ),
      );

      expect(state.isGmPanelOpen, isFalse);
      await tester.tap(find.byType(GmFloatingTab));
      await tester.pump();
      expect(state.isGmPanelOpen, isTrue);
      await tester.tap(find.byType(GmFloatingTab));
      await tester.pump();
      expect(state.isGmPanelOpen, isFalse);

      await disposeTree(tester);
    });
  });

  // ------------------------------------------------------------------------
  // Il giro completo, premendo i pulsanti veri
  // ------------------------------------------------------------------------

  group('Il giro completo', () {
    testWidgets('un incontro generato arriva sulla mappa come gruppo di token', (WidgetTester tester) async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      await pumpPanel(tester, state, const Size(460, 900));
      await openTool(tester, GmTool.incontro);

      await tapButton(tester, 'GENERA INCONTRO');
      // Generare **non** mette niente in tavola: il Master decide se e dove.
      expect(state.mapTokens, isEmpty);

      // Non ogni incontro ha nemici: "Pioggia acida" e' un incontro di
      // atmosfera, con `groupSize: 0`, e senza nemici il pulsante non c'e' —
      // giustamente. Il caso del test e' la banda, quindi si ritira finche' non
      // ne esce una: e' la casualita' della tabella, non quella dell'app.
      for (int attempt = 0; attempt < 12 && find.text('MANDA AL TAVOLO').evaluate().isEmpty; attempt++) {
        await tapButton(tester, 'GENERA INCONTRO');
      }
      expect(
        find.text('MANDA AL TAVOLO'),
        findsWidgets,
        reason: 'dodici estrazioni senza una banda: la tabella degli incontri non pesca piu\' i nemici',
      );

      await tapButton(tester, 'MANDA AL TAVOLO');

      expect(state.mapTokens, isNotEmpty);
      expect(state.campaign?.tokens.length, state.mapTokens.length);
      expect(state.mapTokens.map((MapToken t) => t.groupId).toSet(), hasLength(1));
      // Il registro racconta cos'e' arrivato in tavola, come per ogni altro
      // cambiamento: senza, il tavolo non saprebbe spiegare quei token.
      expect(state.sessionLog.first.delta, 'MAPPA');
      expect(state.sessionLog.first.description, contains('token sulla mappa'));

      await disposeTree(tester);
    });

    testWidgets('il bottino raccolto entra nell inventario della scheda aperta', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      await pumpPanel(tester, state, const Size(460, 900));
      await openTool(tester, GmTool.bottino);

      await tapButton(tester, 'RACOGLI');
      final int before = state.sheet!.inventory.length;

      // Ogni voce del bottino ha il suo pulsante: e' quello con il "+" e il
      // suggerimento che dice dove finira'.
      final Finder entry = find.byTooltip('Aggiungi all\'inventario della scheda aperta');
      expect(entry, findsWidgets, reason: 'nessuna voce di bottino con un pulsante per l\'inventario');
      await tester.ensureVisible(entry.first);
      await tester.pump();
      await tester.tap(entry.first);
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        state.sheet!.inventory.length,
        greaterThan(before),
        reason: 'il bottino non e\' entrato nell\'inventario',
      );

      await disposeTree(tester);
    });

    testWidgets('i contanti del bottino vanno sul conto della scheda', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      await pumpPanel(tester, state, const Size(460, 900));
      await openTool(tester, GmTool.bottino);

      await tapButton(tester, 'RACOGLI');
      final int before = state.sheet!.eurobucks;

      await tapButton(tester, 'CONTANTI AL PORTAFOGLIO');

      expect(state.sheet!.eurobucks, greaterThan(before));

      await disposeTree(tester);
    });

    testWidgets('nell applicazione vera il pannello si apre e resta aperto cambiando schermata',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CpredApp());
      await settle(tester);

      expect(find.byType(GmPanel), findsNothing);
      await tester.tap(find.byType(GmFloatingTab));
      await settle(tester);
      expect(find.byType(GmPanel), findsOneWidget);

      // Il punto della richiesta: non e' una schermata che si apre e si chiude
      // per forza. Andando alle impostazioni resta li', perche' e' montato
      // nella cornice dell'applicazione e non dentro una schermata.
      await tester.tap(find.text('Impostazioni'));
      await settle(tester);
      expect(find.text('IMPOSTAZIONI'), findsOneWidget);
      expect(find.byType(GmPanel), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets('un tiro calcolato si scrive nel registro della sessione', (WidgetTester tester) async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      await pumpPanel(tester, state, const Size(460, 900));
      await openTool(tester, GmTool.dadi);

      // Un'espressione coi soli numeri: senza una scheda aperta le sigle e i
      // nomi delle abilita' non si possono risolvere, ed e' una scelta del
      // motore — un nome sconosciuto e' un errore, non uno zero.
      await tester.enterText(find.byType(TextField).first, '2d6 + 3');
      await tester.pump();
      await tapButton(tester, 'TIRA');

      // Calcolare non scrive niente: il registro tiene quello che il Master
      // decide di rendere noto al tavolo.
      expect(state.sessionLog, isEmpty);

      await tapButton(tester, 'AL REGISTRO');

      expect(state.sessionLog.first.delta, 'TIRO');
      expect(state.sessionLog.first.description, contains('2d6'));

      await disposeTree(tester);
    });
  });
}
