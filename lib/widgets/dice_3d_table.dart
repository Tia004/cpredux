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

  /// Generatore di un tetraedro regolare D4 (4 facce triangolari).
  static _DieModel createD4(double radius) {
    final double a = radius * 1.35 / math.sqrt(3.0);
    final List<_Vec3> v = <_Vec3>[
      _Vec3(a, a, a), // 0
      _Vec3(a, -a, -a), // 1
      _Vec3(-a, a, -a), // 2
      _Vec3(-a, -a, a), // 3
    ];

    const List<List<int>> faceIndices = <List<int>>[
      <int>[0, 2, 1], // Faccia 1
      <int>[0, 1, 3], // Faccia 2
      <int>[0, 3, 2], // Faccia 3
      <int>[1, 2, 3], // Faccia 4
    ];

    final List<_PolyFace> f = <_PolyFace>[];
    for (int i = 0; i < faceIndices.length; i++) {
      final List<int> idx = faceIndices[i];
      final _Vec3 n = (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]]).normalized();
      f.add(_PolyFace(indices: idx, value: i + 1, normal: n));
    }
    return _DieModel(vertices: v, faces: f);
  }

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

  /// Generatore di un ottaedro regolare D8 (8 facce triangolari equilatere).
  static _DieModel createD8(double radius) {
    final double r = radius * 1.18;
    final List<_Vec3> v = <_Vec3>[
      _Vec3(0, 0, r), // 0: apice sup
      _Vec3(r, 0, 0), // 1
      _Vec3(0, r, 0), // 2
      _Vec3(-r, 0, 0), // 3
      _Vec3(0, -r, 0), // 4
      _Vec3(0, 0, -r), // 5: apice inf
    ];

    const List<List<int>> faceIndices = <List<int>>[
      <int>[0, 1, 2], // 1
      <int>[0, 2, 3], // 3
      <int>[0, 3, 4], // 5
      <int>[0, 4, 1], // 7
      <int>[5, 2, 1], // 8 (opposta a 1)
      <int>[5, 3, 2], // 6 (opposta a 3)
      <int>[5, 4, 3], // 4 (opposta a 5)
      <int>[5, 1, 4], // 2 (opposta a 7)
    ];
    const List<int> values = <int>[1, 3, 5, 7, 8, 6, 4, 2];

    final List<_PolyFace> f = <_PolyFace>[];
    for (int i = 0; i < faceIndices.length; i++) {
      final List<int> idx = faceIndices[i];
      final _Vec3 n = (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]]).normalized();
      f.add(_PolyFace(indices: idx, value: values[i], normal: n));
    }
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

  /// Generatore di un dodecaedro regolare D12 (12 facce pentagonali regolari).
  static _DieModel createD12(double radius) {
    final double phi = (1.0 + math.sqrt(5.0)) / 2.0;
    final double invPhi = 1.0 / phi;
    final double scale = radius / math.sqrt(3.0);

    // 20 vertici del dodecaedro regolare
    final List<_Vec3> v = <_Vec3>[
      // (±1, ±1, ±1) [0..7]
      _Vec3(1, 1, 1) * scale,
      _Vec3(1, 1, -1) * scale,
      _Vec3(1, -1, 1) * scale,
      _Vec3(1, -1, -1) * scale,
      _Vec3(-1, 1, 1) * scale,
      _Vec3(-1, 1, -1) * scale,
      _Vec3(-1, -1, 1) * scale,
      _Vec3(-1, -1, -1) * scale,
      // (0, ±1/phi, ±phi) [8..11]
      _Vec3(0, invPhi, phi) * scale,
      _Vec3(0, invPhi, -phi) * scale,
      _Vec3(0, -invPhi, phi) * scale,
      _Vec3(0, -invPhi, -phi) * scale,
      // (±1/phi, ±phi, 0) [12..15]
      _Vec3(invPhi, phi, 0) * scale,
      _Vec3(invPhi, -phi, 0) * scale,
      _Vec3(-invPhi, phi, 0) * scale,
      _Vec3(-invPhi, -phi, 0) * scale,
      // (±phi, 0, ±1/phi) [16..19]
      _Vec3(phi, 0, invPhi) * scale,
      _Vec3(phi, 0, -invPhi) * scale,
      _Vec3(-phi, 0, invPhi) * scale,
      _Vec3(-phi, 0, -invPhi) * scale,
    ];

    // Le 12 facce pentagonali regolari perfettamente chiuse senza fessure
    const List<List<int>> faceIndices = <List<int>>[
      <int>[0, 12, 14, 4, 8],  // 1
      <int>[0, 8, 10, 2, 16],  // 2
      <int>[0, 16, 17, 1, 12], // 3
      <int>[1, 9, 5, 14, 12],  // 4
      <int>[1, 17, 3, 11, 9],  // 5
      <int>[2, 10, 6, 15, 13], // 6
      <int>[2, 13, 3, 17, 16], // 7
      <int>[3, 13, 15, 7, 11], // 8
      <int>[4, 18, 6, 10, 8],  // 9
      <int>[4, 14, 5, 19, 18], // 10
      <int>[5, 9, 11, 7, 19],  // 11
      <int>[6, 18, 19, 7, 15], // 12
    ];

    final List<_PolyFace> f = <_PolyFace>[];
    for (int i = 0; i < faceIndices.length; i++) {
      final List<int> idx = faceIndices[i];
      _Vec3 center = const _Vec3(0, 0, 0);
      for (final int vi in idx) {
        center = center + v[vi];
      }
      center = center * (1.0 / idx.length);
      _Vec3 n = (v[idx[1]] - v[idx[0]]).cross(v[idx[2]] - v[idx[0]]).normalized();
      if (n.dot(center) < 0) {
        n = n * -1.0;
      }
      f.add(_PolyFace(indices: idx, value: i + 1, normal: n));
    }
    return _DieModel(vertices: v, faces: f);
  }

  /// Generatore di un icosaedro regolare D20 (20 facce triangolari equilatere).
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

  /// Generatore di un Zocchihedron sferico geodetico D100 a 100 facce perfettamente chiuse e simmetriche.
  static _DieModel createD100(double radius) {
    const int n = 20; // 20 facce per fascia
    final List<_Vec3> v = <_Vec3>[];
    final List<List<int>> faceIndices = <List<int>>[];

    // Polo Nord (0) e Polo Sud (1)
    v.add(_Vec3(0, 0, radius)); // 0: Polo Nord
    v.add(_Vec3(0, 0, -radius)); // 1: Polo Sud

    _Vec3 spherePoint(double latDeg, double lonDeg) {
      final double lat = latDeg * math.pi / 180.0;
      final double lon = lonDeg * math.pi / 180.0;
      return _Vec3(
        radius * math.cos(lat) * math.cos(lon),
        radius * math.cos(lat) * math.sin(lon),
        radius * math.sin(lat),
      );
    }

    // Ring 1: 20 vertici a +54 gradi
    final int r1 = v.length;
    for (int i = 0; i < n; i++) {
      v.add(spherePoint(54.0, (i * 360.0) / n));
    }

    // Ring 2: 20 vertici a +18 gradi (sfasati di 9 gradi)
    final int r2 = v.length;
    for (int i = 0; i < n; i++) {
      v.add(spherePoint(18.0, (i * 360.0) / n + (180.0 / n)));
    }

    // Ring 3: 20 vertici a -18 gradi
    final int r3 = v.length;
    for (int i = 0; i < n; i++) {
      v.add(spherePoint(-18.0, (i * 360.0) / n));
    }

    // Ring 4: 20 vertici a -54 gradi (sfasati di 9 gradi)
    final int r4 = v.length;
    for (int i = 0; i < n; i++) {
      v.add(spherePoint(-54.0, (i * 360.0) / n + (180.0 / n)));
    }

    // Fascia 1: Calotta Polo Nord -> Ring 1 (20 triangoli)
    for (int i = 0; i < n; i++) {
      final int next = (i + 1) % n;
      faceIndices.add(<int>[0, r1 + i, r1 + next]);
    }

    // Fascia 2: Ring 1 -> Ring 2 (20 quadrilateri)
    for (int i = 0; i < n; i++) {
      final int next = (i + 1) % n;
      faceIndices.add(<int>[r1 + i, r2 + i, r2 + next, r1 + next]);
    }

    // Fascia 3: Fascia equatoriale Ring 2 -> Ring 3 (20 quadrilateri)
    for (int i = 0; i < n; i++) {
      final int next = (i + 1) % n;
      faceIndices.add(<int>[r2 + i, r3 + i, r3 + next, r2 + next]);
    }

    // Fascia 4: Ring 3 -> Ring 4 (20 quadrilateri)
    for (int i = 0; i < n; i++) {
      final int next = (i + 1) % n;
      faceIndices.add(<int>[r3 + i, r4 + i, r4 + next, r3 + next]);
    }

    // Fascia 5: Calotta Ring 4 -> Polo Sud (20 triangoli)
    for (int i = 0; i < n; i++) {
      final int next = (i + 1) % n;
      faceIndices.add(<int>[1, r4 + next, r4 + i]);
    }

    final List<_PolyFace> f = <_PolyFace>[];
    for (int i = 0; i < faceIndices.length; i++) {
      final List<int> idx = faceIndices[i];
      _Vec3 center = const _Vec3(0, 0, 0);
      for (final int vi in idx) {
        center = center + v[vi];
      }
      final _Vec3 normal = center.normalized();
      f.add(_PolyFace(indices: idx, value: i + 1, normal: normal));
    }

    return _DieModel(vertices: v, faces: f);
  }

  /// Generatore di una moneta cilindrica 3D con bordo poligonale spesso (Testa / Croce).
  static _DieModel createCoin(double radius) {
    const int segments = 16;
    const double thickness = 6.0;
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

    // Spessore 3D perimetrale (bordo cilindrico scanalato a 16 facce quadrate)
    for (int i = 0; i < segments; i++) {
      final int nextI = (i + 1) % segments;
      final int top1 = i;
      final int top2 = nextI;
      final int bot1 = segments + i;
      final int bot2 = segments + nextI;

      final double midAngle = (i + 0.5) * 2 * math.pi / segments;
      final _Vec3 rimNormal = _Vec3(math.cos(midAngle), math.sin(midAngle), 0.0);

      f.add(
        _PolyFace(
          indices: <int>[top1, top2, bot2, bot1],
          value: 0, // 0 = bordo perimetrale (senza numero)
          normal: rimNormal,
        ),
      );
    }

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

  @visibleForTesting
  static ({int vertices, int faces}) getMeshStatsForTesting(DiceType type) {
    final _DieModel model = switch (type) {
      DiceType.coin => _DieModel.createCoin(100.0),
      DiceType.d4 => _DieModel.createD4(100.0),
      DiceType.d6 => _DieModel.createD6(100.0),
      DiceType.d8 => _DieModel.createD8(100.0),
      DiceType.d10 => _DieModel.createD10(100.0),
      DiceType.d12 => _DieModel.createD12(100.0),
      DiceType.d20 => _DieModel.createD20(100.0),
      DiceType.d100 => _DieModel.createD100(100.0),
    };
    return (vertices: model.vertices.length, faces: model.faces.length);
  }

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

    final bool isCoin = widget.die == DiceType.coin;

    for (int i = 0; i < count; i++) {
      final double endX = startOffset + (i * spacing) + (_rng.nextDouble() * 12 - 6);
      final double endY = (_rng.nextDouble() * 24 - 12);
      final double startX = (_rng.nextDouble() > 0.5 ? -180.0 : 180.0) + (_rng.nextDouble() * 40 - 20);
      final double startY = 120.0 + (_rng.nextDouble() * 60);

      // Per la moneta: flip verticale velocissimo attorno all'asse orizzontale X
      final double spinX = isCoin
          ? (_rng.nextDouble() * 4.0 + 16.0) * math.pi
          : (_rng.nextDouble() * 12.0 + 8.0) * math.pi;
      final double spinY = isCoin
          ? (_rng.nextDouble() * 0.4 - 0.2) * math.pi
          : (_rng.nextDouble() * 14.0 + 8.0) * math.pi;
      final double spinZ = isCoin
          ? (_rng.nextDouble() * 0.4 - 0.2) * math.pi
          : (_rng.nextDouble() * 10.0 + 6.0) * math.pi;

      list.add(
        _ActiveDie(
          targetValue: res[i],
          dieType: widget.die,
          startX: startX,
          startY: startY,
          endX: endX,
          endY: endY,
          spinX: spinX,
          spinY: spinY,
          spinZ: spinZ,
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

    // Crea modello geometrico reale in base al tipo di dado
    final double dieSize = switch (dieType) {
      DiceType.d4 => 38.0,
      DiceType.d6 => 38.0,
      DiceType.d8 => 36.0,
      DiceType.d10 => 33.0,
      DiceType.d12 => 34.0,
      DiceType.d20 => 35.0,
      DiceType.d100 => 38.0,
      DiceType.coin => 34.0,
    };

    final _DieModel model = switch (dieType) {
      DiceType.d4 => _DieModel.createD4(dieSize * 0.85),
      DiceType.d6 => _DieModel.createD6(dieSize),
      DiceType.d8 => _DieModel.createD8(dieSize * 0.82),
      DiceType.d10 => _DieModel.createD10(dieSize * 0.72),
      DiceType.d12 => _DieModel.createD12(dieSize * 0.75),
      DiceType.d20 => _DieModel.createD20(dieSize * 0.78),
      DiceType.d100 => _DieModel.createD100(dieSize * 0.82),
      DiceType.coin => _DieModel.createCoin(dieSize * 0.88),
    };

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

    // 3. Proiezione prospettica 3D con camera inclinata sul tavolo
    const double camTilt = 0.52; // Inclinazione della vista verso il tavolo (~30°)
    final double cosTilt = math.cos(camTilt);
    final double sinTilt = math.sin(camTilt);

    final List<Offset> proj2D = <Offset>[];
    final List<double> vertexCamZ = <double>[];

    for (final _Vec3 v in rotVertices) {
      final double wx = v.x + curX;
      final double wy = v.y + curY;
      final double wz = v.z + bounceZ;

      // Coordinate nello spazio camera (allineata con la vista dall'alto)
      final double eyeX = wx;
      final double eyeY = wy * cosTilt - wz * sinTilt;
      final double eyeZ = wy * sinTilt + wz * cosTilt;
      vertexCamZ.add(eyeZ);

      final double camZ = _camDist - eyeZ;
      final double s = _focalLen / (camZ > 10.0 ? camZ : 10.0);

      proj2D.add(center + Offset(eyeX * s, eyeY * s));
    }

    // 4. Ordina le facce visibili per profondità (Painter's algorithm puro)
    final List<({_PolyFace face, double depth, _Vec3 camNormal})> sortedFaces = <({_PolyFace face, double depth, _Vec3 camNormal})>[];

    for (final _PolyFace face in model.faces) {
      final _Vec3 rotN = face.normal.rotate(rx, ry, rz);

      // Trasforma la normale nello spazio camera
      final double nCamX = rotN.x;
      final double nCamY = rotN.y * cosTilt - rotN.z * sinTilt;
      final double nCamZ = rotN.y * sinTilt + rotN.z * cosTilt;

      // Back-face culling rigoroso: le facce orientate all'indietro vengono rimosse
      // azzerando ogni trasparenza interna o sovrapposizione di wireframe
      if (nCamZ > 0.001) {
        double avgEyeZ = 0.0;
        for (final int idx in face.indices) {
          avgEyeZ += vertexCamZ[idx];
        }
        avgEyeZ /= face.indices.length;

        sortedFaces.add((
          face: face,
          depth: avgEyeZ,
          camNormal: _Vec3(nCamX, nCamY, nCamZ),
        ));
      }
    }

    sortedFaces.sort((a, b) => a.depth.compareTo(b.depth));

    // 5. Renderizza ciascuna faccia visibile come poligono solido opaco
    for (final item in sortedFaces) {
      final _PolyFace face = item.face;
      final _Vec3 n = item.camNormal;

      // Shading: Ambient + Diffuse contrastato
      final double diff = math.max(0.0, n.dot(lightDir));
      final double brightness = (0.35 + 0.65 * diff).clamp(0.25, 1.0);

      final Color baseDieColor = dieType == DiceType.d10
          ? const Color(0xFF1B242C)
          : const Color(0xFF1E2228);

      final Color tintedBase = Color.lerp(baseDieColor, accentColor, 0.10)!;

      // Colore solido al 100% (alpha 255) per evitare dadi trasparenti o cavi
      final Color faceColor = Color.fromARGB(
        255,
        (tintedBase.r * 255 * brightness).clamp(0, 255).toInt(),
        (tintedBase.g * 255 * brightness).clamp(0, 255).toInt(),
        (tintedBase.b * 255 * brightness).clamp(0, 255).toInt(),
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

      // Disegna poligono solido
      final Paint facePaint = Paint()
        ..color = faceColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(facePath, facePaint);

      // Bordo illuminato continuo e nitido della faccia
      final Paint strokePaint = Paint()
        ..color = accentColor.withValues(alpha: (0.45 + 0.50 * diff).clamp(0.0, 1.0))
        ..strokeWidth = 1.25
        ..style = PaintingStyle.stroke;
      canvas.drawPath(facePath, strokePaint);

      // Baricentro 2D per il numero
      double c2dX = 0.0;
      double c2dY = 0.0;
      for (final int idx in face.indices) {
        c2dX += proj2D[idx].dx;
        c2dY += proj2D[idx].dy;
      }
      c2dX /= face.indices.length;
      c2dY /= face.indices.length;

      // Disegna numero solo sulle facce ben orientate verso la camera
      if (face.value > 0) {
        final bool showNumber = switch (dieType) {
          DiceType.d100 => n.z >= 0.68,
          DiceType.d20 => n.z >= 0.45,
          _ => n.z >= 0.35,
        };
        if (showNumber) {
          _paintFaceNumber(canvas, Offset(c2dX, c2dY), face.value, n.z);
        }
      }
    }
  }

  void _paintFaceNumber(Canvas canvas, Offset pos, int value, double tilt) {
    if (value <= 0) return; // Non dipinge numero sul bordo cilindrico della moneta

    final String text;
    final double baseFontSize;
    if (dieType == DiceType.coin) {
      text = '$value';
      baseFontSize = 14.0;
    } else if (dieType == DiceType.d100) {
      text = '$value';
      baseFontSize = 8.5;
    } else if (dieType == DiceType.d20 || dieType == DiceType.d12) {
      text = '$value';
      baseFontSize = 10.5;
    } else {
      text = '$value';
      baseFontSize = 13.0;
    }

    final TextSpan span = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w900,
        fontSize: baseFontSize * tilt,
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
