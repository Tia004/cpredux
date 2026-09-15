import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import 'animated_number.dart';

/// Visualizer a forma di Quadrifoglio per la Fortuna (LUCK) che si riempie
/// con fluido animato in verde/oro cyberpunk.
class LuckClover extends StatefulWidget {
  const LuckClover({
    super.key,
    required this.current,
    required this.max,
    this.size = 178,
    this.label = 'Fortuna',
  });

  final int current;
  final int max;
  final double size;
  final String label;

  @override
  State<LuckClover> createState() => _LuckCloverState();
}

class _LuckCloverState extends State<LuckClover> with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _wave;

  double get _targetRatio =>
      widget.max <= 0 ? 0 : (widget.current / widget.max).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: CprMotion.value, value: _targetRatio);
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  }

  @override
  void didUpdateWidget(covariant LuckClover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current == widget.current && oldWidget.max == widget.max) return;
    _fill.animateWith(SpringSimulation(CprMotion.valueSpring, _fill.value, _targetRatio, 0));
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color cloverColor = Color(0xFF2ED573);

    return Semantics(
      label: '${widget.label}: ${widget.current} su ${widget.max}',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_fill, _wave]),
                builder: (BuildContext context, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _CloverPainter(
                    ratio: _fill.value.clamp(0.0, 1.0),
                    wavePhase: _wave.value,
                    color: cloverColor,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedNumber(
                  value: widget.current,
                  style: CprType.numeral.copyWith(
                    color: cloverColor,
                    fontSize: widget.size > 140 ? 32 : 24,
                    shadows: <Shadow>[
                      Shadow(color: cloverColor.withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                  upColor: cloverColor,
                  downColor: CprPalette.humanityEroded,
                ),
                Text(
                  '/ ${widget.max}',
                  style: CprType.numeralSmall.copyWith(color: CprPalette.inkFaint),
                ),
                const SizedBox(height: 4),
                CprLabel(widget.label, color: CprPalette.veil(cloverColor, 0.85)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CloverPainter extends CustomPainter {
  const _CloverPainter({
    required this.ratio,
    required this.wavePhase,
    required this.color,
  });

  final double ratio;
  final double wavePhase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path clover = _cloverPath(size);
    final Rect bounds = clover.getBounds();

    // Sfondo sagomato
    canvas.drawPath(clover, Paint()..color = CprPalette.surfaceSunken);

    // Clip fluido
    canvas.save();
    canvas.clipPath(clover);

    if (ratio > 0.001) {
      final double fillTop = bounds.bottom - (bounds.height * ratio);
      final Path wave = Path()..moveTo(-2, fillTop);
      const int steps = 24;
      final double stepPx = (size.width + 4) / steps;
      for (int i = 0; i <= steps; i++) {
        final double x = -2 + i * stepPx;
        final double y = fillTop + math.sin((x / size.width * 2 * math.pi) + (wavePhase * 2 * math.pi)) * 3.5;
        wave.lineTo(x, y);
      }
      wave
        ..lineTo(size.width + 4, size.height + 4)
        ..lineTo(-4, size.height + 4)
        ..close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.45),
          ],
        ).createShader(bounds);
      canvas.drawPath(wave, fillPaint);
    }
    canvas.restore();

    // Bordo sagomato al neon
    final Paint borderPaint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(clover, borderPaint);
  }

  static Path _cloverPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = math.min(w, h) * 0.23;

    final Path path = Path();
    // 4 foglie del quadrifoglio
    path.addOval(Rect.fromCircle(center: Offset(cx, cy - r), radius: r * 0.95));
    path.addOval(Rect.fromCircle(center: Offset(cx, cy + r * 0.85), radius: r * 0.95));
    path.addOval(Rect.fromCircle(center: Offset(cx - r, cy), radius: r * 0.95));
    path.addOval(Rect.fromCircle(center: Offset(cx + r, cy), radius: r * 0.95));

    // Gambo
    final Path stem = Path()
      ..moveTo(cx - 2, cy + r * 0.5)
      ..quadraticBezierTo(cx + 4, h * 0.85, cx + 8, h * 0.96)
      ..quadraticBezierTo(cx + 2, h * 0.85, cx + 2, cy + r * 0.5)
      ..close();
    path.addPath(stem, Offset.zero);

    return path;
  }

  @override
  bool shouldRepaint(_CloverPainter old) =>
      old.ratio != ratio || old.wavePhase != wavePhase || old.color != color;
}

/// Visualizer per l'Empatia (EMP) che si riempie con fluido animato in ciano/violetto.
class EmpathyGauge extends StatefulWidget {
  const EmpathyGauge({
    super.key,
    required this.current,
    required this.max,
    this.size = 178,
    this.label = 'Empatia',
  });

  final int current;
  final int max;
  final double size;
  final String label;

  @override
  State<EmpathyGauge> createState() => _EmpathyGaugeState();
}

class _EmpathyGaugeState extends State<EmpathyGauge> with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _wave;

  double get _targetRatio =>
      widget.max <= 0 ? 0 : (widget.current / widget.max).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: CprMotion.value, value: _targetRatio);
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  }

  @override
  void didUpdateWidget(covariant EmpathyGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current == widget.current && oldWidget.max == widget.max) return;
    _fill.animateWith(SpringSimulation(CprMotion.valueSpring, _fill.value, _targetRatio, 0));
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color empColor = Color(0xFF9B51E0);

    return Semantics(
      label: '${widget.label}: ${widget.current} su ${widget.max}',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_fill, _wave]),
                builder: (BuildContext context, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _EmpathyPainter(
                    ratio: _fill.value.clamp(0.0, 1.0),
                    wavePhase: _wave.value,
                    color: empColor,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedNumber(
                  value: widget.current,
                  style: CprType.numeral.copyWith(
                    color: empColor,
                    fontSize: widget.size > 140 ? 32 : 24,
                    shadows: <Shadow>[
                      Shadow(color: empColor.withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                  upColor: CprPalette.cyan,
                  downColor: CprPalette.danger,
                ),
                Text(
                  '/ ${widget.max}',
                  style: CprType.numeralSmall.copyWith(color: CprPalette.inkFaint),
                ),
                const SizedBox(height: 4),
                CprLabel(widget.label, color: CprPalette.veil(empColor, 0.85)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmpathyPainter extends CustomPainter {
  const _EmpathyPainter({
    required this.ratio,
    required this.wavePhase,
    required this.color,
  });

  final double ratio;
  final double wavePhase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path diamond = _empathyDiamondPath(size);
    final Rect bounds = diamond.getBounds();

    canvas.drawPath(diamond, Paint()..color = CprPalette.surfaceSunken);

    canvas.save();
    canvas.clipPath(diamond);

    if (ratio > 0.001) {
      final double fillTop = bounds.bottom - (bounds.height * ratio);
      final Path wave = Path()..moveTo(-2, fillTop);
      const int steps = 24;
      final double stepPx = (size.width + 4) / steps;
      for (int i = 0; i <= steps; i++) {
        final double x = -2 + i * stepPx;
        final double y = fillTop + math.sin((x / size.width * 2 * math.pi) + (wavePhase * 2 * math.pi)) * 3.5;
        wave.lineTo(x, y);
      }
      wave
        ..lineTo(size.width + 4, size.height + 4)
        ..lineTo(-4, size.height + 4)
        ..close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.85),
            CprPalette.cyan.withValues(alpha: 0.45),
          ],
        ).createShader(bounds);
      canvas.drawPath(wave, fillPaint);
    }
    canvas.restore();

    final Paint borderPaint = Paint()
      ..color = color.withValues(alpha: 0.80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(diamond, borderPaint);
  }

  static Path _empathyDiamondPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.90, h * 0.50)
      ..lineTo(w * 0.5, h * 0.94)
      ..lineTo(w * 0.10, h * 0.50)
      ..close();
  }

  @override
  bool shouldRepaint(_EmpathyPainter old) =>
      old.ratio != ratio || old.wavePhase != wavePhase || old.color != color;
}

/// Visualizer per l'Umanità con riempimento fluido animato in stile cuore/anima cyberpunk.
class HumanityFillGauge extends StatefulWidget {
  const HumanityFillGauge({
    super.key,
    required this.current,
    required this.max,
    this.size = 178,
    this.label = 'Umanita',
  });

  final int current;
  final int max;
  final double size;
  final String label;

  @override
  State<HumanityFillGauge> createState() => _HumanityFillGaugeState();
}

class _HumanityFillGaugeState extends State<HumanityFillGauge> with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _wave;

  double get _targetRatio =>
      widget.max <= 0 ? 0 : (widget.current / widget.max).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: CprMotion.value, value: _targetRatio);
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
  }

  @override
  void didUpdateWidget(covariant HumanityFillGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current == widget.current && oldWidget.max == widget.max) return;
    _fill.animateWith(SpringSimulation(CprMotion.valueSpring, _fill.value, _targetRatio, 0));
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
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
                animation: Listenable.merge(<Listenable>[_fill, _wave]),
                builder: (BuildContext context, _) => CustomPaint(
                  size: Size.square(widget.size),
                  painter: _HumanityFillPainter(
                    ratio: _fill.value.clamp(0.0, 1.0),
                    wavePhase: _wave.value,
                    color: stateColor,
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedNumber(
                  value: widget.current,
                  style: CprType.numeral.copyWith(
                    color: stateColor,
                    fontSize: widget.size > 140 ? 32 : 24,
                    shadows: <Shadow>[
                      Shadow(color: stateColor.withValues(alpha: 0.6), blurRadius: 10),
                    ],
                  ),
                  upColor: CprPalette.humanityIntact,
                  downColor: CprPalette.humanityEroded,
                ),
                Text(
                  '/ ${widget.max}',
                  style: CprType.numeralSmall.copyWith(color: CprPalette.inkFaint),
                ),
                const SizedBox(height: 4),
                CprLabel(widget.label, color: CprPalette.veil(stateColor, 0.85)),
                if (lost > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '-$lost PERSA',
                    style: CprType.label.copyWith(color: CprPalette.humanityEroded, fontSize: 9.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HumanityFillPainter extends CustomPainter {
  const _HumanityFillPainter({
    required this.ratio,
    required this.wavePhase,
    required this.color,
  });

  final double ratio;
  final double wavePhase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path hex = _cyberHexPath(size);
    final Rect bounds = hex.getBounds();

    canvas.drawPath(hex, Paint()..color = CprPalette.surfaceSunken);

    canvas.save();
    canvas.clipPath(hex);

    if (ratio > 0.001) {
      final double fillTop = bounds.bottom - (bounds.height * ratio);
      final Path wave = Path()..moveTo(-2, fillTop);
      const int steps = 24;
      final double stepPx = (size.width + 4) / steps;
      for (int i = 0; i <= steps; i++) {
        final double x = -2 + i * stepPx;
        final double y = fillTop + math.sin((x / size.width * 2 * math.pi) + (wavePhase * 2 * math.pi)) * 3.5;
        wave.lineTo(x, y);
      }
      wave
        ..lineTo(size.width + 4, size.height + 4)
        ..lineTo(-4, size.height + 4)
        ..close();

      final Paint fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.85),
            color.withValues(alpha: 0.40),
          ],
        ).createShader(bounds);
      canvas.drawPath(wave, fillPaint);
    }
    canvas.restore();

    final Paint borderPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(hex, borderPaint);
  }

  static Path _cyberHexPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.92, h * 0.72)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.08, h * 0.72)
      ..lineTo(w * 0.08, h * 0.28)
      ..close();
  }

  @override
  bool shouldRepaint(_HumanityFillPainter old) =>
      old.ratio != ratio || old.wavePhase != wavePhase || old.color != color;
}
