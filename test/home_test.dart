import 'dart:io';

import 'package:cpredux/app/app.dart';
import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/document_library.dart';
import 'package:cpredux/data/migrator.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/features/home/home_screen.dart';
import 'package:cpredux/widgets/menu.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/legacy_sheet_fixture.dart';

/// Avanza oltre le animazioni di ingresso e di apertura dei menu'.
///
/// Non si usa `pumpAndSettle`: il menu' principale ha animazioni che si
/// ripetono, e "aspetta che tutto si fermi" non finirebbe mai.
///
/// E non basta un `pump` lungo: `AnimatedSize` decide la propria altezza
/// **durante** l'impaginazione, quindi il primo fotogramma dopo l'apertura
/// misura il contenuto e **avvia** l'animazione. Con un solo `pump` da 900 ms
/// l'animazione resta a zero: il corpo del menu' e' disegnato alla sua altezza
/// finale mentre la colonna gli riserva spazio zero, e finisce **sopra** le
/// righe successive. Serve una sequenza di fotogrammi, come nel programma vero.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}

/// Il testo di una voce di menu', distinto dall'omonima riga dei recenti.
///
/// Serve perche' un documento appena creato compare **due volte** nella
/// schermata: nel menu' a tendina e fra i recenti. Cercare il nome senza dire
/// dove si intende trovarlo renderebbe il test ambiguo, e l'ambiguita' qui non
/// e' un dettaglio: le due cose si toccano in posti diversi.
Finder _menuEntry(String label) => find.descendant(
      of: find.byType(ExpandableMenuRow),
      matching: find.text(label),
    );

void main() {
  late Directory temp;
  late Directory docs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_home_test');
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

  // --- La libreria dei documenti -------------------------------------------

  group('documenti esistenti', () {
    late AppState state;

    setUp(() async {
      state = AppState();
      addTearDown(state.dispose);
    });

    test('trova schede e campagne distinguendole dal contenuto', () async {
      await state.createSheet(name: 'Jackie', directory: docs.path);
      await state.createCampaign(name: 'Night City', directory: docs.path);

      final List<DocumentEntry> found = DocumentLibrary.scan();

      expect(found.length, 2);
      expect(
        found.firstWhere((DocumentEntry d) => d.name == 'Jackie').kind,
        DocumentKind.sheet,
      );
      expect(
        found.firstWhere((DocumentEntry d) => d.name == 'Night City').kind,
        DocumentKind.campaign,
      );
    });

    test('una campagna rinominata resta una campagna', () async {
      await state.createCampaign(name: 'Night City', directory: docs.path);
      // Il nome del file non dice niente: entrambi i tipi usano `.cpredux`.
      File(p.join(docs.path, 'Night City.cpredux'))
          .renameSync(p.join(docs.path, 'Sembra una scheda.cpredux'));

      final List<DocumentEntry> found = DocumentLibrary.scan();

      expect(found.single.kind, DocumentKind.campaign);
      expect(found.single.name, 'Night City');
    });

    test('il filtro per tipo esclude l altro', () async {
      await state.createSheet(name: 'Jackie', directory: docs.path);
      await state.createCampaign(name: 'Night City', directory: docs.path);

      expect(DocumentLibrary.scan(kind: DocumentKind.sheet).length, 1);
      expect(DocumentLibrary.scan(kind: DocumentKind.campaign).length, 1);
    });

    test('un documento da un altra cartella entra nell elenco', () async {
      final Directory elsewhere = Directory(p.join(temp.path, 'altrove'))..createSync();
      await state.createSheet(name: 'Lontana', directory: elsewhere.path);

      final List<DocumentEntry> found =
          DocumentLibrary.scan(extraPaths: <String>[p.join(elsewhere.path, 'Lontana.cpredux')]);

      expect(found.any((DocumentEntry d) => d.name == 'Lontana'), isTrue);
    });

    test('un file illeggibile compare segnato invece di sparire', () async {
      // Un documento che sparisce dall'elenco senza spiegazione fa credere di
      // averlo perso.
      File(p.join(docs.path, 'Rotto.cpredux')).writeAsStringSync('non sono un database');

      final List<DocumentEntry> found = DocumentLibrary.scan();

      expect(found.single.name, 'Rotto');
      expect(found.single.readable, isFalse);
    });

    test('un recente che punta nel vuoto resta visibile come mancante', () {
      final List<DocumentEntry> found = DocumentLibrary.scan(
        extraPaths: <String>[p.join(temp.path, 'sparita.cpredux')],
        includeAppFolder: false,
      );

      expect(found.single.missing, isTrue);
      expect(found.single.readable, isFalse);
    });

    test('la lettura arriva anche nelle sottocartelle ma non all infinito', () async {
      final Directory nested = Directory(p.join(docs.path, 'a', 'b'))..createSync(recursive: true);
      await state.createSheet(name: 'Profonda', directory: nested.path);

      final Directory tooDeep =
          Directory(p.join(docs.path, 'a', 'b', 'c', 'd'))..createSync(recursive: true);
      await state.createSheet(name: 'Troppo profonda', directory: tooDeep.path);

      final List<DocumentEntry> found = DocumentLibrary.scan();
      final List<String> names = found.map((DocumentEntry d) => d.name).toList();

      expect(names, contains('Profonda'));
      expect(names, isNot(contains('Troppo profonda')));
    });

    test('lo stato applicativo rilegge l elenco quando glielo si chiede', () async {
      state.refreshDocumentLibrary();
      expect(state.documents, isEmpty);

      await state.createSheet(name: 'Jackie', directory: docs.path);
      state.refreshDocumentLibrary();

      expect(state.documentsOfKind(DocumentKind.sheet).length, 1);
      expect(state.documentsOfKind(DocumentKind.campaign), isEmpty);
    });
  });

  // --- Dove finisce la scheda convertita -----------------------------------

  group('destinazione della conversione', () {
    late AppState state;
    late String legacy;

    setUp(() async {
      state = AppState();
      addTearDown(state.dispose);
      legacy = p.join(temp.path, 'Vecchia.cpred_sheet');
      createLegacySheet(legacy);
    });

    test('tra i documenti dell app per impostazione predefinita', () async {
      final MigrationReport report = state.migrateLegacySheet(legacy);

      final String expected = p.join(AppPaths.documentsDir().path, 'Vecchia.cpredux');
      expect(report.outputPath, expected);
      expect(File(expected).existsSync(), isTrue);
      expect(state.screen, AppScreen.sheet);
      expect(state.documentPath, expected);
      // Il **nome del personaggio** viene dalla scheda vecchia, non dal nome del
      // file: la scheda si chiama "Vecchia" perche' si chiama cosi' il file, ma
      // il personaggio dentro si chiama Jackie. Mostrare "Vecchia" nella scheda
      // aperta vorrebbe dire aver perso il nome del personaggio per strada.
      expect(state.sheet!.meta.name, 'Jackie');
    });

    test('accanto alla scheda vecchia, se e quello che si chiede', () async {
      final MigrationReport report = state.migrateLegacySheet(
        legacy,
        target: MigrationTarget.besideOriginal,
      );

      expect(report.outputPath, p.join(temp.path, 'Vecchia.cpredux'));
      expect(File(report.outputPath!).existsSync(), isTrue);
    });

    test('non sovrascrive mai un documento che esiste gia', () async {
      final String first = state.migrationOutputPath(legacy, MigrationTarget.appData);
      File(first).writeAsStringSync('occupato');

      final String second = state.migrationOutputPath(legacy, MigrationTarget.appData);

      expect(second, isNot(first));
      expect(second, contains('(1)'));
    });

    test('la scheda vecchia non viene toccata', () async {
      // Confronto sui **byte**: una `.cpred_sheet` e' un database, non testo,
      // quindi non si puo' leggerla come stringa.
      final List<int> before = File(legacy).readAsBytesSync();
      state.migrateLegacySheet(legacy);
      expect(File(legacy).readAsBytesSync(), before);
    });
  });

  // --- La schermata --------------------------------------------------------

  group('menu principale', () {
    Future<AppState> openHome(WidgetTester tester, {AppState? existing}) async {
      final AppState state = existing ?? AppState();
      // Solo se lo stato e' nostro: chi lo passa lo possiede gia', e disporlo
      // due volte e' un errore vero, non una svista del test.
      if (existing == null) addTearDown(state.dispose);

      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: _HomeHost()),
          ),
        ),
      );
      await _settle(tester);
      return state;
    }

    testWidgets('la riga della conversione accetta un file trascinato',
        (WidgetTester tester) async {
      await openHome(tester);

      expect(find.textContaining('Trascina qui una'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('apri scheda elenca le schede che ci sono', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'Jackie', directory: docs.path);
      state.refreshDocumentLibrary();

      await openHome(tester, existing: state);

      expect(find.textContaining('1 scheda trovata'), findsOneWidget);
      await tester.tap(find.text('Apri scheda'));
      await _settle(tester);

      expect(_menuEntry('Jackie'), findsOneWidget);
      expect(_menuEntry('Sfoglia i file…'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('aprire una scheda dall elenco la carica', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'Jackie', directory: docs.path);
      state.refreshDocumentLibrary();

      await openHome(tester, existing: state);
      await tester.tap(find.text('Apri scheda'));
      await _settle(tester);

      await tester.tap(_menuEntry('Jackie'));
      await _settle(tester);

      expect(state.screen, AppScreen.sheet);
      expect(state.sheet!.meta.name, 'Jackie');

      await _disposeTree(tester);
    });

    testWidgets('il menu della campagna offre creare e partecipare',
        (WidgetTester tester) async {
      await openHome(tester);

      await tester.tap(find.text('Crea o partecipa a una campagna'));
      await _settle(tester);

      expect(_menuEntry('Crea una nuova campagna'), findsOneWidget);
      expect(_menuEntry('Partecipa a una campagna'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('apri campagna elenca le campagne esistenti', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createCampaign(name: 'Night City', directory: docs.path);
      state.refreshDocumentLibrary();

      await openHome(tester, existing: state);

      expect(find.textContaining('1 campagna trovata'), findsOneWidget);
      await tester.tap(find.text('Apri campagna'));
      await _settle(tester);

      expect(_menuEntry('Night City'), findsOneWidget);

      await _disposeTree(tester);
    });

    testWidgets('aprire una campagna dall elenco la carica come campagna',
        (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createCampaign(name: 'Night City', directory: docs.path);
      state.refreshDocumentLibrary();

      await openHome(tester, existing: state);
      await tester.tap(find.text('Apri campagna'));
      await _settle(tester);
      await tester.tap(_menuEntry('Night City'));
      await _settle(tester);

      // Si apre come **campagna**, non come scheda: e' il motivo per cui il
      // tipo viene letto dal contenuto invece che dal nome del file.
      expect(state.screen, AppScreen.campaign);
      expect(state.campaign!.meta.name, 'Night City');
      expect(state.sheet, isNull);

      await _disposeTree(tester);
    });

    testWidgets('partecipare chiede il personaggio, l indirizzo e la porta',
        (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'Jackie', directory: docs.path);
      state.refreshDocumentLibrary();

      await openHome(tester, existing: state);
      await tester.tap(find.text('Crea o partecipa a una campagna'));
      await _settle(tester);
      await tester.tap(_menuEntry('Partecipa a una campagna'));
      await _settle(tester);

      expect(find.text('PARTECIPA A UNA CAMPAGNA'), findsOneWidget);
      expect(find.text('INDIRIZZO DEL MASTER'), findsOneWidget);
      expect(find.text('PORTA'), findsOneWidget);

      // Senza indirizzo il collegamento non parte e il motivo viene detto:
      // un pulsante che non fa niente e non spiega perche' e' un vicolo cieco.
      await tester.tap(find.text('COLLEGA'));
      await _settle(tester);

      expect(find.textContaining('Inserisci indirizzo e porta'), findsOneWidget);
      expect(state.isJoined, isFalse);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('senza schede, partecipare lo dice invece di fallire in silenzio',
        (WidgetTester tester) async {
      await openHome(tester);

      await tester.tap(find.text('Crea o partecipa a una campagna'));
      await _settle(tester);
      await tester.tap(_menuEntry('Partecipa a una campagna'));
      await _settle(tester);

      expect(find.textContaining('Non c\'e\' nessuna scheda'), findsOneWidget);

      await _disposeTree(tester);
    });
  });

  group('app completa', () {
    testWidgets('il menu principale si costruisce con la libreria dei documenti',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CpredApp());
      await _settle(tester);

      expect(find.text('Crea o partecipa a una campagna'), findsOneWidget);
      expect(find.textContaining('Trascina qui una'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });
  });
}

/// La schermata principale, importata dalla sua posizione reale.
class _HomeHost extends StatelessWidget {
  const _HomeHost();

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
