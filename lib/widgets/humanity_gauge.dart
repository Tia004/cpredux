import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import 'animated_number.dart';

/// Shared by the character vitals and cyberware panels. The liquid represents
/// remaining humanity, with a genuinely empty/full silhouette at the endpoints.
class HumanityGauge extends StatefulWidget {
  const HumanityGauge({
    super.key,
    required this.current,
    required this.max,
    this.size = 190,
    this.label = 'Umanità',
  });

  final int current;
  final int max;
  final double size;
  final String label;

  @override
  State<HumanityGauge> createState() => _HumanityGaugeState();
}

class _HumanityGaugeState extends State<HumanityGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _wave.stop();
    } else {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double ratio = widget.max <= 0
        ? 0
        : (widget.current / widget.max).clamp(0.0, 1.0);
    final int lost = math.max(0, math.max(0, widget.max) - widget.current);
    final Color color = Color.lerp(
      CprPalette.humanityEroded,
      CprPalette.humanityIntact,
      ratio,
    )!;
    return Semantics(
      label: '${widget.label}: ${widget.current} su ${widget.max}, $lost persi',
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              child: RepaintBoundary(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: ratio, end: ratio),
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : CprMotion.value,
                  curve: Curves.easeInOutCubic,
                  builder: (BuildContext context, double level, Widget? child) {
                    return AnimatedBuilder(
                      animation: _wave,
                      builder: (BuildContext context, Widget? child) =>
                          CustomPaint(
                            painter: HumanityHeadPainter(
                              ratio: level,
                              phase: _wave.value,
                              color: color,
                            ),
                          ),
                    );
                  },
                ),
              ),
            ),
            // Keep the value in the cranial silhouette, leaving the profile clear.
            Positioned(
              left: widget.size * .12,
              right: widget.size * .24,
              top: widget.size * .29,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedNumber(
                    value: widget.current,
                    style: CprType.numeral.copyWith(
                      color: CprPalette.ink,
                      fontSize: widget.size > 160 ? 32 : 27,
                      shadows: const <Shadow>[
                        Shadow(color: Color(0xCC071419), blurRadius: 8),
                      ],
                    ),
                    upColor: CprPalette.humanityIntact,
                    downColor: CprPalette.humanityEroded,
                  ),
                  Text(
                    '/ ${widget.max}',
                    style: CprType.numeralSmall.copyWith(
                      color: CprPalette.inkMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label.toUpperCase(),
                    style: CprType.label.copyWith(
                      color: CprPalette.ink,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            if (lost > 0)
              Positioned(
                bottom: 0,
                child: Text(
                  '-$lost PERSA',
                  style: CprType.label.copyWith(
                    color: CprPalette.humanityEroded,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HumanityHeadPainter extends CustomPainter {
  const HumanityHeadPainter({
    required this.ratio,
    required this.phase,
    required this.color,
  });
  final double ratio;
  final double phase;
  final Color color;

  static Path silhouette(Size size) {
    final Path p = Path()
      ..moveTo(30, 89)
      ..lineTo(30, 72)
      ..cubicTo(15, 64, 10, 50, 12, 35)
      ..cubicTo(14, 16, 26, 7, 44, 7)
      ..cubicTo(62, 6, 74, 17, 75, 32)
      ..lineTo(75, 38)
      ..cubicTo(75, 41, 81, 47, 85, 52)
      ..quadraticBezierTo(88, 56, 82, 57)
      ..lineTo(76, 58)
      ..lineTo(76, 64)
      ..quadraticBezierTo(78, 66, 74, 68)
      ..lineTo(74, 72)
      ..quadraticBezierTo(74, 78, 65, 78)
      ..lineTo(56, 77)
      ..lineTo(55, 89)
      ..close();
    return p.transform(
      Matrix4.diagonal3Values(size.width / 100, size.height / 100, 1).storage,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path head = silhouette(size);
    final Rect bounds = head.getBounds();
    final double level = ratio.clamp(0.0, 1.0);
    canvas.drawPath(head, Paint()..color = CprPalette.surfaceSunken);
    canvas.save();
    canvas.clipPath(head);
    if (level > 0) {
      final double top = bounds.bottom - bounds.height * level;
      // The wave vanishes at 0 and 100%, so the endpoints remain exact.
      final double amplitude = math.sin(level * math.pi) * size.height * .016;
      final Path liquid = Path()..moveTo(0, top);
      for (int i = 0; i <= 40; i++) {
        final double x = size.width * i / 40;
        liquid.lineTo(
          x,
          top +
              math.sin(i / 40 * math.pi * 2 + phase * math.pi * 2) * amplitude,
        );
      }
      liquid
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        liquid,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              color.withValues(alpha: .8),
              color.withValues(alpha: .28),
            ],
          ).createShader(bounds),
      );
      canvas.drawLine(
        Offset(0, top),
        Offset(size.width, top),
        Paint()
          ..color = color.withValues(alpha: .25)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
    canvas.drawPath(
      head,
      Paint()
        ..color = color.withValues(alpha: .16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      head,
      Paint()
        ..color = color.withValues(alpha: .85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    // Small temple implant keeps the profile readable without covering the fill.
    final Offset temple = Offset(size.width * .68, size.height * .38);
    canvas.drawCircle(
      temple,
      size.width * .018,
      Paint()..color = CprPalette.ink.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(HumanityHeadPainter oldDelegate) =>
      ratio != oldDelegate.ratio ||
      phase != oldDelegate.phase ||
      color != oldDelegate.color;
}
