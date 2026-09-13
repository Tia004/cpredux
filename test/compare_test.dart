import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/document_library.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:cpredux/features/compare/compare_picker.dart';
import 'package:cpredux/features/compare/compare_screen.dart';
import 'package:cpredux/features/home/home_screen.dart';
import 'package:cpredux/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Avanza a fotogrammi, come un'applicazione vera: le animazioni di ingresso e
/// l'`AnimatedSwitcher` delle schermate non finiscono con un `pump` solo.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  late Directory temp;
  late Directory docs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_compare_test');
    docs = Directory(p.join(temp.path, 'documenti'))..createSync(recursive: true);
    AppPaths.overrideForTesting(
      config: temp.path,
      data: temp.path,
      documents: docs.path,
    );
  });

  tearDown(() {
    AppPaths.clearOverrides();
    SettingsStore.save(AppSettings());
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Due schede **su disco**, con differenze vere da trovare: Destrezza e
  /// denaro.
  Future<({String prima, String dopo, AppState state})> twoSavedSheets() async {
    final AppState state = AppState();
    addTearDown(state.dispose);

    await state.createSheet(name: 'Prima', directory: docs.path);
    state.mutate((CharacterSheet s) {
      s.identity.tag = 'Jackie';
      s.statBase[Stat.dexterity] = 6;
    });
    final String prima = state.documentPath!;
    state.save();

    await state.createSheet(name: 'Dopo', directory: docs.path);
    state.mutate((CharacterSheet s) {
      s.identity.tag = 'Jackie';
      s.statBase[Stat.dexterity] = 8;
      s.eurobucks = 500;
    });
    final String dopo = state.documentPath!;
    state.save();

    return (prima: prima, dopo: dopo, state: state);
  }

  /// Monta la schermata di confronto con un confronto gia' aperto.
  Future<void> openComparison(
    WidgetTester tester,
    AppState state,
    Comparison comparison,
  ) async {
    state.openComparison(comparison);

    tester.view.physicalSize = const Size(1500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: CprTheme.dark(),
          home: const Scaffold(body: CompareScreen()),
        ),
      ),
    );
    await _settle(tester);
  }

  group('schermata di confronto', () {
    testWidgets('mostra i due lati e il numero di differenze', (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;

      await openComparison(
        tester,
        state,
        Comparison(
          before: state.readSheetSide(sheets.prima, label: 'Copia di ieri'),
          after: state.readSheetSide(sheets.dopo, label: 'Adesso'),
        ),
      );

      expect(find.text('CONFRONTO'), findsOneWidget);
      // Le due intestazioni dicono **quale** scheda e' quale: senza, il
      // confronto sarebbe due colonne di numeri senza un proprietario.
      expect(find.text('Copia di ieri'), findsOneWidget);
      expect(find.text('Adesso'), findsOneWidget);
      expect(find.textContaining('differenze in'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('la riga cambiata mostra i due valori, il segno e la base',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;

      await openComparison(
        tester,
        state,
        Comparison(
          before: state.readSheetSide(sheets.prima),
          after: state.readSheetSide(sheets.dopo),
        ),
      );

      // Destrezza: base 6 e 8, +1 di carico leggero applicato dal progetto.
      expect(find.text('Destrezza'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('base 6 → 8'), findsOneWidget);

      // Il segno accompagna il colore: il colore da solo chiede di ricordarsi
      // quale delle due colonne e' quella nuova.
      expect(find.text('−'), findsWidgets);
      expect(find.text('+'), findsWidgets);

      expect(find.text('Eurobucks'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('parte dalle differenze, e "tutto" mostra anche il resto',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;

      await openComparison(
        tester,
        state,
        Comparison(
          before: state.readSheetSide(sheets.prima),
          after: state.readSheetSide(sheets.dopo),
        ),
      );

      expect(find.text('CARATTERISTICHE'), findsOneWidget);
      expect(find.text('CYBERWARE'), findsNothing);

      await tester.tap(find.text('TUTTO'));
      await _settle(tester);

      expect(find.text('CYBERWARE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('toccare una sezione la chiude', (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;

      await openComparison(
        tester,
        state,
        Comparison(
          before: state.readSheetSide(sheets.prima),
          after: state.readSheetSide(sheets.dopo),
        ),
      );

      expect(find.text('Destrezza'), findsOneWidget);

      // "Abilita" sono 68 righe: se una sezione non si chiude, la differenza
      // che interessa si perde in mezzo.
      await tester.tap(find.text('CARATTERISTICHE'));
      await _settle(tester);

      expect(find.text('Destrezza'), findsNothing);

      await _disposeTree(tester);
    });

    testWidgets('si puo invertire l ordine dei due lati', (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;

      await openComparison(
        tester,
        state,
        Comparison(
          before: state.readSheetSide(sheets.prima, label: 'Prima'),
          after: state.readSheetSide(sheets.dopo, label: 'Dopo'),
        ),
      );

      expect(state.comparison!.before.label, 'Prima');

      await tester.tap(find.text('INVERTI').first);
      await _settle(tester);

      expect(state.comparison!.before.label, 'Dopo');
      expect(state.comparison!.after.label, 'Prima');
      // L'intestazione delle colonne si ripete in ogni sezione, quindi compare
      // piu' di una volta: e' voluto, perche' scorrendo una sezione lunga la
      // testata uscirebbe dallo schermo.
      expect(find.text('prima · Dopo'), findsWidgets);

      await _disposeTree(tester);
    });

    testWidgets('una scheda contro se stessa non ha differenze', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'Copia', directory: docs.path);
      final String path = state.documentPath!;
      state.save();

      await openComparison(
        tester,
        state,
        Comparison(
          before: state.readSheetSide(path),
          after: state.readSheetSide(path),
        ),
      );

      expect(find.textContaining('Le due schede sono identiche'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('una finestra stretta non manda in overflow la schermata',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;
      state.openComparison(
        Comparison(
          before: state.readSheetSide(sheets.prima),
          after: state.readSheetSide(sheets.dopo),
        ),
      );

      tester.view.physicalSize = const Size(900, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: CompareScreen()),
          ),
        ),
      );
      await _settle(tester);

      // La barra in alto ha titolo, filtro e due pulsanti: e' la prima cosa a
      // non starci piu' quando la finestra si restringe.
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('senza un confronto aperto la schermata lo dice', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: CompareScreen()),
          ),
        ),
      );
      await _settle(tester);

      // Un riquadro nero senza spiegazione e' indistinguibile da un difetto.
      expect(find.textContaining('nessun confronto aperto'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });
  });

  group('come ci si arriva', () {
    Future<void> openHome(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await _settle(tester);
    }

    testWidgets('dal menu principale si scelgono due schede e si confrontano',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;
      state.refreshDocumentLibrary();

      await openHome(tester, state);
      await tester.tap(find.text('Confronta due schede'));
      await _settle(tester);

      expect(find.text('CONFRONTA DUE SCHEDE'), findsOneWidget);
      expect(find.text('PRIMA'), findsOneWidget);
      expect(find.text('DOPO'), findsOneWidget);
      expect(find.byType(TechDropdown<DocumentEntry>), findsNWidgets(2));

      await tester.tap(find.text('CONFRONTA'));
      await _settle(tester);

      final Comparison? comparison = state.comparison;
      expect(comparison, isNotNull);
      expect(
        <String?>{comparison!.before.path, comparison.after.path},
        <String?>{sheets.prima, sheets.dopo},
      );

      await _disposeTree(tester);
    });

    testWidgets('scegliere due volte lo stesso file viene fermato',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;
      state.refreshDocumentLibrary();

      await openHome(tester, state);
      await tester.tap(find.text('Confronta due schede'));
      await _settle(tester);

      // La prima tendina e' precompilata con la scheda piu' recente: nella
      // seconda si sceglie **quella stessa**, per provare il rifiuto.
      final String firstSelected = state.documentsOfKind(DocumentKind.sheet).first.name;
      await tester.tap(find.byType(TechDropdown<DocumentEntry>).last);
      await _settle(tester);
      await tester.tap(find.text(firstSelected).last);
      await _settle(tester);

      await tester.tap(find.text('CONFRONTA'));
      await _settle(tester);

      // Un file confrontato con se stesso da' zero differenze, che si legge
      // come "non e' cambiato niente": la risposta giusta alla domanda
      // sbagliata.
      expect(state.comparison, isNull);
      expect(find.textContaining('stesso file'), findsOneWidget);

      await _disposeTree(tester);
    });

    /// Monta un pulsante che apre il selettore **come fa la scheda**: il
    /// risultato del dialogo diventa il confronto aperto.
    ///
    /// Serve un supporto perche' il flusso vero passa dalle impostazioni della
    /// scheda; qui interessa che il dialogo consegni un confronto valido.
    Future<void> openPickerFromAStandIn(WidgetTester tester, AppState state) async {
      tester.view.physicalSize = const Size(1500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (BuildContext context) => Center(
                  child: TextButton(
                    onPressed: () async {
                      final Comparison? comparison = await showComparePicker(
                        context,
                        state: state,
                        openSheet: state.sideOfOpenSheet()!,
                      );
                      if (comparison != null) state.openComparison(comparison);
                    },
                    child: const Text('apri'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('dalla scheda aperta si sceglie solo l altra versione',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;
      state.refreshDocumentLibrary();

      // La scheda aperta e' "Dopo", appena salvata: il confronto parte da li'.
      final ComparisonSide open = state.sideOfOpenSheet()!;
      expect(open.dirty, isFalse);

      await openPickerFromAStandIn(tester, state);

      await tester.tap(find.text('apri'));
      await _settle(tester);

      // Un lato solo da scegliere, e la scheda aperta dichiarata per quello
      // che e': quello che si vede adesso, non quello che c'e' sul disco.
      expect(find.text('LA COPIA DA CONFRONTARE'), findsOneWidget);
      expect(find.text('QUESTA SCHEDA, ADESSO'), findsOneWidget);
      expect(find.textContaining('come e\''), findsOneWidget);

      await tester.tap(find.text('CONFRONTA'));
      await _settle(tester);

      final Comparison? comparison = state.comparison;
      expect(comparison, isNotNull);
      expect(comparison!.before.path, sheets.prima);
      expect(comparison.after.path, sheets.dopo);

      await _disposeTree(tester);
    });

    testWidgets('una copia con modifiche non salvate lo dichiara',
        (WidgetTester tester) async {
      final ({String prima, String dopo, AppState state}) sheets = await twoSavedSheets();
      final AppState state = sheets.state;

      // Una modifica in memoria e nessun salvataggio: la scheda aperta e' una
      // versione che su disco non esiste.
      state.mutate((CharacterSheet s) => s.eurobucks = 999);
      expect(state.sideOfOpenSheet()!.dirty, isTrue);

      await openPickerFromAStandIn(tester, state);

      await tester.tap(find.text('apri'));
      await _settle(tester);

      expect(find.textContaining('modifiche non ancora salvate'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });
  });
}
