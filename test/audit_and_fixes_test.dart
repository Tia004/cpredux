import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/document_library.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:cpredux/features/sheet/tab_stats.dart';
import 'package:cpredux/net/session.dart';
import 'package:cpredux/version.dart';
import 'package:cpredux/widgets/dice_3d_table.dart';
import 'package:cpredux/widgets/window_title_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory docs;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_audit_test');
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

  group('Canonical Storage & Library Indexing', () {
    test('AppPaths.sheetsDir returns valid subfolder in dataDir', () {
      final Directory sheetsDir = AppPaths.sheetsDir();
      expect(sheetsDir.existsSync(), isTrue);
      expect(sheetsDir.path, startsWith(AppPaths.dataDir().path));
      expect(p.basename(sheetsDir.path), equals('sheets'));
    });

    test('DocumentLibrary.scan indexes sheets inside sheetsDir', () async {
      final Directory sheetsDir = AppPaths.sheetsDir();
      final AppState state = AppState();
      addTearDown(state.dispose);

      await state.createSheet(name: 'Solo Crow', directory: sheetsDir.path);
      state.save();

      final List<DocumentEntry> entries = DocumentLibrary.scan();
      expect(entries.any((DocumentEntry e) => e.name == 'Solo Crow'), isTrue);
      final DocumentEntry entry = entries.firstWhere((DocumentEntry e) => e.name == 'Solo Crow');
      expect(entry.path, startsWith(sheetsDir.path));
    });
  });

  group('Window Title Bar & Dynamic Version & Update Button', () {
    testWidgets('Displays dynamic version string and update button', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(
              appBar: WindowTitleBar(),
            ),
          ),
        ),
      );

      // Verify dynamic app version string is displayed
      expect(find.text('v$appVersion'), findsOneWidget);

      // Verify update action button is rendered with sync icon
      final Finder updateBtn = find.byTooltip('Verifica aggiornamenti');
      expect(updateBtn, findsOneWidget);
      expect(find.descendant(of: updateBtn, matching: find.byIcon(Icons.sync)), findsOneWidget);

      // Tap update button
      await tester.tap(updateBtn);
      await tester.pump();
    });
  });

  group('Dice Model Solid Geometry & Labeling', () {
    test('DiceType.coin is labeled d2', () {
      expect(DiceType.coin.label, equals('d2'));
    });

    test('D12 has 12 closed regular pentagonal faces and 20 vertices', () {
      final ({int faces, int vertices}) stats = Dice3DTable.getMeshStatsForTesting(DiceType.d12);
      expect(stats.vertices, equals(20));
      expect(stats.faces, equals(12));
    });

    test('D100 has 100 closed regular spherical faces and 82 vertices', () {
      final ({int faces, int vertices}) stats = Dice3DTable.getMeshStatsForTesting(DiceType.d100);
      expect(stats.vertices, equals(82));
      expect(stats.faces, equals(100));
    });

    test('All dice types build with valid vertices and faces', () {
      for (final DiceType type in DiceType.values) {
        final ({int faces, int vertices}) stats = Dice3DTable.getMeshStatsForTesting(type);
        expect(stats.vertices, greaterThan(0));
        expect(stats.faces, greaterThan(0));
      }
    });

    testWidgets('Dice3DTable renders all dice types smoothly', (WidgetTester tester) async {
      for (final DiceType type in DiceType.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CprTheme.dark(),
            home: Scaffold(
              body: Dice3DTable(
                die: type,
                results: const <int>[1],
                total: 1,
                label: type.label,
                modifier: 0,
                isCritical: false,
                isFumble: false,
                revealKey: type.index,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Dice3DTable), findsOneWidget);
      }
    });
  });

  group('Character Sheet Stat Lock & Unlock Flow', () {
    testWidgets('Stats tab shows lock indicator and pencil unlock button with modal confirmation', (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      await state.createSheet(name: 'Alt Cunningham', directory: docs.path);
      state.mutate((CharacterSheet s) {
        s.statBase[Stat.intelligence] = 8;
        s.statBase[Stat.reflexes] = 6;
        s.statBase[Stat.dexterity] = 7;
        s.statBase[Stat.technique] = 8;
        s.statBase[Stat.cool] = 6;
        s.statBase[Stat.willpower] = 7;
        s.statBase[Stat.luck] = 6;
        s.statBase[Stat.movement] = 6;
        s.statBase[Stat.body] = 5;
        s.statBase[Stat.empathy] = 7;
      });
      state.save();

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: StatsTab(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Stats are populated (> 0 total points), so stat lock is active
      // Look for the pencil unlock icon
      final Finder pencilButton = find.byTooltip('Modifica caratteristiche base (richiede conferma)');
      expect(pencilButton, findsOneWidget);
      expect(find.descendant(of: pencilButton, matching: find.byIcon(Icons.edit_outlined)), findsOneWidget);

      // Verify no emoji is used
      expect(find.textContaining('✏️'), findsNothing);

      // Tapping pencil opens confirmation dialog
      await tester.tap(pencilButton);
      await tester.pumpAndSettle();

      expect(find.text('MODIFICA CARATTERISTICHE BASE'), findsOneWidget);
      expect(find.textContaining('I punti caratteristica'), findsOneWidget);

      // Tap confirm button "SBLOCCA MODIFICA"
      final Finder unlockAction = find.text('SBLOCCA MODIFICA');
      expect(unlockAction, findsOneWidget);
      await tester.tap(unlockAction);
      await tester.pumpAndSettle();

      // Dialog is closed
      expect(find.text('MODIFICA CARATTERISTICHE BASE'), findsNothing);

      // Now lock override is active; pencil tooltip changes to 'Blocca modifiche caratteristiche base'
      expect(find.byTooltip('Blocca modifiche caratteristiche base'), findsOneWidget);
      expect(find.text('SBLOCCATO'), findsOneWidget);
      expect(find.byIcon(Icons.lock_open), findsOneWidget);
    });
  });

  group('Automatic Master Sheet Comparison on Player Connect', () {
    test('Master detects sheet differences on player join and opens comparison', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      // 1. Save master's canonical version of the character in library
      final Directory sheetsDir = AppPaths.sheetsDir();
      await state.createSheet(name: 'Johnny Silver', directory: sheetsDir.path);
      state.mutate((CharacterSheet s) {
        s.eurobucks = 500;
        s.statBase[Stat.intelligence] = 6;
        s.statBase[Stat.cool] = 10;
      });
      state.save();
      final CharacterSheet masterSheet = state.sheet!;

      // 2. Incoming player connects with a modified version (e.g. 5000 ED instead of 500)
      final CharacterSheet playerSheet = CharacterSheet.fromJson(masterSheet.toJson());
      playerSheet.eurobucks = 5000;

      final HostedPlayer incomingPlayer = HostedPlayer(id: 'player-01')
        ..characterName = 'Johnny Silver'
        ..state.addAll(<String, Object?>{
          'sheet': playerSheet.toJson(),
        });

      // Verify currently comparison is null
      expect(state.comparison, isNull);

      // 3. Trigger check incoming player sheet
      state.checkIncomingPlayerSheetForTesting(incomingPlayer);

      // 4. Comparison must now be opened automatically!
      expect(state.comparison, isNotNull);
      final Comparison comparison = state.comparison!;
      expect(comparison.after.sheet.eurobucks, equals(5000));
      expect(comparison.before.sheet.eurobucks, equals(500));

      // 5. Test that when an identical sheet connects, comparison is not opened
      state.closeComparison();
      expect(state.comparison, isNull);

      final HostedPlayer identicalPlayer = HostedPlayer(id: 'player-02')
        ..characterName = 'Johnny Silver'
        ..state.addAll(<String, Object?>{
          'sheet': masterSheet.toJson(),
        });

      state.checkIncomingPlayerSheetForTesting(identicalPlayer);
      expect(state.comparison, isNull);
    });
  });
}
