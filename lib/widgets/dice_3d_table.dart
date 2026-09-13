import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';
import '../domain/enums.dart';

/// Vettore 3D per calcoli di rotazione, shading e proiezione prospettica.
class _Vec3 {
  const _Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  _Vec3 operator +(_Vec3 o) => _Vec3(x + o.x, y + o.y, z + o.z);
  _Vec3 operator -(_Vec3 o) => _Vec3(x - o.x, y - o.y, z - o.z);
  _Vec3 operator *(double s) => _Vec3(x * s, y * s, z * s);

  double dot(_Vec3 o) => x * o.x + y * o.y + z * o.z;

  _Vec3 cross(_Vec3 o) => _Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  _Vec3 normalized() {
    final double len = length;
    if (len < 0.0001) return const _Vec3(0, 0, 1);
    return _Vec3(x / len, y / len, z / len);
  }

  /// Ruota attorno all'asse X
  _Vec3 rotX(double rad) {
    final double c = math.cos(rad);
    final double s = math.sin(rad);
    return _Vec3(x, y * c - z * s, y * s + z * c);
  }

  /// Ruota attorno all'asse Y
  _Vec3 rotY(double rad) {
    final double c = math.cos(rad);
    final double s = math.sin(rad);
    return _Vec3(x * c + z * s, y, -x * s + z * c);
  }

  /// Ruota attorno all'asse Z
  _Vec3 rotZ(double rad) {
    final double c = math.cos(rad);
    final double s = math.sin(rad);
    return _Vec3(x * c - y * s, x * s + y * c, z);
  }

  _Vec3 rotate(double rx, double ry, double rz) {
    return rotZ(rz).rotY(ry).rotX(rx);
  }
}

/// Definizione di una faccia poliedrica.
class _PolyFace {
  _PolyFace({
    required this.indices,
    required this.value,
    required this.normal,
  });

  final List<int> indices;
  final int value;
  final _Vec3 normal;
}

/// Modello 3D geometrico per i vari tipi di dado.
class _DieModel {
  _DieModel({required this.vertices, required this.faces});

  final List<_Vec3> vertices;
  final List<_PolyFace> faces;

  /// Generatore di un cubo D6 con le facce opposte che sommano a 7:
  /// 1 opposto a 6, 2 opposto a 5, 3 opposto a 4.
  static _DieModel createD6(double size) {
    final double s = size / 2.0;
    final List<_Vec3> v = <_Vec3>[
      _Vec3(-s, -s, -s), // 0
      _Vec3(s, -s, -s), // 1
      _Vec3(s, s, -s), // 2
      _Vec3(-s, s, -s), // 3
      _Vec3(-s, -s, s), // 4
      _Vec3(s, -s, s), // 5
      _Vec3(s, s, s), // 6
      _Vec3(-s, s, s), // 7
    ];

    final List<_PolyFace> f = <_PolyFace>[
      // Faccia superiore (+Z): 6
      _PolyFace(indices: <int>[4, 5, 6, 7], value: 6, normal: const _Vec3(0, 0, 1)),
      // Faccia inferiore (-Z): 1
      _PolyFace(indices: <int>[3, 2, 1, 0], value: 1, normal: const _Vec3(0, 0, -1)),
      // Faccia frontale (+Y): 3
      _PolyFace(indices: <int>[7, 6, 2, 3], value: 3, normal: const _Vec3(0, 1, 0)),
      // Faccia posteriore (-Y): 4
      _PolyFace(indices: <int>[0, 1, 5, 4], value: 4, normal: const _Vec3(0, -1, 0)),
      // Faccia destra (+X): 5
      _PolyFace(indices: <int>[5, 1, 2, 6], value: 5, normal: const _Vec3(1, 0, 0)),
      // Faccia sinistra (-X): 2
      _PolyFace(indices: <int>[4, 7, 3, 0], value: 2, normal: const _Vec3(-1, 0, 0)),
    ];

    return _DieModel(vertices: v, faces: f);
  }

  /// Generatore di un trapezoedro pentagonale D10.
  static _DieModel createD10(double radius) {
    final double hApex = radius * 1.35;
    final double hMid = radius * 0.22;
    final List<_Vec3> v = <_Vec3>[
      _Vec3(0, 0, hApex), // 0: apice superiore
      _Vec3(0, 0, -hApex), // 1: apice inferiore
    ];

    // 5 vertici anello superiore
    for (int i = 0; i < 5; i++) {
      final double ang = (i * 2.0 * math.pi) / 5.0;
      v.add(_Vec3(radius * math.cos(ang), radius * math.sin(ang), hMid));
    }
    // 5 vertici anello inferiore sfasati di pi/5
    for (int i = 0; i < 5; i++) {
      final double ang = (i * 2.0 * math.pi) / 5.0 + (math.pi / 5.0);
      v.add(_Vec3(radius * math.cos(ang), radius * math.sin(ang), -hMid));
    }

    final List<_PolyFace> f = <_PolyFace>[];
    // 5 facce superiori (aquiloni o triangoli)
    for (int i = 0; i < 5; i++) {
      final int top1 = 2 + i;
      final int bot = 7 + i;
      final int top2 = 2 + ((i + 1) % 5);
      final _Vec3 n = (v[top1] - v[0]).cross(v[bot] - v[0]).normalized();
      final int val = ((i * 2) + 2); // 2, 4, 6, 8, 10
      f.add(_PolyFace(indices: <int>[0, top1, bot, top2], value: val, normal: n));
    }
    // 5 facce inferiori
    for (int i = 0; i < 5; i++) {
      final int bot1 = 7 + i;
      final int top = 2 + ((i + 1) % 5);
      final int bot2 = 7 + ((i + 1) % 5);
      final _Vec3 n = (v[top] - v[1]).cross(v[bot1] - v[1]).normalized();
      final int val = ((i * 2) + 1); // 1, 3, 5, 7, 9
      f.add(_PolyFace(indices: <int>[1, bot2, top, bot1], value: val, normal: n));
    }

    return _DieModel(vertices: v, faces: f);
  }

  /// Generatore di un icosaedro regolare D20.
  static _DieModel createD20(double radius) {
    final double phi = (1.0 + math.sqrt(5.0)) / 2.0;
    final double scale = radius / math.sqrt(1.0 + phi * phi);

    final List<_Vec3> v = <_Vec3>[
      _Vec3(-1, phi, 0) * scale,
      _Vec3(1, phi, 0) * scale,
      _Vec3(-1, -phi, 0) * scale,
      _Vec3(1, -phi, 0) * scale,
      _Vec3(0, -1, phi) * scale,
      _Vec3(0, 1, phi) * scale,
      _Vec3(0, -1, -phi) * scale,
      _Vec3(0, 1, -phi) * scale,
      _Vec3(phi, 0, -1) * scale,
      _Vec3(phi, 0, 1) * scale,
      _Vec3(-phi, 0, -1) * scale,
      _Vec3(-phi, 0, 1) * scale,
    ];

    const List<List<int>> faceIndices = <List<int>>[
      <int>[0, 11, 5], <int>[0, 5, 1], <int>[0, 1, 7], <int>[0, 7, 10], <int>[0, 10, 11],
      <int>[1, 5, 9], <int>[5, 11, 4], <int>[11, 10, 2], <int>[10, 7, 6], <int>[7, 1, 8],
      <int>[3, 9, 4], <int>[3, 4, 2], <int>[3, 2, 6], <int>[3, 6, 8], <int>[3, 8, 9],
      <int>[4, 9, 5], <int>[2, 4, 11], <int>[6, 2, 10], <int>[8, 6, 7], <int>[9, 8, 1],
    ];

    final List<_PolyFace> f = <_PolyFace>[];
    for (int i = 0; i < faceIndices.length; i++) {
      final List<int> idx = faceIndices[i];
      final _Vec3 n = (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]]).normalized();
      f.add(_PolyFace(indices: idx, value: i + 1, normal: n));
    }
    return _DieModel(vertices: v, faces: f);
  }

  /// Generatore di una moneta cilindrica (Testa / Croce).
  static _DieModel createCoin(double radius) {
    const int segments = 16;
    const double thickness = 5.0;
    final List<_Vec3> v = <_Vec3>[];

    // Cerchio superiore (+Z)
    for (int i = 0; i < segments; i++) {
      final double a = (i * 2 * math.pi) / segments;
      v.add(_Vec3(radius * math.cos(a), radius * math.sin(a), thickness / 2));
    }
    // Cerchio inferiore (-Z)
    for (int i = 0; i < segments; i++) {
      final double a = (i * 2 * math.pi) / segments;
      v.add(_Vec3(radius * math.cos(a), radius * math.sin(a), -thickness / 2));
    }

    final List<_PolyFace> f = <_PolyFace>[
      // Faccia Testa (1)
      _PolyFace(
        indices: List<int>.generate(segments, (int i) => i),
        value: 1,
        normal: const _Vec3(0, 0, 1),
      ),
      // Faccia Croce (2)
      _PolyFace(
        indices: List<int>.generate(segments, (int i) => segments * 2 - 1 - i),
        value: 2,
        normal: const _Vec3(0, 0, -1),
      ),
    ];
    return _DieModel(vertices: v, faces: f);
  }
}

/// Stato di un singolo dado lanciato sul tavolo con fisica di rotazione e rimbalzo.
class _ActiveDie {
  _ActiveDie({
    required this.targetValue,
    required this.dieType,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.spinX,
    required this.spinY,
    required this.spinZ,
  });

  final int targetValue;
  final DiceType dieType;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double spinX;
  final double spinY;
  final double spinZ;

  /// Rotazione calcolata per allineare la faccia target verso l'alto
  (double, double, double) getTargetAngles(_DieModel model) {
    // Cerca la faccia con il valore target
    _PolyFace? targetFace;
    for (final _PolyFace f in model.faces) {
      if (f.value == targetValue) {
        targetFace = f;
        break;
      }
    }
    targetFace ??= model.faces.first;

    // Vogliamo che la normale della faccia punti verso (0, 0, 1) nello spazio camera
    final _Vec3 n = targetFace.normal;
    // Angoli di rotazione per orientare n verso +Z
    final double pitch = math.atan2(n.y, n.z);
    final double yaw = -math.atan2(n.x, math.sqrt(n.y * n.y + n.z * n.z));
    return (pitch, yaw, 0.0);
  }
}

/// Visualizer 3D dei dadi tirati su un tavolo spazioso cyberpunk.
class Dice3DTable extends StatefulWidget {
  const Dice3DTable({
    super.key,
    required this.die,
    required this.results,
    required this.total,
    required this.label,
    required this.modifier,
    required this.isCritical,
    required this.isFumble,
    required this.revealKey,
    this.tableHeight = 280.0,
  });

  final DiceType die;
  final List<int> results;
  final int total;
  final String label;
  final int modifier;
  final bool isCritical;
  final bool isFumble;
  final int revealKey;
  final double tableHeight;

  @override
  State<Dice3DTable> createState() => _Dice3DTableState();
}

class _Dice3DTableState extends State<Dice3DTable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rollAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  final math.Random _rng = math.Random();
  List<_ActiveDie> _activeDice = <_ActiveDie>[];

  @override
  void initState() {
    super.initState();
    _rollAnim.addListener(() => setState(() {}));
    _setupDice();
    _rollAnim.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant Dice3DTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealKey != oldWidget.revealKey ||
        widget.results != oldWidget.results) {
      _setupDice();
      _rollAnim.forward(from: 0.0);
    }
  }

  void _setupDice() {
    final List<int> res = widget.results.isEmpty ? <int>[widget.total] : widget.results;
    final int count = res.length.clamp(1, 8);
    final List<_ActiveDie> list = <_ActiveDie>[];

    // Distribuzione posizioni finali sul tavolo
    final double spacing = 52.0;
    final double startOffset = -((count - 1) * spacing) / 2.0;

    for (int i = 0; i < count; i++) {
      final double endX = startOffset + (i * spacing) + (_rng.nextDouble() * 12 - 6);
      final double endY = (_rng.nextDouble() * 24 - 12);
      final double startX = (_rng.nextDouble() > 0.5 ? -180.0 : 180.0) + (_rng.nextDouble() * 40 - 20);
      final double startY = 120.0 + (_rng.nextDouble() * 60);

      list.add(
        _ActiveDie(
          targetValue: res[i],
          dieType: widget.die,
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          spinX: (_rng.nextDouble() * 12.0 + 8.0) * math.pi,
          spinY: (_rng.nextDouble() * 14.0 + 8.0) * math.pi,
          spinZ: (_rng.nextDouble() * 10.0 + 6.0) * math.pi,
        ),
      );
    }

    setState(() => _activeDice = list);
  }

  @override
  void dispose() {
    _rollAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.isCritical
        ? CprPalette.success
        : widget.isFumble
            ? CprPalette.danger
            : CprPalette.yellow;

    return Container(
      height: widget.tableHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1014),
        border: Border.all(
          color: widget.isCritical
              ? CprPalette.success.withValues(alpha: 0.8)
              : widget.isFumble
                  ? CprPalette.danger.withValues(alpha: 0.8)
                  : CprPalette.veil(CprPalette.cyan, 0.4),
          width: widget.isCritical || widget.isFumble ? 1.6 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: widget.isCritical || widget.isFumble ? 0.25 : 0.08),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Texture tavolo da gioco cyberpunk con griglia tattica
          Positioned.fill(
            child: CustomPaint(
              painter: _TableTrayPainter(
                accent: accent,
                isCritical: widget.isCritical,
                pulse: _rollAnim.value,
              ),
            ),
          ),

          // Canvas 3D dei dadi
          Positioned.fill(
            child: CustomPaint(
              painter: _Dice3DRenderer(
                dice: _activeDice,
                progress: _rollAnim.value,
                dieType: widget.die,
                accentColor: accent,
              ),
            ),
          ),

          // Banner con Risultato e Dettaglio sovrapposto in trasparenza
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: AnimatedBuilder(
              animation: _rollAnim,
              builder: (BuildContext context, _) {
                final double t = Curves.easeOutCubic.transform(_rollAnim.value);
                final bool finished = _rollAnim.value >= 0.75;
                final double opacity = finished ? ((_rollAnim.value - 0.75) / 0.25).clamp(0.0, 1.0) : 0.0;

                return Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, (1.0 - t) * 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: CprPalette.surface.withValues(alpha: 0.88),
                        border: Border(
                          left: BorderSide(color: accent, width: 3),
                          top: BorderSide(color: CprPalette.hairline),
                          right: BorderSide(color: CprPalette.hairline),
                          bottom: BorderSide(color: CprPalette.hairline),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          // Risultato grande
                          Text(
                            '${widget.total}',
                            style: CprType.display.copyWith(
                              fontSize: 32,
                              color: accent,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Dettaglio tiro
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  widget.label.toUpperCase(),
                                  style: CprType.label.copyWith(
                                    color: CprPalette.ink,
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _buildDetailString(),
                                  style: CprType.caption.copyWith(
                                    color: CprPalette.inkMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Badge critico / fallimento
                          if (widget.isCritical)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              color: CprPalette.veil(CprPalette.success, 0.22),
                              child: Text(
                                'CRITICO',
                                style: CprType.label.copyWith(
                                  color: CprPalette.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (widget.isFumble)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              color: CprPalette.veil(CprPalette.danger, 0.22),
                              child: Text(
                                'FALLIMENTO CRITICO',
                                style: CprType.label.copyWith(
                                  color: CprPalette.danger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildDetailString() {
    if (widget.results.length > 1) {
      final String parts = widget.results.join(' + ');
      final String mod = widget.modifier == 0
          ? ''
          : widget.modifier > 0
              ? ' + ${widget.modifier}'
              : ' - ${widget.modifier.abs()}';
      return '$parts$mod = ${widget.total}';
    }
    if (widget.modifier != 0) {
      final String mod = widget.modifier > 0 ? '+${widget.modifier}' : '${widget.modifier}';
      return '${widget.results.isNotEmpty ? widget.results.first : widget.total} ($mod)';
    }
    return '${widget.die.label} (${widget.total})';
  }
}

/// Sfondo e bordi del tavolo/tray con estetica Cyberpunk e griglia tattica.
class _TableTrayPainter extends CustomPainter {
  _TableTrayPainter({
    required this.accent,
    required this.isCritical,
    required this.pulse,
  });

  final Color accent;
  final bool isCritical;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Gradiente radiale tavolo (sensazione di feltro scuro illuminato dall'alto)
    final Paint bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width / 2, size.height * 0.45),
        size.width * 0.7,
        <Color>[
          const Color(0xFF141A22),
          const Color(0xFF090D10),
        ],
      );
    canvas.drawRect(rect, bgPaint);

    // Griglia tattica isometrica sottile
    final Paint gridPaint = Paint()
      ..color = const Color(0x1820E8FF)
      ..strokeWidth = 0.8;

    const double step = 34.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Angoli a spacco (chamfer) tipici di Cyberpunk Red
    final Paint cornerPaint = Paint()
      ..color = accent.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double clen = 16.0;
    // Top-Left
    canvas.drawLine(const Offset(4, 4), const Offset(4 + clen, 4), cornerPaint);
    canvas.drawLine(const Offset(4, 4), const Offset(4, 4 + clen), cornerPaint);
    // Top-Right
    canvas.drawLine(Offset(size.width - 4, 4), Offset(size.width - 4 - clen, 4), cornerPaint);
    canvas.drawLine(Offset(size.width - 4, 4), Offset(size.width - 4, 4 + clen), cornerPaint);
    // Bottom-Left
    canvas.drawLine(Offset(4, size.height - 4), Offset(4 + clen, size.height - 4), cornerPaint);
    canvas.drawLine(Offset(4, size.height - 4), Offset(4, size.height - 4 - clen), cornerPaint);
    // Bottom-Right
    canvas.drawLine(Offset(size.width - 4, size.height - 4), Offset(size.width - 4 - clen, size.height - 4), cornerPaint);
    canvas.drawLine(Offset(size.width - 4, size.height - 4), Offset(size.width - 4, 4 + clen), cornerPaint);

    // Effetto bagliore critico
    if (isCritical) {
      final double waveRadius = (pulse * size.width * 0.75);
      final Paint wavePaint = Paint()
        ..color = CprPalette.success.withValues(alpha: (1.0 - pulse) * 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(size.width / 2, size.height * 0.45), waveRadius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TableTrayPainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.isCritical != isCritical ||
      oldDelegate.pulse != pulse;
}

/// Renderer 3D con camera, ombre, backface culling e proiezioni per i dadi.
class _Dice3DRenderer extends CustomPainter {
  _Dice3DRenderer({
    required this.dice,
    required this.progress,
    required this.dieType,
    required this.accentColor,
  });

  final List<_ActiveDie> dice;
  final double progress;
  final DiceType dieType;
  final Color accentColor;

  static const double _camDist = 420.0;
  static const double _focalLen = 380.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (dice.isEmpty) return;

    final Offset center = Offset(size.width / 2, size.height * 0.44);

    // Crea modello geometrico in base al tipo di dado
    final _DieModel model;
    final double dieSize = dieType == DiceType.d10 ? 32.0 : (dieType == DiceType.d6 ? 38.0 : 34.0);

    switch (dieType) {
      case DiceType.d6:
        model = _DieModel.createD6(dieSize);
        break;
      case DiceType.d10:
      case DiceType.d100:
        model = _DieModel.createD10(dieSize * 0.72);
        break;
      case DiceType.d20:
        model = _DieModel.createD20(dieSize * 0.78);
        break;
      case DiceType.coin:
        model = _DieModel.createCoin(dieSize * 0.85);
        break;
      default:
        model = _DieModel.createD6(dieSize);
    }

    // Direzione luce: da in alto a sinistra verso il tavolo
    final _Vec3 lightDir = const _Vec3(-0.45, -0.65, 0.75).normalized();

    // Disegna ciascun dado
    for (final _ActiveDie die in dice) {
      _renderSingleDie(canvas, center, die, model, lightDir);
    }
  }

  void _renderSingleDie(
    Canvas canvas,
    Offset center,
    _ActiveDie die,
    _DieModel model,
    _Vec3 lightDir,
  ) {
    // Fisica: progressione con curva di rimbalzo
    final double t = progress.clamp(0.0, 1.0);

    // Posizione sul tavolo: interpolazione lineare da start a end
    final double curX = ui.lerpDouble(die.startX, die.endX, Curves.easeOutQuad.transform(t))!;
    final double curY = ui.lerpDouble(die.startY, die.endY, Curves.easeOutQuad.transform(t))!;

    // Altezza dal tavolo (Z): serie di rimbalzi
    final double bounceZ;
    if (t < 0.40) {
      final double subT = t / 0.40;
      bounceZ = math.sin(subT * math.pi) * 85.0 * (1.0 - subT * 0.3);
    } else if (t < 0.70) {
      final double subT = (t - 0.40) / 0.30;
      bounceZ = math.sin(subT * math.pi) * 35.0;
    } else if (t < 0.90) {
      final double subT = (t - 0.70) / 0.20;
      bounceZ = math.sin(subT * math.pi) * 12.0;
    } else {
      bounceZ = 0.0;
    }

    // Angoli di rotazione: all'inizio ruotano velocemente, alla fine si assestano sul target
    final (double targetRx, double targetRy, double targetRz) = die.getTargetAngles(model);

    final double spinDecay = math.pow(1.0 - t, 2.5).toDouble();
    final double rx = targetRx + die.spinX * spinDecay;
    final double ry = targetRy + die.spinY * spinDecay;
    final double rz = targetRz + die.spinZ * spinDecay;

    // 1. Disegna ombra proiettata sul tavolo a Z = 0
    final double shadowScale = (1.0 - (bounceZ / 120.0).clamp(0.0, 0.7));
    final double shadowOpacity = (0.55 * (1.0 - (bounceZ / 140.0).clamp(0.0, 0.8)));

    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: shadowOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6.0 + bounceZ * 0.08);

    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(curX + bounceZ * 0.15, curY + bounceZ * 0.2),
        width: 44.0 * shadowScale,
        height: 26.0 * shadowScale,
      ),
      shadowPaint,
    );

    // 2. Ruota i vertici del modello
    final List<_Vec3> rotVertices = <_Vec3>[];
    for (final _Vec3 v in model.vertices) {
      rotVertices.add(v.rotate(rx, ry, rz));
    }

    // 3. Calcola proiezioni 2D dei vertici
    final List<Offset> proj2D = <Offset>[];
    for (final _Vec3 v in rotVertices) {
      final double worldX = v.x + curX;
      final double worldY = v.y + curY;
      final double worldZ = v.z + bounceZ;

      // Proiezione prospettica con camera inclinata
      final double camZ = _camDist - worldZ;
      final double s = _focalLen / (camZ > 10.0 ? camZ : 10.0);

      proj2D.add(center + Offset(worldX * s, (worldY - worldZ * 0.6) * s));
    }

    // 4. Ordina le facce per profondità (Painter's algorithm)
    final List<({_PolyFace face, double depth, _Vec3 rotNormal})> sortedFaces = <({_PolyFace face, double depth, _Vec3 rotNormal})>[];

    for (final _PolyFace face in model.faces) {
      final _Vec3 rotN = face.normal.rotate(rx, ry, rz);

      // Back-face culling: normale rivolta verso la camera
      if (rotN.z > -0.15) {
        double avgZ = 0.0;
        for (final int idx in face.indices) {
          avgZ += rotVertices[idx].z;
        }
        avgZ /= face.indices.length;

        sortedFaces.add((face: face, depth: avgZ, rotNormal: rotN));
      }
    }

    sortedFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // 5. Renderizza ciascuna faccia visibile
    for (final item in sortedFaces) {
      final _PolyFace face = item.face;
      final _Vec3 n = item.rotNormal;

      // Shading: Ambient + Diffuse
      final double diff = math.max(0.0, n.dot(lightDir));
      final double brightness = 0.28 + 0.72 * diff;

      final Color baseDieColor = dieType == DiceType.d10
          ? const Color(0xFF1B242C)
          : const Color(0xFF1E2228);

      final Color faceColor = Color.lerp(
        baseDieColor,
        accentColor,
        0.08,
      )!
          .withValues(
            red: (baseDieColor.r * brightness).clamp(0.0, 1.0),
            green: (baseDieColor.g * brightness).clamp(0.0, 1.0),
            blue: (baseDieColor.b * brightness).clamp(0.0, 1.0),
          );

      final Path facePath = Path();
      for (int i = 0; i < face.indices.length; i++) {
        final Offset pt = proj2D[face.indices[i]];
        if (i == 0) {
          facePath.moveTo(pt.dx, pt.dy);
        } else {
          facePath.lineTo(pt.dx, pt.dy);
        }
      }
      facePath.close();

      // Disegna poligono faccia
      final Paint facePaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(facePath, facePaint);

      // Bordo illuminato della faccia
      final Paint strokePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.35 + 0.45 * diff)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke;
      canvas.drawPath(facePath, strokePaint);

      // Calcola baricentro 2D per il numero
      double c2dX = 0.0;
      double c2dY = 0.0;
      for (final int idx in face.indices) {
        c2dX += proj2D[idx].dx;
        c2dY += proj2D[idx].dy;
      }
      c2dX /= face.indices.length;
      c2dY /= face.indices.length;

      // Disegna numero sulla faccia solo se è abbastanza rivolta verso lo schermo
      if (n.z > 0.35) {
        _paintFaceNumber(canvas, Offset(c2dX, c2dY), face.value, n.z);
      }
    }
  }

  void _paintFaceNumber(Canvas canvas, Offset pos, int value, double tilt) {
    final String text = '$value';
    final TextSpan span = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w900,
        fontSize: 13.0 * tilt,
        color: accentColor.withValues(alpha: (0.75 + 0.25 * tilt).clamp(0.0, 1.0)),
        shadows: <Shadow>[
          Shadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 2.0,
          ),
        ],
      ),
    );

    final TextPainter tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _Dice3DRenderer oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.dice != dice ||
      oldDelegate.dieType != dieType ||
      oldDelegate.accentColor != accentColor;
}
