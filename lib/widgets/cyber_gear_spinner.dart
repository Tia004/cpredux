import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';

/// Indicatore animato ad ingranaggi / rotelle cyberpunk (Dual Meshing Gears).
///
/// Mostra due rotelle meccaniche dentate che ruotano in sincronia a velocità
/// opposta, con denti smussati e accenti cromatici cybernetici luminosi.
class CyberGearSpinner extends StatefulWidget {
  const CyberGearSpinner({
    super.key,
    this.size = 28.0,
    this.accent,
    this.secondaryAccent,
    this.duration = const Duration(milliseconds: 2400),
  });

  final double size;
  final Color? accent;
  final Color? secondaryAccent;
  final Duration duration;

  @override
  State<CyberGearSpinner> createState() => _CyberGearSpinnerState();
}

class _CyberGearSpinnerState extends State<CyberGearSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.accent ?? CprPalette.cyan;
    final Color secondaryColor = widget.secondaryAccent ?? CprPalette.yellow;

    return Semantics(
      label: 'Elaborazione IA in corso (rotelle animate)',
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, _) {
          return CustomPaint(
            size: Size(widget.size * 1.5, widget.size),
            painter: _DualGearPainter(
              progress: _ctrl.value,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
            ),
          );
        },
      ),
    );
  }
}

class _DualGearPainter extends CustomPainter {
  const _DualGearPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    final double r1 = h * 0.44;
    final double r2 = h * 0.32;

    final Offset c1 = Offset(r1 + 2, h * 0.5);
    final Offset c2 = Offset(c1.dx + r1 + r2 - 3, h * 0.54);

    // Ingranaggio primario (senso orario)
    _drawGear(
      canvas: canvas,
      center: c1,
      radius: r1,
      teeth: 8,
      toothHeight: r1 * 0.26,
      angle: progress * 2 * math.pi,
      color: primaryColor,
    );

    // Ingranaggio secondario (senso antiorario, sincronizzato al rapporto dei raggi)
    final double gearRatio = 8.0 / 6.0;
    _drawGear(
      canvas: canvas,
      center: c2,
      radius: r2,
      teeth: 6,
      toothHeight: r2 * 0.28,
      angle: -progress * 2 * math.pi * gearRatio + 0.35,
      color: secondaryColor,
    );
  }

  void _drawGear({
    required Canvas canvas,
    required Offset center,
    required double radius,
    required int teeth,
    required double toothHeight,
    required double angle,
    required Color color,
  }) {
    final Paint linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final double step = (2 * math.pi) / teeth;
    final double halfTooth = step * 0.24;

    for (int i = 0; i < teeth; i++) {
      final double a = angle + i * step;

      final double a1 = a - halfTooth;
      final double a2 = a - halfTooth * 0.6;
      final double a3 = a + halfTooth * 0.6;
      final double a4 = a + halfTooth;

      final double rIn = radius - toothHeight * 0.5;
      final double rOut = radius + toothHeight * 0.5;

      final Offset p0 = center + Offset(math.cos(a1) * rIn, math.sin(a1) * rIn);
      final Offset p1 = center + Offset(math.cos(a2) * rOut, math.sin(a2) * rOut);
      final Offset p2 = center + Offset(math.cos(a3) * rOut, math.sin(a3) * rOut);
      final Offset p3 = center + Offset(math.cos(a4) * rIn, math.sin(a4) * rIn);

      if (i == 0) {
        path.moveTo(p0.dx, p0.dy);
      } else {
        path.lineTo(p0.dx, p0.dy);
      }
      path.lineTo(p1.dx, p1.dy);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(p3.dx, p3.dy);
    }
    path.close();

    // Disegna corpo ingranaggio con bagliore
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    // Mozzo centrale (foro dell'asse)
    final double hubRadius = radius * 0.35;
    canvas.drawCircle(center, hubRadius, glowPaint);
    canvas.drawCircle(center, hubRadius, linePaint);

    // Dettaglio fori interni
    final int holes = 3;
    final double holeR = hubRadius * 0.45;
    final double holeDist = radius * 0.62;
    for (int j = 0; j < holes; j++) {
      final double ha = angle + (j * 2 * math.pi / holes);
      final Offset hCenter = center + Offset(math.cos(ha) * holeDist, math.sin(ha) * holeDist);
      canvas.drawCircle(hCenter, holeR, linePaint);
    }
  }

  @override
  bool shouldRepaint(_DualGearPainter old) =>
      old.progress != progress ||
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor;
}

/// Scheda cyberpunk avanzata mostrata in chat o nei generatori durante il processing/thinking dell'IA.
class CyberAiProcessingCard extends StatefulWidget {
  const CyberAiProcessingCard({
    super.key,
    this.statusText = 'ELABORAZIONE NEURALE IN CORSO...',
    this.thinkingDetails,
    this.accent,
  });

  final String statusText;
  final String? thinkingDetails;
  final Color? accent;

  @override
  State<CyberAiProcessingCard> createState() => _CyberAiProcessingCardState();
}

class _CyberAiProcessingCardState extends State<CyberAiProcessingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  bool _thinkingExpanded = true;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? CprPalette.cyan;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const CyberGearSpinner(size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (BuildContext context, _) {
                        return Text(
                          widget.statusText,
                          style: CprType.label.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color.lerp(accent, Colors.white, _pulseCtrl.value * 0.4),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Accesso a Datapool & Modello Cyberpunk RED...',
                      style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (widget.thinkingDetails != null && widget.thinkingDetails!.isNotEmpty)
                IconButton(
                  icon: Icon(
                    _thinkingExpanded ? Icons.psychology : Icons.psychology_outlined,
                    size: 18,
                    color: accent,
                  ),
                  tooltip: _thinkingExpanded ? 'Nascondi pensiero IA' : 'Mostra pensiero IA',
                  onPressed: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
                ),
            ],
          ),
          if (widget.thinkingDetails != null &&
              widget.thinkingDetails!.isNotEmpty &&
              _thinkingExpanded) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CprPalette.voidBlack,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: CprPalette.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.terminal, size: 12, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        'NEURAL THINKING TRACE:',
                        style: CprType.mono(accent, size: 9.5, weight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    widget.thinkingDetails!,
                    style: CprType.mono(CprPalette.inkMuted, size: 10),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
