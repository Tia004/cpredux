import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/palette.dart';

/// Sfondo tecnico: griglia fine + viniettatura.
///
/// La griglia e' disegnata a bassissima opacita'. Serve a due cose concrete:
/// da' profondita' alle superfici piatte (senza di essa i pannelli scuri
/// sembrano ritagliati nel vuoto) e rende visibile il bordo della finestra
/// quando l'app gira a schermo intero.
///
/// Costo: si disegna una volta e si riusa. Il `RepaintBoundary` a monte evita
/// che venga ridisegnata a ogni frame delle animazioni sovrastanti.
class TechBackground extends StatelessWidget {
  const TechBackground({
    super.key,
    required this.child,
    this.gridSize = 32,
    this.accent,
    this.showVignette = true,
  });

  final Widget child;
  final double gridSize;
  final Color? accent;
  final bool showVignette;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: ColoredBox(color: CprPalette.voidBlack)),
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _GridPainter(
                gridSize: gridSize,
                color: accent ?? CprPalette.yellow,
                showVignette: showVignette,
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.gridSize,
    required this.color,
    required this.showVignette,
  });

  final double gridSize;
  final Color color;
  final bool showVignette;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = CprPalette.veil(color, 0.035)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    // Croci ai nodi ogni 4 celle: come le griglie tecniche, orientano l'occhio
    // senza aggiungere rumore.
    final Paint cross = Paint()
      ..color = CprPalette.veil(color, 0.07)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += gridSize * 4) {
      for (double y = 0; y <= size.height; y += gridSize * 4) {
        canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), cross);
        canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), cross);
      }
    }

    if (showVignette) {
      final Rect rect = Offset.zero & size;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            rect.center,
            size.longestSide * 0.62,
            <Color>[
              const Color(0x00000000),
              CprPalette.veil(CprPalette.voidBlack, 0.55),
            ],
            <double>[0.55, 1.0],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.gridSize != gridSize || old.color != color || old.showVignette != showVignette;
}
