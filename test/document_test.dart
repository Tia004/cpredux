import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/cpredux_file.dart';
import 'package:cpredux/data/migrator.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/legacy_sheet_fixture.dart';

/// Attende il salvataggio automatico.
///
/// Il ritardo di accorpamento e' di 700 ms: si aspetta un po' oltre, perche' un
/// test che fallisce per 5 ms di troppo non e' un test, e' una sveglia.
Future<void> _waitAutosave() => Future<void>.delayed(const Duration(milliseconds: 950));

void main() {
  late Directory temp;
  late Directory docs;
  late AppState state;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_document_test');
    docs = Directory(p.join(temp.path, 'documenti'))..createSync(recursive: true);
    // Le impostazioni finiscono nella cartella temporanea: i test non devono
    // toccare la configurazione vera di chi li esegue.
    AppPaths.overrideForTesting(config: temp.path, data: temp.path);
    state = AppState();
  });

  tearDown(() {
    state.dispose();
    AppPaths.clearOverrides();
    SettingsStore.save(AppSettings());
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('creare una scheda la apre e la scrive su disco', () async {
    await state.createSheet(name: 'Jackie', directory: docs.path);

    expect(state.screen, AppScreen.sheet);
    expect(state.sheet, isNotNull);
    expect(state.totals, isNotNull);
    expect(state.isDirty, isFalse);

    final File file = File(p.join(docs.path, 'Jackie.cpredux'));
    expect(file.existsSync(), isTrue);
    expect(state.documentPath, file.path);

    // Una scheda nuova parte dai default del progetto originale.
    expect(state.sheet!.statBase[Stat.body], 1);
    expect(state.totals!.maxHitPoints, greaterThan(0));
  });

  test('la modifica viene salvata da sola e si ritrova riaprendo il file', () async {
    await state.createSheet(name: 'Jackie', directory: docs.path);
    final String path = state.documentPath!;

    state.mutate((s) {
      s.identity.tag = 'Jackie';
      s.statBase[Stat.body] = 8;
      s.identity.currentHp = 42;
    });

    expect(state.isDirty, isTrue);
    await _waitAutosave();
    expect(state.isDirty, isFalse, reason: 'Il salvataggio automatico non e avvenuto');

    state.closeDocument();
    expect(state.screen, AppScreen.home);
    expect(state.sheet, isNull);

    await state.openDocument(path);
    expect(state.screen, AppScreen.sheet);
    expect(state.sheet!.identity.tag, 'Jackie');
    expect(state.sheet!.statBase[Stat.body], 8);
    expect(state.sheet!.identity.currentHp, 42);
  });

  test('campagne e schede si riconoscono dal contenuto, non dal nome del file', () async {
    await state.createCampaign(name: 'Night City', directory: docs.path);
    final String path = state.documentPath!;
    expect(state.screen, AppScreen.campaign);
    expect(state.campaign, isNotNull);

    // Il file viene rinominato: l'estensione e' la stessa per entrambi i tipi,
    // quindi il riconoscimento deve venire dal contenuto.
    final String renamed = p.join(docs.path, 'Nome fuorviante.cpredux');
    File(path).renameSync(renamed);

    state.closeDocument();
    await state.openDocument(renamed);

    expect(state.screen, AppScreen.campaign);
    expect(state.campaign!.meta.name, 'Night City');
    expect(state.sheet, isNull);
  });

  test('non si crea una seconda scheda con lo stesso nome', () async {
    await state.createSheet(name: 'Jackie', directory: docs.path);

    expect(
      () => state.createSheet(name: 'Jackie', directory: docs.path),
      throwsA(isA<CpreduxException>()),
    );
  });

  test('una scheda del vecchio formato viene convertita e aperta', () async {
    final String legacy = p.join(docs.path, 'Vecchia.cpred_sheet');
    createLegacySheet(legacy);

    // Prima l'anteprima, che non scrive nulla.
    final MigrationReport preview = state.analyseLegacySheet(legacy);
    expect(preview.sheet.identity.tag, 'Jackie');
    expect(preview.totalElements, greaterThan(0));

    final MigrationReport report = state.migrateLegacySheet(legacy);

    // Il vecchio file resta dov'e', con un backup accanto.
    expect(File(legacy).existsSync(), isTrue);
    expect(File(report.backupPath!).existsSync(), isTrue);

    // E la scheda e' aperta, pronta da usare.
    expect(state.screen, AppScreen.sheet);
    expect(state.sheet!.identity.tag, 'Jackie');
    expect(state.sheet!.inventory, hasLength(3));
    expect(state.totals, isNotNull);
    expect(File(report.outputPath!).existsSync(), isTrue);
  });

  test('aprire direttamente una vecchia .cpred_sheet spiega cosa fare', () async {
    final String legacy = p.join(docs.path, 'Vecchia.cpred_sheet');
    createLegacySheet(legacy);

    await expectLater(
      state.openDocument(legacy),
      throwsA(
        isA<CpreduxException>().having(
          (CpreduxException e) => e.detail,
          'detail',
          contains('Converti'),
        ),
      ),
    );
  });

  test('i recenti ricordano i documenti aperti e si possono dimenticare', () async {
    await state.createSheet(name: 'Jackie', directory: docs.path);
    final String path = state.documentPath!;

    expect(state.settings.recentFiles.first, path);

    await state.updateSettings((s) => s.forgetFile(path));
    expect(state.settings.recentFiles, isEmpty);

    // E la scelta e' sopravvissuta alla riscrittura del file delle impostazioni.
    expect(SettingsStore.load().recentFiles, isEmpty);
  });

  test('le impostazioni si salvano davvero su disco', () async {
    await state.updateSettings((s) {
      s.autosave = false;
      s.enableLoad = false;
      s.discordClientId = '1234567890';
    });

    final AppSettings reloaded = SettingsStore.load();
    expect(reloaded.autosave, isFalse);
    expect(reloaded.enableLoad, isFalse);
    expect(reloaded.discordClientId, '1234567890');
  });

  test('con il salvataggio automatico spento la modifica resta non salvata', () async {
    await state.updateSettings((s) => s.autosave = false);
    await state.createSheet(name: 'Jackie', directory: docs.path);

    state.mutate((s) => s.identity.tag = 'Modificato');
    await _waitAutosave();

    expect(state.isDirty, isTrue, reason: 'Non deve salvare da solo se e spento');

    state.save();
    expect(state.isDirty, isFalse);
  });

  test('aprire un documento inesistente non lascia lo stato a meta', () async {
    expect(
      () => state.openDocument(p.join(docs.path, 'NonEsiste.cpredux')),
      throwsA(isA<CpreduxException>()),
    );
    expect(state.sheet, isNull);
    expect(state.campaign, isNull);
    expect(state.screen, AppScreen.home);
  });
}
