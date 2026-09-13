// Importa nel catalogo gli oggetti di un **dataset esterno**.
//
// Il dataset di riferimento e' il sistema Foundry VTT "Cyberpunk RED - Core"
// (Project Red Team, https://gitlab.com/cyberpunk-red-team/fvtt-cyberpunk-red-core),
// contenuto non ufficiale pubblicato sotto la Homebrew Content Policy di
// R. Talsorian Games. Il repository non viene copiato in questo progetto: si
// scarica a parte e questo script legge i suoi pacchetti YAML.
//
// Perche' da un dataset e non a mano: sono centinaia di voci con danno,
// cadenza di tiro, capienza del caricatore, SP e penalita'. Ricopiarle a mano
// significa introdurre errori che nessuno notera' finche' non sono al tavolo.
// Qui la conversione e' meccanica, ripetibile e **dichiarata**: ogni voce
// importata porta `source: fvtt-cpred`, cosi' l'app puo' dire da dove viene un
// dato invece di presentare tutto come ugualmente autorevole.
//
// Uso:
//   git clone --depth 1 --filter=blob:none --sparse \
//     https://gitlab.com/cyberpunk-red-team/fvtt-cyberpunk-red-core.git /tmp/fvtt-cpred
//   cd /tmp/fvtt-cpred && git sparse-checkout set src/packs/core
//
//   dart run tool/import_dataset_catalog.dart --source /tmp/fvtt-cpred --dry-run
//   dart run tool/import_dataset_catalog.dart --source /tmp/fvtt-cpred
//   dart run tool/build_catalog.dart
//
// Il seed esistente vince sempre: questo script aggiunge, non corregge.

import 'dart:io';

import 'package:cpredux/data/catalog_seed.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/items.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:yaml/yaml.dart';

/// I pacchetti che corrispondono alle categorie di oggetti del progetto.
///
/// Restano fuori, di proposito: `cyberware` (ha un modello suo, con il costo in
/// umanita'), `drugs`, `programs`, `vehicles`, `upgrades` e le tabelle di
/// regole. Sono contenuti diversi, e mescolarli al catalogo oggetti
/// significherebbe un catalogo che non si sa piu' cosa contiene.
const List<String> defaultPacks = <String>[
  'weapons',
  'weapons-branded',
  'ammo',
  'armor',
  'clothing',
  'gear',
];

/// Le voci del dataset che **sono lo stesso oggetto** di una voce gia' nel seed.
///
/// Nel seed i tipi generici hanno il nome italiano ("Pistola Pesante"); il
/// dataset ha lo stesso oggetto in inglese ("Heavy Pistol"). Il riconoscimento
/// per nome non li vede, quindi senza questa tabella il catalogo conterrebbe due
/// volte la stessa cosa — una seria e una no.
///
/// La tabella e' scritta a mano di proposito: e' una decisione, non un'euristica.
/// Una regola automatica ("stesso danno, stesso tipo") accoppierebbe anche
/// oggetti diversi, e un oggetto perso in silenzio e' peggio di un doppione
/// visibile. Vale **solo se l'identificativo indicato esiste davvero nel seed**:
/// se un giorno la voce curata sparisce, l'oggetto del dataset viene importato
/// invece di essere saltato verso il nulla.
///
/// Le chiavi sono `pacchetto/nomefile-senza-estensione`.
const Map<String, String> _curatedCounterparts = <String, String>{
  // Armi: i tipi generici del manuale.
  'weapons/medium_pistol': 'wpn-medium-pistol',
  'weapons/heavy_pistol': 'wpn-heavy-pistol',
  'weapons/very_heavy_pistol': 'wpn-very-heavy-pistol',
  'weapons/smg': 'wpn-smg',
  'weapons/heavy_smg': 'wpn-heavy-smg',
  'weapons/shotgun': 'wpn-shotgun',
  'weapons/assault_rifle': 'wpn-assault-rifle',
  'weapons/sniper_rifle': 'wpn-sniper-rifle',
  'weapons/bow': 'wpn-bow',
  'weapons/grenade_launcher': 'wpn-grenade-launcher',
  'weapons/rocket_launcher': 'wpn-rocket-launcher',
  'weapons/flamethrower': 'wpn-flamethrower',
  'weapons/light_melee': 'wpn-melee-light',
  'weapons/medium_melee': 'wpn-melee-medium',
  'weapons/heavy_melee': 'wpn-melee-heavy',
  'weapons/very_heavy_melee': 'wpn-melee-very-heavy',

  // Armature: solo le parti che il seed copre gia'.
  'armor/leathers_head': 'arm-leathers',
  'armor/leathers_body': 'arm-leathers-body',
  'armor/kevlar__body': 'arm-kevlar',
  'armor/kevlar__head': 'arm-kevlar-helmet',
  'armor/light_armorjack_body': 'arm-light-armorjack',
  'armor/medium_armorjack_body': 'arm-medium-armorjack',
  'armor/heavy_armorjack_body': 'arm-heavy-armorjack',
  'armor/flak_body': 'arm-flak',
  'armor/metalgear__body': 'arm-metalgear',
  'armor/bodyweight_suit': 'arm-bodyweight-suit',
  'armor/bullet_proof_shield': 'arm-bulletproof-shield',

  // Abbigliamento: i sette capi generici del seed.
  'clothing/generic_chic_top': 'clo-top-generic',
  'clothing/generic_chic_bottoms': 'clo-bottom-generic',
  'clothing/generic_chic_hat': 'clo-hat',
  'clothing/generic_chic_footwear': 'clo-shoes',
  'clothing/generic_chic_mirrorshades': 'clo-mirrorshades',
  'clothing/urban_flash_jacket': 'clo-jacket-urban',
  'clothing/nomad_leathers_jacket': 'clo-jacket-leather',

  // Equipaggiamento. Munizioni escluse di proposito: il dataset le distingue
  // per famiglia d'arma (pistola, fucile, fucile a pompa...), quindi non sono
  // lo stesso oggetto delle voci generiche del seed, che restano utili a chi
  // non vuole distinguere.
  'gear/agent': 'gear-agent',
  'gear/binoculars': 'gear-binoculars',
  'gear/duct_tape': 'gear-duct-tape',
  'gear/flashlight': 'gear-flashlight',
  'gear/cyberdeck': 'gear-carried-cyberdeck',
  'gear/medtech_bag': 'gear-medkit',
  'gear/radio_communicator': 'gear-radio',
  'gear/rope_60m_yd': 'gear-rope',
  'gear/grapple_gun': 'gear-grapple',
  'gear/techtool': 'gear-toolkit',
  'gear/techscanner': 'gear-techscanner',
  'gear/lock_picking_set': 'gear-lockpick',
  'gear/kibble_pack': 'gear-kibble',
  'gear/inflatable_bed___sleep_bag': 'gear-sleeping-bag',
};

/// Le voci che **non sono oggetti da catalogo**, con il motivo.
///
/// Nel dataset i profili di attacco a mani nude stanno nella stessa cartella
/// delle armi, e le protesi dermiche stanno nella cartella delle armature
/// perche' il sistema le usa per calcolare la protezione. Nel catalogo
/// sarebbero rispettivamente voci che nessuno compra e armature da 0 eb che
/// sono in realta' cyberware.
const Map<String, String> _notCatalogItems = <String, String>{
  'weapons/unarmed': 'profili di attacco, non oggetti',
  'weapons/martial_arts': 'profili di attacco, non oggetti',
  'armor/skin_weave': 'voci di supporto del cyberware, non armature',
  'armor/subdermal_armor': 'voci di supporto del cyberware, non armature',
};

void main(List<String> arguments) {
  final _Options options = _Options.parse(arguments);
  final Directory packRoot = Directory('${options.source}/src/packs/core');
  if (!packRoot.existsSync()) {
    stderr.writeln('Pacchetti non trovati in ${packRoot.path}');
    stderr.writeln('');
    stderr.writeln(_Options.usage);
    exitCode = 2;
    return;
  }

  // Il seed si legge **prima** della conversione: serve a sapere quali tipi
  // generici esistono gia', cosi' il dataset non li importa due volte.
  final File seedFile = File(options.seedPath);
  final List<String> problems = <String>[];
  final List<CatalogItem> existing = seedFile.existsSync()
      ? CatalogSeed.parse(seedFile.readAsStringSync(), problems: problems)
      : <CatalogItem>[];

  if (problems.isNotEmpty) {
    stderr.writeln('Il seed contiene voci che non si leggono:');
    for (final String problem in problems) {
      stderr.writeln('  - $problem');
    }
    stderr.writeln('Nessuna scrittura: un seed rotto non si sistema importando.');
    exitCode = 1;
    return;
  }

  final DatasetImport imported = readDataset(
    packRoot,
    packs: options.packs,
    curatedIds: <String>{for (final CatalogItem item in existing) item.id},
  );

  stdout.writeln('Sorgente: ${packRoot.path}');
  stdout.writeln('Pacchetti: ${options.packs.join(', ')}');
  stdout.writeln('');
  stdout.writeln('Oggetti convertiti: ${imported.items.length}');
  for (final MapEntry<ItemCategory, int> entry in imported.counts.entries) {
    stdout.writeln('    ${entry.key.label}: ${entry.value}');
  }
  for (final String note in imported.notes) {
    stdout.writeln('  nota: $note');
  }
  for (final MapEntry<String, int> entry in imported.skippedByReason.entries) {
    stdout.writeln('  saltati (${entry.value}): ${entry.key}');
  }

  final SeedMerge merge = CatalogSeed.merge(
    existing: existing,
    incoming: imported.items,
    problems: problems,
  );

  stdout.writeln('');
  stdout.writeln('Fusione con ${options.seedPath} (${existing.length} voci)');
  stdout.writeln('  nuove voci: ${merge.added.length}');
  stdout.writeln('  gia\' riconosciute per nome: ${merge.alreadyPresent.length}');
  stdout.writeln('  totale: ${merge.items.length}');
  for (final String problem in problems) {
    stdout.writeln('  avviso: $problem');
  }

  if (options.dryRun) {
    stdout.writeln('');
    stdout.writeln('Prova a vuoto: il seed non e\' stato toccato.');
    return;
  }

  if (merge.added.isEmpty) {
    stdout.writeln('');
    stdout.writeln('Niente da scrivere: il seed e\' gia\' aggiornato.');
    return;
  }

  seedFile.writeAsStringSync(CatalogSeed.encodeAll(merge.items));
  stdout.writeln('');
  stdout.writeln('Seed aggiornato: ${options.seedPath}');
  stdout.writeln('Ora rigenera il catalogo spedito:');
  stdout.writeln('  dart run tool/build_catalog.dart');
}

/// Cosa e' uscito dalla conversione di un dataset.
class DatasetImport {
  const DatasetImport({
    required this.items,
    required this.notes,
    required this.counts,
    required this.skippedByReason,
  });

  final List<CatalogItem> items;

  /// Cosa vale la pena sapere su **tutte** le voci (un peso assente, una
  /// convenzione applicata): detto una volta invece che duecento.
  final List<String> notes;

  final Map<ItemCategory, int> counts;

  /// Cosa non e' entrato, raggruppato per motivo. Il conteggio e' il punto:
  /// "36 varianti di qualita'" e' un'informazione, "36 file ignorati" no.
  final Map<String, int> skippedByReason;
}

/// Converte tutti i pacchetti indicati dentro `src/packs/core`.
DatasetImport readDataset(
  Directory packRoot, {
  List<String> packs = defaultPacks,
  Set<String> curatedIds = const <String>{},
}) {
  final List<CatalogItem> items = <CatalogItem>[];
  final List<String> notes = <String>[];
  final Map<ItemCategory, int> counts = <ItemCategory, int>{};
  final Map<String, int> skipped = <String, int>{};
  final Set<String> ids = <String>{};

  void skip(String reason) => skipped.update(reason, (int v) => v + 1, ifAbsent: () => 1);

  int zeroWeight = 0;

  for (final String pack in packs) {
    final Directory directory = Directory('${packRoot.path}/$pack');
    if (!directory.existsSync()) {
      skip('pacchetto assente: $pack');
      continue;
    }

    final List<File> files = directory
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.yaml'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

    for (final File file in files) {
      // I file si chiamano `weapon.medium_pistol.yaml`: il prefisso e' il tipo,
      // e qui serve solo la parte che identifica l'oggetto.
      final String fileName = file.uri.pathSegments.last.replaceAll(RegExp(r'\.yaml$'), '');
      final int dot = fileName.indexOf('.');
      final String stem = dot < 0 ? fileName : fileName.substring(dot + 1);
      final String key = '$pack/$stem';

      final String? notAnItem = _notCatalogItems[key];
      if (notAnItem != null) {
        skip(notAnItem);
        continue;
      }

      // Doppione di una voce curata: si salta **solo** se quella voce esiste
      // davvero nel seed (vedi `_curatedCounterparts`).
      final String? curated = _curatedCounterparts[key];
      if (curated != null && curatedIds.contains(curated)) {
        skip('gia\' nel seed come tipo generico ($curated)');
        continue;
      }

      final Object? decoded;
      try {
        decoded = loadYaml(file.readAsStringSync());
      } on Object catch (error) {
        skip('YAML non leggibile: $error');
        continue;
      }
      if (decoded is! Map) {
        skip('file senza una mappa di dati');
        continue;
      }

      final Map<String, Object?> doc = plainMap(decoded);
      final String name = '${doc['name'] ?? ''}'.trim();
      if (name.isEmpty) {
        skip('voce senza nome');
        continue;
      }

      // Le varianti di qualita' sono voci separate nel dataset (prezzo e
      // modificatori diversi), ma il catalogo non ha un campo "qualita'": due
      // voci con lo stesso nome e dati diversi sarebbero indistinguibili
      // all'utente. Meglio non importarle che importarle sbagliate.
      if (name.endsWith('(Excellent)') || name.endsWith('(Poor)')) {
        skip('varianti di qualita\' (Excellent/Poor)');
        continue;
      }

      final CatalogItem? item = convertItem(doc, ids: ids, onSkip: skip);
      if (item == null) continue;

      if (item.weight == 0) zeroWeight++;
      items.add(item);
      counts.update(item.category, (int v) => v + 1, ifAbsent: () => 1);
    }
  }

  if (zeroWeight > 0) {
    notes.add(
      'Il dataset non registra il peso: $zeroWeight voci importate pesano 0 e si '
      'correggono dalla scheda.',
    );
  }
  if (items.isNotEmpty) {
    notes.add(
      'Voci importate dal dataset Foundry sotto la Homebrew Content Policy di '
      'R. Talsorian Games: sono dati di terzi, non verificati da questo progetto.',
    );
  }

  return DatasetImport(
    items: items,
    notes: notes,
    counts: counts,
    skippedByReason: skipped,
  );
}

/// Converte **una** voce del dataset. Pubblica perche' e' la parte che i test
/// verificano: ogni campo ha una regola, e una regola non verificata e' una
/// supposizione.
CatalogItem? convertItem(
  Map<String, Object?> doc, {
  Set<String>? ids,
  void Function(String reason)? onSkip,
}) {
  void skip(String reason) => onSkip?.call(reason);

  final String type = '${doc['type'] ?? ''}';
  final String name = '${doc['name'] ?? ''}'.trim();
  final Map<String, Object?> system = plainMap(doc['system']);

  final ItemCategory? category = _categoryFor(type);
  if (category == null) {
    skip(type == 'cyberware'
        ? 'impianti (hanno il loro modello, con il costo in umanita\')'
        : 'tipo non gestito: $type');
    return null;
  }

  final int cost = _int(plainMap(system['price'])['market']);
  final String description = _describe(system, type);

  WeaponData? weapon;
  ArmorData? armor;
  ClothingData? clothing;

  if (category == ItemCategory.weapon) {
    weapon = _weapon(system, name, skip);
    // Il campo "danno" esiste per le armi bianche come per quelle da fuoco:
    // una voce senza danno sarebbe un'arma che non fa niente, ed e' meglio
    // saltarla che portarsi dietro un dato vuoto.
    if (weapon == null || weapon.damage.isEmpty) {
      skip('arma senza danno');
      return null;
    }
  } else if (category == ItemCategory.armor) {
    armor = _armor(system, name, skip);
  } else if (category == ItemCategory.clothing) {
    clothing = _clothing(system, name, skip);
  }

  final String id = _uniqueId('${_prefix(category)}-${slug(name)}', ids);
  return CatalogItem(
    id: id,
    name: name,
    category: category,
    rarity: Rarity.common,
    cost: cost,
    description: description,
    // Il peso non c'e' nel dataset: resta zero e viene detto nel rapporto.
    weight: 0,
    source: 'fvtt-cpred',
    weapon: weapon,
    armor: armor,
    clothing: clothing,
  );
}

// --- mappatura ---------------------------------------------------------------

ItemCategory? _categoryFor(String type) {
  switch (type) {
    case 'weapon':
      return ItemCategory.weapon;
    case 'ammo':
      return ItemCategory.ammunition;
    case 'armor':
      return ItemCategory.armor;
    case 'clothing':
      return ItemCategory.clothing;
    // Un cyberdeck e' attrezzatura, non cyberware: nel vecchio progetto stava
    // fra gli oggetti, e il cyberware ha qui un modello tutto suo.
    case 'gear':
    case 'cyberdeck':
      return ItemCategory.equipment;
    default:
      return null;
  }
}

String _prefix(ItemCategory category) {
  switch (category) {
    case ItemCategory.weapon:
      return 'wpn';
    case ItemCategory.ammunition:
      return 'amm';
    case ItemCategory.armor:
      return 'arm';
    case ItemCategory.clothing:
      return 'clo';
    case ItemCategory.equipment:
      return 'gear';
    case ItemCategory.item:
      return 'item';
  }
}

WeaponData? _weapon(Map<String, Object?> system, String name, void Function(String) skip) {
  final String damage = '${system['damage'] ?? ''}'.trim();
  final Skill? skill = _skill(system, name, skip);
  final Map<String, Object?> magazine = plainMap(system['magazine']);

  return WeaponData(
    skillId: (skill ?? Skill.meleeWeapon).id,
    handsRequired: '${_int(system['handsReq'], 1)}',
    damage: damage,
    currentAmmo: 0,
    maxAmmo: _int(magazine['max']),
    rof: _int(system['rof'], 1),
    isConcealable: plainMap(system['concealable'])['concealable'] == true,
    properties: _properties(system),
  );
}

/// L'abilita' dell'arma: nel dataset e' il **nome mostrato**
/// (`weaponSkill: Shoulder Arms`), quindi la mappatura e' per nome e non per
/// identificativo. Se il nome non e' noto si ripiega sul tipo d'arma, e se
/// nemmeno quello lo e', sulla mischia — dichiarandolo.
Skill? _skill(Map<String, Object?> system, String name, void Function(String) skip) {
  final String skillName = '${system['weaponSkill'] ?? ''}'.trim();
  if (skillName.isNotEmpty) {
    final Skill? skill = switch (skillName) {
      'Handgun' => Skill.handgun,
      'Shoulder Arms' => Skill.shoulderArms,
      'Heavy Weapons' => Skill.heavyWeapons,
      'Melee Weapon' => Skill.meleeWeapon,
      'Brawling' => Skill.brawling,
      'Archery' => Skill.archery,
      'Autofire' => Skill.autofire,
      'Athletics' => Skill.athletics,
      'Martial Arts' => Skill.martialArts,
      _ => null,
    };
    if (skill != null) return skill;
    skip('abilita\' non mappata: "$skillName"');
  }

  final String weaponType = '${system['weaponType'] ?? ''}'.trim();
  final Skill? byType = switch (weaponType) {
    'assaultRifle' => Skill.shoulderArms,
    'sniperRifle' => Skill.shoulderArms,
    'shotgun' => Skill.shoulderArms,
    'bow' => Skill.archery,
    'crossbow' => Skill.archery,
    'grenadeLauncher' => Skill.heavyWeapons,
    'rocketLauncher' => Skill.heavyWeapons,
    'flamethrower' => Skill.heavyWeapons,
    'medPistol' || 'heavyPistol' || 'vHeavyPistol' || 'smg' => Skill.handgun,
    _ => null,
  };
  if (byType != null) {
    skip('abilita\' dedotta dal tipo d\'arma ($weaponType)');
    return byType;
  }
  skip('abilita\' dell\'arma sconosciuta: "$name"');
  return null;
}

/// Le proprieta' che il dataset registra e che non hanno un campo proprio nel
/// catalogo: modificatore al tiro, marchio, fuoco automatico, perforazione.
String _properties(Map<String, Object?> system) {
  final List<String> parts = <String>[];
  final String brand = '${system['brand'] ?? ''}'.trim();
  if (brand.isNotEmpty) parts.add(brand);

  final int attackmod = _int(system['attackmod']);
  if (attackmod != 0) parts.add('${attackmod > 0 ? '+' : ''}$attackmod al tiro');

  final Map<String, Object?> fireModes = plainMap(system['fireModes']);
  if (_int(fireModes['autoFire']) > 0) parts.add('Fuoco automatico ${_int(fireModes['autoFire'])}');
  if (fireModes['suppressiveFire'] == true) parts.add('Fuoco di soppressione');

  if (system['canIgnoreArmor'] == true) parts.add('Ignora l\'armatura');
  final int ignorePercent = _int(system['ignoreArmorPercent']);
  if (ignorePercent > 0) parts.add('Ignora il $ignorePercent% dell\'armatura');

  return parts.join(' · ');
}

ArmorData? _armor(Map<String, Object?> system, String name, void Function(String) skip) {
  final int penalty = _positive(_int(system['penalty']));

  if (system['isShield'] == true) {
    // Uno scudo non ha SP: ha punti struttura che si consumano. Il catalogo
    // non ha un campo per quelli, quindi il valore finisce in SP.
    final int hitPoints = _positive(_int(plainMap(system['shieldHitPoints'])['max']));
    skip('scudi: i punti struttura registrati come SP');
    return ArmorData(slot: ArmorSlot.shield, sp: hitPoints, penalties: penalty);
  }

  final bool isHead = system['isHeadLocation'] == true;
  if (system['isBodyLocation'] != true && !isHead) {
    skip('armatura senza slot (ne\' testa ne\' corpo): "$name"');
    return null;
  }

  final Map<String, Object?> location = plainMap(system[isHead ? 'headLocation' : 'bodyLocation']);
  return ArmorData(
    slot: isHead ? ArmorSlot.head : ArmorSlot.body,
    sp: _positive(_int(location['sp'])),
    penalties: penalty,
  );
}

ClothingData? _clothing(Map<String, Object?> system, String name, void Function(String) skip) {
  final String type = '${system['type'] ?? ''}'.trim();
  final ClothingSlot? slot = switch (type) {
    'top' => ClothingSlot.top,
    'bottoms' => ClothingSlot.bottom,
    'jacket' => ClothingSlot.jacket,
    'footwear' => ClothingSlot.shoes,
    'jewelry' => ClothingSlot.jewels,
    'mirrorshades' => ClothingSlot.mirroredGlasses,
    'glasses' => ClothingSlot.eyeGlasses,
    'contactLenses' => ClothingSlot.contactLenses,
    'hats' => ClothingSlot.hat,
    _ => null,
  };
  if (slot == null) {
    skip('capo senza slot noto: "$type"');
    return null;
  }

  final String style = '${system['style'] ?? ''}'.trim();
  final ClothingStyle? mapped = switch (style) {
    'genericChic' => ClothingStyle.genericChic,
    'leisurewear' => ClothingStyle.leisurewear,
    'urbanFlash' => ClothingStyle.urbanFlash,
    'businesswear' => ClothingStyle.businessWear,
    'edgerunner' => ClothingStyle.edgerunner,
    'highFashion' => ClothingStyle.highFashion,
    'bagLadyChic' => ClothingStyle.bagLadyChic,
    'minimalisticFashion' => ClothingStyle.minimalisticFashion,
    'exotics' => ClothingStyle.exotics,
    'naturalists' => ClothingStyle.naturalists,
    'gangColors' => ClothingStyle.gangColours,
    'bohemian' => ClothingStyle.bohemian,
    'nomadLeathers' => ClothingStyle.nomadLeathers,
    'asiaPop' => ClothingStyle.asiaPop,
    'entropism' => ClothingStyle.entropism,
    'kitsch' => ClothingStyle.kitsch,
    'neoMilitarism' => ClothingStyle.neoMilitarism,
    'neoKitsch' => ClothingStyle.neoKitsch,
    _ => null,
  };
  if (mapped == null && style.isNotEmpty) skip('stile non mappato: "$style"');

  return ClothingData(slot: slot, style: mapped ?? ClothingStyle.genericChic);
}

/// Descrizione leggibile: il testo del dataset, il riferimento al manuale, e i
/// fatti che non hanno un campo proprio (confezione, slot di un cyberdeck).
String _describe(Map<String, Object?> system, String type) {
  final List<String> parts = <String>[];

  final String text = plainText(plainMap(system['description'])['value']);
  if (text.isNotEmpty) parts.add(text);

  final int amount = _int(system['amount'], 1);
  if (amount > 1) parts.add('Confezione da $amount.');

  if (type == 'cyberdeck') {
    final int slots = _int(plainMap(system['installedItems'])['slots']);
    if (slots > 0) parts.add('$slots slot per programmi.');
  }

  final Object? sources = system['sources'];
  if (sources is List && sources.isNotEmpty) {
    final Map<String, Object?> first = plainMap(sources.first);
    final String book = '${first['book'] ?? ''}'.trim();
    final int? page = int.tryParse('${first['page'] ?? ''}');
    if (book.isNotEmpty) {
      parts.add(page == null ? '$book.' : '$book, p. $page.');
    }
  }

  return parts.join(' ');
}

/// Il dataset scrive le descrizioni in HTML minimo: qui diventano testo.
///
/// Non e' cosmesi: la descrizione finisce in una scheda che si legge al tavolo,
/// e `<p>` in mezzo alle parole sarebbe illeggibile.
String plainText(Object? html) {
  if (html == null) return '';
  return '$html'
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</p>\s*<p>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Uno slug leggibile e stabile: stesso nome, stesso identificativo.
String slug(String name) {
  const Map<String, String> accents = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final StringBuffer buffer = StringBuffer();
  for (final int code in name.toLowerCase().runes) {
    final String char = String.fromCharCode(code);
    buffer.write(accents[char] ?? char);
  }
  final String result = buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return result.isEmpty ? 'voce' : result;
}

String _uniqueId(String candidate, Set<String>? taken) {
  if (taken == null) return candidate;
  if (taken.add(candidate)) return candidate;
  for (int suffix = 2; suffix < 10000; suffix++) {
    final String next = '$candidate-$suffix';
    if (taken.add(next)) return next;
  }
  return candidate;
}

/// YAML di `package:yaml` produce `YamlMap`/`YamlList`: qui diventano mappe e
/// liste normali, cosi' il resto del codice non deve sapere da dove vengono.
Map<String, Object?> plainMap(Object? value) {
  if (value is! Map) return <String, Object?>{};
  return value.map((Object? k, Object? v) => MapEntry('$k', plain(v)));
}

Object? plain(Object? value) {
  if (value is Map) {
    return value.map((Object? k, Object? v) => MapEntry('$k', plain(v)));
  }
  if (value is List) return <Object?>[for (final Object? entry in value) plain(entry)];
  return value;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int _positive(int value) => value < 0 ? 0 : value;

class _Options {
  _Options({
    required this.source,
    required this.seedPath,
    required this.packs,
    required this.dryRun,
  });

  final String source;
  final String seedPath;
  final List<String> packs;
  final bool dryRun;

  static final String usage = '''
Uso:
  dart run tool/import_dataset_catalog.dart --source <cartella del dataset> [opzioni]

Il dataset si prepara una volta sola:
  git clone --depth 1 --filter=blob:none --sparse \\
    https://gitlab.com/cyberpunk-red-team/fvtt-cyberpunk-red-core.git /tmp/fvtt-cpred
  cd /tmp/fvtt-cpred && git sparse-checkout set src/packs/core

Opzioni:
  --source <percorso>   radice del dataset (deve contenere src/packs/core)
  --packs a,b,c         pacchetti da leggere (predefinito: ${defaultPacks.join(', ')})
  --seed <percorso>     seed da aggiornare (predefinito: ${CatalogSeed.path})
  --dry-run             mostra cosa cambierebbe senza scrivere nulla
  --help                questo messaggio''';

  static _Options parse(List<String> arguments) {
    String source = '';
    String seedPath = CatalogSeed.path;
    List<String> packs = defaultPacks;
    bool dryRun = false;

    for (int i = 0; i < arguments.length; i++) {
      final String argument = arguments[i];
      switch (argument) {
        case '--help':
        case '-h':
          stdout.writeln(usage);
          exit(0);
        case '--dry-run':
        case '-n':
          dryRun = true;
        case '--source':
          if (i + 1 >= arguments.length) {
            stderr.writeln('--source vuole un percorso.');
            exit(2);
          }
          source = arguments[++i];
        case '--seed':
          if (i + 1 >= arguments.length) {
            stderr.writeln('--seed vuole un percorso.');
            exit(2);
          }
          seedPath = arguments[++i];
        case '--packs':
          if (i + 1 >= arguments.length) {
            stderr.writeln('--packs vuole un elenco.');
            exit(2);
          }
          packs = arguments[++i].split(',').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
        default:
          stderr.writeln('Opzione sconosciuta: $argument\n');
          stderr.writeln(usage);
          exit(2);
      }
    }

    if (source.isEmpty) {
      stderr.writeln('Serve --source <cartella del dataset>.\n');
      stderr.writeln(usage);
      exit(2);
    }

    return _Options(source: source, seedPath: seedPath, packs: packs, dryRun: dryRun);
  }
}
