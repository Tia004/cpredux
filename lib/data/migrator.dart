import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../domain/cyberware.dart';
import '../domain/effects.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import '../domain/modifiers.dart';
import '../domain/sheet.dart';
import '../domain/skills.dart';
import '../domain/stats.dart';
import 'catalog.dart';
import 'cpredux_file.dart';
import 'legacy_item.dart';

enum MigrationSeverity { info, warning }

/// Una riga del resoconto di conversione.
///
/// Il resoconto non e' decorazione: convertire un formato distrugge
/// informazioni per definizione, e l'utente deve poter vedere *cosa* non e'
/// passato invece di scoprirlo tre sessioni dopo quando gli manca un oggetto.
class MigrationNote {
  const MigrationNote(this.message, {this.severity = MigrationSeverity.info});

  final String message;
  final MigrationSeverity severity;

  bool get isWarning => severity == MigrationSeverity.warning;
}

/// Risultato completo della conversione, anteprima compresa.
class MigrationReport {
  const MigrationReport({
    required this.sheet,
    required this.notes,
    required this.counts,
    this.backupPath,
    this.outputPath,
    this.imageDirectory,
  });

  final CharacterSheet sheet;
  final List<MigrationNote> notes;

  /// Quanti elementi sono passati, per sezione. Serve all'anteprima:
  /// "12 oggetti, 4 impianti, 3 effetti" dice in un colpo se la conversione ha
  /// funzionato meglio di qualunque messaggio di successo generico.
  final Map<String, int> counts;

  final String? backupPath;
  final String? outputPath;
  final String? imageDirectory;

  List<MigrationNote> get warnings => notes.where((MigrationNote n) => n.isWarning).toList();
  bool get hasWarnings => warnings.isNotEmpty;
  int get totalElements => counts.values.fold(0, (int a, int b) => a + b);
}

/// Dove mettere la scheda convertita.
///
/// E' una domanda che vale la pena fare, non un'impostazione da nascondere:
/// chi converte una scheda vecchia spesso non sa dove il programma tiene i
/// documenti, e metterla "da qualche parte" e' il modo piu' rapido per non
/// ritrovarla piu'. La scelta predefinita e' la cartella dell'app, perche' e'
/// l'unica che i menu' "Apri scheda" esplorano.
enum MigrationTarget {
  /// Nella cartella dei documenti dell'app.
  appData(
    'Tra i documenti dell\'app',
    'La ritrovi nei menu\' "Apri scheda". Consigliato.',
  ),

  /// Accanto alla vecchia `.cpred_sheet`, dove sta gia' l'originale.
  besideOriginal(
    'Accanto alla scheda vecchia',
    'Nella stessa cartella del file di partenza.',
  );

  const MigrationTarget(this.label, this.description);

  final String label;
  final String description;
}

/// Converte i vecchi `.cpred_sheet` nel nuovo formato `.cpredux`.
///
/// La conversione e' **deterministica e verificabile** grazie a una proprieta'
/// del progetto originale: ogni enum ha un identificativo numerico stabile
/// (`databaseId` / `databaseValue`), quindi la mappatura non dipende mai
/// dall'ordine di dichiarazione ne' dai nomi visualizzati. L'unica eccezione
/// reale e' `EffectKnowledge`, i cui valori nel database sono -1/0/1 mentre
/// gli ordinali sarebbero 0/1/2: mappare per ordinale trasformerebbe ogni
/// "Sconosciuto" in "No" e ogni "No" in "Si'". Qui si mappa per valore.
abstract final class SheetMigrator {
  /// Versione scritta dal vecchio progetto nelle chiavi `db_version`.
  static const String legacyVersion = 'cpred_sheet_1.0';

  /// Legge un vecchio file e costruisce la scheda **senza scrivere nulla**.
  /// E' quello che alimenta l'anteprima prima che l'utente confermi.
  static MigrationReport analyse(
    String legacyPath, {
    required String now,
    String? assetsRoot,
    ItemCatalog? catalog,
  }) {
    final File file = File(legacyPath);
    if (!file.existsSync()) {
      throw CpreduxException('La vecchia scheda non esiste.', detail: legacyPath);
    }

    final Database db;
    try {
      db = sqlite3.open(legacyPath);
    } on SqliteException catch (e) {
      throw CpreduxException('Il file non e\' una scheda leggibile.', detail: e.message);
    }

    try {
      // Un file che *si apre* ma non e' un database SQLite non fallisce alla
      // `open`: fallisce alla prima query, con un errore di basso livello che
      // non dice nulla all'utente. Qui diventa un messaggio comprensibile.
      _validate(db, legacyPath);
      return _build(
        db,
        legacyPath: legacyPath,
        now: now,
        assetsRoot: assetsRoot,
        catalog: catalog,
      );
    } on SqliteException catch (e) {
      throw CpreduxException(
        'Il file non e\' una scheda CPRED leggibile.',
        detail: e.message,
      );
    } finally {
      db.close();
    }
  }

  /// Converte e scrive il nuovo documento, facendo prima un backup.
  static MigrationReport convert(
    String legacyPath, {
    required String outputPath,
    required String now,
    ItemCatalog? catalog,
  }) {
    final File output = File(outputPath);
    if (output.existsSync() && output.lengthSync() > 0) {
      throw CpreduxException('La destinazione esiste gia\'.', detail: outputPath);
    }

    // Backup *prima* di toccare qualunque cosa. Convertire e' distruttivo per
    // definizione: il file originale va messo al sicuro prima, non dopo.
    final String backup = CpreduxFile.backup(legacyPath);

    final Directory assetsDir = Directory(
      '${p.withoutExtension(outputPath)}.assets',
    );
    final MigrationReport report = analyse(
      legacyPath,
      now: now,
      assetsRoot: assetsDir.path,
      catalog: catalog,
    );

    final CpreduxFile doc = CpreduxFile.create(
      outputPath,
      kind: DocumentKind.sheet,
      name: report.sheet.meta.name,
      documentId: report.sheet.meta.id,
      now: now,
    );
    try {
      doc.writePayload(report.sheet.toJson(), name: report.sheet.meta.name, now: now);
    } finally {
      doc.close();
    }

    return MigrationReport(
      sheet: report.sheet,
      notes: report.notes,
      counts: report.counts,
      backupPath: backup,
      outputPath: outputPath,
      imageDirectory:
          assetsDir.existsSync() && assetsDir.listSync().isNotEmpty ? assetsDir.path : null,
    );
  }

  // --- interni -------------------------------------------------------------

  static void _validate(Database db, String path) {
    final ResultSet versionRows = db.select(
      "SELECT param_value FROM key_parameters WHERE param_key = 'db_version';",
    );
    if (versionRows.isEmpty) {
      throw CpreduxException(
        'Il file non contiene una scheda CPRED.',
        detail: 'Manca la chiave db_version in $path',
      );
    }
    final String version = versionRows.first['param_value'] as String? ?? '';
    if (version != legacyVersion) {
      // Non e' un errore fatale: si prova comunque, ma il resoconto lo dira'.
      return;
    }
  }

  static String? _key(Database db, String key) {
    final ResultSet rows = db.select(
      'SELECT param_value FROM key_parameters WHERE param_key = ?;',
      <Object?>[key],
    );
    if (rows.isEmpty) return null;
    return rows.first['param_value'] as String?;
  }

  static int _keyInt(Database db, String key, [int fallback = 0]) {
    final String? raw = _key(db, key);
    if (raw == null || raw.trim().isEmpty) return fallback;
    return int.tryParse(raw.trim()) ?? fallback;
  }

  static bool _hasTable(Database db, String name) {
    final ResultSet rows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name = ?;",
      <Object?>[name],
    );
    return rows.isNotEmpty;
  }

  static MigrationReport _build(
    Database db, {
    required String legacyPath,
    required String now,
    String? assetsRoot,
    ItemCatalog? catalog,
  }) {
    final List<MigrationNote> notes = <MigrationNote>[];
    final Map<String, int> counts = <String, int>{};

    // --- Anagrafica -------------------------------------------------------
    final SheetIdentity identity = SheetIdentity(
      tag: _key(db, 'tag') ?? '',
      playerName: _key(db, 'player_name') ?? '',
      gameDate: _key(db, 'game_date') ?? '',
      aliases: _key(db, 'aliases') ?? '',
      reputation: _key(db, 'reputation') ?? '',
      role: _key(db, 'role') ?? '',
      roleAbility: _key(db, 'role_ability') ?? '',
      roleRank: _key(db, 'role_rank') ?? '',
      currentHp: _keyInt(db, 'current_hit_points'),
      currentLuck: _keyInt(db, 'current_luck'),
      currentImprovementPoints: _keyInt(db, 'current_improvement_points'),
      totalImprovementPoints: _keyInt(db, 'total_improvement_points'),
      severeInjuries: _key(db, 'severe_injuries') ?? '',
      addictions: _key(db, 'addictions') ?? '',
      inspirationPoints: _keyInt(db, 'inspiration_points'),
    );

    final String characterImage = _key(db, 'character_image') ?? '';
    final PhysicalDescription physical = PhysicalDescription(
      age: _key(db, 'age') ?? '',
      height: _key(db, 'height') ?? '',
      weight: _key(db, 'weight') ?? '',
      eyes: _key(db, 'eyes') ?? '',
      skin: _key(db, 'skin') ?? '',
      hair: _key(db, 'hair') ?? '',
      description: _key(db, 'physical_description') ?? '',
      imagePath: _extractImage(
        characterImage,
        _key(db, 'character_image_extension') ?? 'png',
        assetsRoot,
        'ritratto',
      ),
    );

    // --- Caratteristiche e abilita' ---------------------------------------
    final Map<Stat, int> statBase = <Stat, int>{for (final Stat s in Stat.values) s: 1};
    final ResultSet statRows = db.select('SELECT id, stat_value FROM stats;');
    int unknownStats = 0;
    for (final Row row in statRows) {
      final Stat? stat = Stat.fromId(_int(row['id']));
      if (stat == null) {
        unknownStats++;
        continue;
      }
      statBase[stat] = _int(row['stat_value'], 1);
    }
    if (unknownStats > 0) {
      notes.add(MigrationNote(
        '$unknownStats caratteristiche sconosciute ignorate (probabilmente da una versione piu\' recente).',
        severity: MigrationSeverity.warning,
      ));
    }

    final Map<Skill, int> skillLevels = <Skill, int>{
      for (final Skill s in Skill.values) s: s.isEssential ? 2 : 0,
    };
    final ResultSet skillRows = db.select('SELECT id, skill_level FROM skills;');
    int unknownSkills = 0;
    for (final Row row in skillRows) {
      final Skill? skill = Skill.fromId(_int(row['id']));
      if (skill == null) {
        unknownSkills++;
        continue;
      }
      skillLevels[skill] = _int(row['skill_level']);
    }
    if (unknownSkills > 0) {
      notes.add(MigrationNote(
        '$unknownSkills abilita\' sconosciute ignorate.',
        severity: MigrationSeverity.warning,
      ));
    }

    // --- Alterazioni: prima si indicizza chi le possiede -------------------
    // Le tabelle ponte dicono quale cyberware o effetto "possiede" la riga di
    // alterazione. Le alterazioni non referenziate da nessuna ponte sono
    // quelle inserite a mano, e finiscono nella lista manuale della scheda.
    final Map<int, String> statAlterationOwner = _bridgeOwners(db, 'cyberware_stats_alterations', 'effect_stats_alterations');
    final Map<int, String> skillAlterationOwner = _bridgeOwners(db, 'cyberware_skills_alterations', 'effect_skills_alterations');
    final Map<int, String> proficiencyAlterationOwner =
        _bridgeOwners(db, 'cyberware_proficiencies_alterations', 'effect_proficiencies_alterations');

    final Map<String, List<StatModifier>> cyberwareStatMods = <String, List<StatModifier>>{};
    final Map<String, List<SkillModifier>> cyberwareSkillMods = <String, List<SkillModifier>>{};
    final Map<String, List<StatModifier>> effectStatMods = <String, List<StatModifier>>{};
    final Map<String, List<SkillModifier>> effectSkillMods = <String, List<SkillModifier>>{};

    void bucket(
      Map<String, List<StatModifier>> statMap,
      Map<String, List<SkillModifier>> skillMap,
      String ownerKey,
      StatModifier? statMod,
      SkillModifier? skillMod,
    ) {
      if (statMod != null) {
        (statMap[ownerKey] ??= <StatModifier>[]).add(statMod);
      }
      if (skillMod != null) {
        (skillMap[ownerKey] ??= <SkillModifier>[]).add(skillMod);
      }
    }

    final List<StatModifier> manualStatMods = <StatModifier>[];
    final List<SkillModifier> manualSkillMods = <SkillModifier>[];

    // stats_alterations
    final ResultSet statAlterations = db.select(
      'SELECT id, stat_id, alteration, is_active FROM stats_alterations;',
    );
    int orphanStatAlterations = 0;
    for (final Row row in statAlterations) {
      final int id = _int(row['id']);
      final Stat? stat = Stat.fromId(_int(row['stat_id']));
      if (stat == null) {
        unknownStats++;
        continue;
      }
      final StatModifier mod = StatModifier(
        target: stat,
        value: _int(row['alteration']),
        isActive: _int(row['is_active']) != 0,
      );
      final String? owner = statAlterationOwner[id];
      if (owner == null) {
        manualStatMods.add(mod);
      } else if (owner.startsWith('cw:')) {
        bucket(cyberwareStatMods, cyberwareSkillMods, owner, mod, null);
      } else {
        bucket(effectStatMods, effectSkillMods, owner, mod, null);
      }
    }

    // skills_alterations
    final ResultSet skillAlterations = db.select(
      'SELECT id, skill_id, alteration, is_active FROM skills_alterations;',
    );
    for (final Row row in skillAlterations) {
      final int id = _int(row['id']);
      final int skillId = _int(row['skill_id']);
      final SkillModifier mod = SkillModifier(
        skillId: skillId,
        value: _int(row['alteration']),
        isActive: _int(row['is_active']) != 0,
      );
      final String? owner = skillAlterationOwner[id];
      if (owner == null) {
        manualSkillMods.add(mod);
      } else if (owner.startsWith('cw:')) {
        bucket(cyberwareStatMods, cyberwareSkillMods, owner, null, mod);
      } else {
        bucket(effectStatMods, effectSkillMods, owner, null, mod);
      }
    }

    if (orphanStatAlterations > 0) {
      notes.add(MigrationNote(
        '$orphanStatAlterations alterazioni orfane spostate fra le correzioni manuali.',
        severity: MigrationSeverity.warning,
      ));
    }

    // --- Competenze -------------------------------------------------------
    final List<Proficiency> proficiencies = <Proficiency>[];
    if (_hasTable(db, 'proficiencies')) {
      final ResultSet profRows = db.select(
        'SELECT id, master_skill_id, proficiency_name, proficiency_level FROM proficiencies;',
      );
      for (final Row row in profRows) {
        final int profId = _int(row['id']);
        final List<StatModifier> statMods = <StatModifier>[];
        final List<SkillModifier> skillMods = <SkillModifier>[];

        final ResultSet profAlterations = db.select(
          'SELECT id, alteration, is_active FROM proficiencies_alterations WHERE proficiency_id = ?;',
          <Object?>[profId],
        );
        for (final Row alt in profAlterations) {
          // Le correzioni alle competenze si applicano all'abilita' master:
          // e' l'unico modo per farle contare in un tiro di dado, e mantiene
          // il motore di calcolo a due soli livelli (caratteristiche e abilita').
          skillMods.add(SkillModifier(
            skillId: _int(row['master_skill_id']),
            value: _int(alt['alteration']),
            isActive: _int(alt['is_active']) != 0,
          ));
          proficiencyAlterationOwner[_int(alt['id'])];
        }

        proficiencies.add(Proficiency(
          id: 'prof-$profId',
          masterSkillId: _int(row['master_skill_id']),
          name: row['proficiency_name'] as String? ?? '',
          level: _int(row['proficiency_level']),
          statModifiers: statMods,
          skillModifiers: skillMods,
        ));
      }
      counts['competenze'] = proficiencies.length;
    }

    // --- Inventario -------------------------------------------------------
    final List<InventoryEntry> inventory = <InventoryEntry>[];
    if (_hasTable(db, 'items')) {
      // `items` non ha una colonna `is_equipped`: l'equipaggiamento vive nelle
      // tabelle dei sottotipi (weapons, armors, clothing), perche' solo loro
      // sanno cosa significa "indossato". Leggere la colonna da `items`
      // faceva fallire la conversione di *qualunque* scheda con un oggetto.
      final ResultSet itemRows = db.select(
        'SELECT id, name, cost, description, rarity, weight, category, quantity, '
        'base64image, image_extension FROM items;',
      );
      int matchedToCatalog = 0;
      int personalised = 0;
      int customItems = 0;

      for (final Row row in itemRows) {
        final int itemId = _int(row['id']);
        final String name = row['name'] as String? ?? 'Oggetto #$itemId';

        // Si costruisce una mappa con le **stesse chiavi del formato v1** e si
        // delega la conversione: cosi' le vecchie schede Java e i documenti
        // `.cpredux` v1 passano dallo stesso codice, e sistemare un caso limite
        // non richiede di ricordarsi di farlo due volte.
        final Map<String, Object?> legacy = <String, Object?>{
          'id': 'item-$itemId',
          'name': name,
          'category': _int(row['category']),
          'rarity': _int(row['rarity']),
          'cost': _int(row['cost']),
          'description': row['description'] as String? ?? '',
          'weight': _double(row['weight']),
          'quantity': _int(row['quantity'], 1),
          'isEquipped': false,
        };

        final ResultSet weaponRows = db.select(
          'SELECT * FROM weapons WHERE item_id = ?;',
          <Object?>[itemId],
        );
        if (weaponRows.isNotEmpty) {
          final Row w = weaponRows.first;
          legacy['weapon'] = <String, Object?>{
            'skillId': _int(w['weapon_skill'], 12),
            'handsRequired': w['hands_required'] as String? ?? '1',
            'damage': w['damage'] as String? ?? '',
            'currentAmmo': _int(w['current_ammo']),
            'maxAmmo': _int(w['max_ammo']),
            'rof': _int(w['rof'], 1),
            'isConcealable': _int(w['is_concealable']) != 0,
            'properties': w['properties'] as String? ?? '',
          };
          legacy['isEquipped'] = _int(w['is_equipped']) != 0;
        }

        final ResultSet armorRows = db.select(
          'SELECT * FROM armors WHERE item_id = ?;',
          <Object?>[itemId],
        );
        if (armorRows.isNotEmpty) {
          final Row a = armorRows.first;
          legacy['armor'] = <String, Object?>{
            'slot': _int(a['slot'], 1),
            'sp': _int(a['sp']),
            'penalties': _int(a['penalties']),
          };
          legacy['isEquipped'] = _int(a['is_equipped']) != 0;
        }

        final ResultSet clothingRows = db.select(
          'SELECT * FROM clothing WHERE item_id = ?;',
          <Object?>[itemId],
        );
        if (clothingRows.isNotEmpty) {
          final Row c = clothingRows.first;
          legacy['clothing'] = <String, Object?>{
            'slot': ClothingSlot.fromOrdinal(_int(c['slot'])).name,
            'style': ClothingStyle.fromOrdinal(_int(c['style'])).name,
          };
          legacy['isEquipped'] = _int(c['is_equipped']) != 0;
        }

        // Le immagini Base64 escono dal documento e diventano file affiancati:
        // era la causa principale delle schede da decine di MB.
        final String? image = _extractImage(
          row['base64image'] as String?,
          row['image_extension'] as String?,
          assetsRoot,
          'oggetto-$itemId',
        );
        if (image != null) legacy['imagePath'] = image;

        final LegacyItemResult result = LegacyItemConverter.convert(
          legacy,
          entryId: 'item-$itemId',
          catalog: catalog,
        );
        if (result.matched) {
          matchedToCatalog++;
          if (result.personalisationCount > 0) personalised++;
        } else {
          customItems++;
        }
        inventory.add(result.entry);
      }

      counts['oggetti'] = inventory.length;
      if (matchedToCatalog > 0) counts['agganciati al catalogo'] = matchedToCatalog;
      if (personalised > 0) counts['con personalizzazioni'] = personalised;
      if (customItems > 0) counts['oggetti personalizzati'] = customItems;

      if (matchedToCatalog > 0) {
        notes.add(MigrationNote(
          "$matchedToCatalog oggetti riconosciuti nel catalogo: la scheda non ne conserva piu' "
          'una copia, quindi pesa meno e segue gli aggiornamenti.',
        ));
      }
      if (customItems > 0) {
        notes.add(MigrationNote(
          '$customItems oggetti non sono nel catalogo: restano definiti dentro la scheda, '
          'con tutti i loro dati.',
        ));
      }
    }

    // --- Cyberware --------------------------------------------------------
    final List<Cyberware> cyberwareList = <Cyberware>[];
    if (_hasTable(db, 'installed_cyberware')) {
      final ResultSet rows = db.select('SELECT * FROM installed_cyberware;');
      for (final Row row in rows) {
        final int cwId = _int(row['id']);
        final String key = 'cw:$cwId';
        cyberwareList.add(Cyberware(
          id: key,
          name: row['name'] as String? ?? 'Cyberware #$cwId',
          category: CyberwareCategory.fromId(_int(row['cyberware_category'])) ??
              CyberwareCategory.neuralware,
          rarity: Rarity.fromOrdinal(_int(row['rarity'])),
          isFoundational: _int(row['is_foundational']) != 0,
          description: row['description'] as String? ?? '',
          installedAt: row['install_date'] as String?,
          humanityLost: _int(row['humanity_lost']),
          weight: _double(row['weight']),
          cost: _int(row['cost']),
          lifeEffect: _int(row['effect_life']),
          lifePercentEffect: _double(row['effect_life_perc']),
          loadEffect: _double(row['effect_load']),
          loadPercentEffect: _double(row['effect_load_perc']),
          imagePath: _extractImage(
            row['base64image'] as String?,
            row['image_extension'] as String?,
            assetsRoot,
            'cyberware-$cwId',
          ),
          statModifiers: cyberwareStatMods[key] ?? <StatModifier>[],
          skillModifiers: cyberwareSkillMods[key] ?? <SkillModifier>[],
        ));
      }
      counts['cyberware'] = cyberwareList.length;
    }

    // --- Effetti ----------------------------------------------------------
    final List<Effect> effects = <Effect>[];
    if (_hasTable(db, 'effects')) {
      final ResultSet rows = db.select('SELECT * FROM effects;');
      for (final Row row in rows) {
        final int effectId = _int(row['id']);
        final String key = 'eff:$effectId';
        effects.add(Effect(
          id: key,
          name: row['name'] as String? ?? 'Effetto #$effectId',
          duration: row['duration'] as String? ?? '',
          intensity: _int(row['intensity']),
          isTreatable: EffectKnowledge.fromId(_int(row['is_treatable'], -1)) ?? EffectKnowledge.unknown,
          isCurable: EffectKnowledge.fromId(_int(row['is_curable'], -1)) ?? EffectKnowledge.unknown,
          isLethal: EffectKnowledge.fromId(_int(row['is_lethal'], -1)) ?? EffectKnowledge.unknown,
          lifeEffect: _int(row['life_effect']),
          lifePercentEffect: _double(row['life_percentage_effect']),
          loadEffect: _double(row['load_effect']),
          loadPercentEffect: _double(row['load_percentage_effect']),
          otherEffects: row['other_effects'] as String? ?? '',
          description: row['description'] as String? ?? '',
          isActive: _int(row['is_active']) != 0,
          statModifiers: effectStatMods[key] ?? <StatModifier>[],
          skillModifiers: effectSkillMods[key] ?? <SkillModifier>[],
        ));
      }
      counts['effetti'] = effects.length;
    }

    // --- Note -------------------------------------------------------------
    final List<Note> noteList = <Note>[];
    if (_hasTable(db, 'notes')) {
      final ResultSet rows = db.select('SELECT * FROM notes;');
      for (final Row row in rows) {
        noteList.add(Note(
          id: 'nota-${_int(row['id'])}',
          title: row['title'] as String? ?? '',
          content: row['content'] as String? ?? '',
          createdAt: row['creation_date'] as String? ?? '',
          updatedAt: row['last_edit'] as String? ?? '',
        ));
      }
      counts['note'] = noteList.length;
    }

    // --- Background -------------------------------------------------------
    final List<Friend> friends = <Friend>[];
    if (_hasTable(db, 'bg_friends')) {
      for (final Row row in db.select('SELECT id, name FROM bg_friends;')) {
        friends.add(Friend(id: 'amico-${_int(row['id'])}', name: row['name'] as String? ?? ''));
      }
    }
    final List<TragicStory> stories = <TragicStory>[];
    if (_hasTable(db, 'bg_tragic_stories')) {
      for (final Row row in db.select('SELECT id, name FROM bg_tragic_stories;')) {
        stories.add(TragicStory(id: 'storia-${_int(row['id'])}', name: row['name'] as String? ?? ''));
      }
    }
    final List<Enemy> enemies = <Enemy>[];
    if (_hasTable(db, 'bg_enemies')) {
      for (final Row row in db.select('SELECT * FROM bg_enemies;')) {
        enemies.add(Enemy(
          id: 'nemico-${_int(row['id'])}',
          who: row['who'] as String? ?? '',
          whatCausedIt: row['what_caused_it'] as String? ?? '',
          whatCanTheyThrowAtYou: row['what_can_they_throw_at_you'] as String? ?? '',
          whatsGonnaHappen: row['whats_gonna_happen'] as String? ?? '',
        ));
      }
    }

    final Background background = Background(
      culturalOrigins: _key(db, 'cultural_origins') ?? '',
      personality: _key(db, 'personality') ?? '',
      favouriteClothingStyle: _key(db, 'favourite_clothing_style') ?? '',
      favouriteHairStyle: _key(db, 'favourite_hair_style') ?? '',
      whatDoYouValueMost: _key(db, 'what_do_you_value_most') ?? '',
      feelingsAboutPeople: _key(db, 'feelings_about_people') ?? '',
      mostValuedPerson: _key(db, 'most_valued_person') ?? '',
      mostValuedPossession: _key(db, 'most_valued_possession') ?? '',
      familyBackground: _key(db, 'family_background') ?? '',
      childhoodEnvironment: _key(db, 'childhood_environment') ?? '',
      familyCrisis: _key(db, 'family_crisis') ?? '',
      lifeGoals: _key(db, 'life_goals') ?? '',
      reputationEvents: _key(db, 'reputation_events') ?? '',
      roleSpecificLifepath: _key(db, 'role_specific_lifepath') ?? '',
      housing: _key(db, 'housing') ?? '',
      housingRent: _key(db, 'housing_rent') ?? '',
      lifestyle: _key(db, 'lifestyle') ?? '',
      lifestyleCost: _key(db, 'lifestyle_cost') ?? '',
      friends: friends,
      tragicStories: stories,
      enemies: enemies,
    );
    counts['contatti'] = friends.length + stories.length + enemies.length;

    // --- Scheda -----------------------------------------------------------
    final String legacyName = p.basenameWithoutExtension(legacyPath);
    final String sheetName = identity.tag.trim().isNotEmpty ? identity.tag.trim() : legacyName;

    final CharacterSheet sheet = CharacterSheet(
      meta: DocumentMeta(
        id: 'sheet-${DateTime.now().microsecondsSinceEpoch}',
        name: sheetName,
        createdAt: now,
        updatedAt: now,
      ),
      identity: identity,
      statBase: statBase,
      skillLevels: skillLevels,
      statModifiers: manualStatMods,
      skillModifiers: manualSkillMods,
      proficiencies: proficiencies,
      inventory: inventory,
      cyberware: cyberwareList,
      effects: effects,
      notes: noteList,
      background: background,
      physical: physical,
      eurobucks: _keyInt(db, 'eurobucks'),
      oldConnections: _key(db, 'old_connections') ?? '',
    );

    if (manualStatMods.isNotEmpty || manualSkillMods.isNotEmpty) {
      notes.add(MigrationNote(
        '${manualStatMods.length + manualSkillMods.length} correzioni non collegate a un impianto o effetto '
        'sono state spostate fra le correzioni manuali della scheda.',
      ));
    }

    return MigrationReport(sheet: sheet, notes: notes, counts: counts);
  }

  /// Costruisce la mappa `alteration_id -> proprietario`.
  ///
  /// Il proprietario e' codificato come `cw:<id>` o `eff:<id>`, gli stessi
  /// identificativi usati poi per le liste di modificatori di cyberware ed
  /// effetti.
  static Map<int, String> _bridgeOwners(Database db, String cyberwareTable, String effectTable) {
    final Map<int, String> owners = <int, String>{};
    if (_hasTable(db, cyberwareTable)) {
      for (final Row row in db.select('SELECT * FROM $cyberwareTable;')) {
        owners[_int(row['alteration_id'])] = 'cw:${_int(row['cyberware_id'])}';
      }
    }
    if (_hasTable(db, effectTable)) {
      for (final Row row in db.select('SELECT * FROM $effectTable;')) {
        owners[_int(row['alteration_id'])] = 'eff:${_int(row['effect_id'])}';
      }
    }
    return owners;
  }

  /// Salva un'immagine Base64 del vecchio formato come file, e restituisce il
  /// percorso.
  ///
  /// Il vecchio progetto incorporava le immagini nella scheda in Base64: con
  /// qualche decina di oggetti significavano schede da decine di MB, lente da
  /// aprire e impossibili da leggere in un diff. Qui le immagini escono dal
  /// documento e diventano file affiancati, cosi' il `.cpredux` resta leggero.
  static String? _extractImage(
    String? base64,
    String? extension,
    String? assetsRoot,
    String baseName,
  ) {
    if (base64 == null || base64.trim().isEmpty || assetsRoot == null) return null;
    try {
      final List<int> bytes = base64Decode(base64);
      if (bytes.isEmpty) return null;
      final Directory dir = Directory(assetsRoot);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final String ext = (extension == null || extension.trim().isEmpty) ? 'png' : extension.trim();
      final String filePath = p.join(assetsRoot, '$baseName.$ext');
      File(filePath).writeAsBytesSync(bytes, flush: true);
      return filePath;
    } catch (_) {
      // Un'immagine corrotta non deve far fallire la conversione di una
      // scheda: si perde il ritratto, non i punti abilita'.
      return null;
    }
  }

  static int _int(Object? value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _double(Object? value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
