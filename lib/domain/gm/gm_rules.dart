/// Infrastruttura degli strumenti del Master: tabelle da tirare e numeri di
/// regola con la loro provenienza.
///
/// Il problema che questo file risolve non e' tecnico. Un'app di supporto al
/// tavolo prende continuamente decisioni di *contenuto*: quanto costa una
/// settimana di terapia, quanto rende una settimana di lavoro per un Fixer, che
/// DV ha un fucile a 40 metri. Alcuni di quei numeri sono **stampati sul
/// manuale** e sbagliarli significa che il Master applica una regola falsa al
/// tavolo senza accorgersene. Altri non esistono nel manuale — sono tabelle che
/// questa applicazione si inventa per comodita' (che i nemici abbiano in tasca
/// un chip di dati) — e presentarli con la stessa sicurezza dei primi e' una
/// bugia.
///
/// Quindi nessun numero vive nudo nel codice. Ogni valore e' un [GmRule] con
/// una [GmConfidence] dichiarata, e l'interfaccia ha l'obbligo di mostrare la
/// differenza. Un valore [GmConfidence.daVerificare] si vede in giallo con la
/// nota che dice dove guardare; un [GmConfidence.proposta] si vede dichiarato
/// come proposta. E tutti sono sovrascrivibili, perche' ogni tavolo ha le sue
/// house rule e la risposta giusta e' "cambialo", non "scrivi all'autore".
library;

import 'dart:math' as math;

/// Quanto ci si puo' fidare di un valore.
enum GmConfidence {
  /// Stampato sul manuale e riportato qui dopo verifica diretta.
  verificato('Verificato', 'Controllato sul manuale.'),

  /// Tratto dal manuale ma non ancora ricontrollato riga per riga.
  ///
  /// Non e' "probabilmente giusto": e' "va guardato". Il posto in cui un errore
  /// fa piu' danno e' proprio qui, perche' sembra autorevole.
  daVerificare('Da verificare', 'Tratto dal manuale, non ancora ricontrollato.'),

  /// Scelto da questa applicazione. Non e' una regola del gioco.
  proposta('Proposta', 'Tabella di questa applicazione, non del manuale.');

  const GmConfidence(this.label, this.explanation);

  final String label;
  final String explanation;
}

/// Un numero di regola, con il motivo per cui credergli.
class GmRule {
  const GmRule({
    required this.id,
    required this.label,
    required this.value,
    required this.confidence,
    this.unit = '',
    this.note = '',
    this.group = '',
    this.min = 0,
    this.max = 1000000,
  });

  final String id;
  final String label;
  final double value;
  final GmConfidence confidence;

  /// "eb", "settimane", "metri"... usata nell'interfaccia e nel testo esportato.
  final String unit;
  final String note;
  final String group;

  /// Intervallo ammesso quando il Master lo corregge a mano: serve a impedire
  /// che un refuso (una settimana di terapia da 500000 eb) venga accettato.
  final double min;
  final double max;

  GmRule withValue(double newValue) => GmRule(
        id: id,
        label: label,
        value: newValue.clamp(min, max),
        confidence: confidence,
        unit: unit,
        note: note,
        group: group,
        min: min,
        max: max,
      );

  bool get isInteger => value == value.roundToDouble();

  String get displayValue => isInteger ? value.round().toString() : value.toStringAsFixed(2);
}

/// Il libro delle regole: i valori predefiniti piu' le correzioni del tavolo.
///
/// Le correzioni vivono in memoria e vengono salvate dalle impostazioni: qui
/// c'e' solo il meccanismo, cosi' i calcolatori restano funzioni pure e i test
/// possono fissare i numeri senza toccare il disco.
class GmRuleBook {
  GmRuleBook({Map<String, double>? overrides, List<GmRule> schema = const <GmRule>[]})
      : _overrides = <String, double>{...?overrides},
        _schema = <String, GmRule>{for (final GmRule r in schema) r.id: r};

  final Map<String, double> _overrides;

  /// Regole che non stanno in [GmRules] ma che il tavolo deve poter correggere
  /// come tutte le altre.
  ///
  /// L'esempio che ha reso necessario questo parametro e' la tabella DV
  /// balistica: e' una matrice di sessantaquattro valori, generata dal
  /// calcolatore che la usa. Finche' il libro delle regole non la conosceva,
  /// `set` su un DV non trovava lo schema e **usciva senza scrivere niente**:
  /// il pannello avrebbe mostrato una correzione che non veniva applicata.
  final Map<String, GmRule> _schema;

  Map<String, double> get overrides => Map<String, double>.unmodifiable(_overrides);

  GmRule? _base(String id) => GmRules.byId(id) ?? _schema[id];

  /// Tutte le regole note, schema aggiuntivo incluso, con le correzioni
  /// applicate. E' quello che un pannello delle impostazioni vuole mostrare.
  List<GmRule> get rules => <GmRule>[...GmRules.all, ..._schema.values].map(rule).toList(growable: false);

  /// Una regola per identificativo, corretta se il tavolo l'ha corretta.
  GmRule rule(GmRule base) {
    final double? override = _overrides[base.id];
    return override == null ? base : base.withValue(override);
  }

  double value(String id) {
    final GmRule? base = _base(id);
    if (base == null) return 0;
    return rule(base).value;
  }

  int intValue(String id) => value(id).round();

  void set(String id, double value) {
    final GmRule? base = _base(id);
    if (base == null) return;
    _overrides[id] = value.clamp(base.min, base.max);
  }

  void clear(String id) => _overrides.remove(id);

  void clearAll() => _overrides.clear();

  bool isOverridden(String id) => _overrides.containsKey(id);

  Map<String, Object?> toJson() => <String, Object?>{'rules': _overrides};

  static GmRuleBook fromJson(Map<String, Object?> json, {List<GmRule> schema = const <GmRule>[]}) {
    final Object? raw = json['rules'];
    final Map<String, double> parsed = <String, double>{};
    if (raw is Map) {
      raw.forEach((Object? k, Object? v) {
        if (k is String && v is num) parsed[k] = v.toDouble();
      });
    }
    return GmRuleBook(overrides: parsed, schema: schema);
  }

  /// Una copia che condivide le correzioni ma non lo stato: serve al pannello
  /// per calcolare un'anteprima senza sporcare i valori veri.
  GmRuleBook copy() => GmRuleBook(overrides: overrides, schema: _schema.values.toList());
}

/// I valori predefiniti.
///
/// Ogni voce dichiara la propria fiducia. La regola pratica seguita qui: se non
/// ero in grado di citare il punto esatto del manuale mentre scrivevo, la voce e'
/// [GmConfidence.daVerificare]; se il numero non viene dal manuale affatto, e'
/// [GmConfidence.proposta].
abstract final class GmRules {
  // --- Terapia e cyberpsicosi ---------------------------------------------
  static const GmRule therapyCostStandard = GmRule(
    id: 'therapy.cost.standard',
    label: 'Costo di una settimana di terapia standard',
    value: 500,
    unit: 'eb',
    confidence: GmConfidence.daVerificare,
    note: 'La terapia e\' la via per recuperare Umanita\'. Il costo per settimana e\' quello che va confermato per primo, perche\' e\' il numero che il giocatore paga.',
    group: 'Terapia',
    max: 100000,
  );

  static const GmRule therapyCostExtreme = GmRule(
    id: 'therapy.cost.extreme',
    label: 'Costo di una settimana di terapia estrema',
    value: 1000,
    unit: 'eb',
    confidence: GmConfidence.daVerificare,
    note: 'Programma piu\' aggressivo: piu\' cara, piu\' Umanita\' per settimana.',
    group: 'Terapia',
    max: 100000,
  );

  static const GmRule therapyHumanityStandard = GmRule(
    id: 'therapy.humanity.standard',
    label: 'Umanita\' recuperata per settimana (standard)',
    value: 2,
    unit: 'punti',
    confidence: GmConfidence.daVerificare,
    note: 'Applicata come valore fisso. Il manuale la esprime come tiro: se il tavolo preferisce, qui si mette la media e si tira a mano.',
    group: 'Terapia',
    max: 20,
  );

  static const GmRule therapyHumanityExtreme = GmRule(
    id: 'therapy.humanity.extreme',
    label: 'Umanita\' recuperata per settimana (estrema)',
    value: 4,
    unit: 'punti',
    confidence: GmConfidence.daVerificare,
    note: 'Il doppio della standard, a costo doppio: e\' la scelta che rende la terapia estrema conveniente solo per chi ha fretta e soldi.',
    group: 'Terapia',
    max: 20,
  );

  static const GmRule therapyPerImplantCap = GmRule(
    id: 'therapy.cap.perImplant',
    label: 'Limite: Umanita\' recuperabile per singolo impianto',
    value: 1,
    unit: 'volte il costo dell\'impianto',
    confidence: GmConfidence.daVerificare,
    note: 'Si recupera Umanita\' perduta dal cyberware, ma non oltre quella persa da ciascun impianto. E\' il vincolo che impedisce alla terapia di essere una macchina da annullamento: senza, basta pagare e il cyberware non costa piu\' niente.',
    group: 'Terapia',
    max: 10,
  );

  // --- Guarigione ---------------------------------------------------------
  static const GmRule healPerDayRest = GmRule(
    id: 'heal.perDay.rest',
    label: 'PV recuperati al giorno di riposo completo',
    value: 2,
    unit: 'volte il Fisico',
    confidence: GmConfidence.daVerificare,
    note: 'Riposo completo significa niente turni di guardia, niente lavori, niente sparatorie.',
    group: 'Guarigione',
    max: 20,
  );

  static const GmRule healPerDayLight = GmRule(
    id: 'heal.perDay.light',
    label: 'PV recuperati al giorno di attivita\' leggera',
    value: 1,
    unit: 'volte il Fisico',
    confidence: GmConfidence.daVerificare,
    note: 'Chi continua a lavorare guarisce comunque, ma la meta\' della velocita\'.',
    group: 'Guarigione',
    max: 20,
  );

  static const GmRule healMedtechBonus = GmRule(
    id: 'heal.medtechBonus',
    label: 'Bonus di un Medtech con Farmaci',
    value: 2,
    unit: 'PV al giorno',
    confidence: GmConfidence.daVerificare,
    note: 'L\'assistenza di un Medtech che usa Farmaci accorcia la degenza. Il valore esatto va letto sul manuale.',
    group: 'Guarigione',
    max: 50,
  );

  static const GmRule healSevereInjuryDays = GmRule(
    id: 'heal.severeInjury.days',
    label: 'Giorni di degenza per una ferita grave',
    value: 10,
    unit: 'giorni',
    confidence: GmConfidence.daVerificare,
    note: 'La degenza comanda sul recupero dei PV: si puo\' avere la vita al massimo e la gamba ancora rotta.',
    group: 'Guarigione',
    max: 400,
  );

  // --- Stile di vita e alloggio -------------------------------------------
  static const GmRule lifestyleKibble = GmRule(
    id: 'lifestyle.kibble',
    label: 'Cibo: Kibble',
    value: 100,
    unit: 'eb al mese',
    confidence: GmConfidence.daVerificare,
    note: 'Il livello piu\' basso: due pasti al giorno di quello che passa la fabbrica.',
    group: 'Stile di vita',
    max: 100000,
  );

  static const GmRule lifestylePrepak = GmRule(
    id: 'lifestyle.prepak',
    label: 'Cibo: Prefabbricato',
    value: 300,
    unit: 'eb al mese',
    confidence: GmConfidence.daVerificare,
    note: 'Il livello intermedio: si mangia tutte le volte che serve, e si sa che cosa.',
    group: 'Stile di vita',
    max: 100000,
  );

  static const GmRule lifestyleFresh = GmRule(
    id: 'lifestyle.fresh',
    label: 'Cibo: cibo fresco',
    value: 500,
    unit: 'eb al mese',
    confidence: GmConfidence.daVerificare,
    note: 'Il livello piu\' caro: e\' anche l\'unico in cui il cibo e\' cibo e non un prodotto industriale.',
    group: 'Stile di vita',
    max: 100000,
  );

  static const GmRule housingCubeHotel = GmRule(
    id: 'housing.cubeHotel',
    label: 'Alloggio: Cube Hotel',
    value: 500,
    unit: 'eb al mese',
    confidence: GmConfidence.daVerificare,
    note: 'Camera-cubo a noleggio. E\' il livello piu\' basso di alloggio con una porta che si chiude.',
    group: 'Stile di vita',
    max: 100000,
  );

  static const GmRule housingApartment = GmRule(
    id: 'housing.apartment',
    label: 'Alloggio: appartamento in affitto',
    value: 1500,
    unit: 'eb al mese',
    confidence: GmConfidence.daVerificare,
    note: 'Piu\' stanze, una porta vera, e la bolletta dell\'acqua che arriva lo stesso.',
    group: 'Stile di vita',
    max: 100000,
  );

  static const GmRule housingLuxury = GmRule(
    id: 'housing.luxury',
    label: 'Alloggio: attico di lusso',
    value: 5000,
    unit: 'eb al mese',
    confidence: GmConfidence.daVerificare,
    note: 'Il livello che serve a far capire quanto guadagna chi non lavora per strada.',
    group: 'Stile di vita',
    max: 1000000,
  );

  static const GmRule homelessHealPenalty = GmRule(
    id: 'lifestyle.homelessPenalty',
    label: 'Penalita\' al recupero PV senza alloggio',
    value: 0.5,
    unit: 'fattore',
    confidence: GmConfidence.daVerificare,
    note: 'Chi dorme per strada non recupera come chi ha un letto. Il fattore esatto va confermato.',
    group: 'Stile di vita',
    max: 1,
  );

  // --- Mercato nero -------------------------------------------------------
  static const GmRule marketRankPerTier = GmRule(
    id: 'market.rankPerTier',
    label: 'Ranghi di Contatti richiesti per salire di fascia',
    value: 2,
    unit: 'ranghi',
    confidence: GmConfidence.proposta,
    note: 'Non e\' una regola del manuale: e\' la scala con cui questa applicazione traduce il rango di Contatti in fasce di reperibilita\'. Si puo\' cambiare senza rompere niente.',
    group: 'Mercato nero',
    max: 10,
  );

  // --- Rete ---------------------------------------------------------------
  static const GmRule quickhackBaseDefense = GmRule(
    id: 'net.defense.base',
    label: 'Difesa di un programma non dichiarata',
    value: 6,
    unit: 'valore',
    confidence: GmConfidence.proposta,
    note: 'Usata solo quando il programma non ha una difesa nel suo blocco statistiche.',
    group: 'Rete',
    max: 30,
  );

  // --- Trasporti ----------------------------------------------------------
  /// Quanto vale la mappa in metri, da un bordo all'altro.
  ///
  /// E' il numero che rende possibile tutto il resto: la mappa e' una griglia
  /// normalizzata 0..1 — giusto per disegnare, ma senza unita' di misura — e
  /// senza una scala dichiarata "45 km/h" non significa niente. Dichiarata e
  /// non misurata: e' la larghezza che questa applicazione attribuisce a Night
  /// City, e un tavolo che la vuole diversa la cambia qui invece di fidarsi.
  static const GmRule transportMapSpan = GmRule(
    id: 'transport.mapSpan',
    label: 'Larghezza della mappa in metri',
    value: transportMapSpanDefault,
    unit: 'metri',
    confidence: GmConfidence.proposta,
    note: 'La mappa e\' disegnata su una griglia senza unita\' di misura. Questo e\' il numero che la lega ai metri: se un taxi arriva sempre troppo presto o troppo tardi, si corregge da qui.',
    group: 'Trasporti',
    min: 500,
    max: 200000,
  );

  /// Di quanto una strada e' piu' lunga della linea retta fra le sue fermate.
  static const GmRule transportRoadFactor = GmRule(
    id: 'transport.roadFactor',
    label: 'Allungamento delle strade rispetto alla linea retta',
    value: transportRoadFactorDefault,
    unit: '×',
    confidence: GmConfidence.proposta,
    note: 'Nessuna strada e\' dritta. Senza questo fattore ogni percorso risulterebbe piu\' corto del vero, e i veicoli arriverebbero sempre in anticipo.',
    group: 'Trasporti',
    min: 1,
    max: 3,
  );

  /// Quante volte il tempo del tavolo corre rispetto a quello vero.
  ///
  /// Attraversare dodici chilometri a quarantacinque all'ora sono sedici
  /// minuti: realistico e inguardabile. Con il tempo moltiplicato un inseguimento
  /// si vede accadere invece di essere riassunto a parole.
  static const GmRule transportTimeScale = GmRule(
    id: 'transport.timeScale',
    label: 'Moltiplicatore del tempo sulla mappa',
    value: transportTimeScaleDefault,
    unit: '×',
    confidence: GmConfidence.proposta,
    note: 'Quanto tempo di gioco passa per ogni secondo vero. Le velocita\' mostrate restano quelle reali dei veicoli: e\' l\'orologio a correre, non i veicoli.',
    group: 'Trasporti',
    min: 1,
    max: 600,
  );

  /// I tre valori dei trasporti come costanti.
  ///
  /// Servono separati dalle [GmRule] perche' il motore del movimento li usa
  /// come valori predefiniti di parametro, e in quel posto Dart accetta solo
  /// costanti di compilazione: `transportMapSpan.value` non lo e'.
  static const double transportMapSpanDefault = 12000;
  static const double transportRoadFactorDefault = 1.35;
  static const double transportTimeScaleDefault = 12;

  /// Tutte le regole, in ordine di gruppo.
  static const List<GmRule> all = <GmRule>[
    therapyCostStandard,
    therapyCostExtreme,
    therapyHumanityStandard,
    therapyHumanityExtreme,
    therapyPerImplantCap,
    healPerDayRest,
    healPerDayLight,
    healMedtechBonus,
    healSevereInjuryDays,
    lifestyleKibble,
    lifestylePrepak,
    lifestyleFresh,
    housingCubeHotel,
    housingApartment,
    housingLuxury,
    homelessHealPenalty,
    marketRankPerTier,
    quickhackBaseDefense,
    transportMapSpan,
    transportRoadFactor,
    transportTimeScale,
  ];

  static GmRule? byId(String id) {
    for (final GmRule r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  static List<String> get groups {
    final List<String> seen = <String>[];
    for (final GmRule r in all) {
      if (r.group.isNotEmpty && !seen.contains(r.group)) seen.add(r.group);
    }
    return seen;
  }

  /// Quante regole sono ancora da verificare: il pannello lo mostra in cima,
  /// perche' e' un debito verso il tavolo e non un dettaglio.
  static int get unverifiedCount => all.where((GmRule r) => r.confidence != GmConfidence.verificato).length;
}

/// Una voce di tabella con il suo peso relativo.
class WeightedEntry<T> {
  const WeightedEntry(this.value, {required this.weight});

  final T value;
  final int weight;
}

/// Una tabella da tirare.
///
/// Il peso e' un intero: una voce con peso 3 esce tre volte piu' spesso di una
/// con peso 1. E' il modo piu' semplice per esprimere "gli agguati di strada
/// sono piu' comuni delle incursioni della Max-Tac" senza inventare intervalli
/// di dado che poi vanno tenuti allineati a mano.
class RollTable<T> {
  const RollTable({
    required this.id,
    required this.title,
    required this.entries,
    this.confidence = GmConfidence.proposta,
    this.note = '',
  });

  final String id;
  final String title;
  final List<WeightedEntry<T>> entries;
  final GmConfidence confidence;
  final String note;

  int get totalWeight => entries.fold<int>(0, (int a, WeightedEntry<T> e) => a + e.weight);

  /// Tira sulla tabella. Restituisce anche il numero uscito, perche' il Master
  /// spesso vuole dirlo ad alta voce ("un 7: pattuglia della Max-Tac").
  TableRoll<T> roll(math.Random random) {
    final int total = totalWeight;
    if (total <= 0) {
      throw StateError('La tabella "$id" non ha voci.');
    }
    final int ticket = random.nextInt(total) + 1;
    int cursor = 0;
    for (final WeightedEntry<T> entry in entries) {
      cursor += entry.weight;
      if (ticket <= cursor) {
        return TableRoll<T>(index: ticket, total: total, value: entry.value, probability: entry.weight / total);
      }
    }
    final WeightedEntry<T> last = entries.last;
    return TableRoll<T>(index: total, total: total, value: last.value, probability: last.weight / total);
  }

  /// Probabilita' di ciascuna voce, per mostrarla nel pannello: un Master che
  /// vede "Max-Tac: 5%" sa che la sta giocando come evento raro.
  List<double> get probabilities {
    final int total = totalWeight;
    if (total <= 0) return const <double>[];
    return entries.map((WeightedEntry<T> e) => e.weight / total).toList(growable: false);
  }
}

/// L'esito di un tiro su tabella.
class TableRoll<T> {
  const TableRoll({
    required this.index,
    required this.total,
    required this.value,
    required this.probability,
  });

  final int index;
  final int total;
  final T value;
  final double probability;

  String get percentage => '${(probability * 100).toStringAsFixed(probability < 0.01 ? 1 : 0)}%';
}
