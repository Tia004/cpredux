import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/night_city.dart';
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

    _paintWaypoints(canvas, rect);
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
    if (img == null || corners.length != 4) return;

    final List<Offset> p = <Offset>[for (final Offset c in corners) mapToLocal(c, rect)];
    final double w = img.width.toDouble();
    final double h = img.height.toDouble();

    final ui.Vertices vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.fromList(<double>[
        p[0].dx, p[0].dy,
        p[1].dx, p[1].dy,
        p[2].dx, p[2].dy,
        p[3].dx, p[3].dy,
      ]),
      textureCoordinates: Float32List.fromList(<double>[0, 0, w, 0, w, h, 0, h]),
      indices: Uint16List.fromList(<int>[0, 1, 2, 0, 2, 3]),
    );

    final Paint paint = Paint()
      ..shader = ui.ImageShader(img, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage)
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    final bool faded = imageOpacity < 1;
    if (faded) {
      canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(255, 255, 255, imageOpacity));
    }
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
    if (faded) canvas.restore();
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
      old.waypoints.length != waypoints.length;
}
