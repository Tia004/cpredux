import 'dart:convert';
import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/catalog.dart';
import 'package:cpredux/data/catalog_schema.dart';
import 'package:cpredux/data/document_upgrade.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/features/sheet/tab_inventory.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/items.dart';
import 'package:cpredux/domain/rules.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Il catalogo **spedito con l'app**, non uno costruito nel test.
///
/// Il catalogo e' un asset generato da `tool/build_catalog.dart`: se il seed si
/// rompe, o se qualcuno modifica il seed e dimentica di rigenerare il database,
/// i test devono accorgersene qui — non l'utente, al primo avvio.
ItemCatalog _shipped() {
  final String path = p.join('assets', 'catalog', 'catalog.sqlite');
  expect(
    File(path).existsSync(),
    isTrue,
    reason: 'Catalogo assente: esegui `dart run tool/build_catalog.dart`.',
  );
  expect(
    p.normalize(path).replaceAll(r'\', '/'),
    ItemCatalog.assetKey,
    reason: 'Il file generato e il percorso dichiarato in pubspec devono coincidere.',
  );
  return ItemCatalog.openFile(path, readOnly: true);
}

/// Costruisce una voce d'inventario nel **vecchio formato grasso** (v1), quella
/// in cui l'oggetto era copiato per intero dentro la scheda.
Map<String, Object?> _fatEntry(CatalogItem item, {String id = 'item-0'}) => <String, Object?>{
      'id': id,
      'name': item.name,
      'category': item.category.id,
      'rarity': item.rarity.name,
      'cost': item.cost,
      'description': item.description,
      'weight': item.weight,
      'quantity': 2,
      'isEquipped': true,
      if (item.weapon != null)
        'weapon': <String, Object?>{
          'skillId': item.weapon!.skillId,
          'handsRequired': item.weapon!.handsRequired,
          'damage': item.weapon!.damage,
          'currentAmmo': 3,
          'maxAmmo': item.weapon!.maxAmmo,
          'rof': item.weapon!.rof,
          'isConcealable': item.weapon!.isConcealable,
          'properties': item.weapon!.properties,
        },
      if (item.armor != null)
        'armor': <String, Object?>{
          'slot': item.armor!.slot.id,
          'sp': item.armor!.sp,
          'penalties': item.armor!.penalties,
        },
      if (item.clothing != null)
        'clothing': <String, Object?>{
          'slot': item.clothing!.slot.name,
          'style': item.clothing!.style.name,
        },
    };

Map<String, Object?> _payloadWith(List<Object?> inventory) => <String, Object?>{
      'formatVersion': 1,
      'meta': <String, Object?>{'id': 'sheet-x', 'name': 'Prova'},
      'inventory': inventory,
    };

void main() {
  test('il catalogo spedito si apre, e coerente e indicizzato', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    expect(
      catalog.itemCount,
      greaterThan(50),
      reason: 'Un catalogo quasi vuoto non serve a nessuno.',
    );
    expect(catalog.version, CatalogSchema.version);
    expect(
      catalog.validate(),
      isEmpty,
      reason: 'Le voci spedite devono superare i controlli di integrita.',
    );

    // Le categorie che il filtro della UI puo' mostrare devono esistere davvero:
    // una categoria vuota sarebbe un filtro che non trova mai nulla.
    expect(catalog.categories(), isNotEmpty);
    expect(catalog.all().map((CatalogItem i) => i.id).toSet(), hasLength(catalog.itemCount));
  });

  test('il catalogo esce dall asset, si estrae e si riapre in sola lettura', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final Directory temp = Directory.systemTemp.createTempSync('cpredux_catalog_asset');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    addTearDown(AppPaths.clearOverrides);
    AppPaths.overrideForTesting(config: temp.path, data: temp.path);

    final ItemCatalog catalog = await ItemCatalog.loadBundled();
    addTearDown(catalog.close);

    // E' il percorso che fa l'app all'avvio. Un catalogo che non si carica non
    // fa fallire l'avvio, quindi senza questo test il sintomo sarebbe
    // "gli oggetti non si agganciano al catalogo", e nessuno saprebbe perche'.
    expect(
      catalog.itemCount,
      greaterThan(0),
      reason: 'Il catalogo non si e caricato dall asset spedito.',
    );
    expect(
      File(p.join(AppPaths.configDir().path, 'catalog', 'catalog.sqlite')).existsSync(),
      isTrue,
      reason: 'La copia su disco non e stata creata.',
    );
  });

  test('la ricerca per nome e per categoria si comporta come al tavolo', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final CatalogItem anyWeapon = catalog
        .search(category: ItemCategory.weapon, limit: 1)
        .first;

    // "Contiene", non "inizia con": al tavolo si cerca "pisto" e ci si aspetta
    // anche "Pistola pesante". Con la ricerca per prefisso non uscirebbe nulla.
    final String fragment = anyWeapon.name.toLowerCase().substring(0, 4);
    final List<CatalogItem> found = catalog.search(query: fragment);
    expect(found, isNotEmpty);
    expect(
      found.every((CatalogItem i) => i.name.toLowerCase().contains(fragment)),
      isTrue,
    );

    final List<CatalogItem> weapons = catalog.search(category: ItemCategory.weapon);
    expect(weapons, isNotEmpty);
    expect(
      weapons.every((CatalogItem i) => i.category == ItemCategory.weapon),
      isTrue,
    );

    final List<CatalogItem> rare = catalog.search(rarity: Rarity.rare);
    expect(rare.every((CatalogItem i) => i.rarity == Rarity.rare), isTrue);
  });

  test('il riconoscimento per nome ignora maiuscole e punteggiatura', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final CatalogItem item = catalog.all().firstWhere((CatalogItem i) => i.name.contains(' '));

    final CatalogItem? noisy = catalog.matchByName('  ${item.name.toUpperCase()} !  ');
    expect(noisy?.id, item.id);

    expect(catalog.matchByName('  '), isNull);
    expect(catalog.matchByName('Oggetto che non esiste di sicuro'), isNull);
    // Il nome normalizzato non deve poter combaciare con una voce diversa per
    // via della sola punteggiatura.
    expect(CatalogItem.matchKey(item.name), CatalogItem.matchKey(item.name.replaceAll('-', ' ')));
  });

  test('una voce v1 riconosciuta diventa un riferimento e la scheda si alleggerisce', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final CatalogItem item = catalog.search(category: ItemCategory.weapon, limit: 1).first;
    final Map<String, Object?> fat = _fatEntry(item);

    final DocumentUpgradeResult result = DocumentUpgrade.upgrade(
      _payloadWith(<Object?>[fat]),
      fromVersion: 1,
      toVersion: 2,
      catalog: catalog,
    );

    expect(result.upgraded, isTrue);
    expect(result.counts['riconosciuti dal catalogo'], 1);
    expect(result.notes, isNotEmpty);

    final Map<String, Object?> thin = readInventory(result.payload).single.toJson();

    // L'oggetto non e' piu' dentro la scheda: c'e' solo il riferimento.
    expect(thin['catalogId'], item.id);
    expect(thin, isNot(contains('custom')));
    expect(thin, isNot(contains('weapon')));

    // E il file, di conseguenza, e' molto piu' piccolo. E' la proprieta' che
    // rende una scheda da cinquanta oggetti una scheda da pochi KB.
    expect(
      jsonEncode(thin).length * 2,
      lessThan(jsonEncode(fat).length),
      reason: 'La voce leggera non e\' piu\' leggera di quella grassa.',
    );

    // Cio' che l'utente vede non cambia: il resto arriva dal catalogo.
    final CharacterSheet sheet = CharacterSheet.fromJson(result.payload);
    final ResolvedItem resolved =
        ResolvedItem.resolveAll(sheet.inventory, catalog.byId).single;
    expect(resolved.name, item.name);
    expect(resolved.weapon?.damage, item.weapon!.damage);
    expect(resolved.weapon?.currentAmmo, 3, reason: 'Le munizioni sono stato d\'istanza.');
    expect(resolved.entry.quantity, 2);
    expect(resolved.entry.isEquipped, isTrue);
    expect(resolved.isPersonalised, isFalse);
  });

  test('una voce modificata conserva solo le differenze', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final CatalogItem item = catalog.all().firstWhere((CatalogItem i) => i.cost > 0);
    final Map<String, Object?> fat = _fatEntry(item)..['cost'] = item.cost + 137;

    final DocumentUpgradeResult result = DocumentUpgrade.upgrade(
      _payloadWith(<Object?>[fat]),
      fromVersion: 1,
      toVersion: 2,
      catalog: catalog,
    );

    final Map<String, Object?> thin = readInventory(result.payload).single.toJson();
    expect(thin['catalogId'], item.id);
    expect(thin['overrides'], <String, Object?>{'cost': item.cost + 137});

    // Un solo campo toccato: tutto il resto continua a seguire il catalogo.
    expect(result.counts['con personalizzazioni'], 1);
    final CharacterSheet sheet = CharacterSheet.fromJson(result.payload);
    final ResolvedItem resolved =
        ResolvedItem.resolveAll(sheet.inventory, catalog.byId).single;
    expect(resolved.cost, item.cost + 137);
    expect(resolved.name, item.name, reason: 'Il nome non era stato modificato.');
  });

  test('una voce che il catalogo non conosce non perde nulla', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final Map<String, Object?> fat = <String, Object?>{
      'id': 'item-9',
      'name': 'Fucile a rotaia di contrabbando',
      'category': ItemCategory.weapon.id,
      'rarity': Rarity.exotic.name,
      'cost': 12345,
      'description': 'Modificato a mano in officina',
      'weight': 6.25,
      'quantity': 1,
      'weapon': <String, Object?>{
        'skillId': 10,
        'handsRequired': '2',
        'damage': '6d6',
        'maxAmmo': 4,
        'rof': 2,
      },
    };

    final DocumentUpgradeResult result = DocumentUpgrade.upgrade(
      _payloadWith(<Object?>[fat]),
      fromVersion: 1,
      toVersion: 2,
      catalog: catalog,
    );

    final Map<String, Object?> thin = readInventory(result.payload).single.toJson();
    expect(thin, isNot(contains('catalogId')));
    expect(result.counts['oggetti personalizzati'], 1);

    // La definizione viaggia con la scheda, intera: e' l'unica copia che esiste.
    final CharacterSheet sheet = CharacterSheet.fromJson(result.payload);
    final ResolvedItem resolved =
        ResolvedItem.resolveAll(sheet.inventory, catalog.byId).single;
    expect(resolved.isCustom, isTrue);
    expect(resolved.name, 'Fucile a rotaia di contrabbando');
    expect(resolved.cost, 12345);
    expect(resolved.unitWeight, 6.25);
    expect(resolved.rarity, Rarity.exotic);
    expect(resolved.description, 'Modificato a mano in officina');
    expect(resolved.weapon?.damage, '6d6');
    expect(resolved.weapon?.maxAmmo, 4);
  });

  group('interfaccia', () {
    /// Un catalogo minimo, costruito nel test: cosi' l'aspettativa e' leggibile
    /// e non dipende da quale voce e' capitata per prima nel catalogo spedito.
    CatalogItem pistol() => CatalogItem(
          id: 'wpn-test-pistol',
          name: 'Pistola di Prova',
          category: ItemCategory.weapon,
          rarity: Rarity.rare,
          cost: 500,
          weight: 2,
          source: 'core',
          weapon: WeaponData(
            skillId: Skill.handgun.id,
            damage: '3d6',
            maxAmmo: 8,
            rof: 2,
          ),
        );

    Future<AppState> openInventory(WidgetTester tester, ItemCatalog catalog,
        {ItemOverride? overrides}) async {
      final Directory temp = Directory.systemTemp.createTempSync('cpredux_inventory_ui');
      addTearDown(() {
        if (temp.existsSync()) temp.deleteSync(recursive: true);
      });

      final AppState state = AppState(catalog: catalog);
      addTearDown(state.dispose);
      await state.createSheet(name: 'Prova', directory: temp.path);
      state.mutate(
        (CharacterSheet s) => s.inventory.add(
          InventoryEntry.fromCatalog(pistol(), id: 'item-1')..overrides = overrides ?? ItemOverride(),
        ),
      );

      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: InventoryTab()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      return state;
    }

    /// Smonta l'albero per fermare le animazioni in loop, e lascia scadere il
    /// timer del salvataggio automatico: se il test finisce prima, flutter_test
    /// lo segnala come timer ancora pendente e il test fallisce per una ragione
    /// che non ha niente a che vedere con cio' che stava verificando.
    Future<void> disposeTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
    }

    testWidgets('l inventario legge il catalogo e non la copia nella scheda',
        (WidgetTester tester) async {
      final ItemCatalog catalog = ItemCatalog.inMemory(items: <CatalogItem>[pistol()]);
      addTearDown(catalog.close);

      await openInventory(tester, catalog);

      // Nome e peso arrivano dal catalogo: nella scheda c'e' solo il riferimento.
      expect(find.text('Pistola di Prova'), findsOneWidget);
      expect(find.textContaining('Danno 3d6'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await disposeTree(tester);
    });

    testWidgets('una voce personalizzata si riconosce a colpo d occhio',
        (WidgetTester tester) async {
      final ItemCatalog catalog = ItemCatalog.inMemory(items: <CatalogItem>[pistol()]);
      addTearDown(catalog.close);

      await openInventory(tester, catalog, overrides: ItemOverride(cost: 999));

      // Il costo modificato vince su quello di catalogo, e la riga lo dice.
      expect(find.text('999'), findsOneWidget);
      expect(find.text('PERS.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await disposeTree(tester);
    });

    testWidgets('il selettore del catalogo si apre dalla scheda', (WidgetTester tester) async {
      final ItemCatalog catalog = ItemCatalog.inMemory(items: <CatalogItem>[pistol()]);
      addTearDown(catalog.close);

      await openInventory(tester, catalog);

      await tester.tap(find.text('DAL CATALOGO'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CATALOGO OGGETTI'), findsOneWidget);
      expect(find.text('Pistola di Prova'), findsWidgets);
      expect(tester.takeException(), isNull);

      await disposeTree(tester);
    });
  });

  test('un catalogo assente non fa fallire la conversione', () {
    final Map<String, Object?> fat = <String, Object?>{
      'id': 'item-0',
      'name': 'Pistola pesante',
      'category': ItemCategory.weapon.id,
      'weight': 2.5,
      'quantity': 1,
    };

    // Senza catalogo ogni voce resta definita dentro la scheda: si perde la
    // possibilita' di aggiornare gli oggetti, non gli oggetti.
    final DocumentUpgradeResult result = DocumentUpgrade.upgrade(
      _payloadWith(<Object?>[fat]),
      fromVersion: 1,
      toVersion: 2,
    );

    expect(result.counts['oggetti personalizzati'], 1);
    final Map<String, Object?> thin = readInventory(result.payload).single.toJson();
    expect(thin['custom'], isNotNull);
  });

  test('un armatura di catalogo equipaggiata penalizza davvero', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final CatalogItem armor = catalog.byId('arm-metalgear')!;

    // La penalita' e' una **grandezza**: se il catalogo la spedisse negativa,
    // il motore la ignorerebbe e la corazza piu' pesante del gioco non
    // penalizzerebbe nulla. E' un errore che non fa fallire niente a occhio, e
    // per questo va bloccato qui.
    expect(
      armor.armor!.penalties,
      greaterThan(0),
      reason: 'Le penalita di armatura si esprimono come valore positivo.',
    );

    final CharacterSheet sheet =
        CharacterSheet.fresh(id: 's', name: 'Prova', now: '2026-01-01T00:00:00.000');
    sheet.statBase[Stat.body] = 10;
    sheet.statBase[Stat.reflexes] = 8;
    sheet.statBase[Stat.dexterity] = 8;
    sheet.inventory.add(
      InventoryEntry.fromCatalog(armor, id: 'item-0')..isEquipped = true,
    );

    final SheetTotals totals = computeTotals(sheet, lookup: catalog.byId);

    // Riflessi non dipendono mai dal carico: 8 - 4.
    expect(totals.statValue(Stat.reflexes), 8 - armor.armor!.penalties);
    // Destrezza invece subisce **anche** il carico, e a questo peso il carico e'
    // "Leggero" (+1): 8 + 1 - 4.
    expect(totals.loadStatus, LoadStatus.light);
    expect(totals.statValue(Stat.dexterity), 8 + 1 - armor.armor!.penalties);
  });

  test('una voce disarmata non penalizza e una armata in zaino nemmeno', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    final CatalogItem armor = catalog.byId('arm-metalgear')!;
    final CharacterSheet sheet =
        CharacterSheet.fresh(id: 's', name: 'Prova', now: '2026-01-01T00:00:00.000');
    sheet.statBase[Stat.body] = 10;
    sheet.statBase[Stat.reflexes] = 8;
    // Presente in inventario ma non equipaggiata: pesa, non penalizza.
    sheet.inventory.add(InventoryEntry.fromCatalog(armor, id: 'item-0'));

    final SheetTotals totals = computeTotals(sheet, lookup: catalog.byId);
    expect(totals.statValue(Stat.reflexes), 8);
  });

  test('le voci di catalogo non hanno immagini ufficiali', () {
    final ItemCatalog catalog = _shipped();
    addTearDown(catalog.close);

    // L'artwork di Cyberpunk RED e' di R. Talsorian Games e non viene spedito.
    // Le immagini sono uno slot che l'utente puo' riempire: se un giorno
    // qualcuno ne aggiunge una, deve essere una scelta consapevole e non un
    // effetto collaterale del generatore.
    final List<CatalogItem> withImage =
        catalog.all().where((CatalogItem i) => i.imageAsset != null).toList();
    expect(withImage, isEmpty);
  });
}
