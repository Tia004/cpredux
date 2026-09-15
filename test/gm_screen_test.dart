import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/dice_expression.dart';
import 'package:cpredux/features/gm/gm_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La console del Master, disegnata davvero.
///
/// Il valore di questi test non e' "la schermata esiste": e' che **ogni**
/// sezione si costruisca. Tredici pannelli diversi possono fallire ognuno per
/// conto proprio — un layout che chiede altezza infinita, una lista vuota letta
/// come se avesse un primo elemento — e il modo in cui un utente lo scopre e'
/// aprire la sezione sbagliata durante una partita. Girarci sopra in un test
/// costa pochi secondi.
const List<({String name, Size size})> kWindowSizes = <({String name, Size size})>[
  (name: 'Desktop (1920x1080)', size: Size(1920, 1080)),
  (name: 'Compatto (800x600)', size: Size(800, 600)),
];

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_gm_test');
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

  Future<void> pumpScreen(WidgetTester tester, AppState state, Size size) async {
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
  }

  /// Apre una sezione dalla barra laterale.
  ///
  /// `ensureVisible` non e' un dettaglio: a 800x600 la barra scorre, e senza di
  /// esso il test fallirebbe per "il pulsante non c'e'" anche quando il
  /// pulsante c'e' e funziona.
  Future<void> openTool(WidgetTester tester, GmTool tool) async {
    final Finder finder = find.text(tool.label);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 200));
  }

  for (final (:name, :size) in kWindowSizes) {
    group('Console del Master a $name', () {
      testWidgets('si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = AppState();
        addTearDown(state.dispose);

        await pumpScreen(tester, state, size);
        expect(find.byType(GmScreen), findsOneWidget);
        expect(find.text('STRUMENTI DEL MASTER'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('ogni sezione si apre e si disegna', (WidgetTester tester) async {
        final AppState state = AppState();
        addTearDown(state.dispose);

        await pumpScreen(tester, state, size);

        for (final GmTool tool in GmTool.values) {
          await openTool(tester, tool);
          // Il titolo del pannello e' il nome della sezione in maiuscolo: e' la
          // prova che la sezione si e' davvero disegnata, e non solo che la sua
          // voce esiste nella barra laterale.
          expect(
            find.text(tool.label.toUpperCase()),
            findsWidgets,
            reason: 'la sezione "${tool.label}" non si e\' disegnata',
          );
          await tester.pump(const Duration(milliseconds: 60));
        }

        await _disposeTree(tester);
      });
    });
  }

  testWidgets('il pannello dei dadi tira e mostra il dettaglio', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 900));

    // L'espressione predefinita non ha nomi da risolvere senza una scheda
    // aperta: il pannello deve comunque saperlo dire invece di crollare.
    expect(find.textContaining('Nessuna scheda aperta'), findsOneWidget);

    final Finder field = find.byType(TextField).first;
    await tester.enterText(field, '2 + 3 * 4');
    await tester.pump(const Duration(milliseconds: 100));
    // Le etichette dei pulsanti sono maiuscole: `TechButton` le trasforma lui.
    await tester.tap(find.text('TIRA').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('14'), findsWidgets);
    await _disposeTree(tester);
  });

  testWidgets('la sezione delle regole elenca i numeri e li corregge', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 1000));
    await openTool(tester, GmTool.regole);

    // I gruppi sono chiusi all'apertura: si apre quello della terapia.
    expect(find.text('TERAPIA'), findsOneWidget);
    await tester.tap(find.text('TERAPIA'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Costo di una settimana di terapia standard'), findsOneWidget);

    // Una correzione deve arrivare fino alle impostazioni, non fermarsi a
    // schermo: e' la differenza fra un pannello che sembra funzionare e uno che
    // funziona.
    await state.setGmRule('therapy.cost.standard', 750);
    await tester.pump(const Duration(milliseconds: 100));

    final AppSettings reloaded = SettingsStore.load();
    expect(reloaded.gmRuleOverrides['therapy.cost.standard'], 750);
    expect(state.gmRuleBook.intValue('therapy.cost.standard'), 750);

    await state.resetGmRule('therapy.cost.standard');
    await tester.pump(const Duration(milliseconds: 100));
    expect(SettingsStore.load().gmRuleOverrides, isEmpty);
    expect(state.gmRuleBook.intValue('therapy.cost.standard'), 500);

    await _disposeTree(tester);
  });

  testWidgets('le macro si salvano, si tirano e si cancellano', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 900));
    expect(state.gmMacros, isEmpty);

    await state.saveGmMacro(const DiceMacro(
      id: 'macro_test',
      name: 'Attacco con Malorian 3516',
      expression: '1d10 + 7',
    ));
    await tester.pump(const Duration(milliseconds: 200));

    expect(SettingsStore.load().gmMacros.single.name, 'Attacco con Malorian 3516');
    expect(find.text('Attacco con Malorian 3516'), findsOneWidget);
    expect(find.text('1d10 + 7'), findsOneWidget);

    await tester.tap(find.text('TIRA').last);
    await tester.pump(const Duration(milliseconds: 200));
    // Il risultato sta fra 8 e 17: quello che conta e' che il tiro sia
    // avvenuto, non quanto e' uscito.
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is RichText && w.text.toPlainText().contains('1d10 + 7 ='),
      ),
      findsOneWidget,
    );

    await state.deleteGmMacro('macro_test');
    await tester.pump(const Duration(milliseconds: 200));
    expect(SettingsStore.load().gmMacros, isEmpty);
    expect(find.text('Attacco con Malorian 3516'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('il generatore di incontri produce nemici e un briefing', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 1000));
    await openTool(tester, GmTool.incontro);

    await tester.tap(find.text('GENERA INCONTRO'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('nemici · uscito'), findsOneWidget);
    // La pioggia acida e' l'unico incontro senza nemici: se esce, il briefing
    // deve comunque esserci invece di un elenco vuoto.
    expect(find.textContaining('Minaccia'), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets('il calcolatore DV risponde alla distanza', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 1000));
    await openTool(tester, GmTool.dv);

    // A dieci metri una pistola: la fascia 7-12.
    expect(find.text('DV DA BATTERE'), findsOneWidget);

    final Finder distance = find.byType(TextField).first;
    await tester.enterText(distance, '900');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('non si può fare'), findsOneWidget);

    await tester.enterText(distance, '10');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('DV DA BATTERE'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('la console di rete attacca e distrugge un programma', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 1100));
    await openTool(tester, GmTool.rete);

    expect(find.textContaining('PROGRAMMI DIFENSIVI ATTIVI'), findsOneWidget);
    await tester.tap(find.textContaining('ATTACCA'));
    await tester.pump(const Duration(milliseconds: 200));

    // Due: la riga del registro e il blocco copiabile che le raccoglie tutte.
    expect(find.textContaining('1d10 ('), findsWidgets);
    expect(find.textContaining('contro Difesa'), findsWidgets);

    await _disposeTree(tester);
  });

  testWidgets('senza correzioni la barra laterale non le annuncia', (WidgetTester tester) async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await pumpScreen(tester, state, const Size(1400, 900));
    expect(find.textContaining('valori corretti dal tavolo'), findsNothing);

    await state.setGmRule('heal.medtechBonus', 4);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('1 valori corretti dal tavolo'), findsOneWidget);

    await _disposeTree(tester);
  });
}
