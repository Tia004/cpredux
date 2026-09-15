/// I calcolatori del Master: quelli che al tavolo si fanno a mente e sbagliati.
///
/// Sono tutti funzioni pure sopra [GmRuleBook]: prendono dei numeri, ne
/// restituiscono altri, e non toccano ne' il disco ne' la scheda. Il motivo e'
/// pratico: la cosa che si sbaglia piu' spesso in un'app di supporto al tavolo
/// non e' il conto, e' **l'ordine dei fattori**. Un Medtech che accorcia la
/// degenza si applica *prima* o *dopo* il riposo? Un tetto per impianto limita
/// il recupero settimanale o il totale? Se queste decisioni stanno dentro un
/// `build()` di un widget, nessuno le puo' verificare.
library;

import 'dart:math' as math;

import '../enums.dart';
import '../net_architecture.dart';
import 'gm_rules.dart';

// --------------------------------------------------------------------------
// DV balistico
// --------------------------------------------------------------------------

/// Le fasce di distanza. Otto, con i confini in metri come sul manuale.
enum RangeBand {
  b0to6('0–6 m', 0, 6),
  b7to12('7–12 m', 7, 12),
  b13to25('13–25 m', 13, 25),
  b26to50('26–50 m', 26, 50),
  b51to100('51–100 m', 51, 100),
  b101to200('101–200 m', 101, 200),
  b201to400('201–400 m', 201, 400),
  b401to800('401–800 m', 401, 800);

  const RangeBand(this.label, this.minMeters, this.maxMeters);

  final String label;
  final int minMeters;
  final int maxMeters;

  /// La fascia di una distanza.
  ///
  /// Il confronto usa **solo il limite superiore**, e non e' un dettaglio: le
  /// fasce del manuale sono "0–6", "7–12", "13–25"... e una distanza di 6,5
  /// metri non sta in nessuna delle due se si confrontano entrambi gli estremi.
  /// Un tavolo che misura 6,5 metri (meta' di una cella da 2) si troverebbe
  /// senza DV, che e' peggio di un DV approssimato.
  static RangeBand? forDistance(double meters) {
    if (meters < 0) return null;
    for (final RangeBand band in RangeBand.values) {
      if (meters <= band.maxMeters) return band;
    }
    return null;
  }
}

/// Le classi di arma a distanza, che sono quelle che hanno una tabella DV.
///
/// Non e' la categoria del catalogo: due armi con la stessa categoria merceologica
/// possono avere tabelle diverse, e il Master sceglie la riga guardando l'arma,
/// non il reparto in cui e' venduta.
enum WeaponClass {
  pistola('Pistola'),
  mitra('Mitra / SMG'),
  fucileAPompa('Fucile a pompa (palla unica)'),
  fucileAssalto('Fucile d\'assalto'),
  fucilePrecisione('Fucile di precisione'),
  mitragliatrice('Mitragliatrice'),
  arco('Arco / Balestra'),
  lanciagranate('Lanciagranate');

  const WeaponClass(this.label);

  final String label;
}

/// Il DV da battere per colpire, con il conto che ci sta dietro.
class BallisticSolution {
  const BallisticSolution({
    required this.weaponClass,
    required this.distanceMeters,
    required this.band,
    required this.baseDv,
    required this.modifier,
    required this.notes,
  });

  final WeaponClass weaponClass;
  final double distanceMeters;
  final RangeBand? band;
  final int baseDv;

  /// Somma algebrica delle scelte tattiche (tiro mirato, copertura...).
  final int modifier;
  final List<String> notes;

  int get finalDv => baseDv + modifier;

  bool get inRange => band != null;

  String get summary {
    if (!inRange) {
      return '$weaponClass: oltre la gittata massima (${distanceMeters.toStringAsFixed(0)} m) — il tiro non si puo\' fare';
    }
    final String mod = modifier == 0 ? '' : ' ${modifier > 0 ? '+' : '−'}${modifier.abs()}';
    return '${weaponClass.label} a ${distanceMeters.toStringAsFixed(0)} m: DV $baseDv$mod = $finalDv';
  }
}

abstract final class Ballistics {
  /// La tabella. **L'ordine delle fasce e' quello di [RangeBand]**.
  ///
  /// Nota sulla fiducia: la tabella DV e' la cosa piu' facile da sbagliare in
  /// tutto il gioco, perche' e' una matrice di quaranta numeri che nessuno
  /// ricorda e che tutti usano a ogni turno di combattimento. Questi valori
  /// sono la lettura di questa applicazione e sono dichiarati
  /// [GmConfidence.daVerificare]: vanno confrontati con il manuale prima di
  /// usarli a un tavolo. Sono sovrascrivibili uno per uno dal pannello.
  static const Map<WeaponClass, List<int>> dvTable = <WeaponClass, List<int>>{
    WeaponClass.pistola: <int>[13, 15, 20, 25, 30, 30, 30, 30],
    WeaponClass.mitra: <int>[15, 13, 15, 20, 25, 25, 30, 30],
    WeaponClass.fucileAPompa: <int>[13, 15, 20, 25, 30, 35, 35, 35],
    WeaponClass.fucileAssalto: <int>[17, 16, 15, 13, 15, 20, 25, 30],
    WeaponClass.fucilePrecisione: <int>[30, 25, 25, 20, 15, 16, 17, 20],
    WeaponClass.mitragliatrice: <int>[20, 18, 18, 20, 25, 30, 35, 40],
    WeaponClass.arco: <int>[15, 13, 15, 20, 25, 30, 35, 40],
    WeaponClass.lanciagranate: <int>[16, 15, 15, 20, 25, 30, 35, 40],
  };

  /// Il DV non dipende dalla distanza esatta ma dalla fascia: e' la ragione per
  /// cui il pannello puo' essere una casella con un numero di metri e non una
  /// griglia da leggere.
  static int dvFor(WeaponClass weapon, double meters, {GmRuleBook? rules}) {
    final RangeBand? band = RangeBand.forDistance(meters);
    if (band == null) return 0;
    return dvAtBand(weapon, band, rules: rules);
  }

  static int dvAtBand(WeaponClass weapon, RangeBand band, {GmRuleBook? rules}) {
    final String id = 'dv.${weapon.name}.${band.name}';
    final double? override = rules?.overrides[id];
    if (override != null) return override.round();
    return dvTable[weapon]![band.index];
  }

  /// Regola per ogni valore della tabella, per il pannello delle correzioni.
  static List<GmRule> asRules() => <GmRule>[
        for (final WeaponClass w in WeaponClass.values)
          if (dvTable[w] != null)
            for (final RangeBand b in RangeBand.values)
              GmRule(
                id: 'dv.${w.name}.${b.name}',
                label: '${w.label} · ${b.label}',
                value: dvTable[w]![b.index].toDouble(),
                unit: 'DV',
                confidence: GmConfidence.daVerificare,
                note: 'Tabella DV balistica: confrontare con il manuale.',
                group: 'DV balistico',
                max: 60,
              ),
      ];

  /// Risolve un tiro, con le scelte tattiche che cambiano il DV.
  static BallisticSolution solve({
    required WeaponClass weapon,
    required double meters,
    bool aimedShot = false,
    bool targetInCover = false,
    bool targetProne = false,
    bool movingTarget = false,
    GmRuleBook? rules,
  }) {
    final RangeBand? band = RangeBand.forDistance(meters);
    final List<String> notes = <String>[];
    int modifier = 0;
    if (aimedShot) {
      modifier += -8;
      notes.add('Tiro mirato: −8. La penalita\' e\' fissa e non dipende dalla distanza.');
    }
    if (targetInCover) {
      modifier += 4;
      notes.add('Bersaglio in copertura: +4 al DV.');
    }
    if (targetProne) {
      modifier += 2;
      notes.add('Bersaglio a terra: +2 al DV a distanza.');
    }
    if (movingTarget) {
      modifier += 2;
      notes.add('Bersaglio in movimento: +2 al DV.');
    }
    if (band == null) {
      notes.add('Oltre le otto fasce: nessun DV previsto.');
    }
    return BallisticSolution(
      weaponClass: weapon,
      distanceMeters: meters,
      band: band,
      baseDv: band == null ? 0 : dvAtBand(weapon, band, rules: rules),
      modifier: modifier,
      notes: notes,
    );
  }
}

// --------------------------------------------------------------------------
// Cyberpsicosi e terapia
// --------------------------------------------------------------------------

/// Dove sta un personaggio rispetto alla propria Umanità secondo il manuale Cyberpunk RED.
enum HumanityStatus {
  stabile(
    'Stabile',
    'Umanità > 40: Nessun sintomo evidente. Il sistema nervoso tollera bene il cyberware.',
  ),
  inErosione(
    'In erosione',
    'Umanità ≤ 40: Primi sintomi di dissociazione e deterioramento neuronale. Necessità di immunosoppressori per rallentare il decadimento del sistema nervoso.',
  ),
  alLimite(
    'Al limite',
    'Umanità ≤ 20 (≥ 10): Dissociazione grave e rischio clinico elevato, ma con Umanità ≥ 10 NON si è ancora cyberpsicopatici conclamati.',
  ),
  cyberpsicosi(
    'Cyberpsicosi',
    'Empatia = 0 e Umanità < 10: Cyberpsicopatico conclamato. Non esistono cure standard (solo trattamenti estremi/sperimentali). Il personaggio è da considerare perso / morto e diventa un PNG ostile del GM.',
  );

  const HumanityStatus(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// Il quadro di Umanita' di un personaggio.
class HumanityReport {
  const HumanityReport({
    required this.maxHumanity,
    required this.lost,
    required this.empathyAtCreation,
    required this.currentEmpathy,
    required this.implantCount,
  });

  final int maxHumanity;
  final int lost;

  /// EMP con cui il personaggio e' stato creato: la differenza con quella
  /// attuale e' il danno che la terapia puo' riparare.
  final int empathyAtCreation;
  final int currentEmpathy;
  final int implantCount;

  int get current => (maxHumanity - lost).clamp(0, maxHumanity);

  double get ratio => maxHumanity == 0 ? 0 : current / maxHumanity;

  /// Empatia calcolata dall'Umanità corrente (1 ogni 10 punti interi di Umanità).
  int get calculatedEmpathy => (current / 10).floor();

  HumanityStatus get status {
    // Si diventa cyberpsicopatici SOLO quando Empatia va a 0 E l'Umanità è sotto 10 (< 10).
    // Con Umanità >= 10 NON si diventa cyberpsicopatici.
    final int effEmp = currentEmpathy <= 0 ? 0 : calculatedEmpathy;
    if (effEmp == 0 && current < 10) {
      return HumanityStatus.cyberpsicosi;
    }
    if (current <= 20) {
      return HumanityStatus.alLimite;
    }
    if (current <= 40) {
      return HumanityStatus.inErosione;
    }
    return HumanityStatus.stabile;
  }

  /// Umanita' che manca per tornare a posto, senza superare il massimo.
  int get recoverable => (maxHumanity - current).clamp(0, maxHumanity);

  int get empathyLost => (empathyAtCreation - currentEmpathy).clamp(0, empathyAtCreation);

  String get summary => 'Umanita\' $current/$maxHumanity (${(ratio * 100).round()}%) · ${status.label}'
      '${implantCount > 0 ? ' · $implantCount impianti' : ''}';
}

enum TherapyProgram {
  nessuna('Nessuna', 'therapy.cost.standard', 'therapy.humanity.standard'),
  standard('Standard', 'therapy.cost.standard', 'therapy.humanity.standard'),
  estrema('Estrema', 'therapy.cost.extreme', 'therapy.humanity.extreme');

  const TherapyProgram(this.label, this.costRuleId, this.rateRuleId);

  final String label;
  final String costRuleId;
  final String rateRuleId;
}

/// Un ciclo di terapia pianificato.
class TherapyPlan {
  const TherapyPlan({
    required this.program,
    required this.weeks,
    required this.costPerWeek,
    required this.humanityPerWeek,
    required this.humanityRecovered,
    required this.wastedHumanity,
    required this.cappedByImplantLimit,
    required this.schedule,
  });

  final TherapyProgram program;
  final int weeks;
  final int costPerWeek;
  final int humanityPerWeek;

  /// Quanta Umanita' torna davvero, che puo' essere meno di `weeks × perWeek`
  /// per via del tetto per impianto.
  final int humanityRecovered;

  /// Quanta Umanita' si sarebbe recuperata senza il tetto: la differenza e' il
  /// motivo per cui il piano e' stato fermato, e va detto invece che nascosto.
  final int wastedHumanity;
  final bool cappedByImplantLimit;

  /// Settimana per settimana: e' la parte che serve al tavolo, perche' la
  /// terapia si gioca come tempo che passa, non come una sottrazione.
  final List<TherapyWeek> schedule;

  int get totalCost => weeks * costPerWeek;

  String get summary => weeks == 0
      ? 'Nessuna terapia pianificata'
      : '${program.label}: $weeks settimane, $totalCost eb, +$humanityRecovered Umanita\'';
}

class TherapyWeek {
  const TherapyWeek({
    required this.week,
    required this.humanityAfter,
    required this.cost,
    required this.milestone,
  });

  final int week;
  final int humanityAfter;
  final int cost;

  /// Cosa e' cambiato: "esce dalla cyberpsicosi", "torna stabile". Un numero
  /// che sale non dice niente; il superamento di una soglia si'.
  final String milestone;

  String get label => 'Settimana $week: Umanita\' $humanityAfter, $cost eb${milestone.isEmpty ? '' : ' — $milestone'}';
}

abstract final class Cyberpsychosis {
  /// Costruisce il quadro a partire dai dati della scheda.
  static HumanityReport report({
    required int empathyAtCreation,
    required int currentEmpathy,
    required int humanityLost,
    int implantCount = 0,
  }) {
    return HumanityReport(
      maxHumanity: empathyAtCreation * 10,
      lost: humanityLost,
      empathyAtCreation: empathyAtCreation,
      currentEmpathy: currentEmpathy,
      implantCount: implantCount,
    );
  }

  /// Pianifica la terapia.
  ///
  /// Le due decisioni di regola, dichiarate perche' sono le piu' facili da
  /// sbagliare in silenzio:
  ///
  /// 1. **il tetto per impianto limita il totale recuperabile**, non il ritmo
  ///    settimanale: si continua a curarsi finche' non si e' esaurito quello che
  ///    ciascun impianto ha tolto;
  /// 2. **non si supera il massimo**: l'Umanita' recuperata in eccesso non si
  ///    accumula. Nessuna delle due cose e' un'ottimizzazione: senza la prima la
  ///    terapia annulla il costo del cyberware, senza la seconda si puo'
  ///    superare il massimo del personaggio e i totali smettono di avere senso.
  static TherapyPlan plan({
    required HumanityReport report,
    required TherapyProgram program,
    int? weeks,
    required GmRuleBook rules,
  }) {
    if (program == TherapyProgram.nessuna) {
      return const TherapyPlan(
        program: TherapyProgram.nessuna,
        weeks: 0,
        costPerWeek: 0,
        humanityPerWeek: 0,
        humanityRecovered: 0,
        wastedHumanity: 0,
        cappedByImplantLimit: false,
        schedule: <TherapyWeek>[],
      );
    }

    final int costPerWeek = rules.intValue(program.costRuleId);
    final int perWeek = rules.intValue(program.rateRuleId);

    // Il tetto: quanto di quella Umanita' e' imputabile a impianti e quindi
    // recuperabile. Con zero impianti non si recupera niente per questa via.
    final int perImplantMultiplier = rules.intValue('therapy.cap.perImplant');
    final int cap = report.implantCount == 0 ? report.recoverable : report.implantCount * perImplantMultiplier * 10;
    final int target = math.min(report.recoverable, cap);

    final int wanted = weeks ?? (perWeek == 0 ? 0 : (target / perWeek).ceil());
    final int effectiveWeeks = math.max(0, weekClamp(wanted));
    final int raw = effectiveWeeks * perWeek;
    final int recovered = math.min(raw, report.recoverable);
    final bool capped = raw > report.recoverable;

    final List<TherapyWeek> schedule = <TherapyWeek>[];
    int humanity = report.current;
    final HumanityStatus start = report.status;
    for (int w = 1; w <= effectiveWeeks; w++) {
      final int before = humanity;
      humanity = math.min(report.maxHumanity, humanity + perWeek);
      schedule.add(TherapyWeek(
        week: w,
        humanityAfter: humanity,
        cost: costPerWeek,
        milestone: _milestone(before, humanity, report, start),
      ));
    }

    return TherapyPlan(
      program: program,
      weeks: effectiveWeeks,
      costPerWeek: costPerWeek,
      humanityPerWeek: perWeek,
      humanityRecovered: recovered,
      wastedHumanity: raw - recovered,
      cappedByImplantLimit: capped,
      schedule: schedule,
    );
  }

  static int weekClamp(int weeks) => weeks.clamp(0, 520);

  /// Descrive il passaggio di una soglia, non il numero.
  static String _milestone(int before, int after, HumanityReport report, HumanityStatus start) {
    HumanityStatus statusAt(int humanity) {
      final int effEmp = (humanity / 10).floor();
      if (effEmp <= 0 && humanity < 10) return HumanityStatus.cyberpsicosi;
      if (humanity <= 20) return HumanityStatus.alLimite;
      if (humanity <= 40) return HumanityStatus.inErosione;
      return HumanityStatus.stabile;
    }

    final HumanityStatus was = statusAt(before);
    final HumanityStatus now = statusAt(after);
    if (was != now) {
      if (now == HumanityStatus.stabile) return 'torna stabile';
      if (now == HumanityStatus.inErosione) return 'esce dalla zona critica';
      if (now == HumanityStatus.alLimite) return 'fuori dalla cyberpsicosi';
      return 'scivola in cyberpsicosi';
    }
    if (after == report.maxHumanity && before < report.maxHumanity) return 'Umanita\' al massimo';
    if (start == HumanityStatus.stabile && after == report.maxHumanity) return 'mantiene il massimo';
    return '';
  }
}

// --------------------------------------------------------------------------
// Guarigione e degenza
// --------------------------------------------------------------------------

/// Quanto ci vuole a rimettere in piedi qualcuno.
class HealingPlan {
  const HealingPlan({
    required this.missingHitPoints,
    required this.body,
    required this.hitPointsPerDay,
    required this.daysToFull,
    required this.severeInjuryDays,
    required this.homeless,
    required this.medtechWithDrugs,
    required this.notes,
  });

  final int missingHitPoints;
  final int body;
  final double hitPointsPerDay;
  final int daysToFull;
  final int severeInjuryDays;
  final bool homeless;
  final bool medtechWithDrugs;
  final List<String> notes;

  int get totalDays => math.max(daysToFull, severeInjuryDays);

  String get summary => missingHitPoints <= 0
      ? 'Nessun danno da guarire'
      : '$missingHitPoints PV in $daysToFull giorni (${hitPointsPerDay.toStringAsFixed(1)} PV/giorno)'
          '${severeInjuryDays > daysToFull ? ' · degenza per ferita grave: $severeInjuryDays giorni' : ''}';
}

abstract final class Healing {
  static HealingPlan plan({
    required int missingHitPoints,
    required int body,
    required bool completeRest,
    required bool medtechWithDrugs,
    required int severeInjuries,
    required GmRuleBook rules,
    bool homeless = false,
  }) {
    final List<String> notes = <String>[];
    double perDay = body *
        (completeRest ? rules.value('heal.perDay.rest') : rules.value('heal.perDay.light'));
    notes.add(completeRest
        ? 'Riposo completo: Fisico × ${rules.value('heal.perDay.rest').round()}.'
        : 'Attivita\' leggera: Fisico × ${rules.value('heal.perDay.light').round()}. Nessuno guarisce correndo.');
    if (medtechWithDrugs) {
      final int bonus = rules.intValue('heal.medtechBonus');
      perDay += bonus;
      notes.add('Medtech con Farmaci: +$bonus PV al giorno.');
    }
    if (homeless) {
      final double factor = rules.value('lifestyle.homelessPenalty');
      perDay *= factor;
      notes.add('Senza alloggio: recupero × $factor. Si dorme male dove fa freddo.');
    }
    if (perDay <= 0) {
      perDay = 0;
      notes.add('Nessun recupero: serve un Fisico non nullo.');
    }
    final int days = perDay <= 0 ? 0 : (missingHitPoints / perDay).ceil();
    // Le ferite gravi non accelerano con il riposo: hanno il loro tempo, e il
    // maggiore fra i due e' la degenza reale. Prendere il minore sarebbe un
    // modo per far guarire una gamba rotta in due giorni dormendo.
    final int severeDays = severeInjuries > 0
        ? (rules.value('heal.severeInjury.days') * severeInjuries).round()
        : 0;
    if (severeInjuries > 0) {
      notes.add('$severeInjuries ferite gravi: ${rules.value('heal.severeInjury.days').round()} giorni ciascuna.');
    }
    return HealingPlan(
      missingHitPoints: missingHitPoints,
      body: body,
      hitPointsPerDay: perDay,
      daysToFull: days,
      severeInjuryDays: severeDays,
      homeless: homeless,
      medtechWithDrugs: medtechWithDrugs,
      notes: notes,
    );
  }
}

// --------------------------------------------------------------------------
// Stile di vita e alloggio
// --------------------------------------------------------------------------

enum FoodTier {
  kibble('Kibble', 'lifestyle.kibble'),
  prepak('Prefabbricato', 'lifestyle.prepak'),
  fresco('Cibo fresco', 'lifestyle.fresh');

  const FoodTier(this.label, this.ruleId);

  final String label;
  final String ruleId;
}

enum HousingTier {
  nessuno('Nessun alloggio', ''),
  cubeHotel('Cube Hotel', 'housing.cubeHotel'),
  appartamento('Appartamento', 'housing.apartment'),
  attico('Attico di lusso', 'housing.luxury');

  const HousingTier(this.label, this.ruleId);

  final String label;
  final String ruleId;
}

/// Il conto mensile di un personaggio.
class LifestyleLedger {
  const LifestyleLedger({
    required this.food,
    required this.housing,
    required this.foodCost,
    required this.housingCost,
    required this.otherRecurring,
    required this.wallet,
    required this.healFactor,
  });

  final FoodTier food;
  final HousingTier housing;
  final int foodCost;
  final int housingCost;

  /// Debiti, affitti di deposito, mantenimento: tutto cio' che si paga ogni mese
  /// e non e' ne' cibo ne' tetto.
  final int otherRecurring;
  final int wallet;

  /// Quanto il tenore di vita aiuta o ostacola il recupero fisico. Viene dalle
  /// regole, non da una costante scritta qui: e' un numero che il tavolo deve
  /// poter correggere.
  final double healFactor;

  int get monthlyCost => foodCost + housingCost + otherRecurring;

  /// Quanti mesi di vita restano, senza entrate. E' il numero che il giocatore
  /// guarda davvero, e va mostrato in mesi interi perche' "2,4 mesi" e' una
  /// risposta peggiore di "due mesi".
  int get runwayMonths => monthlyCost <= 0 ? 0 : wallet ~/ monthlyCost;

  String get summary => '$monthlyCost eb al mese'
      '${runwayMonths > 0 ? ' · $runwayMonths mesi di autonomia' : ''}'
      '${housing == HousingTier.nessuno ? ' · senza alloggio' : ''}';
}

abstract final class Lifestyle {
  static LifestyleLedger ledger({
    required FoodTier food,
    required HousingTier housing,
    required GmRuleBook rules,
    int otherRecurring = 0,
    int wallet = 0,
  }) {
    return LifestyleLedger(
      food: food,
      housing: housing,
      foodCost: rules.intValue(food.ruleId),
      housingCost: housing.ruleId.isEmpty ? 0 : rules.intValue(housing.ruleId),
      otherRecurring: math.max(0, otherRecurring),
      wallet: math.max(0, wallet),
      healFactor: housing == HousingTier.nessuno ? rules.value('lifestyle.homelessPenalty') : 1,
    );
  }
}

// --------------------------------------------------------------------------
// Debiti e contratti
// --------------------------------------------------------------------------

/// Un debito, verso chiunque.
class Debt {
  const Debt({
    required this.id,
    required this.creditor,
    required this.principal,
    required this.weeklyRatePct,
    required this.weeksElapsed,
    this.collateral = '',
    this.note = '',
    this.playerId = '',
    this.playerName = '',
  });

  final String id;
  final String creditor;
  final int principal;

  /// Interesse per settimana, in percentuale. Non e' uniformato dal manuale:
  /// un usuraio e una banca non chiedono la stessa cosa, ed e' giusto che sia
  /// il Master a decidere quanto e' cattivo ciascun creditore.
  final double weeklyRatePct;
  final int weeksElapsed;
  final String collateral;
  final String note;

  /// Identificativo o nome del giocatore/personaggio a cui fa capo il debito.
  final String playerId;
  final String playerName;

  /// Debito composto: l'interesse matura anche sugli interessi.
  ///
  /// Scelta dichiarata e discutibile: con l'interesse semplice un debito
  /// lasciato li' cresce in modo lineare e prevedibile, con il composto
  /// *scappa*. Il composto e' quello che rende un debito una spada di Damocle,
  /// ed e' il motivo per cui il pannello mostra la data in cui il debito
  /// supera il valore di qualunque bottino.
  int owedAt(int weeks) {
    if (weeks <= 0) return principal;
    final double factor = math.pow(1 + weeklyRatePct / 100, weeks).toDouble();
    return (principal * factor).round();
  }

  int get owedNow => owedAt(weeksElapsed);

  String get debtorLabel => playerName.trim().isNotEmpty ? playerName.trim() : 'Tavolo / PG';

  Debt paid(int amount) => Debt(
        id: id,
        creditor: creditor,
        principal: math.max(0, owedNow - amount),
        weeklyRatePct: weeklyRatePct,
        weeksElapsed: 0,
        collateral: collateral,
        note: note,
        playerId: playerId,
        playerName: playerName,
      );

  Debt afterWeeks(int weeks, {bool pay = false}) => Debt(
        id: id,
        creditor: creditor,
        principal: pay ? owedAt(weeks) : principal,
        weeklyRatePct: weeklyRatePct,
        weeksElapsed: pay ? 0 : weeksElapsed + weeks,
        collateral: collateral,
        note: note,
        playerId: playerId,
        playerName: playerName,
      );

  String get summary => '${playerName.trim().isNotEmpty ? '[$playerName] ' : ''}$creditor: $owedNow eb'
      '${weeklyRatePct > 0 ? ' (${weeklyRatePct.toStringAsFixed(1)}%/settimana)' : ' (senza interesse)'}'
      '${collateral.isEmpty ? '' : ' · garanzia: $collateral'}';

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'creditor': creditor,
        'principal': principal,
        'weeklyRatePct': weeklyRatePct,
        'weeksElapsed': weeksElapsed,
        'collateral': collateral,
        'note': note,
        'playerId': playerId,
        'playerName': playerName,
      };

  static Debt fromJson(Map<String, Object?> json) => Debt(
        id: '${json['id'] ?? ''}',
        creditor: '${json['creditor'] ?? ''}',
        principal: (json['principal'] as num?)?.toInt() ?? 0,
        weeklyRatePct: (json['weeklyRatePct'] as num?)?.toDouble() ?? 0,
        weeksElapsed: (json['weeksElapsed'] as num?)?.toInt() ?? 0,
        collateral: '${json['collateral'] ?? ''}',
        note: '${json['note'] ?? ''}',
        playerId: '${json['playerId'] ?? ''}',
        playerName: '${json['playerName'] ?? ''}',
      );
}

/// Tutti i debiti di un personaggio o di una campagna.
class DebtLedger {
  DebtLedger([List<Debt>? debts]) : debts = <Debt>[...?debts];

  final List<Debt> debts;

  int get totalOwed => debts.fold<int>(0, (int a, Debt d) => a + d.owedNow);

  /// Debiti per uno specifico giocatore (per nome o id).
  List<Debt> debtsForPlayer(String nameOrId) {
    final String n = nameOrId.trim().toLowerCase();
    if (n.isEmpty) return debts;
    return debts.where((Debt d) => d.playerId.toLowerCase() == n || d.playerName.toLowerCase() == n).toList();
  }

  int totalOwedBy(String nameOrId) =>
      debtsForPlayer(nameOrId).fold<int>(0, (int a, Debt d) => a + d.owedNow);

  /// Nomi univoci dei giocatori debitori nel registro.
  List<String> get distinctPlayerNames {
    final Set<String> names = <String>{};
    for (final Debt d in debts) {
      if (d.playerName.trim().isNotEmpty) {
        names.add(d.playerName.trim());
      }
    }
    return names.toList()..sort();
  }

  /// La proiezione: quanto si deve fra `weeks` settimane se non si paga niente.
  /// Serve a rispondere alla domanda che il giocatore fa sempre — "posso
  /// aspettare?" — con un numero invece che con un'opinione.
  int projectedAt(int weeks) => debts.fold<int>(0, (int a, Debt d) => a + d.owedAt(d.weeksElapsed + weeks));

  /// Il debito che sta crescendo piu' in fretta, in valore assoluto per
  /// settimana: e' quello da pagare per primo, e non e' sempre il piu' grosso.
  Debt? get fastestGrowing {
    if (debts.isEmpty) return null;
    Debt worst = debts.first;
    double worstRate = 0;
    for (final Debt d in debts) {
      final double rate = (d.owedAt(d.weeksElapsed + 1) - d.owedNow).toDouble();
      if (rate > worstRate) {
        worstRate = rate;
        worst = d;
      }
    }
    return worst;
  }

  void add(Debt debt) {
    final int index = debts.indexWhere((Debt d) => d.id == debt.id);
    if (index >= 0) {
      debts[index] = debt;
    } else {
      debts.add(debt);
    }
  }

  void remove(String id) => debts.removeWhere((Debt d) => d.id == id);

  /// Un pagamento si applica prima al debito che cresce piu' in fretta: e' la
  /// scelta che costa meno, ed e' quella che l'app deve suggerire.
  void pay(int amount) {
    int left = amount;
    while (left > 0 && debts.isNotEmpty) {
      final Debt? target = fastestGrowing;
      if (target == null) break;
      final int owed = target.owedNow;
      final int applied = math.min(left, owed);
      final Debt after = target.paid(applied);
      left -= applied;
      if (after.principal <= 0) {
        remove(target.id);
      } else {
        add(after);
      }
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{'debts': debts.map((Debt d) => d.toJson()).toList()};

  static DebtLedger fromJson(Map<String, Object?> json) {
    final Object? raw = json['debts'];
    if (raw is! List) return DebtLedger();
    return DebtLedger(<Debt>[
      for (final Object? item in raw)
        if (item is Map) Debt.fromJson(Map<String, Object?>.from(item)),
    ]);
  }
}

// --------------------------------------------------------------------------
// Mercato nero: cosa si trova, e a che prezzo di relazioni
// --------------------------------------------------------------------------

/// L'ordine di reperibilita', dal piu' facile al piu' difficile.
///
/// Non e' l'ordine di [Rarity]: quello e' l'ordine in cui il catalogo enumera le
/// rarita' (con "Esotico" in fondo per ragioni storiche del formato). Qui serve
/// l'ordine di *difficolta' a trovarlo*, che e' una cosa diversa.
const List<Rarity> marketLadder = <Rarity>[
  Rarity.common,
  Rarity.uncommon,
  Rarity.rare,
  Rarity.veryRare,
  Rarity.legendary,
  Rarity.exotic,
];

/// Cosa un personaggio puo' davvero comprare.
class MarketAccess {
  const MarketAccess({
    required this.contactsRank,
    required this.maxRarity,
    required this.rules,
  });

  final int contactsRank;
  final Rarity maxRarity;
  final GmRuleBook rules;

  bool canFind(Rarity rarity) => marketLadder.indexOf(rarity) <= marketLadder.indexOf(maxRarity);

  /// Quanto manca per sbloccare la fascia successiva: e' l'informazione che
  /// serve al giocatore per decidere se alzare Contatti o pagare qualcuno.
  int? ranksToUnlockNext() {
    final int index = marketLadder.indexOf(maxRarity);
    if (index >= marketLadder.length - 1) return null;
    final int step = rules.intValue('market.rankPerTier');
    return (index + 1) * step - contactsRank;
  }

  String get summary => 'Contatti $contactsRank → fino a ${maxRarity.label}'
      '${ranksToUnlockNext() == null ? '' : ' · mancano ${ranksToUnlockNext()} ranghi per la fascia successiva'}';
}

abstract final class BlackMarket {
  /// Converte un rango di Contatti nella fascia massima reperibile.
  static MarketAccess access({required int contactsRank, required GmRuleBook rules}) {
    final int step = math.max(1, rules.intValue('market.rankPerTier'));
    final int index = (contactsRank / step).floor().clamp(0, marketLadder.length - 1);
    return MarketAccess(contactsRank: contactsRank, maxRarity: marketLadder[index], rules: rules);
  }

  /// Filtra il catalogo. Il `keep` e' una funzione perche' qui il catalogo non
  /// si conosce: questo file non importa il catalogo, e non deve.
  static List<T> filter<T>(List<T> items, MarketAccess access, Rarity Function(T) rarityOf) {
    return items.where((T item) => access.canFind(rarityOf(item))).toList(growable: false);
  }
}

// --------------------------------------------------------------------------
// Quickhack: attacchi ai programmi
// --------------------------------------------------------------------------

/// Un programma offensivo del Netrunner.
///
/// I nomi sono quelli del manuale; i valori sono la lettura di questa
/// applicazione e vanno confrontati con il blocco statistiche di ciascun
/// programma, che e' l'unico posto in cui sono definitivi.
class NetAttackProgram {
  const NetAttackProgram({
    required this.name,
    required this.attackModifier,
    required this.damageToRez,
    required this.effect,
    this.confidence = GmConfidence.daVerificare,
  });

  final String name;
  final int attackModifier;

  /// Quanto REZ toglie a un programma difensivo quando va a segno.
  final int damageToRez;
  final String effect;
  final GmConfidence confidence;
}

abstract final class NetrunnerPrograms {
  static const List<NetAttackProgram> all = <NetAttackProgram>[
    NetAttackProgram(
      name: 'Wurm',
      attackModifier: 0,
      damageToRez: 6,
      effect: 'Erode il programma bersaglio: il danno si accumula, non lo distrugge subito.',
    ),
    NetAttackProgram(
      name: 'Sword',
      attackModifier: 0,
      damageToRez: 10,
      effect: 'Colpo diretto: il danno e\' alto ma mira a un solo programma.',
    ),
    NetAttackProgram(
      name: 'Eraser',
      attackModifier: 0,
      damageToRez: 4,
      effect: 'Cancella i dati del bersaglio: utile contro programmi di sorveglianza piu\' che contro l\'ICE.',
    ),
    NetAttackProgram(
      name: 'Banhammer',
      attackModifier: -2,
      damageToRez: 20,
      effect: 'Colpo pesante e lento: se arriva, quasi sempre distrugge. La penalita\' all\'attacco e\' il prezzo.',
    ),
    NetAttackProgram(
      name: 'Hellbolt',
      attackModifier: 0,
      damageToRez: 8,
      effect: 'Danno termico sul programma: continuativo, adatto a bersagli che si difendono bene.',
    ),
  ];
}

/// L'esito di un attacco a un programma.
class ProgramAttackResult {
  const ProgramAttackResult({
    required this.program,
    required this.target,
    required this.die,
    required this.interfaceRank,
    required this.attackTotal,
    required this.defense,
    required this.hit,
    required this.rezBefore,
    required this.rezAfter,
    required this.destroyed,
  });

  final NetAttackProgram program;
  final NetIceProgram target;
  final int die;
  final int interfaceRank;
  final int attackTotal;
  final int defense;
  final bool hit;
  final int rezBefore;
  final int rezAfter;
  final bool destroyed;

  /// Il conto per esteso, con i tre pezzi separati: il dado, la bravura del
  /// Netrunner e il modificatore del programma. Una riga che dice solo "17
  /// contro 6" non permette a nessuno di contestare il risultato.
  String get log {
    final String modifier = program.attackModifier == 0 ? '' : ' ${program.attackModifier > 0 ? '+' : '−'}${program.attackModifier.abs()} (${program.name})';
    final String impact = hit
        ? destroyed
            ? 'REZ $rezBefore → 0: programma distrutto'
            : 'REZ $rezBefore → $rezAfter'
        : 'mancato, nessun danno';
    return '${program.name} su ${target.name}: 1d10 ($die) + $interfaceRank$modifier = $attackTotal'
        ' contro Difesa $defense — $impact';
  }
}

/// La console di rete: tiene lo stato dei programmi e applica i danni.
///
/// E' mutabile di proposito. Un calcolatore puro che restituisce "come sarebbe"
/// costringerebbe il pannello a tenere lo stato da qualche altra parte, e la
/// contabilita' del REZ e' esattamente la cosa che si sbaglia quando lo stato
/// sta in una variabile di schermata.
class NetrunnerConsole {
  NetrunnerConsole({List<NetIceProgram>? ice, Map<String, int>? rez})
      : ice = List<NetIceProgram>.of(ice ?? defaultIce),
        _rez = <String, int>{
          for (final NetIceProgram p in ice ?? defaultIce) p.name: p.rez,
          ...?rez,
        };

  /// Tre programmi difensivi sono il minimo per una rete che si possa chiamare
  /// tale: sotto, la console non ha niente da attaccare.
  static final List<NetIceProgram> defaultIce = NetIceProgram.presets.take(3).toList();

  final List<NetIceProgram> ice;
  final Map<String, int> _rez;

  int rezOf(NetIceProgram program) => _rez[program.name] ?? program.rez;

  bool isDestroyed(NetIceProgram program) => rezOf(program) <= 0;

  List<NetIceProgram> get active => ice.where((NetIceProgram p) => !isDestroyed(p)).toList(growable: false);

  /// Attacca un programma. L'interfaccia del Netrunner e' il modificatore, non
  /// il dado: la prova e' 1d10 + Interfaccia + modificatore del programma.
  ProgramAttackResult attack({
    required NetAttackProgram program,
    required NetIceProgram target,
    required int interfaceRank,
    required math.Random random,
  }) {
    final int die = random.nextInt(10) + 1;
    final int attackTotal = die + interfaceRank + program.attackModifier;
    final int defense = target.defense;
    final bool hit = attackTotal >= defense;
    final int before = rezOf(target);
    final int after = hit ? math.max(0, before - program.damageToRez) : before;
    _rez[target.name] = after;
    return ProgramAttackResult(
      program: program,
      target: target,
      die: die,
      interfaceRank: interfaceRank,
      attackTotal: attackTotal,
      defense: defense,
      hit: hit,
      rezBefore: before,
      rezAfter: after,
      destroyed: after <= 0,
    );
  }

  /// Riporta tutti i programmi al REZ pieno: a fine incursione la rete si
  /// riavvia, e senza questo il pannello resterebbe con i danni della sessione
  /// precedente addosso.
  void reset() {
    for (final NetIceProgram p in ice) {
      _rez[p.name] = p.rez;
    }
  }

  Map<String, int> get rezSnapshot => Map<String, int>.unmodifiable(_rez);
}
