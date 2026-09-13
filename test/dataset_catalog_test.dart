import 'dart:io';

import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/import_dataset_catalog.dart';

/// Il convertitore di un dataset esterno e' l'unico punto in cui i dati di
/// **un'altra applicazione** diventano voci del nostro catalogo.
///
/// Per questo i test non usano il dataset vero (che non e' nel repository):
/// costruiscono pacchetti YAML con la stessa forma e verificano una regola alla
/// volta. Un dataset scaricato non si puo' verificare — cambia sotto i piedi —
/// mentre la mappatura si'.
void main() {
  late Directory temp;
  late Directory packRoot;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_dataset');
    packRoot = Directory('${temp.path}/src/packs/core')..createSync(recursive: true);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// Scrive un pacchetto: `packs` e' una mappa `nomefile -> contenuto YAML`
  /// dentro una cartella (`weapons`, `gear`, ...).
  void pack(String name, Map<String, String> files) {
    final Directory directory = Directory('${packRoot.path}/$name')..createSync(recursive: true);
    files.forEach((String fileName, String content) {
      File('${directory.path}/$fileName').writeAsStringSync(content);
    });
  }

  const String weaponYaml = '''
name: Sternmeyer P-35
type: weapon
system:
  attackmod: 1
  brand: Sternmeyer
  concealable:
    concealable: true
  damage: 3d6
  description:
    value: '<p>An old reliable pistol.</p>'
  fireModes:
    autoFire: 0
    suppressiveFire: false
  handsReq: 1
  magazine:
    max: 8
  price:
    market: 50
  rof: 2
  sources:
    - book: Cyberpunk RED
      page: 341
  weaponSkill: Handgun
  weaponType: medPistol
''';

  const String armorYaml = '''
name: Flak (Head)
type: armor
system:
  bodyLocation:
    sp: 0
  description:
    value: '<p>A flak helmet.</p>'
  headLocation:
    sp: 7
  isBodyLocation: false
  isHeadLocation: true
  isShield: false
  penalty: 0
  price:
    market: 50
  sources:
    - book: Cyberpunk RED
      page: 350
''';

  const String clothingYaml = '''
name: Asia Pop Hat
type: clothing
system:
  amount: 1
  description:
    value: '<p>Bright colors, extravagant style.</p>'
  price:
    market: 20
  style: asiaPop
  type: hats
''';

  const String ammoYaml = '''
name: Rifle (Armor-Piercing)
type: ammo
system:
  amount: 10
  description:
    value: '<p>Double ablation to armor.</p>'
  price:
    market: 100
  sources:
    - book: Cyberpunk RED
      page: 345
  type: armorPiercing
  variety: rifle
''';

  const String gearYaml = '''
name: Medtech Bag
type: gear
system:
  description:
    value: '<p>Everything a medtech needs.</p>'
  price:
    market: 100
''';

  group('conversione di una voce', () {
    test('un\'arma porta danno, cadenza, mani, caricatore e abilita', () {
      pack('weapons', <String, String>{'weapon.sternmeyer_p_35.yaml': weaponYaml});

      final DatasetImport imported = readDataset(packRoot);

      final CatalogItem item = imported.items.single;
      expect(item.id, 'wpn-sternmeyer-p-35');
      expect(item.name, 'Sternmeyer P-35');
      expect(item.category, ItemCategory.weapon);
      expect(item.cost, 50);
      expect(item.source, 'fvtt-cpred');
      expect(item.weapon!.skillId, Skill.handgun.id);
      expect(item.weapon!.damage, '3d6');
      expect(item.weapon!.rof, 2);
      expect(item.weapon!.handsRequired, '1');
      expect(item.weapon!.maxAmmo, 8);
      expect(item.weapon!.isConcealable, isTrue);
      expect(item.weapon!.currentAmmo, 0);
      // Il marchio e il modificatore al tiro non hanno un campo proprio nel
      // catalogo: stanno nelle proprieta', che sono testo libero.
      expect(item.weapon!.properties, contains('Sternmeyer'));
      expect(item.weapon!.properties, contains('+1 al tiro'));
      // La descrizione e' testo leggibile, con la pagina del manuale: e' quello
      // che permette di verificare un dato invece di doversi fidare.
      expect(item.description, 'An old reliable pistol. Cyberpunk RED, p. 341.');
      // Il peso non c'e' nel dataset: resta zero, e il rapporto lo dice.
      expect(item.weight, 0);
      expect(imported.notes.join(' '), contains('non registra il peso'));
    });

    test('un\'armatura usa lo slot giusto e le sue SP', () {
      pack('armor', <String, String>{'armor.flak__head.yaml': armorYaml});

      final CatalogItem item = readDataset(packRoot).items.single;

      expect(item.id, 'arm-flak-head');
      expect(item.category, ItemCategory.armor);
      expect(item.armor!.slot, ArmorSlot.head);
      expect(item.armor!.sp, 7);
      expect(item.armor!.penalties, 0);
    });

    test('uno scudo registra i punti struttura come SP, e lo dichiara', () {
      pack('armor', <String, String>{
        'armor.shield.yaml': '''
name: Bullet Proof Shield
type: armor
system:
  description:
    value: '<p>Requires an arm.</p>'
  isBodyLocation: false
  isHeadLocation: false
  isShield: true
  penalty: 2
  price:
    market: 100
  shieldHitPoints:
    max: 10
''',
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items.single.armor!.slot, ArmorSlot.shield);
      expect(imported.items.single.armor!.sp, 10);
      expect(imported.items.single.armor!.penalties, 2);
      expect(imported.skippedByReason.keys.join(' '), contains('scudi'));
    });

    test('un capo porta slot e stile', () {
      pack('clothing', <String, String>{'clothing.asia_pop_hat.yaml': clothingYaml});

      final CatalogItem item = readDataset(packRoot).items.single;

      expect(item.id, 'clo-asia-pop-hat');
      expect(item.category, ItemCategory.clothing);
      expect(item.clothing!.slot, ClothingSlot.hat);
      expect(item.clothing!.style, ClothingStyle.asiaPop);
    });

    test('uno stile non mappato non perde il capo', () {
      pack('clothing', <String, String>{
        'clothing.strano.yaml': '''
name: Capo Strano
type: clothing
system:
  price:
    market: 10
  style: stileCheNonEsiste
  type: top
''',
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items.single.clothing!.style, ClothingStyle.genericChic);
      expect(imported.skippedByReason.keys.join(' '), contains('stile non mappato'));
    });

    test('le munizioni dicono la confezione', () {
      pack('ammo', <String, String>{'ammo.rifle_ap.yaml': ammoYaml});

      final CatalogItem item = readDataset(packRoot).items.single;

      expect(item.id, 'amm-rifle-armor-piercing');
      expect(item.category, ItemCategory.ammunition);
      expect(item.cost, 100);
      expect(item.description, 'Double ablation to armor. Confezione da 10. Cyberpunk RED, p. 345.');
    });

    test('un cyberdeck e\' equipaggiamento, non cyberware', () {
      pack('gear', <String, String>{
        'cyberdeck.cyberdeck.yaml': '''
name: Cyberdeck
type: cyberdeck
system:
  description:
    value: '<p>Netrunner deck.</p>'
  installedItems:
    slots: 7
  price:
    market: 500
''',
        'cyberware.battleglove.yaml': '''
name: Battleglove
type: cyberware
system:
  price:
    market: 100
''',
        'gear.medtech_bag.yaml': gearYaml,
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items, hasLength(2));
      final CatalogItem deck = imported.items.firstWhere((CatalogItem i) => i.name == 'Cyberdeck');
      expect(deck.category, ItemCategory.equipment);
      expect(deck.description, contains('7 slot per programmi'));
      expect(imported.items.map((CatalogItem i) => i.name), isNot(contains('Battleglove')));
      expect(imported.skippedByReason.keys.join(' '), contains('impianti'));
    });
  });

  group('cosa non entra nel catalogo', () {
    test('le varianti di qualita\' si saltano, contate', () {
      pack('weapons', <String, String>{
        'weapon.sternmeyer_p_35.yaml': weaponYaml,
        'weapon.sternmeyer_p_35_poor.yaml': weaponYaml.replaceAll(
          'name: Sternmeyer P-35',
          'name: Sternmeyer P-35 (Poor)',
        ),
        'weapon.sternmeyer_p_35_excellent.yaml': weaponYaml.replaceAll(
          'name: Sternmeyer P-35',
          'name: Sternmeyer P-35 (Excellent)',
        ),
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items, hasLength(1));
      expect(imported.skippedByReason['varianti di qualita\' (Excellent/Poor)'], 2);
    });

    test('i profili di attacco a mani nude non sono oggetti', () {
      pack('weapons', <String, String>{
        'weapon.unarmed.yaml': weaponYaml.replaceAll('name: Sternmeyer P-35', 'name: Unarmed'),
        'weapon.martial_arts.yaml': weaponYaml.replaceAll('name: Sternmeyer P-35', 'name: Martial Arts'),
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items, isEmpty);
      expect(imported.skippedByReason.keys.join(' '), contains('profili di attacco'));
    });

    test('un\'arma senza danno non entra', () {
      pack('weapons', <String, String>{
        'weapon.rotta.yaml': weaponYaml.replaceAll('damage: 3d6', 'damage: ""'),
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items, isEmpty);
      expect(imported.skippedByReason.keys.join(' '), contains('arma senza danno'));
    });

    test('un\'abilita non mappata ripiega sul tipo d\'arma, e lo dichiara', () {
      pack('weapons', <String, String>{
        'weapon.strana.yaml': weaponYaml.replaceAll('weaponSkill: Handgun', 'weaponSkill: Tiro a Caso'),
      });

      final DatasetImport imported = readDataset(packRoot);

      expect(imported.items.single.weapon!.skillId, Skill.handgun.id);
      expect(imported.skippedByReason.keys.join(' '), contains('dedotta dal tipo'));
    });

    test('un tipo non gestito si salta invece di indovinare', () {
      pack('other', <String, String>{
        'program.program.yaml': '''
name: Sword Program
type: program
system:
  price:
    market: 100
''',
      });

      final DatasetImport imported = readDataset(packRoot, packs: <String>['other']);

      expect(imported.items, isEmpty);
      expect(imported.skippedByReason.keys.join(' '), contains('tipo non gestito'));
    });
  });

  group('equivalenze con le voci curate', () {
    test('il tipo generico si salta se la voce curata esiste', () {
      pack('weapons', <String, String>{
        'weapon.medium_pistol.yaml': weaponYaml.replaceAll(
          'name: Sternmeyer P-35',
          'name: Medium Pistol',
        ),
      });

      final DatasetImport imported = readDataset(
        packRoot,
        curatedIds: <String>{'wpn-medium-pistol'},
      );

      expect(imported.items, isEmpty);
      expect(
        imported.skippedByReason.keys.join(' '),
        contains('gia\' nel seed come tipo generico'),
      );
    });

    test('se la voce curata non c\'e\' piu\', l\'oggetto si importa', () {
      pack('weapons', <String, String>{
        'weapon.medium_pistol.yaml': weaponYaml.replaceAll(
          'name: Sternmeyer P-35',
          'name: Medium Pistol',
        ),
      });

      // Senza identificativi curati (o con uno diverso) non si salta niente:
      // un oggetto perso in silenzio sarebbe peggio di un doppione visibile.
      expect(readDataset(packRoot).items, hasLength(1));
      expect(
        readDataset(packRoot, curatedIds: <String>{'wpn-altro'}).items,
        hasLength(1),
      );
    });
  });

  test('le descrizioni HTML diventano testo', () {
    expect(plainText('<p>Due mani,<br>caricatore capiente.</p>'), 'Due mani, caricatore capiente.');
    expect(plainText('<p>A &amp; B</p>'), 'A & B');
    expect(plainText(null), '');
  });
}
