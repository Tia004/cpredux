/// Waypoint, aspetto della mappa e sfondo importato.
///
/// Il modello e' piccolo di proposito. La mappa e' un **riferimento condiviso**,
/// non un motore di gioco: un waypoint ha un nome, una nota, una posizione e
/// una categoria, e nient'altro. Non ha regole, non ha iniziativa, non muove
/// nulla. Al tavolo serve per dire "siamo qui" e perche' tutti vedano la stessa
/// cosa mentre qualcuno lo dice a parole.
library;

import 'dart:ui' show Offset;

import 'json_support.dart';

/// I due aspetti della stessa geometria.
///
/// Non sono due mappe: sono due modi di disegnare gli stessi poligoni. Averne
/// due file significherebbe disallineare i waypoint ogni volta che se ne
/// corregge uno.
enum MapStyle {
  /// Colori spenti, terreno, ombre. Leggibile da lontano, sembra una mappa.
  realistic('Realistica', 'Realistica'),

  /// Griglia, neon, contorni luminosi. Sembra un feed di rete.
  digital('Digitale', 'Digitale');

  const MapStyle(this.label, this.description);

  final String label;
  final String description;

  static MapStyle fromName(String? value) {
    for (final MapStyle s in MapStyle.values) {
      if (s.name == value) return s;
    }
    return MapStyle.digital;
  }
}

/// Cosa c'e' nel waypoint. Cambia il colore e l'icona, e serve a distinguere a
/// colpo d'occhio un nascondiglio da un PNG da incontrare.
enum WaypointKind {
  location('Luogo', 'luogo'),
  danger('Pericolo', 'pericolo'),
  person('Persona', 'persona'),
  job('Lavoro', 'lavoro'),
  shop('Negozio', 'negozio'),
  note('Nota', 'nota');

  const WaypointKind(this.label, this.slug);

  final String label;
  final String slug;

  static WaypointKind fromName(String? value) {
    for (final WaypointKind k in WaypointKind.values) {
      if (k.name == value) return k;
    }
    return WaypointKind.location;
  }
}

/// Chi puo' vedere un waypoint.
///
/// La distinzione non e' cosmetica: e' l'unica ragione per cui un master puo'
/// usare questa sezione senza spoilerare la propria preparazione. Un waypoint
/// `private` **non viene mai trasmesso**, e il test lo verifica sul socket, non
/// solo nella logica.
enum WaypointVisibility {
  /// Solo il master. Non esce mai dal suo programma.
  private('Solo master', 'privato'),

  /// Tutti quelli al tavolo.
  table('Tutto il tavolo', 'tavolo');

  const WaypointVisibility(this.label, this.slug);

  final String label;
  final String slug;

  static WaypointVisibility fromName(String? value) {
    for (final WaypointVisibility v in WaypointVisibility.values) {
      if (v.name == value) return v;
    }
    return WaypointVisibility.table;
  }
}

/// Uno stato di avanzamento, non una proprieta' del dato.
///
/// Un waypoint messo da un giocatore e' una **proposta**: il master e'
/// l'autorita' del tavolo, quindi e' lui a decidere se entra nella mappa
/// condivisa. Fino a quel momento il giocatore lo vede solo lui, tratteggiato.
enum WaypointStatus {
  proposed('In attesa del master', 'proposta'),
  accepted('Condiviso', 'accettato');

  const WaypointStatus(this.label, this.slug);

  final String label;
  final String slug;

  static WaypointStatus fromName(String? value) {
    for (final WaypointStatus s in WaypointStatus.values) {
      if (s.name == value) return s;
    }
    return WaypointStatus.accepted;
  }
}

/// Un segno sulla mappa.
class MapWaypoint {
  MapWaypoint({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.note = '',
    this.kind = WaypointKind.location,
    this.visibility = WaypointVisibility.table,
    this.status = WaypointStatus.accepted,
    this.authorId = '',
    this.authorName = '',
    this.createdAt = '',
  });

  final String id;
  String label;

  /// Posizione in coordinate normalizzate 0..1: lo stesso spazio della
  /// geometria e degli angoli di georeferenziazione di un'immagine importata.
  double x;
  double y;

  String note;
  WaypointKind kind;
  WaypointVisibility visibility;
  WaypointStatus status;
  final String authorId;
  String authorName;
  final String createdAt;

  Offset get position => Offset(x, y);

  set position(Offset value) {
    x = value.dx;
    y = value.dy;
  }

  /// True se questo waypoint puo' essere mandato agli altri.
  ///
  /// Una proposta di un giocatore e' gia' visibile a chi l'ha messa: se la
  /// rimandassimo indietro, il client la vedrebbe come "condivisa" prima che il
  /// master abbia deciso.
  bool get isShareable => visibility == WaypointVisibility.table;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'note': note,
        'x': x,
        'y': y,
        'kind': kind.name,
        'visibility': visibility.name,
        'status': status.name,
        'authorId': authorId,
        'authorName': authorName,
        'createdAt': createdAt,
      };

  static MapWaypoint fromJson(Map<String, Object?> json) => MapWaypoint(
        id: readString(json['id']),
        label: readString(json['label']),
        note: readString(json['note']),
        x: readDouble(json['x']).clamp(0, 1).toDouble(),
        y: readDouble(json['y']).clamp(0, 1).toDouble(),
        kind: WaypointKind.fromName(readString(json['kind'])),
        visibility: WaypointVisibility.fromName(readString(json['visibility'])),
        status: WaypointStatus.fromName(readString(json['status'])),
        authorId: readString(json['authorId']),
        authorName: readString(json['authorName']),
        createdAt: readString(json['createdAt']),
      );

  MapWaypoint copyWith({
    String? label,
    String? note,
    double? x,
    double? y,
    WaypointKind? kind,
    WaypointVisibility? visibility,
    WaypointStatus? status,
    String? authorName,
  }) =>
      MapWaypoint(
        id: id,
        label: label ?? this.label,
        note: note ?? this.note,
        x: x ?? this.x,
        y: y ?? this.y,
        kind: kind ?? this.kind,
        visibility: visibility ?? this.visibility,
        status: status ?? this.status,
        authorId: authorId,
        authorName: authorName ?? this.authorName,
        createdAt: createdAt,
      );
}

/// Lo sfondo della mappa.
///
/// Due possibilita': la geometria spedita con l'app, oppure un'immagine scelta
/// dall'utente, posizionata con quattro angoli. La seconda esiste per una
/// ragione precisa: chi possiede una mappa — comprata, scansionata o disegnata
/// da lui — deve poterla usare **senza** che il programma la spedisca. Il
/// programma non contiene ne' distribuisce nessuna mappa di Night City.
class MapBackground {
  MapBackground({
    this.imagePath = '',
    List<Offset>? corners,
    this.opacity = 1,
  }) : corners = corners ?? defaultCorners;

  /// Percorso dell'immagine importata. Vuoto significa "usa la geometria".
  String imagePath;

  /// I quattro angoli dell'immagine nello spazio 0..1 della mappa:
  /// alto-sinistra, alto-destra, basso-destra, basso-sinistra. In quest'ordine
  /// perche' e' l'ordine in cui l'utente li clicca seguendo il perimetro.
  List<Offset> corners;

  double opacity;

  static List<Offset> get defaultCorners => <Offset>[
        const Offset(0, 0),
        const Offset(1, 0),
        const Offset(1, 1),
        const Offset(0, 1),
      ];

  bool get hasImage => imagePath.trim().isNotEmpty;

  MapBackground copy() => MapBackground(
        imagePath: imagePath,
        corners: List<Offset>.of(corners),
        opacity: opacity,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'imagePath': imagePath,
        'opacity': opacity,
        'corners': <Object?>[
          for (final Offset c in corners) <String, Object?>{'x': c.dx, 'y': c.dy},
        ],
      };

  static MapBackground fromJson(Map<String, Object?> json) {
    final List<Map<String, Object?>> raw = readObjectList(json['corners']);
    final List<Offset> parsed = <Offset>[
      for (final Map<String, Object?> c in raw)
        Offset(readDouble(c['x']).clamp(0, 1).toDouble(), readDouble(c['y']).clamp(0, 1).toDouble()),
    ];
    return MapBackground(
      imagePath: readString(json['imagePath']),
      // Un elenco di angoli incompleto (file modificato a mano, versione
      // precedente) non deve lasciare la mappa senza riferimento: si completa
      // con il rettangolo pieno, che e' cio' che si intende nel 99% dei casi.
      corners: parsed.length == 4 ? parsed : defaultCorners,
      opacity: readDouble(json['opacity'], 1).clamp(0, 1).toDouble(),
    );
  }
}

/// Genera un identificativo per un waypoint.
///
/// Con il tempo in microsecondi e un contatore: due waypoint messi nello stesso
/// microsecondo da due giocatori diversi non devono sovrascriversi a vicenda
/// quando arrivano al master.
String newWaypointId([int? counter]) {
  final int now = DateTime.now().microsecondsSinceEpoch;
  return counter == null ? 'wp-$now' : 'wp-$now-$counter';
}
