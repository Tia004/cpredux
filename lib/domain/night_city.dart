/// La geometria di Night City, disegnata a mano.
///
/// Perche' disegnata e non scaricata: la mappa ufficiale di Night City e' un
/// asset di R. Talsorian Games / CD Projekt RED. La policy sul materiale dei
/// fan permette di creare contenuti propri e di citarne i nomi, non di
/// ridistribuire la loro grafica. Qui non c'e' nessun pixel di quella mappa:
/// ci sono poligoni disegnati in questo file, con i nomi dei distretti usati
/// come riferimenti — esattamente cio' che la policy consente.
///
/// Conseguenza pratica, ed e' il motivo per cui vale la pena: essendo
/// *geometria* e non immagine, la stessa mappa si disegna in due aspetti
/// (realistico e digitale) senza mantenere due file in parallelo, si adatta a
/// qualunque dimensione di finestra senza sfocare, e i waypoint hanno
/// coordinate vere invece di pixel.
///
/// Sistema di coordinate: **0..1 su entrambi gli assi**, con l'origine in alto
/// a sinistra. Non sono metri ne' pixel: e' una griglia normalizzata, cosi' la
/// mappa resta corretta a qualunque dimensione. Chi importa una propria mappa
/// la georeferenzia con quattro angoli in questo stesso spazio, quindi
/// waypoint e immagine condividono un unico sistema di riferimento.
library;

import 'dart:ui' show Color, Offset;

/// Un distretto: un poligono con un nome e un colore.
///
/// Il colore e' l'accento *digitale*. Nell'aspetto realistico non si usa cosi'
/// com'e': viene desaturato e mescolato al terreno, perche' il realismo non
/// ammette sette tinte accese in una schermata sola.
class MapDistrict {
  const MapDistrict({
    required this.id,
    required this.name,
    required this.accent,
    required this.border,
  });

  final String id;
  final String name;
  final Color accent;

  /// I vertici del poligono, in senso orario.
  final List<Offset> border;
}

/// Un'etichetta: il nome di un quartiere, o il nome di un distretto.
class MapLabel {
  const MapLabel(this.name, this.position, {this.scale = 1});

  final String name;
  final Offset position;

  /// 1 = etichetta di distretto, piu' grande. 0.8 = quartiere, piu' piccola e
  /// visibile solo quando si ingrandisce abbastanza da non affollare.
  final double scale;
}

/// Una strada principale. Servono a rendere la mappa leggibile come *luogo* e
/// non come mosaico: senza assi di scorrimento un insieme di poligoni colorati
/// non suggerisce nessuna direzione.
class MapRoad {
  const MapRoad(this.name, this.points);

  final String name;
  final List<Offset> points;
}

abstract final class NightCity {
  /// Il bordo della terraferma. Tutto cio' che sta fuori e' la baia.
  ///
  /// La citta' e' su una penisola: l'acqua occupa il lato ovest, le Badlands
  /// circondano il resto. Prima si disegna l'acqua, poi la terra sopra.
  static const List<Offset> land = <Offset>[
    Offset(0.86, 0.00),
    Offset(1.00, 0.00),
    Offset(1.00, 1.00),
    Offset(0.62, 1.00),
    Offset(0.52, 0.965),
    Offset(0.40, 1.00),
    Offset(0.22, 1.00),
    Offset(0.195, 0.90),
    Offset(0.235, 0.80),
    Offset(0.198, 0.68),
    Offset(0.238, 0.56),
    Offset(0.200, 0.44),
    Offset(0.162, 0.32),
    Offset(0.202, 0.20),
    Offset(0.164, 0.08),
    Offset(0.205, 0.00),
  ];

  /// I distretti, nell'ordine in cui vengono disegnati.
  ///
  /// Ordine e posizioni seguono la disposizione reale: Watson a nord, Westbrook
  /// a est, City Center al centro, Heywood a sud del centro, Santo Domingo a
  /// sud-est, Pacifica a sud-ovest, North Oak a nord-est. La terraferma sotto
  /// funge da Badlands, quindi non serve un poligono per esse: il deserto e'
  /// semplicemente cio' che resta.
  static const List<MapDistrict> districts = <MapDistrict>[
    MapDistrict(
      id: 'watson',
      name: 'WATSON',
      accent: Color(0xFF22E6D2),
      border: <Offset>[
        Offset(0.320, 0.062),
        Offset(0.600, 0.050),
        Offset(0.702, 0.104),
        Offset(0.700, 0.258),
        Offset(0.580, 0.312),
        Offset(0.400, 0.300),
        Offset(0.298, 0.222),
        Offset(0.282, 0.120),
      ],
    ),
    MapDistrict(
      id: 'north-oak',
      name: 'NORTH OAK',
      accent: Color(0xFF7FD1A0),
      border: <Offset>[
        Offset(0.722, 0.058),
        Offset(0.920, 0.048),
        Offset(0.952, 0.160),
        Offset(0.742, 0.170),
      ],
    ),
    MapDistrict(
      id: 'westbrook',
      name: 'WESTBROOK',
      accent: Color(0xFF8B5CF6),
      border: <Offset>[
        Offset(0.742, 0.170),
        Offset(0.952, 0.160),
        Offset(0.962, 0.340),
        Offset(0.860, 0.382),
        Offset(0.742, 0.360),
        Offset(0.702, 0.262),
      ],
    ),
    MapDistrict(
      id: 'city-center',
      name: 'CITY CENTER',
      accent: Color(0xFFFCEE0A),
      border: <Offset>[
        Offset(0.462, 0.330),
        Offset(0.620, 0.322),
        Offset(0.742, 0.360),
        Offset(0.740, 0.500),
        Offset(0.620, 0.540),
        Offset(0.482, 0.528),
        Offset(0.420, 0.440),
      ],
    ),
    MapDistrict(
      id: 'santo-domingo',
      name: 'SANTO DOMINGO',
      accent: Color(0xFFFFA62B),
      border: <Offset>[
        Offset(0.860, 0.382),
        Offset(0.962, 0.340),
        Offset(0.984, 0.720),
        Offset(0.840, 0.782),
        Offset(0.720, 0.740),
        Offset(0.702, 0.560),
        Offset(0.740, 0.440),
      ],
    ),
    MapDistrict(
      id: 'heywood',
      name: 'HEYWOOD',
      accent: Color(0xFF4DA3FF),
      border: <Offset>[
        Offset(0.482, 0.528),
        Offset(0.620, 0.540),
        Offset(0.722, 0.560),
        Offset(0.722, 0.722),
        Offset(0.580, 0.780),
        Offset(0.442, 0.740),
        Offset(0.400, 0.640),
      ],
    ),
    MapDistrict(
      id: 'pacifica',
      name: 'PACIFICA',
      accent: Color(0xFFFF2E88),
      border: <Offset>[
        Offset(0.262, 0.580),
        Offset(0.400, 0.640),
        Offset(0.442, 0.740),
        Offset(0.400, 0.862),
        Offset(0.300, 0.922),
        Offset(0.240, 0.840),
        Offset(0.222, 0.700),
      ],
    ),
  ];

  /// Le strade principali. Non hanno funzione di gioco: servono a leggere la
  /// mappa, e il master che dice "siete sull'autostrada a nord di Kabuki" ha
  /// bisogno che quella strada esista sullo schermo.
  static const List<MapRoad> roads = <MapRoad>[
    MapRoad('N54 ovest', <Offset>[
      Offset(0.268, 0.116),
      Offset(0.330, 0.318),
      Offset(0.452, 0.500),
      Offset(0.462, 0.716),
      Offset(0.360, 0.900),
    ]),
    MapRoad('N54 est', <Offset>[
      Offset(0.716, 0.108),
      Offset(0.756, 0.360),
      Offset(0.800, 0.600),
      Offset(0.844, 0.898),
    ]),
    MapRoad('transito', <Offset>[
      Offset(0.330, 0.318),
      Offset(0.600, 0.340),
      Offset(0.756, 0.360),
      Offset(0.860, 0.450),
    ]),
    MapRoad('cintura sud', <Offset>[
      Offset(0.462, 0.716),
      Offset(0.620, 0.762),
      Offset(0.844, 0.898),
    ]),
  ];

  /// Le etichette dei quartieri. Sono i nomi che si usano davvero al tavolo
  /// ("ci vediamo a Kabuki"), quindi valgono quanto i distretti.
  static const List<MapLabel> places = <MapLabel>[
    MapLabel('Northside', Offset(0.372, 0.146), scale: 0.8),
    MapLabel('Kabuki', Offset(0.446, 0.242), scale: 0.8),
    MapLabel('Little China', Offset(0.556, 0.132), scale: 0.8),
    MapLabel('Arasaka Waterfront', Offset(0.616, 0.088), scale: 0.72),
    MapLabel('Japantown', Offset(0.812, 0.226), scale: 0.8),
    MapLabel('Charter Hill', Offset(0.844, 0.302), scale: 0.8),
    MapLabel('Corpo Plaza', Offset(0.582, 0.406), scale: 0.8),
    MapLabel('Downtown', Offset(0.678, 0.466), scale: 0.8),
    MapLabel('The Glen', Offset(0.522, 0.616), scale: 0.8),
    MapLabel('Vista del Rey', Offset(0.628, 0.642), scale: 0.78),
    MapLabel('Wellsprings', Offset(0.492, 0.702), scale: 0.8),
    MapLabel('Arroyo', Offset(0.848, 0.582), scale: 0.8),
    MapLabel('Rancho Coronado', Offset(0.822, 0.462), scale: 0.78),
    MapLabel('Coastview', Offset(0.318, 0.862), scale: 0.78),
    MapLabel('West Wind Estate', Offset(0.348, 0.686), scale: 0.76),
  ];

  /// Etichette che non appartengono a un distretto.
  static const List<MapLabel> margins = <MapLabel>[
    MapLabel('BAIA DI NIGHT CITY', Offset(0.104, 0.400), scale: 0.86),
    MapLabel('BADLANDS', Offset(0.862, 0.876), scale: 0.94),
  ];

  /// Controlla che la geometria sia sensata.
  ///
  /// Esiste per lo stesso motivo per cui esiste `ItemCatalog.validate()`: una
  /// coordinata fuori scala non fa fallire niente — disegna semplicemente un
  /// distretto fuori dallo schermo, e ce se ne accorge solo guardando. Un test
  /// la blocca subito.
  static List<String> validate() {
    final List<String> problems = <String>[];
    final Set<String> ids = <String>{};

    if (land.length < 3) problems.add('Il bordo della terraferma ha meno di tre vertici.');
    for (final Offset p in land) {
      if (!_inUnitSquare(p)) problems.add('Terraferma: punto fuori scala $p.');
    }

    for (final MapDistrict d in districts) {
      if (!ids.add(d.id)) problems.add('Distretto duplicato: ${d.id}.');
      if (d.border.length < 3) problems.add('Distretto ${d.id}: meno di tre vertici.');
      for (final Offset p in d.border) {
        if (!_inUnitSquare(p)) problems.add('Distretto ${d.id}: punto fuori scala $p.');
      }
      if (d.name.trim().isEmpty) problems.add('Distretto ${d.id}: senza nome.');
    }

    for (final MapRoad r in roads) {
      if (r.points.length < 2) problems.add('Strada ${r.name}: meno di due punti.');
      for (final Offset p in r.points) {
        if (!_inUnitSquare(p)) problems.add('Strada ${r.name}: punto fuori scala $p.');
      }
    }

    for (final MapLabel l in <MapLabel>[...places, ...margins]) {
      if (!_inUnitSquare(l.position)) problems.add('Etichetta ${l.name}: punto fuori scala ${l.position}.');
      if (l.scale <= 0) problems.add('Etichetta ${l.name}: scala non valida.');
    }

    return problems;
  }

  static bool _inUnitSquare(Offset p) =>
      p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1;

  /// Il centro di un distretto, calcolato come media dei vertici. E' dove va
  /// l'etichetta: usare il centroide vero su poligoni irregolari la sposta in
  /// modo poco prevedibile fuori dal distretto.
  static Offset labelPosition(MapDistrict district) {
    double x = 0;
    double y = 0;
    for (final Offset p in district.border) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / district.border.length, y / district.border.length);
  }
}
