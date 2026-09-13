import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Quali angoli vengono tagliati. Tagliare un solo angolo (di solito quello in
/// alto a sinistra o in basso a destra) e' spesso piu' elegante del tagliarli
/// tutti: da' una direzione alla forma.
@immutable
class ChamferCorners {
  const ChamferCorners({
    this.topLeft = true,
    this.topRight = true,
    this.bottomRight = true,
    this.bottomLeft = true,
  });

  final bool topLeft;
  final bool topRight;
  final bool bottomRight;
  final bool bottomLeft;

  static const ChamferCorners all = ChamferCorners();
  static const ChamferCorners top = ChamferCorners(bottomRight: false, bottomLeft: false);
  static const ChamferCorners bottom = ChamferCorners(topLeft: false, topRight: false);
  static const ChamferCorners leading = ChamferCorners(topRight: false, bottomRight: false);
  static const ChamferCorners trailing = ChamferCorners(topLeft: false, bottomLeft: false);
  static const ChamferCorners diagonal = ChamferCorners(topLeft: true, topRight: false, bottomRight: true, bottomLeft: false);
}

/// Costruisce il path di un rettangolo con gli angoli tagliati a 45 gradi.
///
/// Il taglio viene limitato a meta' del lato piu' corto: senza questo vincolo,
/// su un elemento basso e largo (una riga di tabella) i tagli si
/// sovrapporrebbero producendo una forma degenerata.
Path chamferPath(Size size, double cut, [ChamferCorners corners = ChamferCorners.all]) {
  final double w = size.width;
  final double h = size.height;
  final double maxCut = math.min(w, h) / 2;
  double c(bool enabled) => enabled ? math.min(cut, maxCut) : 0;

  final double tl = c(corners.topLeft);
  final double tr = c(corners.topRight);
  final double br = c(corners.bottomRight);
  final double bl = c(corners.bottomLeft);

  final Path path = Path()..moveTo(tl, 0);
  if (tr > 0) {
    path.lineTo(w - tr, 0);
    path.lineTo(w, tr);
  } else {
    path.lineTo(w, 0);
  }
  if (br > 0) {
    path.lineTo(w, h - br);
    path.lineTo(w - br, h);
  } else {
    path.lineTo(w, h);
  }
  if (bl > 0) {
    path.lineTo(bl, h);
    path.lineTo(0, h - bl);
  } else {
    path.lineTo(0, h);
  }
  if (tl > 0) {
    path.lineTo(0, tl);
    path.lineTo(tl, 0);
  } else {
    path.lineTo(0, 0);
  }
  return path..close();
}

/// Ritaglio a chamfer, da usare come `clipper` di un widget.
class ChamferClipper extends CustomClipper<Path> {
  const ChamferClipper({this.cut = 12, this.corners = ChamferCorners.all});

  final double cut;
  final ChamferCorners corners;

  @override
  Path getClip(Size size) => chamferPath(size, cut, corners);

  @override
  bool shouldReclip(ChamferClipper oldClipper) =>
      oldClipper.cut != cut || oldClipper.corners != corners;
}

/// Disegna un rettangolo con angoli tagliati: riempimento, bordo, o entrambi.
///
/// Nota sulle performance: qui usiamo `Path` + `drawPath` e non `drawRRect`,
/// quindi il costo e' leggermente superiore a un rettangolo normale. Va bene
/// per i pannelli e i pulsanti, che sono decine, non per le migliaia di celle
/// di una tabella: li' si usano fill e bordi normali.
class ChamferPainter extends CustomPainter {
  const ChamferPainter({
    this.cut = 12,
    this.corners = ChamferCorners.all,
    this.fill,
    this.stroke,
    this.strokeWidth = 1,
    this.glow,
    this.glowRadius = 18,
  });

  final double cut;
  final ChamferCorners corners;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;

  /// Se valorizzato, disegna un alone esterno dello stesso colore.
  /// E' un effetto costoso: tenerlo su pochi elementi "vivi" per schermata.
  final Color? glow;
  final double glowRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = chamferPath(size, cut, corners);

    if (glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glow!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth * 2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius),
      );
    }
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!..style = PaintingStyle.fill);
    }
    if (stroke != null && strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(ChamferPainter old) =>
      old.cut != cut ||
      old.corners != corners ||
      old.fill != fill ||
      old.stroke != stroke ||
      old.strokeWidth != strokeWidth ||
      old.glow != glow ||
      old.glowRadius != glowRadius;
}

/// Segno "tecnico" ad angolo: due tratti che marcano un angolo del pannello.
/// Serve a dare l'impressione di un'interfaccia strumentale senza aggiungere
/// peso visivo a tutta la cornice.
class CornerTickPainter extends CustomPainter {
  const CornerTickPainter({required this.color, this.length = 10, this.width = 2});

  final Color color;
  final double length;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(length, 0), p);
    canvas.drawLine(Offset.zero, Offset(0, length), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), p);
  }

  @override
  bool shouldRepaint(CornerTickPainter old) =>
      old.color != color || old.length != length || old.width != width;
}
