import 'package:cpredux/app/app.dart';
import 'package:cpredux/design/palette.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/items.dart';
import 'package:cpredux/domain/rules.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:cpredux/widgets/health_heart.dart';
import 'package:cpredux/widgets/humanity_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Imposta una dimensione di finestra logica per il test.
///
/// `devicePixelRatio` a 1 rende `physicalSize` uguale alla dimensione logica,
/// cosi' i numeri nei test si leggono come in un mockup invece che in pixel di
/// dispositivo.
void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Smonta l'albero per fermare le animazioni in loop.
///
/// Il cuore, la spira e il pallino "tavolo aperto" hanno controller in
/// `repeat()`: se il test finisce con l'albero ancora montato, flutter_test
/// segnala un ticker ancora attivo.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Avanza oltre le animazioni di ingresso.
///
/// Non si usa `pumpAndSettle`: con controller in `repeat()` non si
/// stabilizzerebbe mai e il test scadrebbe per timeout.
Future<void> _settleEntrance(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
}

CharacterSheet _sheet() => CharacterSheet.fresh(
      id: 'sheet-test',
      name: 'Test',
      now: '2026-01-01T00:00:00.000',
    );

void main() {
  group('regole', () {
    test('i punti vita massimi seguono la media di Fisico e Volonta', () {
      final CharacterSheet sheet = _sheet();
      sheet.statBase[Stat.body] = 8;
      sheet.statBase[Stat.willpower] = 7;

      final SheetTotals totals = computeTotals(sheet);

      // ceil((8 + 7) / 2) = 8, quindi 10 + 5 * 8 = 50.
      expect(totals.maxHitPoints, 50);
      expect(totals.severeInjuriesThreshold, 25);
    });

    test("l'umanita massima e dieci volte l'Empatia", () {
      final CharacterSheet sheet = _sheet();
      sheet.statBase[Stat.empathy] = 6;
      sheet.identity.currentHumanity = 60;

      final SheetTotals totals = computeTotals(sheet);

      expect(totals.maxEmpathy, 6);
      expect(totals.maxHumanity, 60);
      expect(totals.humanityLost, 0);
    });

    test('il carico massimo e dieci volte il Fisico e lo stato di carico corregge Destrezza', () {
      final CharacterSheet sheet = _sheet();
      sheet.statBase[Stat.body] = 6;
      sheet.statBase[Stat.dexterity] = 6;

      final SheetTotals totals = computeTotals(sheet);

      expect(totals.maxLoad, 60);
      expect(totals.loadStatus, LoadStatus.light);

      // Con il carico leggero il vecchio progetto applica **+1** a Destrezza e
      // Velocita' (LoadStatus.LIGHT ha statsAlterations +1), non zero: essere
      // scarichi e' un vantaggio, non l'assenza di una penalita'. Il port
      // mantiene il comportamento, perche' i valori delle schede esistenti
      // sono calcolati con quella regola.
      expect(totals.statValue(Stat.dexterity), 7);
      expect(totals.statValue(Stat.movement), 2);
    });

    test('sopra il 70% del carico Destrezza e Velocita perdono un punto', () {
      final CharacterSheet sheet = _sheet();
      sheet.statBase[Stat.body] = 5;
      // Un oggetto creato a mano: e' l'unico caso in cui il peso vive dentro
      // la scheda, perche' il catalogo non lo conosce.
      sheet.inventory.add(
        InventoryEntry.customItem(
          CatalogItem(
            id: 'custom-item-zaino',
            name: 'Zaino pieno',
            category: ItemCategory.item,
            weight: 40,
            source: 'custom',
          ),
          id: 'item-1',
        ),
      );

      final SheetTotals totals = computeTotals(sheet);

      // 40 su 50 e' l'80%: stato "Pesante", -1 a Destrezza e Velocita'.
      expect(totals.loadStatus, LoadStatus.heavy);

      // La penalita' c'e' ma non si vede: 1 - 1 fa 0, e il progetto originale
      // blocca ogni caratteristica calcolata a un minimo di 1. Il pavimento
      // vale **dopo** aver sommato tutte le correzioni (carico, armatura,
      // cyberware), quindi non basta applicarlo prima: un personaggio con
      // Destrezza 1 e un'armatura pesante non finisce a -1.
      expect(totals.statValue(Stat.dexterity), 1);
    });

    test('la penalita di carico si vede su una Destrezza alta', () {
      final CharacterSheet sheet = _sheet();
      sheet.statBase[Stat.body] = 5;
      sheet.statBase[Stat.dexterity] = 5;
      sheet.statBase[Stat.movement] = 4;
      sheet.inventory.add(
        InventoryEntry.customItem(
          CatalogItem(
            id: 'custom-item-zaino',
            name: 'Zaino pieno',
            category: ItemCategory.item,
            weight: 40,
            source: 'custom',
          ),
          id: 'item-1',
        ),
      );

      final SheetTotals totals = computeTotals(sheet);

      // Stesso carico "Pesante" del test precedente, ma qui il pavimento a 1
      // non c'entra: si vede la penalita' vera.
      expect(totals.loadStatus, LoadStatus.heavy);
      expect(totals.statValue(Stat.dexterity), 4);
      expect(totals.statValue(Stat.movement), 3);
    });

    test('un tiro di abilita somma caratteristica e abilita', () {
      final CharacterSheet sheet = _sheet();
      sheet.statBase[Stat.reflexes] = 7;
      sheet.skillLevels[Skill.handgun] = 5;

      final SheetTotals totals = computeTotals(sheet);

      expect(totals.skillCheck(Skill.handgun), 12);
    });

    test('i valori predefiniti sono quelli del progetto originale', () {
      final CharacterSheet sheet = _sheet();

      for (final Stat stat in Stat.values) {
        expect(sheet.statBase[stat], 1, reason: 'caratteristica ${stat.label}');
      }
      for (final Skill skill in Skill.values) {
        expect(sheet.skillLevels[skill], skill.isEssential ? 2 : 0, reason: skill.name);
      }
    });
  });

  group('schermate', () {
    testWidgets('il menu si costruisce a dimensione desktop', (WidgetTester tester) async {
      _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(const CpredApp());
      await _settleEntrance(tester);

      expect(find.text('CPRED'), findsWidgets);
      expect(find.text('Nuova scheda'.toUpperCase()), findsNothing);
      expect(find.textContaining('Nuova scheda'), findsWidgets);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('il menu regge una finestra stretta senza andare in overflow',
        (WidgetTester tester) async {
      // 459x949 e' la larghezza reale del pannello di anteprima: se qui il
      // layout regge, regge anche quando l'utente trascina il bordo.
      _setViewport(tester, const Size(459, 949));
      await tester.pumpWidget(const CpredApp());
      await _settleEntrance(tester);

      expect(find.textContaining('Nuova scheda'), findsWidgets);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });
  });

  group('widget vitali', () {
    testWidgets('il cuore mostra i punti vita e regge il flatline', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: CprPalette.surface,
            body: Column(
              children: const <Widget>[
                HealthHeart(current: 38, max: 45),
                HumanityGauge(current: 48, max: 60),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(HealthHeart), findsOneWidget);
      expect(find.byType(HumanityGauge), findsOneWidget);

      // A zero il cuore non deve lanciare: e' lo stato in cui l'app viene
      // guardata piu' spesso di quanto si vorrebbe.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: CprPalette.surface,
            body: Column(
              children: const <Widget>[
                HealthHeart(current: 0, max: 45),
                HumanityGauge(current: 0, max: 60),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });
  });
}
