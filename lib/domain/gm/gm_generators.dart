/// Generatori di contenuto per il Master: incontri, bottino, notizie, PNG
/// rapidi, droghe, lavori secondari.
///
/// Qui c'e' una distinzione che vale la pena dichiarare, perche' decide come si
/// legge tutto il file. Questi generatori **non traducono regole del manuale**:
/// la maggior parte delle voci e' scritta da questa applicazione. Il manuale
/// stabilisce che la Max-Tac esista e che i Tyger Claws gestiscano un
/// territorio; non stabilisce che alle tre di notte, sotto la pioggia acida,
/// incontrino il gruppo in quattro. Quel pezzo lo decide il tavolo, e qui c'e'
/// una proposta.
///
/// Percio' ogni generatore dichiara la propria [GmConfidence]. Il contenuto
/// scritto da me e' [GmConfidence.proposta] e l'interfaccia lo dice; le voci in
/// cui il nome *e'* canonico ma i valori numerici andrebbero riletti (i
/// programmi della rete, gli effetti delle droghe) sono
/// [GmConfidence.daVerificare].
library;

import 'dart:math' as math;

import 'gm_rules.dart';

// --------------------------------------------------------------------------
// PNG rapidi
// --------------------------------------------------------------------------

/// Quanto e' pericoloso un PNG. Determina i tre numeri aggregati.
///
/// La scelta di fondo: un PNG da buttare sul tavolo non ha 68 abilita' e dieci
/// caratteristiche. Ha **un numero per attaccare, uno per difendersi, dei Punti
/// Vita e dell'armatura**. E' il formato che il manuale stesso usa per i
/// nemici di scena, ed e' l'unico che si puo' compilare in dieci secondi mentre
/// i giocatori aspettano.
enum MookTier {
  scagnozzo('Scagnozzo', 9, 9, 20, 4),
  professionista('Professionista', 12, 11, 30, 7),
  elite('Elite', 14, 13, 40, 11),
  letale('Letale', 16, 15, 50, 14);

  const MookTier(this.label, this.combat, this.defense, this.hitPoints, this.sp);

  final String label;

  /// Numero sommato al d10 per attaccare.
  final int combat;

  /// Difesa passiva: il DV che il giocatore deve battere per colpirlo.
  final int defense;

  final int hitPoints;

  /// Punti Struttura dell'armatura, se ne indossa una.
  final int sp;
}

/// Un PNG pronto da usare.
class Mook {
  const Mook({
    required this.name,
    required this.tier,
    required this.combat,
    required this.defense,
    required this.hitPoints,
    required this.sp,
    required this.weapon,
    required this.damage,
    required this.shtick,
  });

  final String name;
  final MookTier tier;
  final int combat;
  final int defense;
  final int hitPoints;
  final int sp;
  final String weapon;
  final String damage;

  /// Cosa lo rende memorabile in una riga: senza questo, quattro scagnozzi con
  /// gli stessi numeri sono quattro bersagli identici e la scena muore.
  final String shtick;

  String get statLine => 'Combattimento +$combat · Difesa $defense · PV $hitPoints · SP $sp';

  /// Blocco pronto da incollare in chat.
  String get chatBlock => '**$name** (${tier.label})\n$statLine\n$weapon — $damage\n$shtick';
}

abstract final class MookGenerator {
  static const List<String> _shticks = <String>[
    'Spara e indietreggia: non vuole morire, vuole che tu te ne vada.',
    'Urla il nome della gang prima di attaccare. Sempre.',
    'Ha una dose di Black Lace in tasca e la usera\' quando perde.',
    'Punta alla giacca, non alla testa: vuole il tuo equipaggiamento intatto.',
    'Ha un telefono economico con la telecamera accesa. Sta trasmettendo.',
    'Conosce la strada meglio di te e lo sa.',
    'È qui solo perche\' gli devono dei soldi.',
    'Ride. Non ha smesso da dieci minuti.',
  ];

  static const Map<MookTier, List<(String, String)>> _weapons = <MookTier, List<(String, String)>>{
    MookTier.scagnozzo: <(String, String)>[
      ('Pistola economica', '2d6'),
      ('Mazza di ferro', '2d6'),
      ('Coltello a serramanico', '1d6'),
      ('Mitra scadente', '2d6'),
    ],
    MookTier.professionista: <(String, String)>[
      ('Pistola pesante', '3d6'),
      ('Fucile d\'assalto', '5d6'),
      ('Fucile a pompa', '5d6'),
      ('SMG con mirino', '2d6'),
    ],
    MookTier.elite: <(String, String)>[
      ('Fucile d\'assalto da tiro', '5d6'),
      ('Mitragliatrice leggera', '5d6'),
      ('Fucile di precisione', '5d6'),
      ('Pistola pesante potenziata', '4d6'),
    ],
    MookTier.letale: <(String, String)>[
      ('Fucile di precisione da cecchino', '5d6'),
      ('Lanciagranate', '6d6'),
      ('Mitragliatrice pesante', '6d6'),
      ('Armi da braccio potenziate', '4d6'),
    ],
  };

  /// Crea un PNG. I numeri del livello sono fissi; varia il contorno, perche'
  /// e' il contorno che il tavolo nota.
  static Mook generate(MookTier tier, math.Random random, {String? name, String? weapon, String? damage}) {
    final (String, String) picked =
        _weapons[tier]![random.nextInt(_weapons[tier]!.length)];
    return Mook(
      name: name ?? _nameFor(tier, random),
      tier: tier,
      combat: tier.combat,
      defense: tier.defense,
      hitPoints: tier.hitPoints,
      sp: tier.sp,
      weapon: weapon ?? picked.$1,
      damage: damage ?? picked.$2,
      shtick: _shticks[random.nextInt(_shticks.length)],
    );
  }

  /// Una banda di nemici per una scena. `size` viene dal generatore di incontri,
  /// non dal caso: la dimensione del gruppo deve seguire la taglia del tavolo,
  /// non un tiro.
  static List<Mook> band(MookTier tier, int size, math.Random random, {String? namePrefix}) {
    return <Mook>[
      for (int i = 0; i < size; i++)
        generate(tier, random, name: namePrefix == null ? null : '$namePrefix ${i + 1}'),
    ];
  }

  static const List<String> _firstNames = <String>[
    'Ray', 'Vik', 'Dom', 'Sol', 'Nina', 'Kato', 'Ivy', 'Bru', 'Zena', 'Mook',
    'Dante', 'Sasha', 'Ren', 'Ola', 'Ciro', 'Wex',
  ];

  static const List<String> _lastNames = <String>[
    'la Spina', 'Kowalski', 'Vasquez', '"Mezza Mano"', 'Reyes', 'Dietrich',
    'Okada', 'Bruno', 'il Sordo', 'Nakamura', 'Ferrer',
  ];

  static String _nameFor(MookTier tier, math.Random random) {
    final String first = _firstNames[random.nextInt(_firstNames.length)];
    final String last = _lastNames[random.nextInt(_lastNames.length)];
    return '$first $last';
  }
}

// --------------------------------------------------------------------------
// Incontri notturni
// --------------------------------------------------------------------------

/// La gravita' di un incontro, usata per decidere quanti PNG e quale livello.
enum EncounterThreat {
  bassa('Bassa', MookTier.scagnozzo),
  media('Media', MookTier.professionista),
  alta('Alta', MookTier.elite),
  letale('Letale', MookTier.letale);

  const EncounterThreat(this.label, this.tier);

  final String label;
  final MookTier tier;
}

/// La scheda di un incontro: cosa succede, dove, con che pretesto, e chi c'e'
/// di fronte. `gruppo` e' del tavolo, non del tiro: si sceglie dal numero di
/// giocatori altrimenti l'incontro non e' calibrato.
class NightEncounter {
  const NightEncounter({
    required this.title,
    required this.threat,
    required this.hook,
    required this.terrain,
    required this.complication,
    required this.reward,
    required this.enemies,
    required this.roll,
  });

  final String title;
  final EncounterThreat threat;

  /// Perche' succede: la riga che si legge ad alta voce per aprire la scena.
  final String hook;
  final String terrain;

  /// Il colpo di scena che rende l'incontro diverso dal precedente.
  final String complication;
  final String reward;

  /// I PNG gia' pronti, generati a partire dalla minaccia.
  final List<Mook> enemies;
  final TableRoll<EncounterSeed> roll;

  String get summary =>
      '$title [${threat.label}] · ${enemies.length} nemici · ${roll.index}/${roll.total} (${roll.percentage})';

  /// Testo pronto per la chat o per le note di sessione.
  String get briefing {
    final StringBuffer b = StringBuffer()
      ..writeln('### $title')
      ..writeln('**Minaccia:** ${threat.label}')
      ..writeln('**Apertura:** $hook')
      ..writeln('**Terreno:** $terrain')
      ..writeln('**Complicazione:** $complication')
      ..writeln('**Bottino previsto:** $reward')
      ..writeln('**Contro:**');
    for (final Mook m in enemies) {
      b.writeln('- ${m.name} — ${m.statLine} — ${m.weapon} (${m.damage})');
    }
    return b.toString().trimRight();
  }
}

/// La voce di tabella, senza i PNG: cosi' la tabella e' costante e condivisa,
/// e i PNG si generano al momento del tiro.
class EncounterSeed {
  const EncounterSeed({
    required this.title,
    required this.threat,
    required this.hook,
    required this.terrain,
    required this.complication,
    required this.reward,
    this.groupSize = 4,
  });

  final String title;
  final EncounterThreat threat;
  final String hook;
  final String terrain;
  final String complication;
  final String reward;

  /// Quanti nemici, prima della correzione per la taglia del tavolo.
  final int groupSize;
}

abstract final class NightEncounterGenerator {
  /// La tabella. Le voci piu' pesanti sono gli agguati di strada, perche' a
  /// Night City la violenza ordinaria e' statisticamente piu' probabile di
  /// qualunque cosa interessante — ed e' esattamente il tono del gioco.
  static const RollTable<EncounterSeed> table = RollTable<EncounterSeed>(
    id: 'encounter.nightcity',
    title: 'Incontri notturni a Night City',
    note: 'Composizione e agganci scritti da questa applicazione: il manuale definisce le gang, non chi passa in quel vicolo stanotte.',
    entries: <WeightedEntry<EncounterSeed>>[
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Taglieggio dei Bozo',
          threat: EncounterThreat.bassa,
          hook: 'Quattro ragazzi con i colori dei Bozo ti chiudono la strada. Vogliono il portafoglio e il giubbotto, in quest\'ordine.',
          terrain: 'Vicolo stretto, una sola uscita, luci al neon rotte',
          complication: 'Uno di loro sta filmando. Se il gruppo li umilia, il video finisce sulla rete entro un\'ora.',
          reward: 'Pochi eb, una pistola economica, un telefono con il video ancora dentro',
          groupSize: 4,
        ),
        weight: 6,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Pedaggio dei Tyger Claws',
          threat: EncounterThreat.media,
          hook: 'I Tyger Claws hanno messo un posto di blocco dove non c\'e\' nessuna strada da controllare. Il pedaggio e\' venti eb o due minuti di conversazione.',
          terrain: 'Strada larga, auto parcheggiate in diagonale, un furgone di traverso',
          complication: 'Il capoposto conosce uno dei personaggi di nome: chiedera\' un favore invece del denaro.',
          reward: 'eb, munizioni, un pacchetto di synthcoke, la mappa di un deposito',
          groupSize: 5,
        ),
        weight: 6,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Raccolta dei Maelstrom',
          threat: EncounterThreat.alta,
          hook: 'I Maelstrom stanno caricando un corpo su un furgone. Il corpo ha ancora un braccio cibernetico che non hanno finito di staccare.',
          terrain: 'Cortile industriale, gru ferme, un generatore che ronza',
          complication: 'Il corpo e\' ancora vivo. Se il gruppo interviene, la priorita\' dei Maelstrom passa dal bottino ai testimoni.',
          reward: 'Cyberware smontato, attrezzi chirurgici, un chip con un\'asta di impianti',
          groupSize: 5,
        ),
        weight: 4,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Pattuglia della Max-Tac',
          threat: EncounterThreat.letale,
          hook: 'Una pattuglia della Max-Tac scende dal veicolo con i fucili gia\' puntati. Non stanno cercando te: stanno cercando chiunque si muova.',
          terrain: 'Piazza aperta, luci bianche, nessuna copertura a meno di cento metri',
          complication: 'Cercano davvero qualcun altro, e se il gruppo resta immobile e zitto se ne vanno. Combattere non e\' la soluzione, e il manuale non lo scrive da nessuna parte.',
          reward: 'Sopravvivere. Chi apre il fuoco non porta a casa niente.',
          groupSize: 4,
        ),
        weight: 2,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Pioggia acida',
          threat: EncounterThreat.bassa,
          hook: 'Il cielo si apre e quello che scende non e\' acqua. Chi resta fuori scopre le giacche tecniche.',
          terrain: 'Qualunque strada, con la visibilita\' che crolla',
          complication: 'La pioggia cancella le tracce: chi stava inseguendo il gruppo perde la pista, ma anche il gruppo perde la propria.',
          reward: 'Nessuno. E\' un incontro di atmosfera, e serve a far costare le cose che succedono dopo.',
          groupSize: 0,
        ),
        weight: 5,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Scavvers al lavoro',
          threat: EncounterThreat.media,
          hook: 'Due scavvers stanno aprendo un\'ambulanza ferma. Dentro c\'e\' qualcuno che batte sulla lamiera.',
          terrain: 'Svincolo sopraelevato, ambulanze abbandonate, sabbia e vetri',
          complication: 'Uno degli scavvers e\' un ex Medtech e lo dice. Vuole contrattare, non combattere.',
          reward: 'Farmaci, un defibrillatore, kit chirurgico, eb',
          groupSize: 3,
        ),
        weight: 4,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Controllo della sicurezza aziendale',
          threat: EncounterThreat.media,
          hook: 'Una squadra privata ti ferma cento metri prima del tuo obiettivo e chiede di vedere il permesso. Non ce l\'hai.',
          terrain: 'Atrio di un palazzo, metal detector, telecamere attive',
          complication: 'I log della telecamera li registrano. Se il gruppo passa con la forza, il volto e\' in un database per sempre.',
          reward: 'Il badge di uno degli agenti, che apre piu\' porte di quante il gruppo immagini',
          groupSize: 4,
        ),
        weight: 3,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Trauma Team che arriva secondo',
          threat: EncounterThreat.bassa,
          hook: 'La sparatoria e\' finita da poco. Il Trauma Team atterra adesso, e non ha nessun interesse a sapere chi ha iniziato.',
          terrain: 'Strada piena di bossoli, un ferito che nessuno paga',
          complication: 'Il contratto di assicurazione copre un solo ferito. Scegliere chi cura e\' la vera scena.',
          reward: 'Un debito di favore verso un medico che risponde al telefono anche alle quattro del mattino',
          groupSize: 3,
        ),
        weight: 3,
      ),
      WeightedEntry<EncounterSeed>(
        EncounterSeed(
          title: 'Inseguitore nei vicoli',
          threat: EncounterThreat.alta,
          hook: 'Qualcuno ti segue da tre isolati e non fa niente per nascondersi bene.',
          terrain: 'Rete di vicoli, scale antincendio, un mercato chiuso',
          complication: 'E\' un professionista pagato per *spaventare*, non per uccidere: serve a far capire chi comanda nel quartiere.',
          reward: 'Un nome, un numero di telefono e la consapevolezza di essere stati comprati come messaggio',
          groupSize: 1,
        ),
        weight: 3,
      ),
    ],
  );

  /// Tira un incontro. `playerCount` non cambia la voce ma il numero di nemici:
  /// lo stesso agguato deve restare una minaccia per due giocatori e per sei.
  static NightEncounter generate(math.Random random, {int playerCount = 4}) {
    final TableRoll<EncounterSeed> roll = table.roll(random);
    final EncounterSeed seed = roll.value;
    final int size = seed.groupSize == 0
        ? 0
        : math.max(1, (seed.groupSize + (playerCount - 4)).clamp(1, 10));
    final List<Mook> enemies = size == 0
        ? const <Mook>[]
        : MookGenerator.band(seed.threat.tier, size, random, namePrefix: seed.title.split(' ').last);
    return NightEncounter(
      title: seed.title,
      threat: seed.threat,
      hook: seed.hook,
      terrain: seed.terrain,
      complication: seed.complication,
      reward: seed.reward,
      enemies: enemies,
      roll: roll,
    );
  }
}

// --------------------------------------------------------------------------
// Bottino
// --------------------------------------------------------------------------

/// Cosa aveva addosso un nemico.
class LootBundle {
  LootBundle({required this.owner, required this.tier});

  final String owner;
  final MookTier tier;
  final List<LootEntry> entries = <LootEntry>[];
  int eurodollars = 0;

  /// Totale di quello che si puo' convertire subito in eb. Gli oggetti che
  /// valgono per *quello che sono* (un chip con un indirizzo, un badge) sono
  /// esclusi di proposito: sommarli a un totale li fa sembrare vendibili.
  String get summary {
    final StringBuffer b = StringBuffer('$owner: $eurodollars eb');
    if (entries.isNotEmpty) b.write(' + ${entries.map((LootEntry e) => e.short).join(', ')}');
    return b.toString();
  }

  String get chatBlock {
    final StringBuffer b = StringBuffer('**Bottino — $owner** (${tier.label})\n');
    b.writeln('• $eurodollars eb');
    for (final LootEntry e in entries) {
      b.writeln('• ${e.short}${e.note.isEmpty ? '' : ' — ${e.note}'}');
    }
    return b.toString().trimRight();
  }
}

/// Cosa di preciso, in che quantita', e a cosa serve.
enum LootKind { denaro, chip, munizioni, droga, arma, equipaggiamento, cyberware, oggetto }

class LootEntry {
  const LootEntry({required this.name, required this.kind, required this.quantity, this.note = ''});

  final String name;
  final LootKind kind;
  final int quantity;
  final String note;

  String get short => quantity > 1 ? '$name ×$quantity' : name;
}

abstract final class LootGenerator {
  /// Le tasche di un nemico abbattuto.
  static LootBundle forMook(Mook mook, math.Random random) {
    final LootBundle bundle = LootBundle(owner: mook.name, tier: mook.tier);
    bundle.eurodollars = _moneyFor(mook.tier, random);
    final int extras = 1 + random.nextInt(3);
    for (int i = 0; i < extras; i++) {
      final LootEntry entry = _oneEntry(mook.tier, random);
      bundle.entries.add(entry);
    }
    return bundle;
  }

  /// Il bottino dell'intera banda, sommato: e' la forma in cui serve al tavolo
  /// ("quanto abbiamo fatto stanotte?"), non un mucchio di blocchi separati.
  static LootBundle band(List<Mook> band, math.Random random) {
    final LootBundle total = LootBundle(
      owner: '${band.length} nemici (${band.isEmpty ? '—' : band.first.tier.label})',
      tier: band.isEmpty ? MookTier.scagnozzo : band.first.tier,
    );
    for (final Mook m in band) {
      final LootBundle one = forMook(m, random);
      total.eurodollars += one.eurodollars;
      for (final LootEntry e in one.entries) {
        final int index = total.entries.indexWhere((LootEntry x) => x.name == e.name && x.kind == e.kind);
        if (index >= 0) {
          final LootEntry existing = total.entries[index];
          total.entries[index] = LootEntry(
            name: existing.name,
            kind: existing.kind,
            quantity: existing.quantity + e.quantity,
            note: existing.note,
          );
        } else {
          total.entries.add(e);
        }
      }
    }
    return total;
  }

  static int _moneyFor(MookTier tier, math.Random random) {
    final (int, int) range = switch (tier) {
      MookTier.scagnozzo => (10, 80),
      MookTier.professionista => (50, 300),
      MookTier.elite => (200, 900),
      MookTier.letale => (500, 2500),
    };
    return range.$1 + random.nextInt(range.$2 - range.$1 + 1);
  }

  static const RollTable<LootEntry> table = RollTable<LootEntry>(
    id: 'loot.pockets',
    title: 'Tasche di un nemico',
    note: 'Proposta di questa applicazione: il manuale non dice cosa c\'e\' nelle tasche dei nemici.',
    entries: <WeightedEntry<LootEntry>>[
      WeightedEntry<LootEntry>(LootEntry(name: 'Munizioni', kind: LootKind.munizioni, quantity: 1, note: 'un caricatore, se l\'arma la usa'), weight: 8),
      WeightedEntry<LootEntry>(LootEntry(name: 'Chip di dati', kind: LootKind.chip, quantity: 1, note: 'contatti, codici di accesso o un registro di pagamenti'), weight: 5),
      WeightedEntry<LootEntry>(LootEntry(name: 'Black Lace', kind: LootKind.droga, quantity: 1, note: 'dose singola, sigillata con nastro adesivo'), weight: 3),
      WeightedEntry<LootEntry>(LootEntry(name: 'Synthcoke', kind: LootKind.droga, quantity: 1), weight: 3),
      WeightedEntry<LootEntry>(LootEntry(name: 'Telefono usa e getta', kind: LootKind.oggetto, quantity: 1, note: 'un solo numero salvato, senza nome'), weight: 4),
      WeightedEntry<LootEntry>(LootEntry(name: 'Kit medico da strada', kind: LootKind.equipaggiamento, quantity: 1, note: 'abbastanza per stabilizzare, non per curare'), weight: 2),
      WeightedEntry<LootEntry>(LootEntry(name: 'Radiomicrofono', kind: LootKind.equipaggiamento, quantity: 1), weight: 2),
      WeightedEntry<LootEntry>(LootEntry(name: 'Coltello balistico', kind: LootKind.arma, quantity: 1), weight: 2),
      WeightedEntry<LootEntry>(LootEntry(name: 'Armatura leggera', kind: LootKind.equipaggiamento, quantity: 1, note: 'indossata, con il sangue di qualcun altro'), weight: 2),
      WeightedEntry<LootEntry>(LootEntry(name: 'Borsa di plastica con denti d\'oro', kind: LootKind.oggetto, quantity: 1, note: 'qualcuno li ha strappati, non comprati'), weight: 1),
      WeightedEntry<LootEntry>(LootEntry(name: 'Schede di memoria vuote', kind: LootKind.oggetto, quantity: 1), weight: 2),
      WeightedEntry<LootEntry>(LootEntry(name: 'Braccio cibernetico economico', kind: LootKind.cyberware, quantity: 1, note: 'ancora collegato: smontarlo richiede tempo e attrezzi'), weight: 1),
    ],
  );

  static LootEntry _oneEntry(MookTier tier, math.Random random) {
    final LootEntry base = table.roll(random).value;
    // I nemici piu' seri portano roba piu' seria, e le quantita' seguono la
    // taglia: un caricatore in tasca a un professionista non e' la stessa cosa
    // di un caricatore in tasca a uno scagnozzo.
    final int bonus = switch (tier) {
      MookTier.scagnozzo => 1,
      MookTier.professionista => 2,
      MookTier.elite => 3,
      MookTier.letale => 4,
    };
    if (base.kind == LootKind.munizioni) {
      return LootEntry(name: base.name, kind: base.kind, quantity: bonus, note: base.note);
    }
    return base;
  }
}

// --------------------------------------------------------------------------
// Droghe e dipendenze
// --------------------------------------------------------------------------

/// Una sostanza da strada.
///
/// La forma e' quella che serve al tavolo: cosa fa **adesso**, quanto dura, e
/// cosa succede quando finisce. Il costo in Umanita' e' separato dagli altri
/// effetti perche' e' l'unico che si paga una volta e non si recupera
/// dormendo.
class StreetDrug {
  const StreetDrug({
    required this.name,
    required this.effect,
    required this.duration,
    required this.addictionDv,
    required this.withdrawal,
    required this.cost,
    this.humanityCost = 0,
    this.confidence = GmConfidence.daVerificare,
  });

  final String name;
  final String effect;
  final String duration;

  /// DV della prova per non diventare dipendenti.
  final int addictionDv;
  final String withdrawal;
  final int cost;
  final int humanityCost;
  final GmConfidence confidence;
}

/// Lo stato di dipendenza di un personaggio rispetto a una sostanza.
class AddictionState {
  const AddictionState({
    required this.drug,
    required this.dosesTaken,
    required this.addicted,
    this.daysSinceLastDose = 0,
  });

  final StreetDrug drug;
  final int dosesTaken;
  final bool addicted;
  final int daysSinceLastDose;

  /// La crisi arriva quando e' passato abbastanza tempo da svuotare il corpo.
  bool get inWithdrawal => addicted && daysSinceLastDose >= 1;

  String get status {
    if (!addicted) return 'Non dipendente ($dosesTaken dosi)';
    if (inWithdrawal) return 'In crisi da $daysSinceLastDose giorni';
    return 'Dipendente, in equilibrio';
  }
}

abstract final class DrugCatalog {
  /// Le sostanze.
  ///
  /// Queste sono **nomi del manuale** e gli effetti sono la mia lettura: la
  /// dicitura [GmConfidence.daVerificare] sta su ogni voce perche' un effetto
  /// sbagliato qui non si nota fino a quando non cambia un combattimento.
  static const List<StreetDrug> all = <StreetDrug>[
    StreetDrug(
      name: 'Black Lace',
      effect: 'Ignore the pain of Serious Injuries while it lasts; the character fights on regardless of wound penalties.',
      duration: '1d6 ore',
      addictionDv: 15,
      withdrawal: 'Tremori e scatti: penalita\' alle prove di precisione finche\' non si consuma o non si fa una settimana di disintossicazione.',
      cost: 50,
      humanityCost: 2,
    ),
    StreetDrug(
      name: 'Synthcoke',
      effect: 'Sensazione di lucidita\' totale: bonus alle prove sociali e di percezione, nessuna paura.',
      duration: '1 ora',
      addictionDv: 17,
      withdrawal: 'Crollo: nessuna prova sociale riesce senza un\'altra dose.',
      cost: 100,
      humanityCost: 1,
    ),
    StreetDrug(
      name: 'Blue Glass',
      effect: 'Rallenta il mondo: pensiero accelerato, il personaggio vede arrivare le cose prima.',
      duration: '2 ore',
      addictionDv: 16,
      withdrawal: 'Emicrania e fotofobia: penalita\' a ogni prova basata sulla vista.',
      cost: 75,
      humanityCost: 1,
    ),
    StreetDrug(
      name: 'Smash',
      effect: 'Forza bruta: bonus al Fisico e ai danni da mischia, nessun freno inibitorio.',
      duration: '30 minuti',
      addictionDv: 18,
      withdrawal: 'Aggressivita\' incontrollata e insonnia.',
      cost: 60,
      humanityCost: 3,
    ),
    StreetDrug(
      name: 'Boost',
      effect: 'Rinforzo muscolare immediato: solleva, sfonda, corre.',
      duration: '1 ora',
      addictionDv: 14,
      withdrawal: 'Debolezza muscolare: il carico massimo dimezzato.',
      cost: 40,
      humanityCost: 1,
    ),
    StreetDrug(
      name: 'Prime Time',
      effect: 'Sensazione di invulnerabilita\': bonus a iniziativa e resistenza al dolore.',
      duration: '1 ora',
      addictionDv: 16,
      withdrawal: 'Paranoia: ogni rumore sembra una minaccia.',
      cost: 90,
      humanityCost: 2,
    ),
  ];

  /// La prova di dipendenza. Il tiro e' 1d10 + Resistenza alle droghe (VOL +
  /// resistenza): qui si prende il modificatore e si restituisce l'esito, cosi'
  /// il pannello puo' dire subito "dipendente" invece di descrivere la regola.
  static AddictionOutcome test(StreetDrug drug, int resistModifier, math.Random random) {
    final int die = random.nextInt(10) + 1;
    final int total = die + resistModifier;
    return AddictionOutcome(drug: drug, die: die, modifier: resistModifier, total: total, dv: drug.addictionDv);
  }

  /// Quante dosi si possono prendere prima che la dipendenza sia probabile, in
  /// media: serve a dare al Master un numero prima che tiri, non dopo.
  static double expectedDosesBeforeAddiction(StreetDrug drug, int resistModifier) {
    final double successChance = ((10 - drug.addictionDv + resistModifier) / 10).clamp(0.0, 1.0);
    if (successChance >= 1) return double.infinity;
    if (successChance <= 0) return 1;
    return 1 / (1 - successChance);
  }
}

class AddictionOutcome {
  const AddictionOutcome({
    required this.drug,
    required this.die,
    required this.modifier,
    required this.total,
    required this.dv,
  });

  final StreetDrug drug;
  final int die;
  final int modifier;
  final int total;
  final int dv;

  bool get addicted => total < dv;

  String get text => '1d10 ($die) + $modifier = $total contro DV $dv → ${addicted ? 'dipendente' : 'nessuna dipendenza'}';
}

// --------------------------------------------------------------------------
// Lavori secondari
// --------------------------------------------------------------------------

/// Cosa rende una settimana di lavoro fra una sessione e l'altra.
class HustleResult {
  const HustleResult({
    required this.role,
    required this.job,
    required this.earned,
    required this.weeks,
    required this.risk,
    required this.complication,
  });

  final String role;
  final String job;
  final int earned;
  final int weeks;
  final String risk;
  final String complication;

  String get summary => '$role · $job · $earned eb in $weeks settimane';
}

abstract final class HustleGenerator {
  /// Il lavoro tipico e quanto rende, per ruolo.
  ///
  /// [GmConfidence.proposta]: il manuale ha una tabella di Hustle per ruolo, ma
  /// gli importi qui **non l'hanno seguita voce per voce**, quindi non e' quella
  /// tabella. E' una proposta di lavoro secondario con la stessa forma.
  static const Map<String, (String, int, int, String)> byRole = <String, (String, int, int, String)>{
    'Solo': ('Sicurezza privata per un locale che non puo\' permettersi un contratto vero', 300, 900, 'Qualcuno ti ha visto lavorare, e adesso sa quanto costi.'),
    'Netrunner': ('Recupero di dati da un server che nessuno sorveglia piu\'', 400, 1200, 'I dati non erano abbandonati: c\'e\' un proprietario, e sta cercando.'),
    'Fixer': ('Mediazione fra due parti che non vogliono incontrarsi', 500, 1500, 'Una delle due parti decide di tagliare fuori il mediatore.'),
    'Tech': ('Riparazioni di fortuna su attrezzatura militare dismessa', 350, 1000, 'Un pezzo riparato cede nel momento peggiore, e qualcuno si ricorda di te.'),
    'Medtech': ('Turni in una clinica che cura chi non ha assicurazione', 300, 800, 'Un paziente non era un paziente.'),
    'Media': ('Un pezzo che qualcuno vuole far sparire prima della pubblicazione', 250, 900, 'La storia e\' vera, ed e\' per questo che e\' pericolosa.'),
    'Lawman': ('Sorveglianza pagata da chi non puo\' denunciare', 300, 850, 'Il bersaglio della sorveglianza e\' un collega.'),
    'Exec': ('Un favore interno che nessuno mettera\' per iscritto', 400, 1300, 'Il favore ti mette in debito con la persona sbagliata.'),
    'Rockerboy': ('Serata in un locale che paga in visibilita\' e in contanti', 200, 1000, 'La visibilita\' attira la persona sbagliata.'),
    'Nomad': ('Un carico da scortare lungo una rotta che i Nomad conoscono', 350, 1100, 'Il carico non e\' quello dichiarato.'),
  };

  static HustleResult generate(String role, int weeks, math.Random random) {
    // Un ruolo scritto in modo diverso ("solo", "Solo ") deve trovare la sua
    // voce: altrimenti il Fixer riceverebbe il lavoro del Solo e nessuno se ne
    // accorgerebbe, perche' i numeri restano plausibili.
    final String wanted = role.trim().toLowerCase();
    final MapEntry<String, (String, int, int, String)> entry = byRole.entries.firstWhere(
      (MapEntry<String, (String, int, int, String)> e) => e.key.toLowerCase() == wanted,
      orElse: () => byRole.entries.first,
    );
    final (String, int, int, String) job = entry.value;
    final int perWeek = job.$2 + random.nextInt(job.$3 - job.$2 + 1);
    return HustleResult(
      role: role,
      job: job.$1,
      earned: perWeek * weeks,
      weeks: weeks,
      risk: 'Ogni settimana di lavoro comporta una prova di abilita\' di ruolo; un fallimento non toglie il denaro, toglie la quiete.',
      complication: job.$4,
    );
  }
}

// --------------------------------------------------------------------------
// Screamsheets
// --------------------------------------------------------------------------

/// Un trafiletto di giornale da mostrare ai giocatori.
class Screamsheet {
  const Screamsheet({
    required this.headline,
    required this.standfirst,
    required this.body,
    required this.byline,
    required this.section,
    required this.dateLine,
    required this.ticker,
  });

  final String headline;
  final String standfirst;
  final String body;
  final String byline;
  final String section;
  final String dateLine;
  final List<String> ticker;

  /// Il pezzo impaginato come lo si mostrerebbe al tavolo.
  String get plainText {
    final StringBuffer b = StringBuffer()
      ..writeln(section.toUpperCase())
      ..writeln(dateLine)
      ..writeln()
      ..writeln(headline.toUpperCase())
      ..writeln(standfirst)
      ..writeln()
      ..writeln(body)
      ..writeln()
      ..writeln('— $byline');
    if (ticker.isNotEmpty) {
      b
        ..writeln()
        ..writeln('IN BREVE');
      for (final String t in ticker) {
        b.writeln('• $t');
      }
    }
    return b.toString().trimRight();
  }
}

abstract final class ScreamsheetGenerator {
  static const List<String> _sections = <String>[
    'Cronaca di Night City',
    'Economia e Affari',
    'Sicurezza Urbana',
    'Cultura e Rete',
    'Sport',
  ];

  static const List<String> _bylines = <String>[
    'di R. Vasquez',
    'di un corrispondente che ha chiesto di restare anonimo',
    'dalla redazione notturna',
    'di K. Okada',
    'agenzia, non verificato',
  ];

  /// Le notizie si compongono da parti: una testata fatta a mano una volta e'
  /// un articolo; composta da parti e' cento articoli che suonano diversi.
  static const List<String> _subjects = <String>[
    'Un deposito della Militech nel quartiere industriale',
    'La linea del metrò sopraelevato di Heywood',
    'Una raffineria di kibble a Northside',
    'Il mercato coperto di Kabuki',
    'Tre torri residenziali di proprietà Arasaka',
    'L\'ospedale pubblico di Pacifica',
    'Un cantiere fermo da quattro anni a Santo Domingo',
  ];

  static const List<String> _events = <String>[
    'è andato a fuoco per la seconda volta in un mese',
    'è stato sigillato da personale non identificato',
    'è stato rilevato da una società che non compare in nessun registro',
    'ha smesso di ricevere rifornimenti',
    'verrà demolito entro la fine del trimestre',
    'è stato teatro di uno scontro a fuoco senza vittime dichiarate',
  ];

  static const List<String> _angles = <String>[
    'Nessun comunicato, nessuna spiegazione, nessun ferito ufficiale.',
    'La società proprietaria non ha risposto alle richieste di commento.',
    'I residenti raccontano una versione diversa da quella ufficiale.',
    'Le autorità cittadine dichiarano che la situazione è sotto controllo.',
    'Chi ci lavorava dentro non è rintracciabile.',
  ];

  static const List<String> _quotes = <String>[
    '«Non è successo niente. Andate a casa.» — portavoce aziendale',
    '«Ci hanno detto di non parlare, e poi ci hanno offerto dei soldi.» — un testimone',
    '«Se non lo scrivete voi, non lo saprà nessuno.» — residente',
    '«È la terza volta quest\'anno. Alla quarta ci abitueremo.» — commerciante della zona',
    '«Non è un incidente, è una decisione.» — ex dipendente',
  ];

  static const List<String> _tickers = <String>[
    'Corso dell\'eb stabile per il sesto giorno consecutivo',
    'Max-Tac: due interventi nella notte, nessun dettaglio diffuso',
    'Un impianto di purificazione dell\'acqua fuori servizio a Pacifica',
    'Nuove rotte dei Nomad verso il sud, pedaggi in aumento',
    'Coprifuoco non annunciato nel distretto industriale',
    'Un\'asta di cyberware dismesso chiude con prezzi record',
    'Sciopero dei tecnici della manutenzione sotterranea',
  ];

  static Screamsheet generate(math.Random random, {String? dateLine}) {
    final String subject = _pick(_subjects, random);
    final String subject2 = _pick(_subjects, random);
    final String event = _pick(_events, random);
    final String angle = _pick(_angles, random);
    final String quote = _pick(_quotes, random);
    final List<String> ticker = _twoDistinct(_tickers, random);
    return Screamsheet(
      headline: '${subject.toUpperCase()} $event'.toUpperCase(),
      standfirst: '$angle Tre ore dopo, sul posto non c\'era più nessuno a rispondere.',
      body: '$subject $event. $quote\n\n'
          'Nella stessa notte, $subject2 è finito al centro di una segnalazione '
          'che nessun ufficio ha voluto commentare. Le due cose, ufficialmente, '
          'non hanno niente in comune.',
      byline: _pick(_bylines, random),
      section: _pick(_sections, random),
      dateLine: dateLine ?? 'Edizione notturna',
      ticker: ticker,
    );
  }

  static String _pick(List<String> from, math.Random random) => from[random.nextInt(from.length)];

  /// Due voci diverse: le brevi in fondo a due titoli identici sembrano un
  /// errore di stampa, non una scelta redazionale.
  static List<String> _twoDistinct(List<String> from, math.Random random) {
    if (from.length < 2) return List<String>.of(from);
    final int first = random.nextInt(from.length);
    final int offset = 1 + random.nextInt(from.length - 1);
    return <String>[from[first], from[(first + offset) % from.length]];
  }
}

// --------------------------------------------------------------------------
// Nomi e dettagli di scena
// --------------------------------------------------------------------------

/// Dettagli minori che servono a improvvisare: come si chiama il locale, chi lo
/// gestisce, che musica c'e'.
class SceneDressing {
  const SceneDressing({
    required this.place,
    required this.keeper,
    required this.detail,
    required this.smell,
    required this.sound,
  });

  final String place;
  final String keeper;
  final String detail;
  final String smell;
  final String sound;

  String get text => '$place — $keeper\n$detail\nOdore: $smell. Suono: $sound.';
}

abstract final class SceneGenerator {
  static const List<String> _places = <String>[
    'il Maglio Freddo, un bar con tre tavoli e un solo bicchiere pulito',
    'la Sala Verde, un bordello con le luci accese a metà',
    'il Deposito 12, un magazzino aperto dove nessuno controlla i badge',
    'la Stazione Nove, fermata del metrò chiusa da anni e ancora usata',
    'il Banco, un mercato di pezzi di ricambio a cielo aperto',
    'la Clinica di Rue, due stanze sopra una lavanderia',
  ];

  static const List<String> _keepers = <String>[
    'gestito da una donna che paga la protezione in informazioni, non in soldi',
    'gestito da due gemelli che non parlano mai nello stesso momento',
    'gestito da un ex Medtech che tiene il conto di ogni ferita che cura',
    'gestito da qualcuno che non c\'è quasi mai, e nessuno sa chi sia',
    'gestito da un uomo con un braccio solo e un registro scritto a mano',
  ];

  static const List<String> _details = <String>[
    'Sul muro c\'è un manifesto elettorale di nove anni fa e nessuno l\'ha staccato.',
    'Una telecamera punta la porta, ma il cavo è tagliato da mesi.',
    'C\'è un gatto che dorme su una macchina da caffè e nessuno lo tocca.',
    'Una corda pende dal soffitto e non si sa a cosa serva.',
    'Il pavimento è più basso di venti centimetri rispetto alla strada.',
  ];

  static const List<String> _smells = <String>[
    'olio bruciato', 'kibble riscaldato', 'cloro', 'pioggia sui metalli', 'incenso economico',
  ];

  static const List<String> _sounds = <String>[
    'una radio che gracchia sempre sulla stessa stazione',
    'un generatore che ronza due toni sotto la conversazione',
    'passi sul piano di sopra che si fermano quando parli',
    'musica che nessuno ha scelto e che nessuno spegne',
    'il metrò che passa ogni sette minuti',
  ];

  static SceneDressing generate(math.Random random) => SceneDressing(
        place: ScreamsheetGenerator._pick(_places, random),
        keeper: ScreamsheetGenerator._pick(_keepers, random),
        detail: ScreamsheetGenerator._pick(_details, random),
        smell: ScreamsheetGenerator._pick(_smells, random),
        sound: ScreamsheetGenerator._pick(_sounds, random),
      );
}
