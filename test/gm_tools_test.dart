import 'dart:math' as math;

import 'package:cpredux/domain/dice_expression.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/gm/gm_calculators.dart';
import 'package:cpredux/domain/gm/gm_generators.dart';
import 'package:cpredux/domain/gm/gm_rules.dart';
import 'package:cpredux/domain/net_architecture.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un `Random` che restituisce facce decise dal test.
///
/// `nextInt(n)` di Dart e' a base zero, ma un gioco di dadi ragiona in facce
/// ("esce 10"): la conversione sta qui una volta sola, invece di essere
/// riscritta in ogni test con lo sbaglio di un'unità in agguato.
class FaceRandom implements math.Random {
  FaceRandom(this.faces);

  final List<int> faces;
  int _cursor = 0;

  int _pick() {
    final int face = faces[_cursor % faces.length];
    _cursor++;
    return face;
  }

  @override
  int nextInt(int max) => (_pick() - 1).clamp(0, max - 1);

  @override
  double nextDouble() => (_pick() - 1) / 100;

  @override
  bool nextBool() => _pick().isEven;
}

void main() {
  // ======================================================================
  // Espressioni di dado
  // ======================================================================
  group('Espressioni di dado', () {
    DiceExpression withFaces(List<int> faces, {DiceNameResolver? names}) =>
        DiceExpression(random: FaceRandom(faces), resolveName: names);

    DiceNameResolver names(Map<String, int> table) => (String name) => table[name];

    test('la matematica rispetta la precedenza e le parentesi', () {
      expect(withFaces(<int>[1]).evaluate('2 + 3 * 4').total, 14);
      expect(withFaces(<int>[1]).evaluate('(2 + 3) * 4').total, 20);
      expect(withFaces(<int>[1]).evaluate('10 - 4').total, 6);
      expect(withFaces(<int>[1]).evaluate('10 / 3').total, 3);
      expect(withFaces(<int>[1]).evaluate('-5 + 8').total, 3);
    });

    test('risolve i nomi di caratteristiche e abilita', () {
      final DiceExpression engine = withFaces(
        <int>[5],
        names: names(<String, int>{'RIF': 8, 'Pistole': 6, 'Riflessi': 8}),
      );
      final ExpressionRoll roll = engine.evaluate('1d10 + RIF + Pistole');
      expect(roll.total, 19);
      expect(roll.resolvedNames['RIF'], 8);
      expect(roll.resolvedNames['Pistole'], 6);
    });

    test('un nome sconosciuto e\' un errore, non uno zero', () {
      // Il caso che conta: se "Pistol" (inglese) valesse 0, il tiro uscirebbe
      // plausibile e sbagliato, e nessuno se ne accorgerebbe mai.
      expect(
        () => withFaces(<int>[5], names: names(<String, int>{'RIF': 8})).evaluate('1d10 + Pistol'),
        throwsA(isA<DiceExpressionError>()),
      );
    });

    test('l\'esplosione ritira e somma', () {
      final ExpressionRoll roll = withFaces(<int>[10, 7]).evaluate('1d10!');
      expect(roll.groups.single.results, <int>[10, 7]);
      expect(roll.total, 17);
      expect(roll.groups.single.exploded, isTrue);
    });

    test('kh tiene i dadi piu alti, kl i piu bassi', () {
      final ExpressionRoll high = withFaces(<int>[5, 3, 2, 1]).evaluate('4d6kh3');
      expect(high.total, 10);
      final ExpressionRoll low = withFaces(<int>[5, 3, 2, 1]).evaluate('4d6kl2');
      expect(low.total, 3);
    });

    test('un d10 da solo si scrive come "d10"', () {
      expect(withFaces(<int>[7]).evaluate('d10').total, 7);
    });

    test('la divisione per zero viene rifiutata', () {
      expect(() => withFaces(<int>[1]).evaluate('6 / 0'), throwsA(isA<DiceExpressionError>()));
    });

    test('un kh impossibile viene rifiutato invece di essere ignorato', () {
      expect(() => withFaces(<int>[1]).evaluate('2d6kh5'), throwsA(isA<DiceExpressionError>()));
    });

    test('il critico di un solo d10 viene riconosciuto', () {
      expect(withFaces(<int>[10]).evaluate('1d10').singleD10Outcome, DiceOutcome.critical);
      expect(withFaces(<int>[1]).evaluate('1d10').singleD10Outcome, DiceOutcome.fumble);
      expect(withFaces(<int>[5]).evaluate('1d10').singleD10Outcome, DiceOutcome.normal);
      // Con tre dadi la nozione di "il d10" non esiste: meglio nulla che un
      // critico inventato sul primo dei tre.
      expect(withFaces(<int>[5, 5, 5]).evaluate('3d10').singleD10Outcome, isNull);
    });

    test('il dettaglio del tiro e\' ricostruibile', () {
      final ExpressionRoll roll = withFaces(<int>[5, 3]).evaluate('1d6 + 3d6kh2');
      expect(roll.breakdown, contains('5'));
      expect(roll.breakdown, contains('tiene'));
      expect(roll.hasDice, isTrue);
    });

    test('validate distingue una forma sbagliata da un nome mancante', () {
      expect(DiceExpression.validate(''), isNotNull);
      expect(DiceExpression.validate('1d10 + RIF'), isNull);
      expect(DiceExpression.validate('2d6 * 3kh2'), isNotNull);
    });

    test('il risolutore dalla scheda trova sigle, caratteristiche e abilita', () {
      final CharacterSheet sheet = CharacterSheet.fresh(id: 's', name: 'V', now: '2026-09-15T00:00:00Z');
      sheet.statBase[Stat.reflexes] = 8;
      sheet.skillLevels[Skill.handgun] = 6;
      final DiceNameResolver resolver = sheetNameResolver(sheet);
      expect(resolver('RIF'), 8);
      expect(resolver('riflessi'), 8);
      expect(resolver('Pistole'), 6);
      expect(resolver('pistole'), 6);
      expect(resolver('Pistol'), isNull);
    });

    test('una macro si salva e si rilegge', () {
      const DiceMacro macro = DiceMacro(
        id: 'm1',
        name: 'Attacco con Malorian 3516',
        expression: '1d10 + RIF + Pistole',
        note: 'arma di qualita\' eccellente',
      );
      final DiceMacro back = DiceMacro.fromJson(macro.toJson());
      expect(back.name, macro.name);
      expect(back.expression, macro.expression);
      expect(back.note, macro.note);
    });
  });

  // ======================================================================
  // Regole con provenienza
  // ======================================================================
  group('Regole con provenienza', () {
    test('nessun numero e\' presentato come verificato se non lo e\'', () {
      // Il valore del controllo non sta nel numero: sta nel fatto che la
      // differenza fra "regola" e "proposta" esista e sia visibile.
      expect(GmRules.all, isNotEmpty);
      for (final GmRule rule in GmRules.all) {
        if (rule.confidence != GmConfidence.verificato) {
          expect(rule.note, isNotEmpty, reason: '${rule.id} dichiara dei dubbi senza dire quali');
        }
      }
      expect(GmRules.unverifiedCount, greaterThan(0));
    });

    test('le correzioni del tavolo vincono sui valori predefiniti e restano nel limite', () {
      final GmRuleBook rules = GmRuleBook();
      expect(rules.intValue('therapy.cost.standard'), 500);
      rules.set('therapy.cost.standard', 750);
      expect(rules.intValue('therapy.cost.standard'), 750);
      expect(rules.isOverridden('therapy.cost.standard'), isTrue);
      // Un refuso non deve poter entrare: 10 milioni per una settimana di
      // terapia e' un numero che nessuno si accorgerebbe di aver scritto.
      rules.set('therapy.cost.standard', 99999999);
      expect(rules.value('therapy.cost.standard'), lessThanOrEqualTo(100000));
      rules.clear('therapy.cost.standard');
      expect(rules.intValue('therapy.cost.standard'), 500);
    });

    test('le correzioni si salvano e si rileggono', () {
      final GmRuleBook rules = GmRuleBook()..set('heal.medtechBonus', 5);
      final GmRuleBook back = GmRuleBook.fromJson(rules.toJson());
      expect(back.value('heal.medtechBonus'), 5);
      expect(back.intValue('therapy.cost.standard'), 500);
    });

    test('una tabella pesata non favorisce una voce per caso', () {
      const RollTable<String> table = RollTable<String>(
        id: 't',
        title: 't',
        entries: <WeightedEntry<String>>[
          WeightedEntry<String>('a', weight: 3),
          WeightedEntry<String>('b', weight: 1),
        ],
      );
      expect(table.totalWeight, 4);
      expect(table.probabilities.first, closeTo(0.75, 0.0001));
      expect(table.roll(FaceRandom(<int>[1])).value, 'a');
      expect(table.roll(FaceRandom(<int>[4])).value, 'b');
      // Il numero uscito viene riportato: serve al Master per dirlo ad alta voce.
      expect(table.roll(FaceRandom(<int>[4])).index, 4);
    });
  });

  // ======================================================================
  // Generatori
  // ======================================================================
  group('Incontri notturni', () {
    test('la taglia del tavolo cambia il numero di nemici, non la scena', () {
      final NightEncounter small = NightEncounterGenerator.generate(FaceRandom(<int>[1]), playerCount: 2);
      final NightEncounter big = NightEncounterGenerator.generate(FaceRandom(<int>[1]), playerCount: 8);
      expect(small.title, big.title);
      expect(small.enemies.length, lessThan(big.enemies.length));
      expect(small.enemies, isNotEmpty);
    });

    test('un incontro di atmosfera non ha nemici', () {
      // La pioggia acida e' la quinta voce: peso 6+6+4+2 = 18 prima di lei.
      final NightEncounter rain = NightEncounterGenerator.generate(FaceRandom(<int>[19]), playerCount: 4);
      expect(rain.title, contains('Pioggia acida'));
      expect(rain.enemies, isEmpty);
      expect(rain.briefing, contains('Pioggia acida'));
    });

    test('un tiro oltre il peso totale resta dentro la tabella', () {
      final NightEncounter last = NightEncounterGenerator.generate(FaceRandom(<int>[999]), playerCount: 4);
      expect(last.title, NightEncounterGenerator.table.entries.last.value.title);
    });

    test('il briefing elenca i nemici con i loro numeri', () {
      final NightEncounter e = NightEncounterGenerator.generate(FaceRandom(<int>[1]), playerCount: 4);
      expect(e.briefing, contains('Minaccia'));
      for (final Mook m in e.enemies) {
        expect(e.briefing, contains(m.name));
        expect(m.statLine, contains('Combattimento'));
      }
    });
  });

  group('PNG rapidi', () {
    test('i tre numeri aggregati seguono il livello', () {
      final Mook grunt = MookGenerator.generate(MookTier.scagnozzo, FaceRandom(<int>[1]));
      final Mook lethal = MookGenerator.generate(MookTier.letale, FaceRandom(<int>[1]));
      expect(grunt.combat, lessThan(lethal.combat));
      expect(grunt.hitPoints, lessThan(lethal.hitPoints));
      expect(grunt.statLine, contains('Difesa'));
    });

    test('una banda ha tanti PNG quanti ne servono e nomi distinti', () {
      final List<Mook> band = MookGenerator.band(MookTier.professionista, 5, FaceRandom(<int>[1, 2, 3]), namePrefix: 'Tyger');
      expect(band.length, 5);
      expect(band.first.name, 'Tyger 1');
      expect(band.last.name, 'Tyger 5');
    });
  });

  group('Bottino', () {
    test('il bottino di una banda somma il denaro e accorpa i doppioni', () {
      final List<Mook> band = MookGenerator.band(MookTier.professionista, 4, FaceRandom(<int>[2, 2, 2]));
      final LootBundle loot = LootGenerator.band(band, FaceRandom(<int>[1]));
      expect(loot.eurodollars, greaterThan(0));
      // Lo stesso oggetto trovato due volte deve comparire come quantita', non
      // come due righe identiche: al tavolo "Municizioni ×2" e' una risposta,
      // due righe uguali sono un errore di stampa.
      for (final LootEntry entry in loot.entries) {
        expect(loot.entries.where((LootEntry e) => e.name == entry.name && e.kind == entry.kind).length, 1);
      }
    });

    test('le munizioni seguono la taglia del nemico', () {
      final LootBundle grunt = LootGenerator.forMook(
        MookGenerator.generate(MookTier.scagnozzo, FaceRandom(<int>[1])),
        FaceRandom(<int>[2]),
      );
      expect(grunt.owner, isNotEmpty);
      expect(grunt.summary, contains('eb'));
    });
  });

  group('Screamsheets', () {
    test('il pezzo ha titolo, firma e due brevi diverse', () {
      final Screamsheet sheet = ScreamsheetGenerator.generate(FaceRandom(<int>[1, 3, 5]));
      expect(sheet.headline, isNotEmpty);
      expect(sheet.byline, isNotEmpty);
      expect(sheet.ticker.length, 2);
      expect(sheet.ticker.first, isNot(sheet.ticker.last));
      expect(sheet.plainText, contains(sheet.headline));
    });

    test('le brevi restano due anche su liste corte', () {
      expect(ScreamsheetGenerator.generate(FaceRandom(<int>[9])).ticker, hasLength(2));
    });
  });

  group('Droghe', () {
    test('la prova di dipendenza distingue riuscita e fallimento', () {
      final StreetDrug lace = DrugCatalog.all.firstWhere((StreetDrug d) => d.name == 'Black Lace');
      final AddictionOutcome failed = DrugCatalog.test(lace, 0, FaceRandom(<int>[1]));
      expect(failed.total, 1);
      expect(failed.addicted, isTrue);
      final AddictionOutcome passed = DrugCatalog.test(lace, 10, FaceRandom(<int>[10]));
      expect(passed.addicted, isFalse);
      expect(passed.text, contains('DV'));
    });

    test('un modificatore altissimo rende la dipendenza non inevitabile', () {
      final StreetDrug boost = DrugCatalog.all.firstWhere((StreetDrug d) => d.name == 'Boost');
      // Boost ha DV 14: con +10 di resistenza e' impossibile fallire, con +7 si
      // fallisce a volte, con 0 si fallisce sempre.
      expect(DrugCatalog.expectedDosesBeforeAddiction(boost, 99), double.infinity);
      expect(DrugCatalog.expectedDosesBeforeAddiction(boost, 7), greaterThan(1));
      expect(DrugCatalog.expectedDosesBeforeAddiction(boost, 0), 1);
    });

    test('la crisi arriva solo a chi e\' dipendente', () {
      final StreetDrug smash = DrugCatalog.all.firstWhere((StreetDrug d) => d.name == 'Smash');
      expect(AddictionState(drug: smash, dosesTaken: 3, addicted: true, daysSinceLastDose: 2).inWithdrawal, isTrue);
      expect(AddictionState(drug: smash, dosesTaken: 3, addicted: false, daysSinceLastDose: 2).inWithdrawal, isFalse);
    });
  });

  group('Lavori secondari', () {
    test('il ruolo si trova anche scritto in modo diverso', () {
      final HustleResult a = HustleGenerator.generate('Fixer', 3, FaceRandom(<int>[1]));
      final HustleResult b = HustleGenerator.generate('  fixer ', 3, FaceRandom(<int>[1]));
      expect(a.job, b.job);
      expect(a.earned, b.earned);
      expect(a.earned, greaterThan(0));
    });

    test('un ruolo che non esiste non fa sparire il pannello', () {
      final HustleResult odd = HustleGenerator.generate('Cantante', 1, FaceRandom(<int>[1]));
      expect(odd.job, isNotEmpty);
      expect(odd.earned, greaterThan(0));
    });
  });

  group('Dettagli di scena', () {
    test('ogni campo e\' valorizzato', () {
      final SceneDressing scene = SceneGenerator.generate(FaceRandom(<int>[2]));
      expect(scene.text, contains('Odore'));
      expect(scene.place, isNotEmpty);
      expect(scene.keeper, isNotEmpty);
      expect(scene.sound, isNotEmpty);
    });
  });

  // ======================================================================
  // Calcolatori
  // ======================================================================
  group('DV balistico', () {
    test('le fasce di distanza hanno i confini giusti', () {
      expect(RangeBand.forDistance(0), RangeBand.b0to6);
      expect(RangeBand.forDistance(6), RangeBand.b0to6);
      expect(RangeBand.forDistance(6.5), RangeBand.b7to12);
      expect(RangeBand.forDistance(7), RangeBand.b7to12);
      expect(RangeBand.forDistance(800), RangeBand.b401to800);
      expect(RangeBand.forDistance(801), isNull);
    });

    test('il DV segue la fascia, non la distanza esatta', () {
      final int atTwo = Ballistics.dvFor(WeaponClass.pistola, 2);
      final int atFive = Ballistics.dvFor(WeaponClass.pistola, 5);
      expect(atTwo, atFive);
      expect(Ballistics.dvFor(WeaponClass.pistola, 30), greaterThan(atFive));
      // La mitragliatrice e' l'arma che migliora a media distanza: se le due
      // fasce fossero uguali per tutte le armi, la tabella non servirebbe.
      expect(Ballistics.dvAtBand(WeaponClass.mitragliatrice, RangeBand.b7to12), lessThan(
        Ballistics.dvAtBand(WeaponClass.mitragliatrice, RangeBand.b0to6),
      ));
      // Un tavolo che misura in metri e mezzi non deve restare senza fascia.
      expect(RangeBand.forDistance(6.5), RangeBand.b7to12);
      expect(RangeBand.forDistance(25.5), RangeBand.b26to50);
    });

    test('oltre la gittata il tiro non si fa, e viene detto', () {
      final BallisticSolution s = Ballistics.solve(weapon: WeaponClass.pistola, meters: 900);
      expect(s.inRange, isFalse);
      expect(s.summary, contains('non si puo'));
    });

    test('le scelte tattiche si vedono una per una', () {
      final BallisticSolution s = Ballistics.solve(
        weapon: WeaponClass.fucileAssalto,
        meters: 10,
        aimedShot: true,
        targetInCover: true,
      );
      expect(s.modifier, -4);
      expect(s.notes.length, 2);
      expect(s.finalDv, s.baseDv - 4);
    });

    test('la tabella si puo correggere come qualsiasi altra regola', () {
      // Lo schema aggiuntivo e' obbligatorio: senza, il libro delle regole non
      // conosce gli identificativi dei DV e `set` scriverebbe nel vuoto.
      final GmRuleBook rules = GmRuleBook(schema: Ballistics.asRules());
      final String id = 'dv.${WeaponClass.pistola.name}.${RangeBand.b0to6.name}';
      final int before = Ballistics.dvAtBand(WeaponClass.pistola, RangeBand.b0to6, rules: rules);
      rules.set(id, 11);
      expect(rules.isOverridden(id), isTrue);
      expect(Ballistics.dvAtBand(WeaponClass.pistola, RangeBand.b0to6, rules: rules), 11);
      expect(before, isNot(11));
      expect(Ballistics.asRules().length, WeaponClass.values.length * RangeBand.values.length);
      // Un identificativo che non esiste non deve entrare di nascosto.
      rules.set('dv.non.esiste', 1);
      expect(rules.isOverridden('dv.non.esiste'), isFalse);
    });
  });

  group('Cyberpsicosi e terapia', () {
    HumanityReport report({required int empathy, required int lost, int implants = 3}) =>
        Cyberpsychosis.report(empathyAtCreation: empathy, currentEmpathy: empathy, humanityLost: lost, implantCount: implants);

    test('lo stato segue le soglie manualistiche CPRed (>40 stabile, <=40 erosione/immunosoppressori, <=20 al limite, <10 cyberpsicosi)', () {
      // 80 di massimo:
      // 20 persi -> UMA 60 (> 40): Stabile
      // 45 persi -> UMA 35 (<= 40 e > 20): In erosione (richiede immunosoppressori)
      // 66 persi -> UMA 14 (<= 20 e >= 10): Al limite (NON ancora cyberpsicopatico conclamato)
      // 72 persi -> UMA 8 (< 10 ed EMP 0): Cyberpsicosi conclamata irreversibile
      // 80 persi -> UMA 0: Cyberpsicosi
      expect(report(empathy: 8, lost: 20).status, HumanityStatus.stabile);
      expect(report(empathy: 8, lost: 45).status, HumanityStatus.inErosione);
      expect(report(empathy: 8, lost: 66).status, HumanityStatus.alLimite);
      expect(report(empathy: 8, lost: 72).status, HumanityStatus.cyberpsicosi);
      expect(report(empathy: 8, lost: 80).status, HumanityStatus.cyberpsicosi);
      expect(report(empathy: 8, lost: 80).current, 0);
      expect(report(empathy: 8, lost: 80).summary, contains('0/80'));
    });

    test('il piano di terapia costa, dura e non supera il massimo', () {
      final HumanityReport r = report(empathy: 8, lost: 30); // 50/80, mancano 30
      final GmRuleBook rules = GmRuleBook();
      final TherapyPlan plan = Cyberpsychosis.plan(report: r, program: TherapyProgram.standard, weeks: 10, rules: rules);
      expect(plan.humanityPerWeek, 2);
      expect(plan.costPerWeek, 500);
      expect(plan.totalCost, 5000);
      expect(plan.humanityRecovered, 20);
      expect(plan.schedule.length, 10);
      // L'ultima settimana non deve portare l'Umanita' oltre il massimo.
      expect(plan.schedule.last.humanityAfter, lessThanOrEqualTo(r.maxHumanity));
    });

    test('l\'Umanita\' sprecata oltre il tetto viene dichiarata, non nascosta', () {
      final HumanityReport r = report(empathy: 8, lost: 70, implants: 1); // mancano 70, ma 1 impianto
      final TherapyPlan plan = Cyberpsychosis.plan(
        report: r,
        program: TherapyProgram.estrema,
        weeks: 40,
        rules: GmRuleBook(),
      );
      expect(plan.cappedByImplantLimit, isTrue);
      expect(plan.wastedHumanity, greaterThan(0));
      expect(plan.humanityRecovered, lessThanOrEqualTo(r.recoverable));
    });

    test('il calendario racconta le soglie, non solo i numeri', () {
      final HumanityReport r = report(empathy: 8, lost: 80, implants: 3);
      final TherapyPlan plan = Cyberpsychosis.plan(
        report: r,
        program: TherapyProgram.estrema,
        weeks: 6,
        rules: GmRuleBook(),
      );
      expect(plan.schedule.first.humanityAfter, greaterThan(0));
      expect(plan.schedule.map((TherapyWeek w) => w.milestone).join(' '), contains('cyberpsicosi'));
      expect(plan.summary, contains('settimane'));
    });

    test('senza terapia non si promette niente', () {
      final TherapyPlan none = Cyberpsychosis.plan(
        report: report(empathy: 5, lost: 10),
        program: TherapyProgram.nessuna,
        rules: GmRuleBook(),
      );
      expect(none.weeks, 0);
      expect(none.totalCost, 0);
      expect(none.summary, contains('Nessuna'));
    });
  });

  group('Guarigione', () {
    test('il riposo completo guarisce piu in fretta dell\'attivita leggera', () {
      final GmRuleBook rules = GmRuleBook();
      final HealingPlan rest = Healing.plan(
        missingHitPoints: 30, body: 5, completeRest: true, medtechWithDrugs: false,
        severeInjuries: 0, rules: rules,
      );
      final HealingPlan light = Healing.plan(
        missingHitPoints: 30, body: 5, completeRest: false, medtechWithDrugs: false,
        severeInjuries: 0, rules: rules,
      );
      expect(rest.daysToFull, 3);
      expect(light.daysToFull, 6);
      expect(rest.summary, contains('PV'));
    });

    test('un Medtech accorcia, e senza alloggio si peggiora', () {
      final GmRuleBook rules = GmRuleBook();
      final HealingPlan withMed = Healing.plan(
        missingHitPoints: 24, body: 5, completeRest: true, medtechWithDrugs: true,
        severeInjuries: 0, rules: rules,
      );
      final HealingPlan homeless = Healing.plan(
        missingHitPoints: 24, body: 5, completeRest: true, medtechWithDrugs: false,
        severeInjuries: 0, rules: rules, homeless: true,
      );
      expect(withMed.hitPointsPerDay, greaterThan(homeless.hitPointsPerDay));
      expect(withMed.notes.join(' '), contains('Medtech'));
      expect(homeless.notes.join(' '), contains('alloggio'));
    });

    test('una ferita grave non guarisce dormendo due giorni', () {
      final HealingPlan plan = Healing.plan(
        missingHitPoints: 10, body: 8, completeRest: true, medtechWithDrugs: false,
        severeInjuries: 1, rules: GmRuleBook(),
      );
      // Il recupero dei PV sarebbe rapidissimo; la degenza della ferita no, ed e'
      // quella che comanda.
      expect(plan.daysToFull, lessThan(plan.severeInjuryDays));
      expect(plan.totalDays, plan.severeInjuryDays);
    });
  });

  group('Stile di vita', () {
    test('il conto mensile somma cibo, tetto e ricorrenti', () {
      final LifestyleLedger ledger = Lifestyle.ledger(
        food: FoodTier.kibble,
        housing: HousingTier.cubeHotel,
        rules: GmRuleBook(),
        otherRecurring: 100,
        wallet: 1200,
      );
      expect(ledger.monthlyCost, 700);
      expect(ledger.runwayMonths, 1);
      expect(ledger.healFactor, 1);
    });

    test('senza alloggio il recupero peggiora e si vede', () {
      final LifestyleLedger ledger = Lifestyle.ledger(
        food: FoodTier.kibble,
        housing: HousingTier.nessuno,
        rules: GmRuleBook(),
        wallet: 5000,
      );
      expect(ledger.housingCost, 0);
      expect(ledger.healFactor, lessThan(1));
      expect(ledger.summary, contains('senza alloggio'));
    });

    test('un attico costa piu di un cubo, e il conto lo dice', () {
      final GmRuleBook rules = GmRuleBook();
      expect(
        Lifestyle.ledger(food: FoodTier.fresco, housing: HousingTier.attico, rules: rules).monthlyCost,
        greaterThan(Lifestyle.ledger(food: FoodTier.kibble, housing: HousingTier.cubeHotel, rules: rules).monthlyCost),
      );
    });
  });

  group('Debiti e contratti', () {
    const Debt loan = Debt(
      id: 'd1',
      creditor: 'un usuraio di Heywood',
      principal: 1000,
      weeklyRatePct: 10,
      weeksElapsed: 0,
      collateral: 'la tua pistola',
    );

    test('l\'interesse si accumula sugli interessi', () {
      expect(loan.owedNow, 1000);
      expect(loan.owedAt(2), 1210);
      expect(loan.summary, contains('usuraio'));
      expect(loan.summary, contains('garanzia'));
    });

    test('il registro proietta il futuro invece di aspettare che accada', () {
      final DebtLedger ledger = DebtLedger(<Debt>[loan]);
      expect(ledger.totalOwed, 1000);
      expect(ledger.projectedAt(4), greaterThan(1400));
    });

    test('il debito che cresce piu in fretta e\' quello da pagare per primo', () {
      final DebtLedger ledger = DebtLedger(<Debt>[
        const Debt(id: 'piccolo', creditor: 'un amico', principal: 200, weeklyRatePct: 0, weeksElapsed: 0),
        const Debt(id: 'cattivo', creditor: 'una banca', principal: 5000, weeklyRatePct: 5, weeksElapsed: 0),
      ]);
      expect(ledger.fastestGrowing?.id, 'cattivo');
      // Non e' il piu' grosso in assoluto: e' quello che costa di piu' aspettare.
      expect(ledger.fastestGrowing?.creditor, 'una banca');
    });

    test('un pagamento estingue il debito e lo toglie dal registro', () {
      final DebtLedger ledger = DebtLedger(<Debt>[
        const Debt(id: 'd1', creditor: 'usuraio', principal: 500, weeklyRatePct: 0, weeksElapsed: 0),
      ]);
      ledger.pay(500);
      expect(ledger.debts, isEmpty);
    });

    test('un pagamento parziale resta come debito residuo', () {
      final DebtLedger ledger = DebtLedger(<Debt>[
        const Debt(id: 'd1', creditor: 'usuraio', principal: 500, weeklyRatePct: 0, weeksElapsed: 0),
      ]);
      ledger.pay(200);
      expect(ledger.totalOwed, 300);
    });

    test('il registro si salva e si rilegge', () {
      final DebtLedger back = DebtLedger.fromJson(DebtLedger(<Debt>[loan]).toJson());
      expect(back.debts.single.creditor, loan.creditor);
      expect(back.totalOwed, 1000);
    });
  });

  group('Mercato nero', () {
    test('il rango di Contatti decide cosa si trova', () {
      final GmRuleBook rules = GmRuleBook();
      expect(BlackMarket.access(contactsRank: 0, rules: rules).maxRarity, Rarity.common);
      expect(BlackMarket.access(contactsRank: 2, rules: rules).maxRarity, Rarity.uncommon);
      expect(BlackMarket.access(contactsRank: 10, rules: rules).maxRarity, Rarity.exotic);
      // Oltre il tetto non si sfonda: senza questo, un rango assurdo sbloccherebbe
      // una fascia che non esiste e il filtro andrebbe in errore.
      expect(BlackMarket.access(contactsRank: 99, rules: rules).maxRarity, Rarity.exotic);
    });

    test('il pannello dice quanto manca alla fascia successiva', () {
      final MarketAccess access = BlackMarket.access(contactsRank: 1, rules: GmRuleBook());
      expect(access.canFind(Rarity.common), isTrue);
      expect(access.canFind(Rarity.exotic), isFalse);
      expect(access.ranksToUnlockNext(), 1);
      expect(BlackMarket.access(contactsRank: 10, rules: GmRuleBook()).ranksToUnlockNext(), isNull);
    });

    test('il filtro usa la rarita\' dell\'oggetto', () {
      final MarketAccess access = BlackMarket.access(contactsRank: 0, rules: GmRuleBook());
      final List<(String, Rarity)> items = <(String, Rarity)>[
        ('kibble', Rarity.common),
        ('fucile militare', Rarity.legendary),
      ];
      final List<(String, Rarity)> found = BlackMarket.filter(items, access, ((String, Rarity) i) => i.$2);
      expect(found.length, 1);
      expect(found.single.$1, 'kibble');
    });
  });

  group('Console di rete', () {
    test('un attacco va a segno, toglie REZ e puo distruggere', () {
      final NetIceProgram target = NetIceProgram.presets.firstWhere((NetIceProgram p) => p.name == 'Skunk');
      final NetrunnerConsole console = NetrunnerConsole(ice: <NetIceProgram>[target]);
      final ProgramAttackResult result = console.attack(
        program: NetrunnerPrograms.all.firstWhere((NetAttackProgram p) => p.name == 'Banhammer'),
        target: target,
        interfaceRank: 6,
        random: FaceRandom(<int>[10]),
      );
      // Interfaccia 6 + d10 10 − 2 di Banhammer = 14, contro Difesa 2: colpisce.
      expect(result.hit, isTrue);
      expect(result.rezAfter, 0);
      expect(result.destroyed, isTrue);
      expect(result.log, contains('distrutto'));
      expect(console.active, isEmpty);
    });

    test('un tiro basso non toglie niente', () {
      final NetIceProgram target = NetIceProgram.presets.firstWhere((NetIceProgram p) => p.name == 'Dragon');
      final NetrunnerConsole console = NetrunnerConsole(ice: <NetIceProgram>[target]);
      final ProgramAttackResult result = console.attack(
        program: NetrunnerPrograms.all.first,
        target: target,
        interfaceRank: 0,
        random: FaceRandom(<int>[1]),
      );
      expect(result.hit, isFalse);
      expect(result.rezAfter, target.rez);
      expect(console.rezOf(target), target.rez);
    });

    test('il resoconto mostra i tre pezzi del conto', () {
      final NetIceProgram target = NetIceProgram.presets.first;
      final NetrunnerConsole console = NetrunnerConsole(ice: <NetIceProgram>[target]);
      final ProgramAttackResult result = console.attack(
        program: NetrunnerPrograms.all.firstWhere((NetAttackProgram p) => p.name == 'Wurm'),
        target: target,
        interfaceRank: 5,
        random: FaceRandom(<int>[7]),
      );
      expect(result.log, contains('1d10 (7)'));
      expect(result.log, contains('+ 5'));
      expect(result.log, contains('contro Difesa'));
    });

    test('il riavvio rimette tutti i programmi al REZ pieno', () {
      final NetIceProgram target = NetIceProgram.presets.first;
      final NetrunnerConsole console = NetrunnerConsole(ice: <NetIceProgram>[target]);
      console.attack(
        program: NetrunnerPrograms.all.last,
        target: target,
        interfaceRank: 8,
        random: FaceRandom(<int>[10]),
      );
      expect(console.rezOf(target), lessThan(target.rez));
      console.reset();
      expect(console.rezOf(target), target.rez);
      expect(console.active.length, 1);
    });

    test('senza programmi indicati la console ne prepara tre', () {
      expect(NetrunnerConsole().ice.length, 3);
      expect(NetrunnerConsole().rezSnapshot.length, 3);
    });
  });
}
