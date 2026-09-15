import 'dart:math' as math;
import 'dart:ui' as ui;

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
                  foregroundPainter: _CyberHeadPainter(
                    level: _level.value.clamp(0.0, 1.0),
                    sweepPhase: _sweep.value,
                    intactColor: CprPalette.humanityIntact,
                    erodedColor: CprPalette.humanityEroded,
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _level,
              builder: (BuildContext context, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: CprPalette.surface.withValues(alpha: 0.68),
                  border: Border.all(
                    color: CprPalette.veil(stateColor, 0.45),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: CprPalette.veil(stateColor, 0.18),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedNumber(
                      value: widget.current,
                      style: CprType.numeral.copyWith(
                        color: stateColor,
                        fontSize: 27,
                        letterSpacing: 0.8,
                        shadows: <Shadow>[
                          Shadow(
                            color: stateColor.withValues(alpha: 0.65),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      upColor: CprPalette.humanityIntact,
                      downColor: CprPalette.humanityEroded,
                    ),
                    Text(
                      '/ ${widget.max}',
                      style: CprType.numeralSmall.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 3),
                    CprLabel(widget.label, color: CprPalette.veil(stateColor, 0.9)),
                    if (lost > 0) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        '-$lost PERSA',
                        style: CprType.label.copyWith(
                          color: CprPalette.humanityEroded,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
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

/// Silhouette e tracciati neurali anatomici della testa cyberpunk con bagliore neon e impulsi fluidi.
class _CyberHeadPainter extends CustomPainter {
  const _CyberHeadPainter({
    required this.level,
    required this.sweepPhase,
    required this.intactColor,
    required this.erodedColor,
  });

  final double level;
  final double sweepPhase;
  final Color intactColor;
  final Color erodedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2 - 4;
    final double s = size.width / 190.0;

    final double erodedRatio = (1.0 - level).clamp(0.0, 1.0);
    final Color mainColor = Color.lerp(intactColor, erodedColor, math.min(1.0, erodedRatio * 1.35))!;
    final double pulse = 0.5 + 0.5 * math.sin(sweepPhase * math.pi * 2);

    // 1. Bagliore circolare di fondo
    final Paint auraPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          mainColor.withValues(alpha: 0.16 + 0.08 * pulse),
          mainColor.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 56 * s));
    canvas.drawCircle(Offset(cx, cy), 56 * s, auraPaint);

    // 2. Silhouette anatomica del cranio cyberpunk (profilo angolato)
    final Path headPath = Path();
    headPath.moveTo(cx - 16 * s, cy + 30 * s);
    headPath.cubicTo(
      cx - 38 * s, cy + 24 * s,
      cx - 44 * s, cy - 14 * s,
      cx - 26 * s, cy - 38 * s,
    );
    headPath.cubicTo(
      cx - 12 * s, cy - 50 * s,
      cx + 14 * s, cy - 50 * s,
      cx + 30 * s, cy - 36 * s,
    );
    headPath.cubicTo(
      cx + 40 * s, cy - 26 * s,
      cx + 42 * s, cy - 10 * s,
      cx + 36 * s, cy - 2 * s,
    );
    headPath.lineTo(cx + 40 * s, cy + 4 * s);
    headPath.lineTo(cx + 42 * s, cy + 14 * s);
    headPath.lineTo(cx + 34 * s, cy + 18 * s);
    headPath.lineTo(cx + 34 * s, cy + 26 * s);
    headPath.lineTo(cx + 26 * s, cy + 34 * s);
    headPath.lineTo(cx + 8 * s, cy + 28 * s);
    headPath.lineTo(cx + 6 * s, cy + 46 * s);
    headPath.lineTo(cx - 12 * s, cy + 46 * s);
    headPath.lineTo(cx - 14 * s, cy + 30 * s);
    headPath.close();

    // Riempimento scuro tecnologico
    final Paint fillPaint = Paint()
      ..color = CprPalette.surfaceRaised.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(headPath, fillPaint);

    // Bagliore neon contorno
    final Paint glowPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.35 + 0.22 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * s);
    canvas.drawPath(headPath, glowPaint);

    // Linea di contorno netta
    final Paint strokePaint = Paint()
      ..color = mainColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * s;
    canvas.drawPath(headPath, strokePaint);

    // 3. Pannellature e innesti cranici
    final Paint panelPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s;

    final Path tempSeam = Path()
      ..moveTo(cx - 8 * s, cy - 42 * s)
      ..cubicTo(cx - 4 * s, cy - 20 * s, cx - 12 * s, cy + 6 * s, cx - 14 * s, cy + 24 * s);
    canvas.drawPath(tempSeam, panelPaint);

    final Path occSeam = Path()
      ..moveTo(cx - 24 * s, cy - 28 * s)
      ..lineTo(cx - 36 * s, cy - 2 * s);
    canvas.drawPath(occSeam, panelPaint);

    // Giunto mandibolare cibernetico
    final Offset jawJoint = Offset(cx + 6 * s, cy + 18 * s);
    canvas.drawCircle(jawJoint, 3.2 * s, panelPaint);
    canvas.drawCircle(
      jawJoint,
      1.4 * s,
      Paint()
        ..color = mainColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill,
    );

    // 4. Cyberocchio neon
    final Offset eyeCenter = Offset(cx + 24 * s, cy + 3 * s);
    canvas.drawCircle(
      eyeCenter,
      4.2 * s,
      Paint()
        ..color = mainColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * s,
    );
    canvas.drawCircle(
      eyeCenter,
      2.0 * s,
      Paint()
        ..color = (erodedRatio > 0.6 ? CprPalette.danger : intactColor).withValues(alpha: 0.95)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s),
    );

    // 5. Linee neurali e bus sinaptici
    final Path neuralBus = Path();
    neuralBus.moveTo(cx + 18 * s, cy - 30 * s);
    neuralBus.cubicTo(
      cx + 4 * s, cy - 34 * s,
      cx - 10 * s, cy - 20 * s,
      cx - 4 * s, cy - 4 * s,
    );
    neuralBus.cubicTo(
      cx + 2 * s, cy + 8 * s,
      cx - 4 * s, cy + 22 * s,
      cx - 4 * s, cy + 44 * s,
    );

    final Path opticBranch = Path()
      ..moveTo(cx - 4 * s, cy - 4 * s)
      ..lineTo(cx + 18 * s, cy + 2 * s);

    final Path occipitalBranch = Path()
      ..moveTo(cx - 8 * s, cy - 14 * s)
      ..lineTo(cx - 30 * s, cy - 4 * s);

    final Paint busPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * s;
    canvas.drawPath(neuralBus, busPaint);
    canvas.drawPath(opticBranch, busPaint);
    canvas.drawPath(occipitalBranch, busPaint);

    // Impulso fluido di sinapsi che scorre lungo la rete neurale
    final ui.PathMetrics metrics = neuralBus.computeMetrics();
    for (final ui.PathMetric metric in metrics) {
      final double distance = (sweepPhase * metric.length) % metric.length;
      final ui.Tangent? tangent = metric.getTangentForOffset(distance);
      if (tangent != null) {
        canvas.drawCircle(
          tangent.position,
          2.6 * s,
          Paint()
            ..color = mainColor.withValues(alpha: 0.95)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * s),
        );
        canvas.drawCircle(
          tangent.position,
          1.4 * s,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Linee glitch cyberpsicosi se l'umanità è gravemente erosa
    if (erodedRatio > 0.45) {
      final double glitchY = cy - 36 * s + ((sweepPhase * 3.5) % 1.0) * 72 * s;
      final Paint glitchPaint = Paint()
        ..color = erodedColor.withValues(alpha: 0.55)
        ..strokeWidth = 1.0 * s;
      canvas.drawLine(
        Offset(cx - 28 * s, glitchY),
        Offset(cx + 24 * s, glitchY),
        glitchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CyberHeadPainter old) =>
      old.level != level ||
      old.sweepPhase != sweepPhase ||
      old.intactColor != intactColor ||
      old.erodedColor != erodedColor;
}

