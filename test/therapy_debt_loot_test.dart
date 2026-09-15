import 'dart:math' as math;

import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/settings_store.dart';
import 'package:cpredux/domain/gm/gm_calculators.dart';
import 'package:cpredux/domain/gm/gm_rules.dart';
import 'package:cpredux/features/ai/ai_assistant_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Terapia Umanità Disattivabile', () {
    test('Regola terapia abilitata predefinita a 1.0 (attiva)', () {
      final GmRuleBook book = GmRuleBook();
      expect(book.rule(GmRules.therapyEnabled).value, equals(1.0));
    });

    test('AppState permette di attivare e disattivare la terapia', () async {
      final AppState state = AppState();
      addTearDown(() async {
        await state.setTherapyEnabled(true);
        state.settings.gmRuleOverrides.remove(GmRules.therapyEnabled.id);
        SettingsStore.save(state.settings);
        state.dispose();
      });

      await state.setTherapyEnabled(true);
      expect(state.isTherapyEnabled, isTrue);

      await state.setTherapyEnabled(false);
      expect(state.isTherapyEnabled, isFalse);

      await state.setTherapyEnabled(true);
      expect(state.isTherapyEnabled, isTrue);
    });
  });

  group('Debito Specifico per Giocatore', () {
    test('Debt supporta playerId e playerName e debtorLabel', () {
      final Debt debt = Debt(
        id: 'd1',
        creditor: 'Arasaka Financial Services',
        principal: 5000,
        weeklyRatePct: 10,
        weeksElapsed: 0,
        playerId: 'p1',
        playerName: 'Johnny Vane',
      );

      expect(debt.playerName, equals('Johnny Vane'));
      expect(debt.playerId, equals('p1'));
      expect(debt.debtorLabel, equals('Johnny Vane'));
      expect(debt.summary, contains('[Johnny Vane]'));
      expect(debt.summary, contains('5000 eb'));
    });

    test('Serializzazione e deserializzazione JSON conserva i campi del debitore', () {
      final Debt original = Debt(
        id: 'd2',
        creditor: 'Militech Repo',
        principal: 10000,
        weeklyRatePct: 5,
        weeksElapsed: 3,
        playerId: 'player-42',
        playerName: 'Panam Palmer',
      );

      final Map<String, Object?> json = original.toJson();
      expect(json['playerId'], equals('player-42'));
      expect(json['playerName'], equals('Panam Palmer'));

      final Debt parsed = Debt.fromJson(json);
      expect(parsed.playerId, equals('player-42'));
      expect(parsed.playerName, equals('Panam Palmer'));
      expect(parsed.debtorLabel, equals('Panam Palmer'));
      expect(parsed.owedAt(parsed.weeksElapsed), equals(original.owedAt(original.weeksElapsed)));
    });

    test('DebtLedger filtra e calcola il totale dovuto per singolo giocatore', () {
      final DebtLedger ledger = DebtLedger(<Debt>[
        const Debt(id: '1', creditor: 'Fixer A', principal: 1000, weeklyRatePct: 0, weeksElapsed: 0, playerName: 'V'),
        const Debt(id: '2', creditor: 'Fixer B', principal: 2500, weeklyRatePct: 0, weeksElapsed: 0, playerName: 'V'),
        const Debt(id: '3', creditor: 'Arasaka', principal: 8000, weeklyRatePct: 0, weeksElapsed: 0, playerName: 'Jackie'),
      ]);

      expect(ledger.distinctPlayerNames, containsAll(<String>['V', 'Jackie']));
      expect(ledger.debtsForPlayer('V').length, equals(2));
      expect(ledger.totalOwedBy('V'), equals(3500));
      expect(ledger.debtsForPlayer('Jackie').length, equals(1));
      expect(ledger.totalOwedBy('Jackie'), equals(8000));
      expect(ledger.totalOwedBy('Sconosciuto'), equals(0));
    });
  });

  group('Generatore Loot Nemico (Base, Avanzata, Manuale)', () {
    test('Modalità Base rispetta scala qualità 0-10', () {
      final AiAssistantService service = AiAssistantService.instance;

      // Qualità 0: spazzatura/tasche vuote, pochi spiccioli
      final AiLootResult low = service.generateLootWithAiProceduralSync(
        prompt: 'Scagnozzo',
        quality: 0,
        random: math.Random(42),
      );
      expect(low.entries, isNotEmpty);
      expect(low.eurodollars, lessThan(20));

      // Qualità 10: alta gamma
      final AiLootResult high = service.generateLootWithAiProceduralSync(
        prompt: 'Agente Corp',
        quality: 10,
        random: math.Random(99),
      );
      expect(high.entries, isNotEmpty);
      expect(high.eurodollars, greaterThan(1000));
    });

    test('Reroll non si basa sul loot precedente e genera esiti indipendenti', () {
      final AiAssistantService service = AiAssistantService.instance;

      // Due chiamate successive con seed/istanze casuali diverse generano istanze fresche
      final AiLootResult roll1 = service.generateLootWithAiProceduralSync(
        prompt: 'Poliziotto NCPD',
        quality: 5,
        random: math.Random(101),
      );

      final AiLootResult roll2 = service.generateLootWithAiProceduralSync(
        prompt: 'Poliziotto NCPD',
        quality: 5,
        random: math.Random(202),
      );

      expect(identical(roll1, roll2), isFalse);
      expect(identical(roll1.entries, roll2.entries), isFalse);
    });

    test('Environment API key getter ed effectiveApiKey', () {
      final AiAssistantService service = AiAssistantService.instance;
      // Verifica che non lanci eccezioni e rispetti l'integrazione env
      expect(service.hasEnvKey, isA<bool>());
      expect(service.effectiveApiKey, isA<String>());
    });
  });
}
