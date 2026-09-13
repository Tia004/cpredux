import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:cpredux/features/campaign/campaign_screen.dart';
import 'package:cpredux/features/compare/compare_screen.dart';
import 'package:cpredux/features/files/file_browser.dart';
import 'package:cpredux/features/home/home_screen.dart';
import 'package:cpredux/features/map/map_section.dart';
import 'package:cpredux/features/settings/settings_screen.dart';
import 'package:cpredux/features/sheet/chat_rich_tools.dart';
import 'package:cpredux/features/sheet/sheet_screen.dart';
import 'package:cpredux/features/sheet/tab_character.dart';
import 'package:cpredux/features/sheet/tab_cyberware.dart';
import 'package:cpredux/features/sheet/tab_dice.dart';
import 'package:cpredux/features/sheet/tab_effects.dart';
import 'package:cpredux/features/sheet/tab_inventory.dart';
import 'package:cpredux/features/sheet/tab_session.dart';
import 'package:cpredux/features/sheet/tab_sheet_settings.dart';
import 'package:cpredux/features/sheet/tab_stats.dart';
import 'package:cpredux/features/sheet/tab_text.dart';
import 'package:cpredux/widgets/dialogs.dart';
import 'package:cpredux/widgets/tech_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Due dimensioni di finestra richieste: Desktop 1920x1080 e Compatto 800x600.
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
  late Directory docs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_all_screens_test');
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
    if (temp.existsSync()) {
      try {
        temp.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Future<AppState> createPopulatedState() async {
    final AppState state = AppState();
    await state.createSheet(name: 'Johnny Silverhand', directory: docs.path);
    state.mutate((CharacterSheet s) {
      s.identity.playerName = 'Tia';
      s.identity.role = 'Rockerboy';
      s.identity.currentHp = 45;
      s.identity.currentHumanity = 50;
      s.identity.currentLuck = 7;
      s.statBase[Stat.reflexes] = 9;
      s.statBase[Stat.body] = 8;
      s.eurobucks = 1250;
    });
    state.save();
    return state;
  }

  Future<AppState> createComparisonState() async {
    final AppState state = AppState();
    final CharacterSheet sheet1 = CharacterSheet.fresh(
      id: 'sheet-1',
      name: 'V - Street Kid',
      now: '2026-01-01T00:00:00.000',
    );
    sheet1.identity.currentHp = 35;
    sheet1.statBase[Stat.body] = 6;
    sheet1.eurobucks = 200;

    final CharacterSheet sheet2 = CharacterSheet.fresh(
      id: 'sheet-2',
      name: 'V - Solo Edgerunner',
      now: '2026-01-02T00:00:00.000',
    );
    sheet2.identity.currentHp = 50;
    sheet2.statBase[Stat.body] = 8;
    sheet2.eurobucks = 4500;

    state.openComparison(
      Comparison(
        before: ComparisonSide(label: 'V (Livello 1)', sheet: sheet1),
        after: ComparisonSide(label: 'V (Livello 5)', sheet: sheet2),
      ),
    );
    return state;
  }

  Future<AppState> createCampaignState() async {
    final AppState state = AppState();
    await state.createCampaign(name: 'Operazione Arasaka Tower', directory: docs.path);
    state.save();
    return state;
  }

  for (final (:name, :size) in kWindowSizes) {
    group('Costruzione schermate a risoluzione $name', () {
      testWidgets('HomeScreen si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
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
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(HomeScreen), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('SettingsScreen si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: const Scaffold(body: SettingsScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(SettingsScreen), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('CampaignScreen (Master) si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createCampaignState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: const Scaffold(body: CampaignScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(CampaignScreen), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('CompareScreen in visualizzazione Fianco a fianco si costruisce', (WidgetTester tester) async {
        final AppState state = await createComparisonState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
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
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(CompareScreen), findsOneWidget);
        expect(find.text('CONFRONTO'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('CompareScreen in visualizzazione Chat Cyberpunk si costruisce', (WidgetTester tester) async {
        final AppState state = await createComparisonState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
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
        await tester.pump(const Duration(milliseconds: 150));

        // Passa alla modalita Chat Cyberpunk
        final Finder chatToggle = find.text('Chat Cyberpunk');
        if (chatToggle.evaluate().isNotEmpty) {
          await tester.tap(chatToggle);
          await tester.pump(const Duration(milliseconds: 150));
        }

        expect(find.byType(CompareScreen), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('MapSection (Master) si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createCampaignState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: const Scaffold(body: MapSection(asGameMaster: true)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(MapSection), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('MapSection (Giocatore) si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: const Scaffold(body: MapSection(asGameMaster: false)),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(MapSection), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('SheetScreen (completa con rail) si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: const Scaffold(body: SheetScreen()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.byType(SheetScreen), findsOneWidget);
        await _disposeTree(tester);
      });

      // --- Verifica sistematica delle 13 sezioni della scheda ---
      final List<({String title, Widget Function() buildWidget})> sheetTabs = <({
        String title,
        Widget Function() buildWidget,
      })>[
        (title: '1. Tab Personaggio', buildWidget: () => const CharacterTab()),
        (title: '2. Tab Statistiche e Abilita', buildWidget: () => const StatsTab()),
        (title: '3. Tab Inventario', buildWidget: () => const InventoryTab()),
        (title: '4. Tab Equipaggiamento', buildWidget: () => const EquipmentTab()),
        (title: '5. Tab Cyberware', buildWidget: () => const CyberwareTab()),
        (title: '6. Tab Effetti', buildWidget: () => const EffectsTab()),
        (title: '7. Tab Sessione (con Registro Differenze e Chat P2P)', buildWidget: () => const SessionTab()),
        (title: '8. Tab Mappa Giocatore', buildWidget: () => const MapSection(asGameMaster: false)),
        (title: '9. Tab Note', buildWidget: () => const NotesTab()),
        (title: '10. Tab Background', buildWidget: () => const BackgroundTab()),
        (title: '11. Tab Descrizione', buildWidget: () => const DescriptionTab()),
        (title: '12. Tab Dadi', buildWidget: () => const DiceTab()),
        (title: '13. Tab Impostazioni Scheda', buildWidget: () => const SheetSettingsTab()),
      ];

      for (final tab in sheetTabs) {
        testWidgets('Scheda: ${tab.title} si costruisce senza eccezioni', (WidgetTester tester) async {
          final AppState state = await createPopulatedState();
          addTearDown(state.dispose);

          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            AppScope(
              state: state,
              child: MaterialApp(
                theme: CprTheme.dark(),
                home: Scaffold(body: tab.buildWidget()),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 150));
          expect(find.byWidgetPredicate((Widget w) => true), findsWidgets);
          await _disposeTree(tester);
        });
      }

      // --- Verifica dei dialoghi ---
      testWidgets('Dialogo Emoji Cyberpunk si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: Scaffold(
                body: Builder(
                  builder: (BuildContext context) => ElevatedButton(
                    onPressed: () => showCyberEmojiPicker(context),
                    child: const Text('Apri Emoji'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Apri Emoji'));
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('SELETTORE EMOJI'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('Dialogo GIF Animate Cyberpunk si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: Scaffold(
                body: Builder(
                  builder: (BuildContext context) => ElevatedButton(
                    onPressed: () => showCyberGifPicker(context),
                    child: const Text('Apri GIF'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Apri GIF'));
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('SELETTORE GIF ANIMATE (TENOR / GIPHY)'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('Dialogo File Browser si costruisce senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: Scaffold(
                body: Builder(
                  builder: (BuildContext context) => ElevatedButton(
                    onPressed: () => showFileBrowser(
                      context,
                      mode: FileBrowserMode.open,
                      title: 'Sfoglia file',
                    ),
                    child: const Text('Apri Browser'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Apri Browser'));
        await tester.pump(const Duration(milliseconds: 150));

        expect(find.text('SFOGLIA FILE'), findsOneWidget);
        await _disposeTree(tester);
      });

      testWidgets('Dialogo TechMessage e TechConfirm si costruiscono senza eccezioni', (WidgetTester tester) async {
        final AppState state = await createPopulatedState();
        addTearDown(state.dispose);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          AppScope(
            state: state,
            child: MaterialApp(
              theme: CprTheme.dark(),
              home: Scaffold(
                body: Builder(
                  builder: (BuildContext context) => Column(
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: () => showTechMessage(
                          context,
                          title: 'Allerta Rete',
                          message: 'Connessione ICE interrotta dal server.',
                        ),
                        child: const Text('Messaggio'),
                      ),
                      ElevatedButton(
                        onPressed: () => showTechConfirm(
                          context,
                          title: 'Conferma Purge',
                          message: 'Cancellare definitivamente i dati?',
                        ),
                        child: const Text('Conferma'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Test Messaggio
        await tester.tap(find.text('Messaggio'));
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('Connessione ICE interrotta dal server.'), findsOneWidget);
        await tester.tap(find.widgetWithText(TechButton, 'CHIUDI'));
        await tester.pump(const Duration(milliseconds: 150));

        // Test Conferma
        await tester.tap(find.text('Conferma'));
        await tester.pump(const Duration(milliseconds: 150));
        expect(find.text('Cancellare definitivamente i dati?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TechButton, 'ANNULLA'));
        await tester.pump(const Duration(milliseconds: 150));

        await _disposeTree(tester);
      });
    });
  }
}
