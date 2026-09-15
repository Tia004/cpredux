/// Il trasporto in tempo reale: un veicolo che si muove sulla mappa mentre il
/// tavolo gioca.
///
/// Perche' un concetto a parte e non un token che si sposta. Un token e' una
/// **cosa che sta in un posto**: un capo dei Tyger Claws in un vicolo, un
/// civile in un negozio. Un trasporto e' una cosa che *sta andando* da qualche
/// parte: ha un percorso, una velocita', un tempo di arrivo, e si muove da solo
/// mentre nessuno lo tocca. Se il movimento lo facesse la mappa, la mappa
/// comincerebbe a possedere il tempo, e il tempo qui appartiene al tavolo.
///
/// Come si muove, in una frase: lo **stato** dice dove sei adesso, e il tempo
/// reale fa il resto. `advance` e' una funzione pura che prende quanto tempo e'
/// passato e sposta il veicolo di conseguenza — quindi si puo' verificare che
/// dopo novanta secondi il taxi e' al posto di blocco senza aspettarne novanta.
///
/// Il problema che questo file risolve per primo non e' tecnico. La mappa e' una
/// griglia normalizzata 0..1, **senza metri**: la scelta giusta per disegnare,
/// ma un "taxi a 45 km/h" su una mappa senza unita' di misura non significa
/// niente. Servono due numeri dichiarati — quanto e' larga Night City e quanto
/// sono piu' lunghe le strade di una linea retta — e sono [GmRule] come tutti
/// gli altri, quindi si vedono con la loro provenienza e si correggono.
///
/// Il secondo problema e' l'ordine di grandezza. Attraversare una citta' di
/// dodici chilometri a quarantacinque all'ora sono sedici minuti: realistico e
/// inguardabile a un tavolo. Quindi il trasporto viaggia in **tempo
/// moltiplicato** — ["tempo.tick.scale"] dice quante volte — e la velocita'
/// mostrata resta quella vera del veicolo. Un inseguimento si guarda accadere
/// invece di essere riassunto a parole.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'gm/gm_rules.dart';
import 'json_support.dart';
import 'skills.dart';

/// Una fermata del percorso: dove si va, e come si chiama quel posto.
///
/// Il percorso e' una lista di fermate e non una polilinea libera perche' e'
/// come lo si descrive a voce ("prima all'Afterlife, poi a Corpo Plaza, poi a
/// casa"), e perche' le fermate hanno un nome: senza nome, il registro direbbe
/// "il taxi e' arrivato a 0.63, 0.41", che al tavolo non vuol dire niente.
class RouteStop {
  const RouteStop(this.name, this.position);

  final String name;
  final Offset position;

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'x': position.dx,
        'y': position.dy,
      };

  static RouteStop fromJson(Map<String, Object?> json) => RouteStop(
        readString(json['name']).trim().isEmpty ? 'Fermata' : readString(json['name']),
        Offset(readDouble(json['x']).clamp(0, 1), readDouble(json['y']).clamp(0, 1)),
      );

  @override
  String toString() => '$name (${position.dx.toStringAsFixed(2)}, ${position.dy.toStringAsFixed(2)})';
}

/// Come ci si sposta.
///
/// Le velocita' sono **proposte di questa applicazione**: il manuale descrive i
/// veicoli con la loro velocita' di combattimento per turno, che serve a
/// risolvere un inseguimento round per round, non a dire quanto ci mette un
/// taxi ad arrivare in centro. Qui serve il secondo numero, e questo non e' il
/// primo. Da qui la [GmConfidence.proposta] su tutte: un Master che le legge sa
/// di poterle cambiare, ed e' quello che deve pensare.
enum TransportMode {
  taxi('Taxi', 45, 'Auto di piazza. C\'e\' sempre, costa poco, e il conducente ha visto di peggio.'),
  groundcar('Groundcar', 70, 'Veicolo privato o rubato: piu\' svelto, e piu\' visibile.'),
  moto('Moto', 110, 'Passa dove le auto non passano. Chi la guida e\' esposto.'),
  aerodyne('Aerodyne', 220, 'Volo urbano: salta le strade, e quindi anche i posti di blocco.'),
  maglev('Maglev', 320, 'Metropolitana sopraelevata. Non si ferma per nessuno sulla strada.');

  const TransportMode(this.label, this.cruiseKmh, this.description);

  final String label;

  /// Velocita' di crociera in chilometri orari, come valore dichiarato.
  final double cruiseKmh;

  final String description;

  static TransportMode fromName(String? value) {
    for (final TransportMode m in TransportMode.values) {
      if (m.name == value) return m;
    }
    return TransportMode.taxi;
  }
}

/// Dove sta andando il veicolo adesso.
enum TransportStatus {
  /// Si sta muovendo.
  inViaggio('In viaggio'),

  /// Fermato da un evento. Riparte da solo alla scadenza, o quando il Master lo
  /// rilascia: la seconda serve per gli eventi che non hanno una durata — un
  /// agguato finisce quando finisce lo scontro.
  fermo('Fermo'),

  /// Arrivato all'ultima fermata.
  arrivato('Arrivato');

  const TransportStatus(this.label);

  final String label;

  static TransportStatus fromName(String? value) {
    for (final TransportStatus s in TransportStatus.values) {
      if (s.name == value) return s;
    }
    return TransportStatus.inViaggio;
  }
}

/// Cosa puo' capitare a un veicolo in strada.
///
/// Un evento non e' un pulsante di pausa: dice **cosa succede**, per quanto, e
/// **cosa deve fare il tavolo**. E' la differenza fra "il taxi si ferma" — che
/// non e' una scena — e "posto di blocco dei Tyger Claws, novanta secondi, il
/// guidatore deve superare una prova di Guidare o lo tirano giu' dal veicolo".
///
/// La durata a zero significa "finche' il Master non lo rilascia", ed e' il
/// caso giusto per tutto cio' che si risolve con una scena invece che con un
/// cronometro: un agguato, un incidente con feriti, una fermata voluta dai
/// passeggeri.
class TransportIncident {
  const TransportIncident({
    required this.id,
    required this.title,
    required this.description,
    required this.haltSeconds,
    this.speedFactor = 1,
    this.check,
    this.checkDv = 0,
    this.checkStake = '',
    this.confidence = GmConfidence.proposta,
  });

  final String id;
  final String title;
  final String description;

  /// Secondi di fermo. Zero = finche' il Master non rilascia.
  final int haltSeconds;

  /// Velocita' a cui riparte, rispetto alla crociera: 0.5 = va a meta'.
  final double speedFactor;

  /// La prova che i passeggeri o il conducente devono superare, se c'e'.
  final Skill? check;
  final int checkDv;

  /// Cosa si rischia se la prova non passa: e' la parte che rende la prova una
  /// decisione invece di un tiro.
  final String checkStake;

  final GmConfidence confidence;

  bool get holdUntilReleased => haltSeconds <= 0;

  /// La riga che va nel registro della sessione.
  String get logLine {
    final String hold = holdUntilReleased ? 'finche\' il Master non rilascia' : '$haltSeconds secondi';
    final String checkPart = check == null ? '' : ' — prova di ${check!.name} DV $checkDv';
    return '$title: $hold$checkPart';
  }
}

/// Gli eventi scatenabili dal Master.
///
/// Sono tutti [GmConfidence.proposta]: non esistono sul manuale come tabella, e
/// presentarli come regole sarebbe la bugia che questa applicazione evita
/// dappertutto. Il Master li scatena quando vuole — non tirano da soli — ed e'
/// giusto cosi': un agguato non e' un evento casuale della strada, e' una
/// decisione narrativa.
abstract final class TransportIncidents {
  static const TransportIncident checkpoint = TransportIncident(
    id: 'posto-di-blocco',
    title: 'Posto di blocco',
    description:
        'Una fila di auto ferme, due con i fucili, e nessuna fretta. Il veicolo si accoda '
        'e aspetta il proprio turno come tutti.',
    haltSeconds: 90,
    check: Skill.driveLandVehicle,
    checkDv: 13,
    checkStake: 'Se la prova non passa, chiedono di aprire il bagagliaio.',
  );

  static const TransportIncident ambush = TransportIncident(
    id: 'agguato',
    title: 'Agguato',
    description:
        'Una macchina si mette di traverso e un\'altra chiude dietro. Non vogliono il '
        'veicolo: vogliono chi c\'e\' dentro.',
    haltSeconds: 0,
    check: Skill.concentration,
    checkDv: 15,
    checkStake: 'Chi non passa agisce per ultimo, e i passeggeri sono fermi sul posto.',
  );

  static const TransportIncident crash = TransportIncident(
    id: 'incidente',
    title: 'Incidente',
    description: 'Un urto laterale, il veicolo gira, e da li\' in poi va storto.',
    haltSeconds: 60,
    speedFactor: 0.5,
    check: Skill.driveLandVehicle,
    checkDv: 15,
    checkStake: 'Se la prova non passa, il veicolo resta fermo e va riparato.',
  );

  static const TransportIncident breakdown = TransportIncident(
    id: 'guasto',
    title: 'Gomma bucata',
    description: 'Qualcosa sull\'asfalto, e il veicolo si abbassa da un lato.',
    haltSeconds: 120,
    check: Skill.landVehicleTech,
    checkDv: 12,
    checkStake: 'Per cambiarla in meta\' tempo: senza, si aspetta.',
  );

  static const TransportIncident policeStop = TransportIncident(
    id: 'fermo-polizia',
    title: 'Fermo della polizia',
    description:
        'Luci blu negli specchietti. Non stanno cercando te: stanno controllando se '
        'qualcuno dentro ha qualcosa da nascondere.',
    haltSeconds: 150,
    check: Skill.persuasion,
    checkDv: 14,
    checkStake: 'Se la prova non passa, si passa al setaccio: la scheda va mostrata.',
  );

  static const TransportIncident passengerStop = TransportIncident(
    id: 'fermata-voluta',
    title: 'Fermata voluta dai passeggeri',
    description: 'Chi e\' a bordo batte sulla spalla del conducente e chiede di fermarsi qui.',
    haltSeconds: 0,
    check: null,
  );

  static const TransportIncident detour = TransportIncident(
    id: 'deviazione',
    title: 'Deviazione',
    description: 'La strada e\' chiusa, o lo diventa: il percorso cambia e allunga.',
    haltSeconds: 30,
    speedFactor: 0.75,
    check: Skill.perception,
    checkDv: 13,
    checkStake: 'Chi se ne accorge in tempo evita di finire nell\'imboscata all\'angolo.',
  );

  static const TransportIncident jam = TransportIncident(
    id: 'ingorgo',
    title: 'Ingorgo',
    description: 'Sei corsie e nessuna che si muove. Nessuno suona il clacson: e\' tardi.',
    haltSeconds: 60,
    speedFactor: 0.6,
    check: null,
  );

  static const List<TransportIncident> all = <TransportIncident>[
    checkpoint,
    ambush,
    crash,
    breakdown,
    policeStop,
    passengerStop,
    detour,
    jam,
  ];

  static TransportIncident? byId(String id) {
    for (final TransportIncident i in all) {
      if (i.id == id) return i;
    }
    return null;
  }
}

/// Cosa e' successo in un passo di tempo.
///
/// Non e' un dettaglio di comodo: senza il resoconto, lo stato dovrebbe
/// confrontare prima e dopo ogni tick per capire se scrivere nel registro, e
/// confrontare due volte al secondo per decidere se e' successo qualcosa e' il
/// modo in cui un registro si riempie di righe identiche.
class TransportTick {
  const TransportTick({this.movedMeters = 0, this.resumed = false, this.arrived = false});

  final double movedMeters;

  /// Il fermo e' scaduto in questo passo.
  final bool resumed;

  /// E' arrivato all'ultima fermata in questo passo.
  final bool arrived;

  bool get isEvent => resumed || arrived;
}

/// Un veicolo sulla mappa, con il suo percorso e il suo orologio.
class Transport {
  Transport({
    required this.id,
    required this.name,
    required this.mode,
    required List<RouteStop> stops,
    required this.speedKmh,
    this.x = 0,
    this.y = 0,
    this.progressMeters = 0,
    this.status = TransportStatus.inViaggio,
    this.haltRemaining = Duration.zero,
    this.haltReason = '',
    this.speedFactor = 1,
    this.lastIncidentId = '',
    List<String> passengers = const <String>[],
    List<String> passengerTokenIds = const <String>[],
    List<String> log = const <String>[],
    this.note = '',
    this.createdAt = '',
  })  : stops = List<RouteStop>.unmodifiable(stops),
        passengers = List<String>.from(passengers),
        passengerTokenIds = List<String>.from(passengerTokenIds),
        log = List<String>.from(log);

  final String id;
  String name;
  TransportMode mode;

  /// Da dove a dove, in ordine.
  final List<RouteStop> stops;

  /// Velocita' di crociera adesso, in km/h. Il Master la puo' cambiare al
  /// tavolo: e' un dato del veicolo, non una regola del gioco.
  double speedKmh;

  double x;
  double y;

  /// Quanti metri ha gia' fatto. Serve al tempo di arrivo e alla barra di
  /// avanzamento; la posizione vera resta [x]/[y], perche' e' quella che deve
  /// restare identica fra master e giocatori anche se uno dei due ha corretto
  /// la scala della mappa per conto suo.
  double progressMeters;

  TransportStatus status;

  /// Quanto manca alla ripartenza automatica.
  Duration haltRemaining;

  /// Perche' e' fermo, in una riga da leggere al tavolo.
  String haltReason;

  /// Moltiplicatore della velocita' dopo un evento (0.5 = va a meta').
  double speedFactor;

  String lastIncidentId;

  /// Chi e' a bordo **per nome**: il conducente, i passeggeri, chi si e' fatto
  /// portare. E' quello che si dice a voce.
  List<String> passengers;

  /// Quali token viaggiano con il veicolo. Sono gli stessi nomi di
  /// [passengers], ma con l'identificativo che serve a spostarli sulla mappa:
  /// un personaggio che prende un taxi deve **vedersi** muovere.
  List<String> passengerTokenIds;

  /// Le ultime cose successe a bordo, dalla piu' recente.
  List<String> log;

  String note;

  final String createdAt;

  Offset get position => Offset(x, y);

  set position(Offset value) {
    x = value.dx.clamp(0, 1).toDouble();
    y = value.dy.clamp(0, 1).toDouble();
  }

  bool get isMoving => status == TransportStatus.inViaggio;

  bool get isHeld => status == TransportStatus.fermo && haltReason.isNotEmpty;

  /// La velocita' effettiva, con il fattore dell'ultimo evento applicato.
  double get effectiveKmh => isMoving ? speedKmh * speedFactor : 0;

  /// Quanto manca in linea d'aria residua, in metri.
  double remainingMeters(double mapSpanMeters) =>
      (routeLengthMeters(stops, mapSpanMeters) - progressMeters).clamp(0, double.infinity);

  /// Il tempo di arrivo alla velocita' attuale, gia' diviso per il
  /// moltiplicatore di tempo: e' il tempo che si aspetta **al tavolo**, non
  /// quello che segnerebbe un cronometro in strada.
  Duration? eta(double mapSpanMeters, {double timeScale = 1}) {
    if (!isMoving || effectiveKmh <= 0) return null;
    final double metersPerSecond = effectiveKmh * 1000 / 3600;
    final double realSeconds = remainingMeters(mapSpanMeters) / metersPerSecond;
    final double tableSeconds = realSeconds / (timeScale <= 0 ? 1 : timeScale);
    return Duration(seconds: tableSeconds.round());
  }

  /// Da quanto a dove va, in una riga.
  String get routeLine => stops.length < 2
      ? 'Percorso incompleto'
      : '${stops.first.name} → ${stops.last.name}${stops.length > 2 ? ' (${stops.length - 2} fermate in mezzo)' : ''}';

  /// Lo stato in una riga, per la lista del tavolo.
  String get statLine {
    final List<String> parts = <String>[];
    parts.add('${effectiveKmh.round()} km/h');
    if (status == TransportStatus.fermo) {
      parts.add(haltReason.isEmpty ? 'fermo' : haltReason);
    }
    if (status == TransportStatus.arrivato) parts.add('arrivato');
    if (passengers.isNotEmpty) parts.add('a bordo: ${passengers.join(', ')}');
    return parts.join(' · ');
  }

  /// Ferma il veicolo. [reason] vuota significa "per volonta' del Master", e
  /// [hold] e' quanto durera' il fermo: zero significa finche' non lo rilascia.
  void halt(String reason, {Duration hold = Duration.zero, String incidentId = '', double speedFactor = 1}) {
    if (status == TransportStatus.arrivato) return;
    status = TransportStatus.fermo;
    haltReason = reason;
    haltRemaining = hold;
    lastIncidentId = incidentId;
    this.speedFactor = speedFactor <= 0 ? 1 : speedFactor;
  }

  void resume() {
    if (status == TransportStatus.arrivato) return;
    status = TransportStatus.inViaggio;
    haltReason = '';
    haltRemaining = Duration.zero;
  }

  /// Un passo di tempo reale.
  ///
  /// [elapsed] e' quanto tempo e' passato davvero (il battito dell'orologio),
  /// [mapSpanMeters] quanto e' larga la mappa in metri, [timeScale] quante volte
  /// il tempo del tavolo corre rispetto a quello vero.
  ///
  /// Il tempo **fermo non si conta come percorso**: chi e' al posto di blocco
  /// non avanza, e un arresto di novanta secondi non deve diventare novanta
  /// secondi di strada.
  TransportTick advance(
    Duration elapsed, {
    required double mapSpanMeters,
    double timeScale = 1,
  }) {
    if (elapsed <= Duration.zero) return const TransportTick();
    if (status == TransportStatus.arrivato) return const TransportTick();

    if (status == TransportStatus.fermo) {
      if (haltRemaining <= Duration.zero) return const TransportTick();
      final Duration left = haltRemaining - elapsed;
      if (left > Duration.zero) {
        haltRemaining = left;
        return const TransportTick();
      }
      // Il fermo e' scaduto in questo passo: quello che avanza del passo non si
      // perde, si conta come strada. Altrimenti ogni fermo costerebbe un battito
      // di ritardo sull'arrivo.
      final Duration surplus = -left;
      haltRemaining = Duration.zero;
      resume();
      return TransportTick(
        movedMeters: _step(surplus, mapSpanMeters: mapSpanMeters, timeScale: timeScale),
        resumed: true,
        arrived: status == TransportStatus.arrivato,
      );
    }

    final double moved = _step(elapsed, mapSpanMeters: mapSpanMeters, timeScale: timeScale);
    return TransportTick(movedMeters: moved, arrived: status == TransportStatus.arrivato);
  }

  double _step(Duration elapsed, {required double mapSpanMeters, required double timeScale}) {
    final double scale = timeScale <= 0 ? 1 : timeScale;
    final double metersPerSecond = (speedKmh * speedFactor) * 1000 / 3600;
    final double tableSeconds = elapsed.inMicroseconds / 1000000 * scale;
    final double meters = metersPerSecond * tableSeconds;
    if (meters <= 0) return 0;

    final double total = routeLengthMeters(stops, mapSpanMeters);
    if (total <= 0) {
      status = TransportStatus.arrivato;
      return 0;
    }

    final double before = progressMeters;
    progressMeters = (progressMeters + meters).clamp(0, total);
    position = positionAlong(stops, progressMeters, mapSpanMeters);
    if (progressMeters >= total) status = TransportStatus.arrivato;
    return progressMeters - before;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'mode': mode.name,
        'stops': stops.map((RouteStop s) => s.toJson()).toList(),
        'speedKmh': speedKmh,
        'x': x,
        'y': y,
        'progressMeters': progressMeters,
        'status': status.name,
        'haltSeconds': haltRemaining.inSeconds,
        'haltReason': haltReason,
        'speedFactor': speedFactor,
        'lastIncidentId': lastIncidentId,
        'passengers': passengers,
        'passengerTokenIds': passengerTokenIds,
        'log': log,
        'note': note,
        'createdAt': createdAt,
      };

  static Transport fromJson(Map<String, Object?> json) => Transport(
        id: readString(json['id']),
        name: readString(json['name'], 'Trasporto'),
        mode: TransportMode.fromName(readNullableString(json['mode'])),
        stops: readObjectList(json['stops']).map(RouteStop.fromJson).toList(),
        speedKmh: readDouble(json['speedKmh'], TransportMode.taxi.cruiseKmh),
        x: readDouble(json['x']).clamp(0, 1),
        y: readDouble(json['y']).clamp(0, 1),
        progressMeters: readDouble(json['progressMeters']),
        status: TransportStatus.fromName(readNullableString(json['status'])),
        haltRemaining: Duration(seconds: readInt(json['haltSeconds'])),
        haltReason: readString(json['haltReason']),
        speedFactor: readDouble(json['speedFactor'], 1) <= 0 ? 1 : readDouble(json['speedFactor'], 1),
        lastIncidentId: readString(json['lastIncidentId']),
        passengers: readStringList(json['passengers']),
        passengerTokenIds: readStringList(json['passengerTokenIds']),
        log: readStringList(json['log']),
        note: readString(json['note']),
        createdAt: readString(json['createdAt']),
      );

  /// La riga che va nel registro quando parte.
  String get departureLine =>
      '$name (${mode.label}): $routeLine, ${speedKmh.round()} km/h'
      '${passengers.isEmpty ? '' : ' — a bordo ${passengers.join(', ')}'}';
}

/// Quanto e' lungo un percorso, in metri.
///
/// La distanza fra le fermate e' in linea d'aria, e [roadFactor] tiene conto
/// del fatto che nessuna strada e' dritta: e' un numero dichiarato e non
/// misurato, quindi si vede e si corregge come tutti gli altri. Senza quel
/// fattore un taxi arriverebbe sempre troppo presto, e nessuno saprebbe dire
/// perche'.
double routeLengthMeters(
  List<RouteStop> stops,
  double mapSpanMeters, {
  double roadFactor = GmRules.transportRoadFactorDefault,
}) {
  if (stops.length < 2) return 0;
  final double factor = roadFactor <= 0 ? 1 : roadFactor;
  double total = 0;
  for (int i = 0; i < stops.length - 1; i++) {
    total += (stops[i + 1].position - stops[i].position).distance * mapSpanMeters * factor;
  }
  return total;
}

/// Dove si trova il veicolo dopo [meters] di percorso.
Offset positionAlong(
  List<RouteStop> stops,
  double meters,
  double mapSpanMeters, {
  double roadFactor = GmRules.transportRoadFactorDefault,
}) {
  if (stops.isEmpty) return Offset.zero;
  if (stops.length == 1) return stops.first.position;
  final double factor = roadFactor <= 0 ? 1 : roadFactor;

  double travelled = 0;
  for (int i = 0; i < stops.length - 1; i++) {
    final Offset a = stops[i].position;
    final Offset b = stops[i + 1].position;
    final double leg = (b - a).distance * mapSpanMeters * factor;
    if (leg <= 0) continue;
    if (travelled + leg >= meters) {
      final double t = ((meters - travelled) / leg).clamp(0, 1).toDouble();
      return Offset(
        (a.dx + (b.dx - a.dx) * t).clamp(0, 1).toDouble(),
        (a.dy + (b.dy - a.dy) * t).clamp(0, 1).toDouble(),
      );
    }
    travelled += leg;
  }
  return stops.last.position;
}

/// La direzione di marcia, in radianti, per orientare il veicolo sulla mappa.
///
/// Senza, un veicolo e' un punto che si sposta: con, e' una cosa che *sta
/// andando* verso qualcosa, ed e' l'unico modo per capire a colpo d'occhio se
/// sta arrivando o scappando.
double headingAlong(
  List<RouteStop> stops,
  double meters,
  double mapSpanMeters, {
  double roadFactor = GmRules.transportRoadFactorDefault,
}) {
  if (stops.length < 2) return 0;
  final double factor = roadFactor <= 0 ? 1 : roadFactor;
  double travelled = 0;
  for (int i = 0; i < stops.length - 1; i++) {
    final Offset a = stops[i].position;
    final Offset b = stops[i + 1].position;
    final double leg = (b - a).distance * mapSpanMeters * factor;
    if (leg <= 0) continue;
    if (travelled + leg >= meters) return math.atan2(b.dy - a.dy, b.dx - a.dx);
    travelled += leg;
  }
  final Offset a = stops[stops.length - 2].position;
  final Offset b = stops.last.position;
  return math.atan2(b.dy - a.dy, b.dx - a.dx);
}
