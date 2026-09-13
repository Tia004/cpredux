import 'dart:convert';
import 'dart:io';

import 'package:cpredux/data/catalog.dart';
import 'package:cpredux/data/cpredux_file.dart';
import 'package:cpredux/data/migrator.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'support/legacy_sheet_fixture.dart';

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_migration_test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('il migratore riconosce ogni tabella della vecchia scheda', () {
    final String legacy = p.join(temp.path, 'Jackie.cpred_sheet');
    createLegacySheet(legacy);

    final MigrationReport report = SheetMigrator.analyse(
      legacy,
      now: '2026-01-01T00:00:00.000',
    );
    final CharacterSheet sheet = report.sheet;

    // Anagrafica.
    expect(sheet.identity.tag, 'Jackie');
    expect(sheet.identity.playerName, 'Tia');
    expect(sheet.identity.currentHp, 32);
    expect(sheet.identity.currentLuck, 5);
    expect(sheet.identity.role, 'Solo');
    expect(sheet.identity.severeInjuries, 'Costola incrinata');
    expect(sheet.meta.name, 'Jackie');
    expect(sheet.eurobucks, 1200);
    expect(sheet.oldConnections, 'Un fixer di nome Reyes');

    // Caratteristiche e abilita'.
    expect(sheet.statBase[Stat.body], 7);
    expect(sheet.statBase[Stat.empathy], 6);
    expect(sheet.statBase[Stat.dexterity], 5);
    expect(sheet.skillLevels[Skill.handgun], 6);
    expect(sheet.skillLevels[Skill.evasion], 4);

    // Descrizione fisica.
    expect(sheet.physical.age, '27');
    expect(sheet.physical.description, 'Cicatrice sull occhio destro');
    expect(sheet.background.culturalOrigins, 'Night City, Heywood');

    // Il cyberware porta con se' l'alterazione che gli appartiene.
    expect(sheet.cyberware, hasLength(1));
    expect(sheet.cyberware.first.name, 'Interfaccia Neurale');
    expect(sheet.cyberware.first.humanityLost, 7);
    expect(sheet.cyberware.first.lifeEffect, 5);
    expect(sheet.cyberware.first.category, CyberwareCategory.neuralware);
    expect(sheet.cyberware.first.statModifiers, hasLength(1));
    expect(sheet.cyberware.first.statModifiers.first.target, Stat.body);
    expect(sheet.cyberware.first.statModifiers.first.value, 2);
    expect(sheet.cyberware.first.skillModifiers.first.skillId, Skill.handgun.id);

    // L'effetto: qui c'e' la trappola dei valori -1/0/1.
    expect(sheet.effects, hasLength(1));
    final effect = sheet.effects.first;
    expect(effect.isTreatable, EffectKnowledge.yes);
    expect(effect.isCurable, EffectKnowledge.no);
    expect(effect.isLethal, EffectKnowledge.unknown);
    expect(effect.lifeEffect, -3);
    expect(effect.statModifiers.first.target, Stat.willpower);
    expect(effect.statModifiers.first.value, -1);

    // L'alterazione non collegata a nulla finisce fra quelle manuali, e resta
    // inattiva come lo era nella scheda originale.
    expect(sheet.statModifiers, hasLength(1));
    expect(sheet.statModifiers.first.target, Stat.dexterity);
    expect(sheet.statModifiers.first.isActive, isFalse);

    // Competenze: la correzione si applica all'abilita' master.
    expect(sheet.proficiencies, hasLength(1));
    expect(sheet.proficiencies.first.name, 'Chimica');
    expect(sheet.proficiencies.first.level, 3);
    expect(sheet.proficiencies.first.skillModifiers.first.skillId, Skill.science.id);

    // Inventario con i sottotipi.
    //
    // Qui si converte **senza catalogo**, ed e' il caso peggiore: ogni voce
    // deve comunque restare completa dentro la scheda, perche' una vecchia
    // scheda che si apre con gli oggetti svuotati sarebbe un disastro.
    expect(sheet.inventory, hasLength(3));
    final List<ResolvedItem> inventory =
        ResolvedItem.resolveAll(sheet.inventory, (String _) => null);

    final ResolvedItem weapon = inventory.firstWhere((i) => i.name == 'Pistola pesante');
    expect(weapon.entry.catalogId, isNull, reason: 'senza catalogo la voce si autodefinisce');
    expect(weapon.weapon?.damage, '3d6');
    expect(weapon.weapon?.currentAmmo, 8);
    expect(weapon.weapon?.rof, 2);
    expect(weapon.entry.isEquipped, isTrue);
    expect(weapon.rarity, Rarity.rare);

    final ResolvedItem armor = inventory.firstWhere((i) => i.name == 'Giacca corazzata');
    expect(armor.armor?.sp, 11);
    expect(armor.armor?.slot, ArmorSlot.body);
    expect(armor.entry.isEquipped, isTrue);

    final ResolvedItem clothing = inventory.firstWhere((i) => i.name == 'Tuta tecnica');
    expect(clothing.clothing?.slot, ClothingSlot.top);
    expect(clothing.clothing?.style, ClothingStyle.edgerunner);
    expect(clothing.entry.isEquipped, isFalse);

    // Note e lifepath.
    expect(sheet.notes, hasLength(1));
    expect(sheet.notes.first.title, 'Piano');
    expect(sheet.background.friends.first.name, 'Kerry');
    expect(sheet.background.tragicStories.first.name, 'Il fratello');
    expect(sheet.background.enemies.first.who, 'Arasaka');

    // Conteggi mostrati nell'anteprima.
    expect(report.counts['oggetti'], 3);
    expect(report.counts['cyberware'], 1);
    expect(report.counts['effetti'], 1);
    expect(report.counts['competenze'], 1);
    expect(report.counts['note'], 1);
    expect(report.totalElements, greaterThan(6));
  });

  test('con il catalogo spedito la vecchia scheda si aggancia invece di duplicare', () {
    final ItemCatalog catalog = ItemCatalog.openFile(
      p.join('assets', 'catalog', 'catalog.sqlite'),
      readOnly: true,
    );
    addTearDown(catalog.close);

    final String legacy = p.join(temp.path, 'Jackie.cpred_sheet');
    createLegacySheet(legacy);

    final MigrationReport report = SheetMigrator.analyse(
      legacy,
      now: '2026-01-01T00:00:00.000',
      catalog: catalog,
    );
    final List<ResolvedItem> inventory =
        ResolvedItem.resolveAll(report.sheet.inventory, catalog.byId);

    ResolvedItem byName(String name) => inventory.firstWhere(
          (ResolvedItem i) => CatalogItem.matchKey(i.name) == CatalogItem.matchKey(name),
        );

    // "Pistola pesante" e' nel catalogo: da adesso segue gli aggiornamenti e
    // non viene piu' copiata dentro la scheda.
    final ResolvedItem weapon = byName('Pistola pesante');
    expect(weapon.entry.catalogId, 'wpn-heavy-pistol');
    expect(weapon.entry.custom, isNull);
    expect(weapon.weapon?.damage, '3d6', reason: 'Il danno arriva dal catalogo.');
    expect(weapon.weapon?.currentAmmo, 8, reason: 'Le munizioni restano nella scheda.');
    expect(weapon.entry.isEquipped, isTrue);
    // Il nome mostrato e' quello del catalogo, con la sua capitalizzazione: e'
    // la conseguenza voluta dell'agganciarsi a una fonte condivisa, e va
    // scritta perche' qualcuno la leggera' come un "mi hai cambiato il nome".
    expect(weapon.name, 'Pistola Pesante');

    // La rarita' del vecchio dato (rare) era diversa da quella di catalogo:
    // resta come personalizzazione, perche' non si sovrascrive il passato.
    expect(weapon.overrides.rarity, Rarity.rare);
    expect(weapon.rarity, Rarity.rare);

    // "Giacca corazzata" e "Tuta tecnica" nel catalogo non ci sono — sono
    // oggetti diversi da quelli che il catalogo conosce — e restano definiti
    // dentro la scheda con tutti i loro dati.
    final ResolvedItem armor = byName('Giacca corazzata');
    expect(armor.isCustom, isTrue);
    expect(armor.armor?.sp, 11);

    final ResolvedItem clothing = byName('Tuta tecnica');
    expect(clothing.isCustom, isTrue);
    expect(clothing.clothing?.style, ClothingStyle.edgerunner);

    expect(report.counts['agganciati al catalogo'], 1);
    expect(report.counts['oggetti personalizzati'], 2);
  });

  test("l'analisi non scrive nulla accanto alla scheda originale", () {
    final String legacy = p.join(temp.path, 'Jackie.cpred_sheet');
    createLegacySheet(legacy);
    final List<String> before = temp.listSync().map((e) => p.basename(e.path)).toList()..sort();

    SheetMigrator.analyse(legacy, now: '2026-01-01T00:00:00.000');

    final List<String> after = temp.listSync().map((e) => p.basename(e.path)).toList()..sort();
    expect(after, before);
  });

  test('la conversione crea il nuovo documento, il backup e le immagini', () {
    final String legacy = p.join(temp.path, 'Jackie.cpred_sheet');
    final String output = p.join(temp.path, 'Jackie.cpredux');
    createLegacySheet(legacy);

    final MigrationReport report = SheetMigrator.convert(
      legacy,
      outputPath: output,
      now: '2026-01-01T00:00:00.000',
    );

    // L'originale e' intatto e il backup esiste.
    expect(File(legacy).existsSync(), isTrue);
    expect(report.backupPath, isNotNull);
    expect(File(report.backupPath!).existsSync(), isTrue);

    // Il documento nuovo e' leggibile con il contenitore vero.
    final CpreduxFile doc = CpreduxFile.open(output);
    final DocumentSummary summary = doc.summary();
    expect(summary.kind, DocumentKind.sheet);
    expect(summary.name, 'Jackie');
    final Map<String, Object?> payload = doc.readPayload();
    doc.close();

    final CharacterSheet reopened = CharacterSheet.fromJson(payload);
    expect(reopened.identity.tag, 'Jackie');
    expect(reopened.identity.currentHp, 32);
    expect(reopened.statBase[Stat.body], 7);
    expect(reopened.inventory, hasLength(3));
    expect(reopened.cyberware.first.statModifiers.first.value, 2);

    // Le immagini sono uscite dal documento e sono diventate file: la scheda
    // resta leggera e l'immagine resta visibile.
    expect(report.imageDirectory, isNotNull);
    final Directory assets = Directory(report.imageDirectory!);
    expect(assets.existsSync(), isTrue);
    expect(
      assets.listSync().whereType<File>().map((File f) => p.basename(f.path)).toList(),
      containsAll(<String>['ritratto.png', 'oggetto-1.png']),
    );
    final ResolvedItem migratedWeapon = ResolvedItem.resolveAll(
      reopened.inventory,
      (String _) => null,
    ).firstWhere((i) => i.name == 'Pistola pesante');
    expect(migratedWeapon.imagePath, isNotNull);
  });

  test('convertire due volte non sovrascrive il risultato precedente', () {
    final String legacy = p.join(temp.path, 'Jackie.cpred_sheet');
    final String output = p.join(temp.path, 'Jackie.cpredux');
    createLegacySheet(legacy);

    SheetMigrator.convert(legacy, outputPath: output, now: '2026-01-01T00:00:00.000');

    expect(
      () => SheetMigrator.convert(legacy, outputPath: output, now: '2026-01-01T00:00:00.000'),
      throwsA(isA<CpreduxException>()),
    );
  });

  test('un file che non e una scheda viene rifiutato con un messaggio chiaro', () {
    final String fake = p.join(temp.path, 'NonUnaScheda.cpred_sheet');
    File(fake).writeAsBytesSync(utf8.encode('questo non e un database'));

    expect(
      () => SheetMigrator.analyse(fake, now: '2026-01-01T00:00:00.000'),
      throwsA(isA<CpreduxException>()),
    );
  });

  test('una versione del database diversa produce un avviso, non un errore', () {
    final String legacy = p.join(temp.path, 'Vecchia.cpred_sheet');
    createLegacySheet(legacy);
    final Database db = sqlite3.open(legacy);
    db.execute("UPDATE key_parameters SET param_value = 'cpred_sheet_0.9' WHERE param_key = 'db_version';");
    db.close();

    final MigrationReport report = SheetMigrator.analyse(legacy, now: '2026-01-01T00:00:00.000');
    expect(report.sheet.identity.tag, 'Jackie');
  });
}
