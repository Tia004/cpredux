import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/cyberware.dart';
import 'anatomy_model.dart';

/// A perspective camera and triangle projection shared by drawing and picking.
/// This is actual 3D mesh geometry, including depth ordering and vertex normals.
class AnatomyCamera {
  const AnatomyCamera({
    this.yaw = -.18,
    this.pitch = 0,
    this.zoom = 1,
    this.pan = Offset.zero,
  });
  final double yaw;
  final double pitch;
  final double zoom;
  final Offset pan;

  AnatomyCamera orbit(double dx, double dy) => AnatomyCamera(
    yaw: (yaw + dx * .009) % (math.pi * 2),
    pitch: (pitch + dy * .007).clamp(-1.15, 1.15),
    zoom: zoom,
    pan: pan,
  );
  AnatomyCamera magnify(double value) => AnatomyCamera(
    yaw: yaw,
    pitch: pitch,
    zoom: value.clamp(.65, 3.5),
    pan: pan,
  );
  AnatomyCamera move(Offset delta) =>
      AnatomyCamera(yaw: yaw, pitch: pitch, zoom: zoom, pan: pan + delta);
}

class AnatomyFace {
  const AnatomyFace(
    this.ax,
    this.ay,
    this.bx,
    this.by,
    this.cx,
    this.cy,
    this.az,
    this.bz,
    this.cz,
    this.zone,
    this.ca,
    this.cb,
    this.cc,
    this.shell,
  );
  final double ax, ay, bx, by, cx, cy, az, bz, cz;
  final int zone, ca, cb, cc;
  final bool shell;
  double get depth => az + bz + cz;

  /// Barycentric interpolation selects the frontmost visible triangle, rather
  /// than fixed screen rectangles that break as soon as the body rotates.
  double? depthAt(Offset p) {
    final double d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy);
    if (d.abs() < .00001) return null;
    final double a = ((by - cy) * (p.dx - cx) + (cx - bx) * (p.dy - cy)) / d;
    final double b = ((cy - ay) * (p.dx - cx) + (ax - cx) * (p.dy - cy)) / d;
    if (a < 0 || b < 0 || a + b > 1) return null;
    return a * az + b * bz + (1 - a - b) * cz;
  }
}

class AnatomyFrame {
  AnatomyFrame(
    this.faces,
    this.vertices, {
    this.auraVertices,
    this.zoneAnchors = const <String, Offset>{},
    this.headCenter,
    this.headRadius = 40.0,
  });
  final List<AnatomyFace> faces;
  final ui.Vertices vertices;

  /// A separate glowing copy of the body shell used to create the luminous
  /// cyan holographic aura without hiding the anatomical systems underneath it.
  final ui.Vertices? auraVertices;

  /// Projected 2D screen coordinates for each body zone.
  final Map<String, Offset> zoneAnchors;

  /// Projected center of the head for cyberpsychosis effects.
  final Offset? headCenter;
  final double headRadius;

  String? pick(Offset position) {
    double closest = -double.infinity;
    int? zone;
    for (final AnatomyFace face in faces) {
      final double? depth = face.depthAt(position);
      if (depth != null && depth > closest) {
        closest = depth;
        zone = face.zone;
      }
    }
    return zone == null ? null : CyberBodyZone.values[zone].id;
  }

  static AnatomyFrame project({
    required AnatomyModel model,
    required Size size,
    required AnatomyCamera camera,
    required String layer,
    String? selectedZone,
    Set<String> installedZones = const <String>{},
  }) {
    final List<AnatomyFace> faces = <AnatomyFace>[];
    final double sy = math.sin(camera.yaw), cy = math.cos(camera.yaw);
    final double sp = math.sin(camera.pitch), cp = math.cos(camera.pitch);
    final double scale =
        math.min(size.height * .43, size.width * .84) * camera.zoom;
    final double centerX = size.width / 2 + camera.pan.dx;
    final double centerY = size.height * .49 + camera.pan.dy;
    final List<double> auraPoints = <double>[];
    final List<int> auraColors = <int>[];
    final Map<String, double> sumX = <String, double>{};
    final Map<String, double> sumY = <String, double>{};
    final Map<String, int> counts = <String, int>{};

    for (final AnatomyMesh mesh in model.meshes) {
      final bool shell = mesh.layer == 'aura' || mesh.layer == 'surface';
      final bool xray = layer == 'surface';
      final bool showInternal =
          (xray && mesh.layer != 'muscles') ||
          layer == 'all' ||
          mesh.layer == layer ||
          (layer == 'vascular' &&
              <String>{'arteries', 'veins'}.contains(mesh.layer));
      final bool show = shell || (layer != 'zones' && showInternal);
      if (!show) continue;
      final Float32List p = mesh.positions;
      final Float32List n = mesh.normals;
      final Float32List projected = Float32List(p.length);
      final Int32List colors = Int32List(p.length ~/ 3);
      // Stile Cyberpunk: titanio cromato per lo scheletro, neon vibrante per arterie/vene/nervi.
      final Color base = switch (mesh.layer) {
        'aura' || 'surface' => const Color(0xFF00F0FF),
        'skeleton' => const Color(0xFFD6F0FF),
        'muscles' => const Color(0xFFC98079),
        'arteries' => const Color(0xFFFF1E46),
        'veins' => const Color(0xFF00E5FF),
        _ => const Color(0xFFFFDE59),
      };
      for (int i = 0; i < p.length; i += 3) {
        final double rx = cy * p[i] + sy * p[i + 2];
        final double rz = -sy * p[i] + cy * p[i + 2];
        final double ry = cp * p[i + 1] - sp * rz;
        final double z = sp * p[i + 1] + cp * rz;
        final double perspective = 5 / (5 - z);
        projected[i] = centerX + rx * scale * perspective;
        projected[i + 1] = centerY - ry * scale * perspective;
        projected[i + 2] = z;
        final double nx = cy * n[i] + sy * n[i + 2];
        final double nz0 = -sy * n[i] + cy * n[i + 2];
        final double ny = cp * n[i + 1] - sp * nz0;
        final double nz = sp * n[i + 1] + cp * nz0;
        final double key = math.max(0, -.42 * nx + .57 * ny + .71 * nz);
        final double rim = math.pow(1 - nz.abs().clamp(0, 1), 2.2).toDouble();
        final double spec =
            math.pow(math.max(0, -.22 * nx + .29 * ny + .93 * nz), 18).toDouble() * .70;
        final double brightness = .22 + .78 * key;
        final int alpha = switch (mesh.layer) {
          'aura' || 'surface' => 38,
          'muscles' => layer == 'surface' ? 0 : 150,
          'skeleton' => 245,
          'arteries' || 'veins' || 'nervous' => 250,
          _ => 235,
        };
        colors[i ~/ 3] = Color.fromARGB(
          alpha,
          ((base.r * brightness + spec * .9 + rim * .25) * 255).round().clamp(0, 255),
          ((base.g * brightness + spec * .9 + rim * .45) * 255).round().clamp(0, 255),
          ((base.b * brightness + spec * .9 + rim * .55) * 255).round().clamp(0, 255),
        ).toARGB32();
      }
      final Uint32List indices = mesh.triangles;
      for (int i = 0; i < indices.length; i += 3) {
        final int ia = indices[i] * 3,
            ib = indices[i + 1] * 3,
            ic = indices[i + 2] * 3;
        final double ax = projected[ia], ay = projected[ia + 1];
        final double bx = projected[ib], by = projected[ib + 1];
        final double cx = projected[ic], cY = projected[ic + 1];
        // Counterclockwise world faces become clockwise in screen Y coordinates.
        if ((bx - ax) * (cY - ay) - (by - ay) * (cx - ax) >= 0) continue;
        final int zone = mesh.zones[i ~/ 3];
        final String id = CyberBodyZone.values[zone].id;
        final double midX = (ax + bx + cx) / 3.0;
        final double midY = (ay + by + cY) / 3.0;
        sumX[id] = (sumX[id] ?? 0) + midX;
        sumY[id] = (sumY[id] ?? 0) + midY;
        counts[id] = (counts[id] ?? 0) + 1;

        final bool selected =
            selectedZone == id || (selectedZone == 'skin' && shell);
        final bool installed =
            installedZones.contains(id) ||
            (installedZones.contains('skin') && shell);
        int tint(int raw) {
          if (!selected && !(layer == 'zones' && installed)) return raw;
          final Color original = Color(raw);
          return Color.lerp(
            original,
            selected ? const Color(0xFF00FFFF) : const Color(0xFFFF9900),
            selected ? .60 : .35,
          )!.withValues(alpha: shell ? (selected ? .35 : .12) : 1).toARGB32();
        }

        faces.add(
          AnatomyFace(
            ax,
            ay,
            bx,
            by,
            cx,
            cY,
            projected[ia + 2],
            projected[ib + 2],
            projected[ic + 2],
            zone,
            tint(colors[indices[i]]),
            tint(colors[indices[i + 1]]),
            tint(colors[indices[i + 2]]),
            shell,
          ),
        );
        if (shell) {
          // Copia additiva per l'alone corporeo azzurro cyberpunk.
          auraPoints.addAll(<double>[ax, ay, bx, by, cx, cY]);
          auraColors.addAll(<int>[
            const Color(0x6600E5FF).toARGB32(),
            const Color(0x6600E5FF).toARGB32(),
            const Color(0x6600E5FF).toARGB32(),
          ]);
        }
      }
    }
    faces.sort((AnatomyFace a, AnatomyFace b) {
      if (a.shell != b.shell) return a.shell ? 1 : -1;
      return a.depth.compareTo(b.depth);
    });
    final Float32List points = Float32List(faces.length * 6);
    final Int32List colors = Int32List(faces.length * 3);
    for (int i = 0; i < faces.length; i++) {
      final AnatomyFace f = faces[i];
      points.setRange(i * 6, i * 6 + 6, <double>[
        f.ax,
        f.ay,
        f.bx,
        f.by,
        f.cx,
        f.cy,
      ]);
      colors.setRange(i * 3, i * 3 + 3, <int>[f.ca, f.cb, f.cc]);
    }

    final Map<String, Offset> zoneAnchors = <String, Offset>{};
    for (final String id in sumX.keys) {
      final int c = counts[id] ?? 1;
      zoneAnchors[id] = Offset(sumX[id]! / c, sumY[id]! / c);
    }
    final Offset? headCenter = zoneAnchors['head'];
    final double headRadius = 38.0 * (scale / (size.height * 0.43)).clamp(0.5, 3.0);

    return AnatomyFrame(
      faces,
      ui.Vertices.raw(ui.VertexMode.triangles, points, colors: colors),
      auraVertices: auraPoints.isEmpty
          ? null
          : ui.Vertices.raw(
              ui.VertexMode.triangles,
              Float32List.fromList(auraPoints),
              colors: Int32List.fromList(auraColors),
            ),
      zoneAnchors: zoneAnchors,
      headCenter: headCenter,
      headRadius: headRadius,
    );
  }
}

class AnatomyPainter extends CustomPainter {
  AnatomyPainter(this.frame);
  final AnatomyFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final ui.Vertices? aura = frame.auraVertices;
    if (aura != null) {
      // Glow olografico azzurro cyberpunk a doppio stadio
      canvas.drawVertices(
        aura,
        BlendMode.plus,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawVertices(
        aura,
        BlendMode.plus,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawVertices(frame.vertices, BlendMode.srcOver, Paint());
    if (aura != null) {
      canvas.drawVertices(aura, BlendMode.plus, Paint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnatomyPainter oldDelegate) => frame != oldDelegate.frame;
}
