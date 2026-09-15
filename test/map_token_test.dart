import 'dart:io';

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/data/catalog.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/domain/campaign.dart';
import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/map_token.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Modello del token', () {
    MapToken token({int hp = 30, int maxHp = 30}) => MapToken(
          id: 'tok-1',
          name: 'Tyger Claws 3',
          x: 0.4,
          y: 0.6,
          hp: hp,
          maxHp: maxHp,
          sp: 7,
          combat: 12,
          defense: 11,
          damage: '3d6',
        );

    test('la salute ha quattro gradini e si legge dal rapporto', () {
      expect(token(hp: 30).health, TokenHealth.illeso);
      expect(token(hp: 18).health, TokenHealth.ferito);
      expect(token(hp: 9).health, TokenHealth.critico);
      expect(token(hp: 0).health, TokenHealth.aTerra);
      expect(token(hp: 0).isDown, isTrue);
      expect(token(hp: 0).healthRatio, 0);
    });

    test('un token senza Punti Vita non finge di averne', () {
      // Il caso che conta: un segnaposto messo solo per dire "qui c'e' qualcuno"
      // non deve mostrare un anello di salute che non significa niente.
      final MapToken blank = MapToken(id: 't', name: 'Figura', x: 0.1, y: 0.1);
      expect(blank.hasHealth, isFalse);
      expect(blank.healthRatio, 1);
      expect(blank.health, TokenHealth.illeso);
      expect(blank.healthRatio, 1);
      expect(blank.statLine, isEmpty);
    });

    test('il danno non scende sotto zero e la cura non supera il massimo', () {
      final MapToken t = token(hp: 4);
      t.applyDamage(30);
      expect(t.hp, 0);
      t.heal(99);
      expect(t.hp, 30);
      expect(t.isDown, isFalse);
    });

    test('la posizione resta dentro la mappa', () {
      final MapToken t = token();
      t.position = const Offset(1.4, -0.2);
      expect(t.x, 1);
      expect(t.y, 0);
    });

    test('la riga di stato porta i numeri che servono al tavolo', () {
      final MapToken t = token();
      expect(t.statLine, contains('PV 30/30'));
      expect(t.statLine, contains('SP 7'));
      expect(t.statLine, contains('Comb +12'));
      expect(t.statLine, contains('Dif 11'));
      expect(t.summary, contains('Tyger Claws 3'));
      expect(t.summary, contains('Nemico'));
    });

    test('un token si salva e si rilegge identico', () {
      final MapToken original = token(hp: 12);
      final MapToken back = MapToken.fromJson(original.toJson());
      expect(back.id, original.id);
      expect(back.name, original.name);
      expect(back.hp, 12);
      expect(back.maxHp, 30);
      expect(back.sp, 7);
      expect(back.combat, 12);
      expect(back.kind, original.kind);
      expect(back.x, original.x);
    });

    test('un tipo sconosciuto non fa fallire la lettura', () {
      final MapToken back = MapToken.fromJson(<String, Object?>{
        'id': 't',
        'name': 'X',
        'x': 0.5,
        'y': 0.5,
        'kind': 'qualcosa-di-nuovo',
      });
      expect(back.kind, TokenKind.nemico);
    });
  });

  group('Disposizione di un gruppo', () {
    test('un token solo sta al centro', () {
      expect(tokenCluster(count: 1, center: const Offset(0.5, 0.5)), <Offset>[const Offset(0.5, 0.5)]);
      expect(tokenCluster(count: 0, center: const Offset(0.5, 0.5)), isEmpty);
    });

    test('otto token non finiscono uno sopra l altro', () {
      final List<Offset> spots = tokenCluster(count: 8, center: const Offset(0.5, 0.5));
      expect(spots.length, 8);
      final Set<String> unique = spots.map((Offset o) => '${o.dx.toStringAsFixed(3)},${o.dy.toStringAsFixed(3)}').toSet();
      expect(unique.length, 8);
      for (final Offset o in spots) {
        expect(o.dx, inInclusiveRange(0, 1));
        expect(o.dy, inInclusiveRange(0, 1));
      }
    });

    test('il cerchio resta dentro la mappa anche vicino al bordo', () {
      final List<Offset> spots = tokenCluster(count: 6, center: const Offset(0.01, 0.99));
      for (final Offset o in spots) {
        expect(o.dx, inInclusiveRange(0, 1));
        expect(o.dy, inInclusiveRange(0, 1));
      }
    });
  });

  group('Token dentro la campagna', () {
    test('i token sopravvivono al salvataggio', () {
      final Campaign campaign = Campaign.fresh(id: 'c1', name: 'Tavolo', now: '2026-09-15T00:00:00Z');
      campaign.tokens.add(MapToken(id: 'tok-1', name: 'Bozzo', x: 0.2, y: 0.3, hp: 20, maxHp: 20));

      final Campaign back = Campaign.fromJson(campaign.toJson());
      expect(back.tokens.length, 1);
      expect(back.tokens.single.name, 'Bozzo');
      expect(back.tokens.single.hp, 20);
    });

    test('una campagna scritta prima dei token si apre lo stesso', () {
      final Map<String, Object?> old = Campaign.fresh(id: 'c1', name: 'Vecchia', now: '2025-01-01T00:00:00Z').toJson()
        ..remove('tokens');
      final Campaign back = Campaign.fromJson(old);
      expect(back.tokens, isEmpty);
      expect(back.waypoints, isEmpty);
    });
  });

  group('Flussi di stato', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('cpredux_token_test');
      AppPaths.overrideForTesting(config: temp.path, data: temp.path, documents: temp.path);
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

    Future<AppState> withCampaign() async {
      final AppState state = AppState();
      await state.createCampaign(name: 'Night City 2045', directory: temp.path);
      return state;
    }

    test('i token di un gruppo condividono il gruppo e finiscono nel registro', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final List<MapToken> created = state.addTokens(
        tokens: <MapToken>[
          MapToken(id: 'a', name: 'Bozzo 1', x: 0.4, y: 0.4, hp: 20, maxHp: 20),
          MapToken(id: 'b', name: 'Bozzo 2', x: 0.6, y: 0.6, hp: 20, maxHp: 20),
        ],
        groupLabel: 'Taglieggio dei Bozo',
      );

      expect(created.length, 2);
      expect(created.first.groupId, isNotEmpty);
      expect(created.first.groupId, created.last.groupId);
      expect(state.mapTokens.length, 2);
      expect(state.tokensArePersisted, isTrue);
      expect(state.sessionLog.first.description, contains('Taglieggio dei Bozo'));
      expect(state.campaign?.tokens.length, 2);
    });

    test('senza campagna i token restano in memoria e non vengono salvati', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      state.addTokens(tokens: <MapToken>[MapToken(id: 'a', name: 'Ragazzo', x: 0.5, y: 0.5)]);
      expect(state.mapTokens.length, 1);
      expect(state.tokensArePersisted, isFalse);
      // E viene detto, invece di lasciar credere che siano salvati.
      expect(state.canRecordSession, isTrue);
    });

    test('ferire un token scrive nel registro e sotto zero non scende', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final MapToken t = state.addTokens(
        tokens: <MapToken>[MapToken(id: 'a', name: 'Maelstrom', x: 0.5, y: 0.5, hp: 10, maxHp: 10)],
      ).single;

      state.damageToken(t.id, 6);
      expect(state.mapTokens.single.hp, 4);
      expect(state.sessionLog.first.description, contains('subisce 6 danni'));

      state.damageToken(t.id, 6);
      expect(state.mapTokens.single.hp, 0);
      expect(state.sessionLog.first.description, contains('a terra'));

      state.damageToken(t.id, 100);
      expect(state.mapTokens.single.hp, 0);

      state.healToken(t.id, 5);
      expect(state.mapTokens.single.hp, 5);
    });

    test('un danno a zero non sporca il registro', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);
      final MapToken t = state.addTokens(
        tokens: <MapToken>[MapToken(id: 'a', name: 'X', x: 0.5, y: 0.5, hp: 0, maxHp: 10)],
      ).single;
      final int before = state.sessionLog.length;
      state.damageToken(t.id, 3);
      expect(state.sessionLog.length, before);
    });

    test('spostare un token lo limita alla mappa', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);
      final MapToken t = state.addTokens(
        tokens: <MapToken>[MapToken(id: 'a', name: 'X', x: 0.5, y: 0.5)],
      ).single;

      state.moveToken(t.id, const Offset(0.8, 0.25));
      expect(state.mapTokens.single.x, 0.8);
      expect(state.mapTokens.single.y, 0.25);

      state.moveToken(t.id, const Offset(2, -1));
      expect(state.mapTokens.single.x, 1);
      expect(state.mapTokens.single.y, 0);
    });

    test('togliere un gruppo toglie solo quel gruppo', () async {
      final AppState state = await withCampaign();
      addTearDown(state.dispose);

      final List<MapToken> first = state.addTokens(
        tokens: <MapToken>[
          MapToken(id: 'a', name: 'A1', x: 0.2, y: 0.2),
          MapToken(id: 'b', name: 'A2', x: 0.3, y: 0.2),
        ],
        groupLabel: 'Gruppo A',
      );
      state.addTokens(tokens: <MapToken>[MapToken(id: 'c', name: 'B1', x: 0.7, y: 0.7)], groupLabel: 'Gruppo B');

      state.removeTokenGroup(first.first.groupId);
      expect(state.mapTokens.length, 1);
      expect(state.mapTokens.single.name, 'B1');
    });

    test('il registro registra solo quando c e un documento', () async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      state.recordSessionEvent('Tiro: 1d10 + 7 = 14', delta: 'TIRO');
      expect(state.sessionLog.first.description, contains('1d10'));
      expect(state.campaign, isNull);
      expect(state.canRecordSession, isFalse);

      state.recordSessionEvent('');
      expect(state.sessionLog.length, 1);
    });
  });

  group('Bottino verso la scheda', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('cpredux_loot_test');
      AppPaths.overrideForTesting(config: temp.path, data: temp.path, documents: temp.path);
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

    AppState withCatalog() => AppState(
          catalog: ItemCatalog.inMemory(items: <CatalogItem>[
            CatalogItem(
              id: 'wpn-heavy-pistol',
              name: 'Pistola pesante',
              category: ItemCategory.weapon,
              rarity: Rarity.common,
              cost: 100,
              weight: 1,
            ),
          ]),
        );

    test('un oggetto che il catalogo conosce entra come voce di catalogo', () async {
      final AppState state = withCatalog();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      final int placed = state.addLootToInventory(name: 'Pistola pesante', quantity: 2);
      expect(placed, 2);

      final CharacterSheet sheet = state.sheet!;
      expect(sheet.inventory.length, 2);
      expect(sheet.inventory.first.catalogId, 'wpn-heavy-pistol');
      expect(sheet.inventory.first.custom, isNull);
      expect(state.sessionLog.first.description, contains('Pistola pesante ×2'));
    });

    test('un oggetto che il catalogo non ha entra definito nella scheda', () async {
      final AppState state = withCatalog();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      state.addLootToInventory(name: 'Chip di dati', note: 'un registro di pagamenti');

      final CharacterSheet sheet = state.sheet!;
      expect(sheet.inventory.length, 1);
      // Il chip non e' un oggetto di catalogo: scartarlo farebbe perdere il pezzo
      // di bottino piu' interessante.
      expect(sheet.inventory.first.catalogId, isNull);
      expect(sheet.inventory.first.custom?.name, 'Chip di dati');
      expect(sheet.inventory.first.custom?.description, 'un registro di pagamenti');
    });

    test('senza scheda aperta il bottino non entra e non mente', () async {
      final AppState state = withCatalog();
      addTearDown(state.dispose);

      expect(state.addLootToInventory(name: 'Pistola pesante'), 0);
      expect(state.addEurobucks(500), isFalse);
      expect(state.sessionLog, isEmpty);
    });

    test('i contanti vanno sul conto con la causale', () async {
      final AppState state = withCatalog();
      addTearDown(state.dispose);
      await state.createSheet(name: 'V', directory: temp.path);

      expect(state.addEurobucks(350, reason: 'Bottino di strada'), isTrue);
      expect(state.sheet!.eurobucks, 350);
      expect(state.sessionLog.first.description, contains('+350 eb'));
      expect(state.sessionLog.first.delta, 'eb');
    });
  });
}
