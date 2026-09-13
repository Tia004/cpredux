import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import 'animated_number.dart';

/// Spira dell'Umanita'.
///
/// Rivoluzionata rispetto a una barra, per una ragione narrativa e non
/// estetica: in Cyberpunk RED l'Umanita' non "scende" come l'acqua in un
/// serbatoio, viene *eros* dal cyberware installato. La barra racconta una
/// perdita continua e recuperabile, i segmenti raccontano una sottrazione
/// permanente a scatti — che e' quello che succede davvero.
///
/// I segmenti mancanti si accendono di magenta: la zona colorata non e' "il
/// residuo", e' *quello che hai perso*. Con un'occhiata sai quanta te ne resta
/// e quanta ne hai lasciata per strada.
class HumanityGauge extends StatefulWidget {
  const HumanityGauge({
    super.key,
    required this.current,
    required this.max,
    this.size = 190,
    this.label = 'Umanita',
    this.segments = 32,
  });

  final int current;
  final int max;
  final double size;
  final String label;
  final int segments;

  @override
  State<HumanityGauge> createState() => _HumanityGaugeState();
}

class _HumanityGaugeState extends State<HumanityGauge> with TickerProviderStateMixin {
  late final AnimationController _level;
  late final AnimationController _sweep;

  double get _target => widget.max <= 0 ? 0 : (widget.current / widget.max).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _level = AnimationController(vsync: this, duration: CprMotion.value, value: _target);
    _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  }

  @override
  void didUpdateWidget(covariant HumanityGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current == widget.current && oldWidget.max == widget.max) return;
    _level.animateWith(SpringSimulation(CprMotion.containerSpring, _level.value, _target, 0));
  }

  @override
  void dispose() {
    _level.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int lost = (widget.max - widget.current).clamp(0, widget.max);
    final double erodedRatio = widget.max <= 0 ? 0 : lost / widget.max;
    final Color stateColor = Color.lerp(
      CprPalette.humanityIntact,
      CprPalette.humanityEroded,
      math.min(1, erodedRatio * 1.35),
    )!;

    return Semantics(
      label: '${widget.label}: ${widget.current} su ${widget.max}, $lost persi',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_level, _sweep]),
                builder: (BuildContext context, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _HumanityPainter(
                    level: _level.value.clamp(0.0, 1.0),
                    segments: widget.segments,
                    intactColor: CprPalette.humanityIntact,
                    erodedColor: CprPalette.humanityEroded,
                    sweepPhase: _sweep.value,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _level,
              builder: (BuildContext context, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedNumber(
                    value: widget.current,
                    style: CprType.numeral.copyWith(color: stateColor, fontSize: 32),
                    upColor: CprPalette.humanityIntact,
                    downColor: CprPalette.humanityEroded,
                  ),
                  Text(
                    '/ ${widget.max}',
                    style: CprType.numeralSmall.copyWith(color: CprPalette.inkFaint),
                  ),
                  const SizedBox(height: 5),
                  CprLabel(widget.label, color: CprPalette.veil(stateColor, 0.8)),
                  if (lost > 0) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      '-$lost PERSA',
                      style: CprType.label.copyWith(color: CprPalette.humanityEroded, fontSize: 9.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HumanityPainter extends CustomPainter {
  const _HumanityPainter({
    required this.level,
    required this.segments,
    required this.intactColor,
    required this.erodedColor,
    required this.sweepPhase,
  });

  final double level;
  final int segments;
  final Color intactColor;
  final Color erodedColor;
  final double sweepPhase;

  // Arco aperto in basso: 270 gradi che partono da in basso a sinistra.
  static const double _startAngle = math.pi * 0.75;
  static const double _sweepAngle = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 16;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    const double strokeWidth = 7.5;
    final double segmentSweep = _sweepAngle / segments;

    final double boundary = level * segments;

    for (int i = 0; i < segments; i++) {
      final double segStart = _startAngle + i * segmentSweep;
      // Il 62% dello spazio e' segmento, il resto e' gap: senza gap i
      // segmenti si fondono e torni ad avere una barra.
      final double segSweep = segmentSweep * 0.62;

      // Posizione del segmento rispetto al confine: 0 = pienamente integro,
      // 1 = pienamente perso. Il clamp produce l'animazione del confine.
      final double d = (boundary - (i + 0.5)).clamp(-1.0, 1.0);
      final double intactness = (d + 1) / 2;

      final Color base = Color.lerp(erodedColor, intactColor, intactness)!;
      final double opacity = intactness > 0.5
          ? 0.35 + 0.65 * (intactness - 0.5) * 2
          : 0.30 + 0.25 * intactness * 2;

      canvas.drawArc(
        rect,
        segStart,
        segSweep,
        false,
        Paint()
          ..color = CprPalette.veil(base, opacity.clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      // Il segmento sul confine pulsa: e' il punto in cui stai perdendo
      // umanita', ed e' l'informazione piu' importante del quadrante.
      final bool isBoundary = (i + 1) > boundary - 1 && (i + 1) <= boundary + 1;
      if (isBoundary && level > 0 && level < 1) {
        final double pulse = 0.5 + 0.5 * math.sin(sweepPhase * math.pi * 2);
        canvas.drawArc(
          rect,
          segStart,
          segSweep,
          false,
          Paint()
            ..color = CprPalette.veil(intactColor, 0.35 + 0.45 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 4 * pulse),
        );
      }
    }

    // Tacche di riferimento esterne: ogni 4 segmenti, per leggere il valore
    // a colpo d'occhio senza contare i singoli pezzi.
    final Paint tick = Paint()
      ..color = CprPalette.veil(CprPalette.inkFaint, 0.5)
      ..strokeWidth = 1;
    for (int i = 0; i <= segments; i += 4) {
      final double a = _startAngle + i * segmentSweep - segmentSweep / 2;
      final Offset dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (radius + 9),
        center + dir * (radius + 14),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_HumanityPainter old) =>
      old.level != level ||
      old.segments != segments ||
      old.sweepPhase != sweepPhase ||
      old.intactColor != intactColor ||
      old.erodedColor != erodedColor;
}
