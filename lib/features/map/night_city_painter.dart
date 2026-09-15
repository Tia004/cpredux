import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/map_token.dart';
import '../../domain/gm/gm_rules.dart';
import '../../domain/night_city.dart';
import '../../domain/transport.dart';
import '../../domain/world_map.dart';
import 'map_geometry.dart';

/// Colori di un aspetto della mappa.
///
/// Sono un insieme e non costanti sparse per il codice: cambiare aspetto
/// significa cambiare **questo** oggetto, e non esiste il caso in cui un
/// elemento resta del colore dell'altro aspetto perche' ce se n'e' dimenticato
/// uno.
typedef _MapColors = ({
  Color base,
  Color water,
  Color waterEdge,
  Color land,
  Color landEdge,
  Color grid,
  Color road,
  Color label,
  Color subLabel,
  Color subDot,
  bool glow,
});

/// Disegna la mappa di Night City.
///
/// Una sola geometria, due aspetti. Non e' un vezzo: significa che un waypoint
/// sta nello stesso posto in entrambi, che correggere un confine lo corregge
/// per tutti e due, e che non esiste il caso "sulla mappa realistica il
/// quartiere si chiama diverso".
///
/// Tutte le misure sono divise per [scale]. Il painter disegna dentro il figlio
/// di un `InteractiveViewer`, quindi le sue coordinate vengono ingrandite:
/// senza quella divisione, ingrandire gonfierebbe anche i nomi dei quartieri e
/// i waypoint, mentre la mappa deve solo mostrare piu' dettaglio.
class NightCityPainter extends CustomPainter {
  NightCityPainter({
    required this.style,
    required this.image,
    required this.corners,
    required this.imageOpacity,
    required this.waypoints,
    required this.hoveredId,
    required this.selectedId,
    required this.draft,
    required this.scale,
    required this.showLabels,
    required this.asGameMaster,
    required this.pulse,
    this.tokens = const <MapToken>[],
    this.selectedTokenId,
    this.transports = const <Transport>[],
    this.selectedTransportId,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final MapStyle style;

  /// Immagine importata dall'utente. Se presente **sostituisce** la geometria:
  /// chi importa la propria mappa vuole vedere quella, non i nostri poligoni
  /// disegnati sopra.
  final ui.Image? image;
  final List<Offset> corners;
  final double imageOpacity;

  final List<MapWaypoint> waypoints;
  final String? hoveredId;
  final String? selectedId;

  /// Chi c'e' sulla mappa.
  ///
  /// Opzionale con valore vuoto: la mappa si disegna anche senza token, e chi
  /// costruisce il pittore non deve conoscerli per forza.
  final List<MapToken> tokens;
  final String? selectedTokenId;

  /// I veicoli in strada, con il loro percorso.
  ///
  /// Separati dai token perche' non sono la stessa cosa: un token sta in un
  /// posto, un veicolo **sta andando** da qualche parte. Il percorso si disegna
  /// sotto tutto il resto — e' contesto, non un oggetto sulla mappa.
  final List<Transport> transports;
  final String? selectedTransportId;

  /// Posizione in attesa di conferma, in coordinate mappa.
  final Offset? draft;

  /// Fattore di ingrandimento corrente: serve a tenere costante la dimensione
  /// *percepita* di testi, simboli e spessori.
  final double scale;

  final bool showLabels;
  final bool asGameMaster;

  /// Animazione 0..1 usata per il battito dei waypoint condivisi e per la banda
  /// che scorre sulla mappa digitale.
  final Animation<double> pulse;

  double get _pulse => pulse.value;

  /// Il master vede anche le posizioni private, ma la distinzione si vede: e'
  /// l'unico modo per non confondere la propria preparazione con lo stato del
  /// tavolo.
  bool get _isGameMaster => asGameMaster;

  _MapColors _colors() {
    if (style == MapStyle.digital) {
      return (
        base: const Color(0xFF060809),
        water: const Color(0xFF08181C),
        waterEdge: CprPalette.veil(CprPalette.cyan, 0.30),
        land: const Color(0xFF0E1116),
        landEdge: CprPalette.hairline,
        grid: CprPalette.veil(CprPalette.cyan, 0.05),
        road: CprPalette.veil(CprPalette.yellow, 0.22),
        label: CprPalette.ink,
        subLabel: CprPalette.inkMuted,
        subDot: CprPalette.inkFaint,
        glow: true,
      );
    }
    return (
      base: const Color(0xFF0B0F10),
      water: const Color(0xFF0C1A1D),
      waterEdge: const Color(0xFF23383C),
      land: const Color(0xFF1C1B16),
      landEdge: const Color(0xFF3A382E),
      grid: const Color(0x00000000),
      road: const Color(0xFF4E4A3C),
      label: const Color(0xFFCFD3C6),
      subLabel: const Color(0xFF8E9187),
      subDot: const Color(0xFF6A6D63),
      glow: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = mapRectIn(size);
    final _MapColors c = _colors();

    canvas.save();
    canvas.clipRect(rect);

    canvas.drawRect(rect, Paint()..color = c.base);

    if (image != null) {
      _paintImportedImage(canvas, rect);
      _paintMarginLabels(canvas, rect, c);
      _paintDistrictLabels(canvas, rect, c);
    } else {
      _paintWater(canvas, rect, c);
      if (style == MapStyle.digital) _paintGrid(canvas, rect, c.grid);
      _paintLand(canvas, rect, c);
      _paintDistricts(canvas, rect, c);
      _paintRoads(canvas, rect, c.road);
      if (showLabels) _paintPlaceLabels(canvas, rect, c);
      _paintMarginLabels(canvas, rect, c);
      _paintDistrictLabels(canvas, rect, c);
    }

    if (style == MapStyle.digital) _paintScanline(canvas, rect);
    _paintVignette(canvas, rect);

    // Il percorso sotto tutto: e' contesto, e non deve coprire i luoghi.
    _paintTransportRoutes(canvas, rect);
    _paintWaypoints(canvas, rect);
    // I token sopra i waypoint: un segnaposto che indica un luogo e' sfondo, la
    // persona che ci sta dentro e' quello che si guarda.
    _paintTokens(canvas, rect);
    // I veicoli sopra i token: chi e' a bordo viaggia con loro, e il veicolo e'
    // la cosa che si muove, quindi e' quella che si guarda.
    _paintTransports(canvas, rect);
    if (draft != null) _paintDraft(canvas, rect, draft!);

    canvas.restore();

    // La cornice e' l'unica cosa fuori dal ritaglio, e dice dove finisce la
    // mappa quando lo sfondo e' scuro come la finestra.
    canvas.drawRect(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = CprPalette.hairline,
    );
  }

  // --- Sfondo --------------------------------------------------------------

  void _paintWater(Canvas canvas, Rect rect, _MapColors c) {
    final Path sea = Path()..addRect(rect);
    final Path land = _closedPath(NightCity.land, rect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, sea, land),
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.centerRight,
          <Color>[c.water, Color.lerp(c.water, CprPalette.voidBlack, 0.45)!],
        ),
    );
    canvas.drawPath(
      land,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / scale
        ..color = c.waterEdge,
    );
  }

  void _paintLand(Canvas canvas, Rect rect, _MapColors c) {
    final Path path = _closedPath(NightCity.land, rect);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topLeft,
          rect.bottomRight,
          <Color>[c.land, Color.lerp(c.land, CprPalette.voidBlack, 0.40)!],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 / scale
        ..color = c.landEdge,
    );
  }

  void _paintGrid(Canvas canvas, Rect rect, Color color) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1 / scale;
    const int divisions = 16;
    for (int i = 1; i < divisions; i++) {
      final double t = i / divisions;
      canvas.drawLine(
        Offset(rect.left + rect.width * t, rect.top),
        Offset(rect.left + rect.width * t, rect.bottom),
        paint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + rect.height * t),
        Offset(rect.right, rect.top + rect.height * t),
        paint,
      );
    }
  }

  void _paintDistricts(Canvas canvas, Rect rect, _MapColors c) {
    canvas.save();
    canvas.clipPath(_closedPath(NightCity.land, rect));

    for (final MapDistrict district in NightCity.districts) {
      final Path path = _closedPath(district.border, rect);

      // L'accento viene mescolato al terreno, non usato puro: sette tinte
      // sature su una schermata sola non sono una mappa, sono una legenda
      // illeggibile.
      canvas.drawPath(
        path,
        Paint()
          ..color = style == MapStyle.digital
              ? CprPalette.veil(district.accent, 0.09)
              : Color.lerp(c.land, _desaturate(district.accent), 0.16)!,
      );

      if (c.glow) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 / scale
            ..color = CprPalette.veil(district.accent, 0.28)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 4 / scale),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (style == MapStyle.digital ? 1.3 : 1.0) / scale
          ..color = style == MapStyle.digital
              ? CprPalette.veil(district.accent, 0.60)
              : Color.lerp(c.landEdge, _desaturate(district.accent), 0.30)!,
      );
    }

    canvas.restore();
  }

  void _paintRoads(Canvas canvas, Rect rect, Color color) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (style == MapStyle.digital ? 1.1 : 1.5) / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    for (final MapRoad road in NightCity.roads) {
      final Path path = _openPath(road.points, rect);
      if (style == MapStyle.digital) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 / scale
            ..strokeCap = StrokeCap.round
            ..color = CprPalette.veil(CprPalette.yellow, 0.10)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 / scale),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintDistrictLabels(Canvas canvas, Rect rect, _MapColors c) {
    for (final MapDistrict district in NightCity.districts) {
      _text(
        canvas,
        district.name,
        mapToLocal(NightCity.labelPosition(district), rect),
        CprType.label.copyWith(
          fontSize: 9.5 / scale,
          letterSpacing: 1.4 / scale,
          color: style == MapStyle.digital ? CprPalette.veil(district.accent, 0.95) : c.label,
        ),
        glow: c.glow ? district.accent : null,
      );
    }
  }

  void _paintPlaceLabels(Canvas canvas, Rect rect, _MapColors c) {
    // I quartieri compaiono solo ingrandendo abbastanza: a scala 1 sono
    // quindici etichette in pochi centimetri, cioe' rumore.
    if (scale < 1.55) return;

    final double alpha = ((scale - 1.55) / 1.4).clamp(0, 1).toDouble();
    for (final MapLabel place in NightCity.places) {
      final Offset at = mapToLocal(place.position, rect);
      canvas.drawCircle(at, 1.8 / scale, Paint()..color = CprPalette.veil(c.subDot, alpha));
      _text(
        canvas,
        place.name,
        at + Offset(0, -7.5 / scale),
        CprType.caption.copyWith(
          fontSize: 8 / scale,
          letterSpacing: 0.2 / scale,
          color: CprPalette.veil(c.subLabel, alpha),
        ),
      );
    }
  }

  void _paintMarginLabels(Canvas canvas, Rect rect, _MapColors c) {
    for (final MapLabel label in NightCity.margins) {
      _text(
        canvas,
        label.name,
        mapToLocal(label.position, rect),
        CprType.label.copyWith(
          fontSize: 9 * label.scale / scale,
          letterSpacing: 3 / scale,
          color: label.name.startsWith('BAIA')
              ? CprPalette.veil(c.waterEdge, 0.9)
              : CprPalette.veil(c.subDot, 0.7),
        ),
      );
    }
  }

  // --- Immagine importata --------------------------------------------------

  /// Disegna l'immagine dell'utente mappandola sui quattro angoli.
  ///
  /// Si usano due triangoli invece di una trasformazione prospettica vera,
  /// perche' `Canvas` non ne offre una per i bitmap. Con angoli quasi
  /// rettangolari — cioe' sempre, quando si cliccano i quattro angoli di una
  /// mappa scannerizzata — la differenza non si vede. Con una prospettiva forte
  /// resterebbe una piega lungo la diagonale: e' un limite dichiarato, e
  /// preferiamo un limite noto a una trasformazione che sembra corretta e
  /// posiziona i waypoint nel posto sbagliato.
  void _paintImportedImage(Canvas canvas, Rect rect) {
    final ui.Image? img = image;
    if (img == null) return;

    final Rect src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final Paint p = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    // Se i corner sono i 4 di default o non validi, disegna direttamente sull'area della mappa
    final bool isDefaultRect = corners.length != 4 ||
        (corners[0] == const Offset(0, 0) &&
            corners[1] == const Offset(1, 0) &&
            corners[2] == const Offset(1, 1) &&
            corners[3] == const Offset(0, 1));

    final Rect targetRect;
    if (isDefaultRect) {
      targetRect = rect;
    } else {
      final List<Offset> pts = <Offset>[for (final Offset c in corners) mapToLocal(c, rect)];
      final double left = math.min(pts[0].dx, pts[3].dx);
      final double right = math.max(pts[1].dx, pts[2].dx);
      final double top = math.min(pts[0].dy, pts[1].dy);
      final double bottom = math.max(pts[2].dy, pts[3].dy);
      targetRect = Rect.fromLTRB(left, top, right, bottom);
    }

    if (imageOpacity < 1) {
      canvas.saveLayer(
        targetRect,
        Paint()..color = Color.fromRGBO(255, 255, 255, imageOpacity.clamp(0.0, 1.0)),
      );
      canvas.drawImageRect(img, src, targetRect, p);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, targetRect, p);
    }
  }

  // --- Effetti -------------------------------------------------------------

  /// Una banda luminosa che scorre verticalmente.
  ///
  /// Non e' decorazione: su una mappa ferma un movimento periodico dice
  /// "questo e' uno schermo vivo". E' lento apposta, perche' non deve attirare
  /// l'occhio mentre il master parla.
  void _paintScanline(Canvas canvas, Rect rect) {
    final double t = _pulse;
    final double y = rect.top + rect.height * t;
    final double band = rect.height * 0.10;

    canvas.drawRect(
      rect,
      Paint()
        // Con tre colori le posizioni non si possono omettere: `Gradient`
        // accetta solo due colori senza, e il disegno fallisce a ogni pittura.
        ..shader = ui.Gradient.linear(
          Offset(rect.left, y - band),
          Offset(rect.left, y + band),
          <Color>[
            const Color(0x00000000),
            CprPalette.veil(CprPalette.cyan, 0.05),
            const Color(0x00000000),
          ],
          <double>[0, 0.5, 1],
        ),
    );
  }

  void _paintVignette(Canvas canvas, Rect rect) {
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          rect.center,
          rect.width * 0.75,
          <Color>[const Color(0x00000000), CprPalette.veil(CprPalette.voidBlack, 0.50)],
          <double>[0.55, 1],
        ),
    );
  }

  // --- Waypoint ------------------------------------------------------------

  void _paintWaypoints(Canvas canvas, Rect rect) {
    // Due passaggi: prima tutti gli anelli, poi le etichette. In un passaggio
    // solo, l'etichetta di un waypoint finirebbe sotto l'anello del successivo.
    for (final MapWaypoint w in waypoints) {
      _paintWaypointRing(canvas, rect, w);
    }
    for (final MapWaypoint w in waypoints) {
      if (w.id == selectedId || w.id == hoveredId) _paintWaypointCard(canvas, rect, w);
    }
  }

  void _paintWaypointRing(Canvas canvas, Rect rect, MapWaypoint w) {
    final Offset at = mapToLocal(w.position, rect);
    final Color color = waypointColor(w);
    final bool selected = w.id == selectedId;
    final bool hovered = w.id == hoveredId;
    final bool pending = w.status == WaypointStatus.proposed;
    final bool hidden = w.visibility == WaypointVisibility.private;

    final double base = (selected ? 7.5 : hovered ? 6.5 : 5.5) / scale;

    // Il battito c'e' solo per le posizioni che il tavolo vede davvero: un
    // anello che pulsa significa "questo esiste per tutti", e una posizione
    // privata o in attesa non e' ancora vera per nessuno.
    if (!pending && !hidden) {
      final double t = _pulse;
      canvas.drawCircle(
        at,
        base + (t * 9) / scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 / scale
          ..color = CprPalette.veil(color, (1 - t) * 0.5),
      );
    }

    if (style == MapStyle.digital && !pending) {
      canvas.drawCircle(
        at,
        base,
        Paint()
          ..color = CprPalette.veil(color, 0.20)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 5 / scale),
      );
    }

    canvas.drawCircle(
      at,
      base,
      Paint()
        ..style = PaintingStyle.fill
        ..color = CprPalette.veil(CprPalette.voidBlack, 0.85),
    );
    canvas.drawCircle(
      at,
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (selected ? 2 : 1.4) / scale
        ..color = pending ? CprPalette.veil(color, 0.6) : color,
    );

    // Al centro un rombo per le posizioni del master, un cerchio pieno per le
    // altre: a questa dimensione un'icona non si legge, e la distinzione che
    // conta al tavolo e' proprio "l'ha messa il master" o no.
    final Paint mark = Paint()..color = CprPalette.veil(color, 0.95);
    if (w.authorId == 'master' || (hidden && _isGameMaster)) {
      final double r = base * 0.5;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - r)
          ..lineTo(at.dx + r, at.dy)
          ..lineTo(at.dx, at.dy + r)
          ..lineTo(at.dx - r, at.dy)
          ..close(),
        mark,
      );
    } else {
      canvas.drawCircle(at, base * 0.38, mark);
    }

    if (hidden || pending) {
      _icon(
        canvas,
        hidden ? Icons.lock_outline : Icons.hourglass_top,
        at + Offset(base * 1.05, -base * 1.05),
        math.max(6 / scale, base * 1.6),
        hidden ? CprPalette.inkMuted : CprPalette.warning,
      );
    }
  }

  void _paintWaypointCard(Canvas canvas, Rect rect, MapWaypoint w) {
    final Offset at = mapToLocal(w.position, rect);
    final Color color = waypointColor(w);

    final TextPainter title = _textPainter(
      w.label.trim().isEmpty ? 'Senza nome' : w.label,
      CprType.body.copyWith(fontSize: 9.5 / scale, fontWeight: FontWeight.w600, color: CprPalette.ink),
    );
    final String subtitle = w.status == WaypointStatus.proposed
        ? 'In attesa del master'
        : '${w.kind.label}${w.visibility == WaypointVisibility.private ? ' · solo master' : ''}';
    final TextPainter sub = _textPainter(
      subtitle,
      CprType.caption.copyWith(fontSize: 8 / scale, color: CprPalette.inkMuted),
    );

    final double pad = 7 / scale;
    final double width = math.max(title.width, sub.width) + pad * 2 + 2 / scale;
    final double height = title.height + sub.height + pad * 2 + 2 / scale;

    // L'etichetta sta **sotto** il segno: sopra coprirebbe proprio il punto che
    // sta indicando.
    final Rect box = Rect.fromLTWH(at.dx - width / 2, at.dy + 12 / scale, width, height);

    canvas.drawRect(
      box,
      Paint()
        ..color = CprPalette.veil(CprPalette.voidBlack, 0.70)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 / scale),
    );
    canvas.drawRect(box, Paint()..color = CprPalette.veil(CprPalette.surface, 0.96));
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top, 2 / scale, box.height),
      Paint()..color = color,
    );
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = CprPalette.veil(color, 0.5),
    );

    title.paint(canvas, box.topLeft + Offset(pad + 2 / scale, pad));
    sub.paint(canvas, box.topLeft + Offset(pad + 2 / scale, pad + title.height + 2 / scale));
  }

  void _paintTokens(Canvas canvas, Rect rect) {
    for (final MapToken t in tokens) {
      _paintToken(canvas, rect, t);
    }
    // Le etichette in un secondo giro, perche' un token disegnato dopo non deve
    // coprire l'etichetta di quello accanto.
    for (final MapToken t in tokens) {
      if (t.id == selectedTokenId) _paintTokenCard(canvas, rect, t);
    }
  }

  /// Un token: colore del tipo, e un anello che dice quanti Punti Vita restano.
  ///
  /// L'anello e' un arco e non un cerchio pieno di colore: a questa dimensione
  /// un disco verde e uno rosso si distinguono, ma "quanto manca" si legge solo
  /// da quanto arco resta. E' la stessa informazione del cuore sulla scheda,
  /// letta dalla stessa distanza.
  void _paintToken(Canvas canvas, Rect rect, MapToken token) {
    final Offset at = mapToLocal(token.position, rect);
    final Color color = tokenColor(token.kind);
    final bool selected = token.id == selectedTokenId;
    final double base = (selected ? 11 : 8.5) / scale;

    if (style == MapStyle.digital) {
      canvas.drawCircle(
        at,
        base * 1.6,
        Paint()
          ..color = CprPalette.veil(color, 0.18)
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 5 / scale),
      );
    }

    canvas.drawCircle(at, base, Paint()..color = CprPalette.veil(CprPalette.voidBlack, 0.88));
    canvas.drawCircle(
      at,
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (selected ? 1.8 : 1.2) / scale
        ..color = CprPalette.veil(color, 0.85),
    );

    // L'anello della salute, sopra il bordo, dal centro verso l'alto.
    if (token.hasHealth) {
      final Color health = tokenHealthColor(token);
      canvas.drawArc(
        Rect.fromCircle(center: at, radius: base * 1.45),
        -math.pi / 2,
        2 * math.pi * token.healthRatio,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 / scale
          ..strokeCap = StrokeCap.round
          ..color = health,
      );
      if (token.isDown) {
        _icon(canvas, Icons.close, at, base * 1.3, CprPalette.healthFlatline);
      }
    }

    // Iniziale del nome: a otto pixel non ci sta un nome, ma due lettere si
    // leggono, e bastano a distinguere "Tyger Claws 3" da "Tyger Claws 4".
    final String initial = _initial(token.name);
    if (initial.isNotEmpty) {
      _text(
        canvas,
        initial,
        at,
        CprType.label.copyWith(fontSize: base * 0.95, color: CprPalette.veil(color, 0.95)),
      );
    }
  }

  /// Il percorso di un veicolo: una linea punteggiata fra le fermate.
  ///
  /// Punteggiata e non continua perche' una linea piena sulla mappa sembra una
  /// strada o un confine, e le strade di Night City sono gia' disegnate: questa
  /// e' un'**intenzione** di movimento, non un'infrastruttura.
  void _paintTransportRoutes(Canvas canvas, Rect rect) {
    for (final Transport t in transports) {
      if (t.stops.length < 2) continue;
      if (t.status == TransportStatus.arrivato && !_isGameMaster) continue;
      final Color color = transportColor(t);
      final List<Offset> points = <Offset>[
        for (final RouteStop s in t.stops) mapToLocal(s.position, rect),
      ];

      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 / scale
        ..strokeCap = StrokeCap.round
        ..color = CprPalette.veil(color, t.status == TransportStatus.fermo ? 0.55 : 0.32);

      for (int i = 0; i < points.length - 1; i++) {
        _dashedLine(canvas, points[i], points[i + 1], paint, 6 / scale, 5 / scale);
      }

      // Le fermate: un quadratino per dire dove si passa, non dove si e'.
      for (final Offset p in points) {
        canvas.drawRect(
          Rect.fromCenter(center: p, width: 3.6 / scale, height: 3.6 / scale),
          Paint()..color = CprPalette.veil(color, 0.7),
        );
      }
    }
  }

  /// Un veicolo sulla mappa.
  ///
  /// La forma e' orientata secondo la direzione di marcia, ed e' la ragione per
  /// cui un veicolo non si disegna come un token: un cerchio che si sposta non
  /// dice se sta arrivando o scappando, e al tavolo quella e' la prima cosa che
  /// si guarda. Fermo, il veicolo mostra una barretta al posto della punta, e
  /// sulla mappa si vede subito che qualcosa lo ha bloccato.
  void _paintTransports(Canvas canvas, Rect rect) {
    for (final Transport t in transports) {
      final Offset at = mapToLocal(t.position, rect);
      final Color color = transportColor(t);
      final bool selected = t.id == selectedTransportId;
      final bool arrived = t.status == TransportStatus.arrivato;
      final bool held = t.status == TransportStatus.fermo;
      final double size = (selected ? 8.5 : 6.5) / scale;

      if (style == MapStyle.digital && !arrived) {
        canvas.drawCircle(
          at,
          size * 2,
          Paint()
            ..color = CprPalette.veil(color, held ? 0.10 : 0.2)
            ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 6 / scale),
        );
      }

      canvas.save();
      canvas.translate(at.dx, at.dy);
      if (!held && !arrived) {
        canvas.rotate(headingAlong(t.stops, t.progressMeters, _spanMetersGuess));
      }

      final Path body = Path()
        ..moveTo(size * 1.7, 0)
        ..lineTo(-size, size * 0.85)
        ..lineTo(-size * 0.45, 0)
        ..lineTo(-size, -size * 0.85)
        ..close();

      canvas.drawPath(body, Paint()..color = CprPalette.veil(CprPalette.voidBlack, 0.85));
      canvas.drawPath(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (selected ? 1.7 : 1.2) / scale
          ..color = CprPalette.veil(color, arrived ? 0.5 : 0.95),
      );

      if (held) {
        // La barretta del fermo: due pixel che dicono "qualcosa lo ha bloccato".
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 1.6 / scale * 2, height: 1.6 / scale * 2),
          Paint()..color = CprPalette.healthFlatline,
        );
      }
      canvas.restore();

      if (selected) _paintTransportCard(canvas, rect, t);
    }
  }

  /// La scheda di un veicolo selezionato: dove va, quanto va, chi c'e' a bordo.
  void _paintTransportCard(Canvas canvas, Rect rect, Transport t) {
    final Offset at = mapToLocal(t.position, rect);
    final Color color = transportColor(t);

    final TextPainter title = _textPainter(
      t.name,
      CprType.body.copyWith(fontSize: 9.5 / scale, fontWeight: FontWeight.w600, color: CprPalette.ink),
    );
    final TextPainter sub = _textPainter(
      '${t.routeLine} · ${t.statLine}',
      CprType.caption.copyWith(fontSize: 8 / scale, color: CprPalette.inkMuted),
    );

    final double pad = 7 / scale;
    final double width = math.max(title.width, sub.width) + pad * 2 + 2 / scale;
    final double height = title.height + sub.height + pad * 2 + 2 / scale;
    final Rect box = Rect.fromLTWH(at.dx - width / 2, at.dy - 22 / scale - height, width, height);

    canvas.drawRect(box, Paint()..color = CprPalette.veil(CprPalette.surface, 0.96));
    canvas.drawRect(
      Rect.fromLTWH(box.left, box.top, 2 / scale, box.height),
      Paint()..color = t.status == TransportStatus.fermo ? CprPalette.healthFlatline : color,
    );
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = CprPalette.veil(color, 0.5),
    );

    title.paint(canvas, box.topLeft + Offset(pad + 2 / scale, pad));
    sub.paint(canvas, box.topLeft + Offset(pad + 2 / scale, pad + title.height + 2 / scale));
  }

  static void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
    final double total = (b - a).distance;
    if (total <= 0) return;
    final Offset step = (b - a) / total;
    double travelled = 0;
    while (travelled < total) {
      final double end = math.min(travelled + dash, total);
      canvas.drawLine(a + step * travelled, a + step * end, paint);
      travelled = end + gap;
    }
  }

  /// Il colore di un veicolo: il modo dice cosa e', lo stato dice come sta.
  static Color transportColor(Transport t) {
    if (t.status == TransportStatus.fermo) return CprPalette.healthFlatline;
    if (t.status == TransportStatus.arrivato) return CprPalette.inkMuted;
    return switch (t.mode) {
      TransportMode.taxi => CprPalette.yellow,
      TransportMode.groundcar => CprPalette.cyan,
      TransportMode.moto => CprPalette.magenta,
      TransportMode.aerodyne => CprPalette.info,
      TransportMode.maglev => CprPalette.violet,
    };
  }

  /// Una scala di ripiego per ruotare il veicolo.
  ///
  /// L'orientamento e' un rapporto fra due punti, quindi non dipende dalla
  /// scala: il valore serve solo a far scorrere il percorso lungo i metri
  /// giusti, e un errore qui sposterebbe di pochi gradi la punta del veicolo.
  static const double _spanMetersGuess = GmRules.transportMapSpanDefault;

  void _paintTokenCard(Canvas canvas, Rect rect, MapToken token) {
    final Offset at = mapToLocal(token.position, rect);
    final Color color = tokenColor(token.kind);
    final Color health = tokenHealthColor(token);

    final TextPainter title = _textPainter(
      token.name.trim().isEmpty ? 'Senza nome' : token.name,
      CprType.body.copyWith(fontSize: 9.5 / scale, fontWeight: FontWeight.w600, color: CprPalette.ink),
    );
    final TextPainter sub = _textPainter(
      token.statLine.isEmpty ? token.kind.label : token.statLine,
      CprType.caption.copyWith(fontSize: 8 / scale, color: CprPalette.inkMuted),
    );

    final double pad = 7 / scale;
    final double width = math.max(title.width, sub.width) + pad * 2 + 2 / scale;
    final double height = title.height + sub.height + pad * 2 + 2 / scale;
    final Rect box = Rect.fromLTWH(at.dx - width / 2, at.dy + 14 / scale, width, height);

    canvas.drawRect(
      box,
      Paint()
        ..color = CprPalette.veil(CprPalette.voidBlack, 0.70)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 3 / scale),
    );
    canvas.drawRect(box, Paint()..color = CprPalette.veil(CprPalette.surface, 0.96));
    // La barra a sinistra e' del colore della **salute**, non del tipo: quando
    // un token e' selezionato la domanda e' "come sta", non "che cos'e'".
    canvas.drawRect(Rect.fromLTWH(box.left, box.top, 2 / scale, box.height), Paint()..color = health);
    canvas.drawRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = CprPalette.veil(color, 0.5),
    );

    title.paint(canvas, box.topLeft + Offset(pad + 2 / scale, pad));
    sub.paint(canvas, box.topLeft + Offset(pad + 2 / scale, pad + title.height + 2 / scale));
  }

  /// Il colore di un token in funzione di cosa rappresenta.
  static Color tokenColor(TokenKind kind) => switch (kind) {
        TokenKind.alleato => CprPalette.humanityIntact,
        TokenKind.nemico => CprPalette.danger,
        TokenKind.neutrale => CprPalette.yellow,
        TokenKind.veicolo => CprPalette.info,
      };

  /// Il colore dello stato di salute, coerente con quello del cuore in scheda.
  static Color tokenHealthColor(MapToken token) {
    if (!token.hasHealth) return CprPalette.inkMuted;
    return switch (token.health) {
      TokenHealth.illeso => CprPalette.healthFull,
      TokenHealth.ferito => CprPalette.healthWounded,
      TokenHealth.critico => CprPalette.healthCritical,
      TokenHealth.aTerra => CprPalette.healthFlatline,
    };
  }

  static String _initial(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    final List<String> words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words.first.length <= 2 ? words.first.toUpperCase() : words.first.substring(0, 2).toUpperCase();
    }
    return (words.first.substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
  }

  void _paintDraft(Canvas canvas, Rect rect, Offset position) {
    final Offset at = mapToLocal(position, rect);
    final double arm = 9 / scale;

    canvas.drawCircle(
      at,
      arm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 / scale
        ..color = CprPalette.veil(CprPalette.yellow, 0.7),
    );
    final Paint crosshair = Paint()
      ..strokeWidth = 1 / scale
      ..color = CprPalette.yellow;
    canvas.drawLine(at - Offset(arm * 1.6, 0), at + Offset(arm * 1.6, 0), crosshair);
    canvas.drawLine(at - Offset(0, arm * 1.6), at + Offset(0, arm * 1.6), crosshair);
  }

  // --- Utilità -------------------------------------------------------------

  /// Colore di un waypoint in funzione della categoria.
  ///
  /// Per categoria e non per autore: al tavolo serve capire "questo e' un
  /// pericolo" prima di "questo l'ha messo Giulia".
  static Color waypointColor(MapWaypoint w) {
    final Color base = switch (w.kind) {
      WaypointKind.location => CprPalette.cyan,
      WaypointKind.danger => CprPalette.danger,
      WaypointKind.person => CprPalette.violet,
      WaypointKind.job => CprPalette.yellow,
      WaypointKind.shop => CprPalette.success,
      WaypointKind.note => CprPalette.inkMuted,
    };
    // Una posizione privata resta leggibile ma smette di competere con quelle
    // condivise: e' preparazione, non stato del tavolo.
    return w.visibility == WaypointVisibility.private
        ? Color.lerp(base, CprPalette.inkMuted, 0.45)!
        : base;
  }

  Path _closedPath(List<Offset> points, Rect rect) {
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final Offset p = mapToLocal(points[i], rect);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  Path _openPath(List<Offset> points, Rect rect) {
    final Path path = Path();
    for (int i = 0; i < points.length; i++) {
      final Offset p = mapToLocal(points[i], rect);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  /// Versione desaturata e scurita di un accento, per l'aspetto realistico.
  static Color _desaturate(Color color) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation * 0.55).clamp(0, 1))
        .withLightness((hsl.lightness * 0.5).clamp(0, 1))
        .toColor();
  }

  TextPainter _textPainter(String text, TextStyle style) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

  void _text(Canvas canvas, String text, Offset center, TextStyle style, {Color? glow}) {
    final TextPainter painter = _textPainter(text, style);
    final Offset at = center - Offset(painter.width / 2, painter.height / 2);

    // Alone sul testo: si disegna lo stesso testo quattro volte attorno, a
    // bassa opacita'. E' piu' economico di un `saveLayer` per ogni etichetta e
    // su fondo nero basta a far sembrare il neon illuminato invece che
    // semplicemente colorato.
    if (glow != null) {
      final TextPainter halo = _textPainter(text, style.copyWith(color: CprPalette.veil(glow, 0.30)));
      final double d = 1.2 / scale;
      for (final Offset o in <Offset>[
        Offset(-d, 0),
        Offset(d, 0),
        Offset(0, -d),
        Offset(0, d),
      ]) {
        halo.paint(canvas, at + o);
      }
    }

    painter.paint(canvas, at);
  }

  void _icon(Canvas canvas, IconData icon, Offset center, double size, Color color) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant NightCityPainter old) =>
      old.style != style ||
      !identical(old.waypoints, waypoints) ||
      old.hoveredId != hoveredId ||
      old.selectedId != selectedId ||
      old.draft != draft ||
      old.scale != scale ||
      old.image != image ||
      !identical(old.corners, corners) ||
      old.showLabels != showLabels ||
      old.imageOpacity != imageOpacity ||
      old.selectedTokenId != selectedTokenId ||
      old.selectedTransportId != selectedTransportId ||
      !identical(old.tokens, tokens) ||
      old.tokens.length != tokens.length ||
      old.transports.length != transports.length ||
      // La posizione dei veicoli cambia a ogni battito senza che la lista cambi
      // identita': senza questo confronto la mappa ridisegnerebbe solo quando
      // un veicolo parte o arriva, cioe' mai, e i taxi resterebbero fermi.
      _transportSignature(old.transports) != _transportSignature(transports) ||
      old.waypoints.length != waypoints.length;

  static String _transportSignature(List<Transport> list) =>
      list.map((Transport t) => '${t.id}:${t.x.toStringAsFixed(4)}:${t.y.toStringAsFixed(4)}:${t.status.name}').join('|');
}
