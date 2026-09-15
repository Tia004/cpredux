import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import 'animated_number.dart';

/// Il cuore dei Punti Vita.
///
/// Tre comportamenti sovrapposti, ognuno con un compito preciso:
///
/// 1. **Livello** — il sangue sale o scende con una molla, non linearmente.
///    Una molla comunica "questo e' un colpo" / "questa e' una cura"; una
///    transizione lineare comunica soltanto "il numero e' cambiato".
/// 2. **Battito** — la frequenza e' funzione dei PV residui: 1000 ms a piena
///    salute, 380 ms in fin di vita. E' l'unico indicatore di urgenza che si
///    percepisce senza leggere un numero.
/// 3. **Impatto** — un anello che si espande e un contraccolpo quando il
///    valore cambia. Serve a rispondere alla domanda "cosa e' appena
///    successo?" nelle schede condivise, dove il master modifica i tuoi PV
///    mentre guardi altrove.
///
/// Tutto il disegno vive in un solo `CustomPaint`: il battito e il livello
/// sono passati al painter come valori, quindi l'albero dei widget *non* si
/// ricostruisce a ogni frame. Su un pannello che gira a 60 fps accanto a
/// tabelle e liste, questa distinzione e' la differenza tra fluido e scattoso.
class HealthHeart extends StatefulWidget {
  const HealthHeart({
    super.key,
    required this.current,
    required this.max,
    this.size = 190,
    this.label = 'Punti Vita',
    this.showNumbers = true,
  });

  final int current;
  final int max;
  final double size;
  final String label;
  final bool showNumbers;

  @override
  State<HealthHeart> createState() => _HealthHeartState();
}

class _HealthHeartState extends State<HealthHeart> with TickerProviderStateMixin {
  late final AnimationController _fill;
  late final AnimationController _wave;
  late final AnimationController _beat;
  late final AnimationController _impact;
  late final AnimationController _flatline;

  double get _targetRatio =>
      widget.max <= 0 ? 0 : (widget.current / widget.max).clamp(0.0, 1.0);

  bool get _isFlatline => widget.max > 0 && widget.current <= 0;

  @override
  void initState() {
    super.initState();
    _fill = AnimationController(vsync: this, duration: CprMotion.value, value: _targetRatio);
    _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400))..repeat();
    _beat = AnimationController(vsync: this, duration: _beatPeriod(_targetRatio));
    _flatline = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
    _impact = AnimationController(vsync: this, duration: const Duration(milliseconds: 640), value: 1);
    _syncBeat();
  }

  @override
  void didUpdateWidget(covariant HealthHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.current == widget.current && oldWidget.max == widget.max) return;

    // Molla verso il nuovo livello. `animateWith` riprende dalla posizione
    // corrente, quindi colpi ravvicinati si sommano invece di resettarsi.
    _fill.animateWith(SpringSimulation(CprMotion.valueSpring, _fill.value, _targetRatio, 0));
    _impact.forward(from: 0);
    _syncBeat();
  }

  @override
  void dispose() {
    _fill.dispose();
    _wave.dispose();
    _beat.dispose();
    _impact.dispose();
    _flatline.dispose();
    super.dispose();
  }

  /// Frequenza cardiaca in funzione della vita residua.
  Duration _beatPeriod(double ratio) {
    final double t = ratio.clamp(0.0, 1.0);
    return Duration(milliseconds: (380 + t * 620).round());
  }

  void _syncBeat() {
    if (_isFlatline) {
      _beat.stop();
      return;
    }
    _beat.duration = _beatPeriod(_targetRatio);
    if (!_beat.isAnimating) _beat.repeat();
  }

  /// Profilo "lub-dub": due pulsazioni asimmetriche per ciclo.
  static double _beatScale(double t) {
    double pulse(double center, double width, double amp) {
      final double d = (t - center).abs();
      if (d > width) return 0;
      final double x = 1 - d / width;
      return amp * (x * x * (3 - 2 * x));
    }

    return 1.0 + pulse(0.10, 0.11, 0.080) + pulse(0.31, 0.09, 0.042);
  }

  @override
  Widget build(BuildContext context) {
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
                animation: Listenable.merge(<Listenable>[_fill, _wave, _beat, _impact, _flatline]),
                builder: (BuildContext context, _) {
                  final double ratio = _fill.value.clamp(0.0, 1.0);
                  final double impact = _impact.value;
                  final bool critical = ratio <= 0.30 && !_isFlatline;
                  // Tremore: solo sotto il 30%, e solo per il tempo
                  // dell'impatto. Un tremore continuo stanca e distrae.
                  final double shake = critical ? math.sin(impact * math.pi * 7) * (1 - impact) * 2.4 : 0;

                  return CustomPaint(
                    size: Size.square(widget.size),
                    painter: _HeartPainter(
                      ratio: ratio,
                      color: CprPalette.healthColorFor(ratio),
                      wavePhase: _wave.value,
                      beatScale: _isFlatline ? 1.0 : _beatScale(_beat.value),
                      impact: impact,
                      impactColor: CprPalette.healthColorFor(ratio),
                      shake: shake,
                      flatlinePhase: _flatline.value,
                      showFlatline: _isFlatline,
                    ),
                  );
                },
              ),
            ),
            if (widget.showNumbers)
              AnimatedBuilder(
                animation: _fill,
                builder: (BuildContext context, _) {
                  final double ratio = _fill.value.clamp(0.0, 1.0);
                  final Color healthColor = CprPalette.healthColorFor(ratio);
                  final bool onLiquid = ratio > 0.50;

                  final Color numberColor = onLiquid
                      ? const Color(0xFFFFFFFF)
                      : (ratio <= 0 ? const Color(0xFFFF3B47) : healthColor);
                  final Color maxColor = onLiquid
                      ? const Color(0xCCFFFFFF)
                      : CprPalette.veil(const Color(0xFFE9EEF2), 0.7);
                  final Color labelColor = onLiquid
                      ? const Color(0xB3FFFFFF)
                      : (ratio <= 0 ? const Color(0xFFFF525E) : CprPalette.veil(healthColor, 0.9));

                  final List<Shadow> shadows = <Shadow>[
                    Shadow(
                      color: (ratio <= 0 ? const Color(0xFFFF3B47) : healthColor).withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ];

                  return Align(
                    alignment: const Alignment(0, 0.02),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AnimatedNumber(
                              value: widget.current,
                              style: CprType.numeral.copyWith(
                                color: numberColor,
                                fontSize: 34,
                                shadows: shadows,
                              ),
                              upColor: CprPalette.success,
                              downColor: CprPalette.danger,
                            ),
                            Text(
                              ' / ${widget.max}',
                              style: CprType.numeralSmall.copyWith(
                                color: maxColor,
                                fontSize: 15,
                                shadows: shadows,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        CprLabel(widget.label, color: labelColor, shadows: shadows),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter({
    required this.ratio,
    required this.color,
    required this.wavePhase,
    required this.beatScale,
    required this.impact,
    required this.impactColor,
    required this.shake,
    required this.flatlinePhase,
    required this.showFlatline,
  });

  final double ratio;
  final Color color;
  final double wavePhase;
  final double beatScale;
  final double impact;
  final Color impactColor;
  final double shake;
  final double flatlinePhase;
  final bool showFlatline;

  @override
  void paint(Canvas canvas, Size size) {
    final Path heart = _heartPath(size);
    final Rect bounds = heart.getBounds();

    canvas.save();
    // Contracolpo e battito applicati sul canvas: nessun widget ricostruito.
    canvas.translate(size.width / 2 + shake, size.height / 2);
    canvas.scale(beatScale + (1 - impact) * 0.035);
    canvas.translate(-size.width / 2, -size.height / 2);

    // 1. Alone: piu' intenso man mano che la vita scende.
    final double urgency = 1 - ratio;
    canvas.drawPath(
      heart,
      Paint()
        ..color = CprPalette.veil(color, 0.18 + 0.30 * urgency)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 16 * urgency),
    );

    // 2. Corpo vuoto.
    canvas.drawPath(heart, Paint()..color = CprPalette.surfaceSunken);

    // 3. Liquido, ritagliato dentro la sagoma.
    canvas.save();
    canvas.clipPath(heart);
    _paintLiquid(canvas, size, bounds);
    canvas.restore();

    // 4. Bordo.
    canvas.drawPath(
      heart,
      Paint()
        ..color = CprPalette.veil(color, 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 5. Anello d'impatto.
    if (impact < 1) {
      canvas.drawPath(
        heart,
        Paint()
          ..color = CprPalette.veil(impactColor, (1 - impact) * 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + 9 * impact
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 8 * impact),
      );
    }

    if (showFlatline) _paintEcg(canvas, size);

    canvas.restore();
  }

  void _paintLiquid(Canvas canvas, Size size, Rect bounds) {
    final double top = bounds.top + bounds.height * 0.10;
    final double bottom = bounds.bottom;
    final double waterY = bottom - (bottom - top) * ratio;

    // Onda posteriore: piu' ampia, piu' scura. Da' profondita' al liquido.
    canvas.drawPath(
      _wavePath(size, waterY, wavePhase * math.pi * 2, 5.0, 1.0),
      Paint()..color = CprPalette.veil(_darken(color, 0.55), 0.85),
    );

    // Onda anteriore, con gradiente verticale.
    final Path front = _wavePath(size, waterY, -wavePhase * math.pi * 2 * 1.4 + 1.1, 3.2, 1.6);
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            _lighten(color, 0.30),
            color,
            _darken(color, 0.35),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ).createShader(Rect.fromLTRB(0, waterY - 6, size.width, bottom)),
    );

    // Bagliore sulla superficie: e' il dettaglio che rende il liquido "bagnato".
    canvas.drawPath(
      front,
      Paint()
        ..color = CprPalette.veil(_lighten(color, 0.75), 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    _paintBubbles(canvas, size, waterY, bottom);
  }

  /// Bolle che risalgono verso la superficie. Sette, non settanta: sono un
  /// accento, e un liquido pieno di bolle sembra gassosa, non sangue.
  void _paintBubbles(Canvas canvas, Size size, double waterY, double bottom) {
    if (ratio <= 0.02 || bottom - waterY < 8) return;
    final double span = bottom - waterY;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      final double seed = i * 0.137 + 0.11;
      final double x = ((seed * 7.3) % 1.0) * size.width * 0.82 + size.width * 0.09;
      final double phase = (wavePhase * (0.55 + seed * 0.5) + seed) % 1.0;
      final double y = bottom - span * phase;
      final double r = 1.2 + 2.1 * ((seed * 3.1) % 1.0);
      paint.color = CprPalette.veil(_lighten(color, 0.85), (1 - phase) * 0.42 * math.min(1, span / 40));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  /// Tracciato ECG piatto con sweep: comunica "fermo" senza usare testo.
  void _paintEcg(Canvas canvas, Size size) {
    final double y = size.height * 0.52;
    final Path line = Path()
      ..moveTo(size.width * 0.20, y)
      ..lineTo(size.width * 0.38, y)
      ..lineTo(size.width * 0.42, y - 13)
      ..lineTo(size.width * 0.46, y + 9)
      ..lineTo(size.width * 0.50, y)
      ..lineTo(size.width * 0.80, y);

    canvas.drawPath(
      line,
      Paint()
        ..color = CprPalette.veil(CprPalette.healthFlatline, 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    final double sweepX = size.width * 0.20 + size.width * 0.60 * flatlinePhase;
    canvas.drawLine(
      Offset(sweepX, y - 16),
      Offset(sweepX, y + 12),
      Paint()
        ..color = CprPalette.veil(CprPalette.ink, 0.16)
        ..strokeWidth = 1,
    );
  }

  Path _wavePath(Size size, double waterY, double phase, double amp, double freq) {
    final Path path = Path()..moveTo(-2, waterY);
    const double stepPx = 3.0;
    for (double x = 0; x <= size.width + stepPx; x += stepPx) {
      final double y = waterY + math.sin((x / size.width) * freq * math.pi * 2 + phase) * amp;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width + stepPx, size.height + 2)
      ..lineTo(-2, size.height + 2)
      ..close();
    return path;
  }

  static Path _heartPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * -0.08, h * 0.54, w * 0.08, h * -0.10, w * 0.5, h * 0.20)
      ..cubicTo(w * 0.92, h * -0.10, w * 1.08, h * 0.54, w * 0.5, h * 0.92)
      ..close();
  }

  static Color _lighten(Color c, double amount) =>
      Color.lerp(c, const Color(0xFFFFFFFF), amount) ?? c;

  static Color _darken(Color c, double amount) =>
      Color.lerp(c, const Color(0xFF000000), amount) ?? c;

  @override
  bool shouldRepaint(_HeartPainter old) =>
      old.ratio != ratio ||
      old.color != color ||
      old.wavePhase != wavePhase ||
      old.beatScale != beatScale ||
      old.impact != impact ||
      old.shake != shake ||
      old.flatlinePhase != flatlinePhase ||
      old.showFlatline != showFlatline;
}
