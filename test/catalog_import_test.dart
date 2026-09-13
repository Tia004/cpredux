import 'dart:io';

import 'package:cpredux/data/catalog.dart';
import 'package:cpredux/data/catalog_seed.dart';
import 'package:cpredux/data/legacy_catalog_import.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'support/legacy_sheet_fixture.dart';

/// Il catalogo deve sapersi nutrire di **dati scritti da un altro programma**.
///
/// La vecchia `.cpred_sheet` e' l'unico insieme di oggetti di gioco che esista
/// davvero: il vecchio progetto non spediva un catalogo, ogni scheda portava i
/// propri oggetti. Questi test verificano due cose distinte e ugualmente
/// importanti: che la lettura capisca quel database, e che il risultato sia
/// **accettabile per il catalogo** — la stessa validazione che gira su quello
/// spedito con l'app.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_import');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Una scheda minima con le sole righe indicate, per i casi limite: la
  /// fixture completa serve a verificare la lettura normale, non gli scarti.
  String minimalSheet({
    String? version = 'cpred_sheet_1.0',
    bool withItemsTable = true,
    List<String> itemRows = const <String>[],
    List<String> weaponRows = const <String>[],
    List<String> armorRows = const <String>[],
    List<String> clothingRows = const <String>[],
  }) {
    final String path = '${temp.path}/minima.cpred_sheet';
    final Database db = sqlite3.open(path);
    db.execute(
      'CREATE TABLE key_parameters (param_key VARCHAR(32) NOT NULL PRIMARY KEY, param_value TEXT);',
    );
    if (version != null) {
      db.execute(
        'INSERT INTO key_parameters (param_key, param_value) VALUES (?, ?);',
        <Object?>['db_version', version],
      );
    }
    if (withItemsTable) {
      db.execute(
        'CREATE TABLE items (id INTEGER NOT NULL PRIMARY KEY, base64image TEXT, image_extension TEXT, '
        'name TEXT NOT NULL UNIQUE, cost INTEGER NOT NULL DEFAULT 0, description TEXT, '
        'rarity INTEGER NOT NULL DEFAULT 0, weight REAL NOT NULL DEFAULT 0, '
        'category INTEGER NOT NULL DEFAULT 0, quantity INTEGER NOT NULL DEFAULT 0);',
      );
      db.execute(
        'CREATE TABLE weapons (id INTEGER NOT NULL PRIMARY KEY, item_id INTEGER NOT NULL UNIQUE, '
        'weapon_skill INTEGER, hands_required TEXT NOT NULL, damage TEXT NOT NULL, '
        'current_ammo INTEGER NOT NULL DEFAULT 0, max_ammo INTEGER NOT NULL DEFAULT 0, '
        'rof INTEGER NOT NULL, is_concealable INTEGER NOT NULL DEFAULT 0, properties TEXT, '
        'is_equipped INTEGER NOT NULL DEFAULT 0);',
      );
      db.execute(
        'CREATE TABLE armors (id INTEGER NOT NULL PRIMARY KEY, item_id INTEGER NOT NULL UNIQUE, '
        'slot INTEGER NOT NULL, sp INTEGER NOT NULL, penalties INTEGER NOT NULL DEFAULT 0, '
        'is_equipped INTEGER NOT NULL DEFAULT 0);',
      );
      db.execute(
        'CREATE TABLE clothing (id INTEGER NOT NULL PRIMARY KEY, item_id INTEGER NOT NULL UNIQUE, '
        'slot INTEGER NOT NULL, style INTEGER NOT NULL, is_equipped INTEGER NOT NULL DEFAULT 0);',
      );
      for (final String row in itemRows) {
        db.execute('INSERT INTO items $row;');
      }
      for (final String row in weaponRows) {
        db.execute('INSERT INTO weapons $row;');
      }
      for (final String row in armorRows) {
        db.execute('INSERT INTO armors $row;');
      }
      for (final String row in clothingRows) {
        db.execute('INSERT INTO clothing $row;');
      }
    }
    db.close();
    return path;
  }

  group('lettura di una vecchia scheda', () {
    test('gli oggetti diventano voci di catalogo con i loro dati specifici', () {
      final String path = '${temp.path}/Scheda.cpred_sheet';
      createLegacySheet(path);

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.version, LegacyCatalogImporter.legacyVersion);
      expect(read.itemCount, 3);
      expect(read.counts[ItemCategory.weapon], 1);
      expect(read.counts[ItemCategory.armor], 1);
      expect(read.counts[ItemCategory.clothing], 1);

      final CatalogItem pistol =
          read.items.firstWhere((CatalogItem i) => i.name == 'Pistola pesante');
      expect(pistol.id, 'legacy-pistola-pesante');
      expect(pistol.category, ItemCategory.weapon);
      expect(pistol.rarity, Rarity.rare);
      expect(pistol.cost, 100);
      expect(pistol.weight, 2.5);
      expect(pistol.description, 'Una mano');
      expect(pistol.source, 'legacy');
      expect(pistol.weapon!.skillId, Skill.handgun.id);
      expect(pistol.weapon!.handsRequired, '1');
      expect(pistol.weapon!.damage, '3d6');
      expect(pistol.weapon!.maxAmmo, 8);
      expect(pistol.weapon!.rof, 2);
      expect(pistol.weapon!.isConcealable, isTrue);
      expect(pistol.weapon!.properties, 'Kick');
      // Le munizioni caricate restano un dato della scheda: nel catalogo non
      // hanno senso, perche' descrivono un esemplare e non l'oggetto.
      expect(pistol.weapon!.currentAmmo, 0);

      final CatalogItem jacket =
          read.items.firstWhere((CatalogItem i) => i.name == 'Giacca corazzata');
      expect(jacket.category, ItemCategory.armor);
      expect(jacket.armor!.slot, ArmorSlot.body);
      expect(jacket.armor!.sp, 11);
      expect(jacket.armor!.penalties, 0);

      final CatalogItem suit =
          read.items.firstWhere((CatalogItem i) => i.name == 'Tuta tecnica');
      expect(suit.category, ItemCategory.clothing);
      expect(suit.clothing!.slot, ClothingSlot.top);
      expect(suit.clothing!.style, ClothingStyle.edgerunner);
    });

    test('dice cosa non e\' entrato nel catalogo, invece di tacerlo', () {
      final String path = '${temp.path}/Scheda.cpred_sheet';
      createLegacySheet(path);

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      // La fixture ha un'immagine Base64 e un'arma con il caricatore pieno:
      // entrambe sono cose che il catalogo **non** porta con se', e l'utente
      // deve poterlo leggere invece di scoprirlo quando l'oggetto e' diverso.
      expect(read.notes.join(' '), contains('immagini'));
      expect(read.notes.join(' '), contains('munizioni caricate'));
      expect(read.skipped, 0);
    });

    test('una categoria fuori scala non fa saltare la voce', () {
      final String path = minimalSheet(
        itemRows: <String>["(id, name, category) VALUES (1, 'Bottino', 42)"],
      );

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.itemCount, 1);
      expect(read.items.single.category, ItemCategory.item);
      expect(read.notes.join(' '), contains('categoria 42'));
    });

    test('un\'abilita sconosciuta ripiega sulla mischia, e lo dichiara', () {
      final String path = minimalSheet(
        itemRows: <String>[
          "(id, name, category) VALUES (1, 'Arma strana', 5)",
        ],
        weaponRows: <String>[
          "(id, item_id, weapon_skill, hands_required, damage, rof) VALUES (1, 1, 99, '1', '1d6', 1)",
        ],
      );

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.items.single.weapon!.skillId, Skill.meleeWeapon.id);
      expect(read.notes.join(' '), contains('abilita\' 99'));
    });

    test('SP negativa riportata a zero: il catalogo la rifiuterebbe', () {
      final String path = minimalSheet(
        itemRows: <String>["(id, name, category) VALUES (1, 'Gilet', 4)"],
        armorRows: <String>[
          "(id, item_id, slot, sp, penalties) VALUES (1, 1, 1, -3, 0)",
        ],
      );

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.items.single.armor!.sp, 0);
      expect(read.notes.join(' '), contains('negativa'));
    });

    test('un oggetto senza nome viene scartato e contato', () {
      final String path = minimalSheet(
        itemRows: <String>[
          "(id, name, category) VALUES (1, '   ', 0)",
          "(id, name, category) VALUES (2, 'Valido', 0)",
        ],
      );

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.itemCount, 1);
      expect(read.skipped, 1);
      expect(read.notes.join(' '), contains('senza nome'));
    });

    test('due oggetti omonimi prendono due identificativi', () {
      final String path = minimalSheet(
        itemRows: <String>[
          "(id, name, category) VALUES (1, 'Coltello', 5)",
          "(id, name, category) VALUES (2, 'Coltello ', 5)",
        ],
      );

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.items, hasLength(2));
      expect(
        read.items.map((CatalogItem i) => i.id).toSet(),
        <String>{'legacy-coltello', 'legacy-coltello-2'},
      );
    });

    test('una scheda senza tabella items non e\' un errore, ma una risposta', () {
      final String path = minimalSheet(withItemsTable: false);

      final LegacyCatalogRead read = LegacyCatalogImporter.read(path);

      expect(read.items, isEmpty);
      expect(read.notes.join(' '), contains('tabella "items"'));
    });

    test('un file che non e\' una scheda viene rifiutato, non interpretato', () {
      final String path = minimalSheet(version: null);

      expect(
        () => LegacyCatalogImporter.read(path),
        throwsA(isA<LegacyCatalogException>()),
      );
    });
  });

  group('fusione nel seed', () {
    test('il seed esistente vince e le voci nuove si aggiungono', () {
      final String path = '${temp.path}/Scheda.cpred_sheet';
      createLegacySheet(path);
      final List<CatalogItem> imported = LegacyCatalogImporter.read(path).items;

      final List<String> problems = <String>[];
      final List<CatalogItem> existing = CatalogSeed.parse(
        File(CatalogSeed.path).readAsStringSync(),
        problems: problems,
      );
      expect(problems, isEmpty, reason: 'Il seed scritto a mano deve essere leggibile.');

      final SeedMerge merge = CatalogSeed.merge(
        existing: existing,
        incoming: imported,
        problems: problems,
      );

      // "Pistola pesante" esiste gia' nel catalogo come "Pistola Pesante": il
      // riconoscimento e' per nome normalizzato, quindi non si duplica.
      expect(merge.added, hasLength(2));
      expect(merge.alreadyPresent.map((CatalogItem i) => i.name), <String>['Pistola pesante']);
      expect(merge.items, hasLength(existing.length + 2));
    });

    test('le voci importate superano la validazione del catalogo', () {
      final String path = '${temp.path}/Scheda.cpred_sheet';
      createLegacySheet(path);
      final List<CatalogItem> imported = LegacyCatalogImporter.read(path).items;
      final List<CatalogItem> existing = CatalogSeed.parse(File(CatalogSeed.path).readAsStringSync());

      final SeedMerge merge = CatalogSeed.merge(existing: existing, incoming: imported);
      final ItemCatalog catalog = ItemCatalog.inMemory(items: merge.items);

      expect(catalog.validate(), isEmpty);
      expect(catalog.itemCount, merge.items.length);
      // Ritrovabile per nome: e' quello che serve per agganciare gli oggetti
      // delle schede gia' esistenti.
      expect(catalog.matchByName('Giacca corazzata')?.id, 'legacy-giacca-corazzata');
      catalog.close();
    });
  });

  group('formato del seed', () {
    test('il seed spedito si legge tutto', () {
      final List<String> problems = <String>[];
      final List<CatalogItem> items = CatalogSeed.parse(
        File(CatalogSeed.path).readAsStringSync(),
        problems: problems,
      );

      expect(problems, isEmpty);
      // Le voci curate a mano restano esattamente quelle: l'importazione
      // aggiunge, non sostituisce.
      expect(items.where((CatalogItem i) => i.source == 'core'), hasLength(63));
      // E il catalogo e' **grande**: la ragione per cui esiste l'importatore e'
      // coprire le categorie del vecchio progetto con oggetti veri.
      expect(items.length, greaterThan(300));
      expect(
        <ItemCategory>{
          for (final CatalogItem item in items) item.category,
        },
        containsAll(ItemCategory.values),
      );
    });

    test('scrivere e rileggere non cambia niente', () {
      final List<CatalogItem> items = CatalogSeed.parse(File(CatalogSeed.path).readAsStringSync());
      final List<CatalogItem> again = CatalogSeed.parse(CatalogSeed.encodeAll(items));

      expect(again, hasLength(items.length));
      for (int i = 0; i < items.length; i++) {
        expect(again[i].id, items[i].id);
        expect(again[i].name, items[i].name);
        expect(again[i].category, items[i].category);
        expect(again[i].rarity, items[i].rarity);
        expect(again[i].cost, items[i].cost);
        expect(again[i].weight, items[i].weight);
        expect(again[i].description, items[i].description);
        expect(again[i].weapon?.skillId, items[i].weapon?.skillId);
        expect(again[i].weapon?.damage, items[i].weapon?.damage);
        expect(again[i].weapon?.maxAmmo, items[i].weapon?.maxAmmo);
        expect(again[i].weapon?.rof, items[i].weapon?.rof);
        expect(again[i].weapon?.isConcealable, items[i].weapon?.isConcealable);
        expect(again[i].armor?.slot, items[i].armor?.slot);
        expect(again[i].armor?.sp, items[i].armor?.sp);
        expect(again[i].clothing?.slot, items[i].clothing?.slot);
        expect(again[i].clothing?.style, items[i].clothing?.style);
      }
      // La scrittura e' **una voce per riga**: e' quello che rende leggibile
      // una diff quando ne cambia una sola. Se una voce occupasse piu' righe,
      // una modifica ne sposterebbe molte e la diff non direbbe piu' cosa e'
      // cambiato.
      final List<String> lines = CatalogSeed.encodeAll(items).split('\n');
      expect(lines.first, '[');
      expect(lines[items.length + 1], ']');
      final List<String> entries = lines.sublist(1, items.length + 1);
      expect(entries.where((String line) => line.trim().isEmpty), isEmpty);
      expect(entries.every((String line) => line.startsWith('  { ')), isTrue);
    });

    test('accetta l\'abilita anche come identificativo numerico', () {
      final List<CatalogItem> items = CatalogSeed.parse('''
[
  { "id": "x", "name": "Prova", "category": "weapon", "weapon": { "skill": 10, "damage": "1d6" } }
]
''');

      expect(items.single.weapon!.skillId, Skill.handgun.id);
    });
  });
}
