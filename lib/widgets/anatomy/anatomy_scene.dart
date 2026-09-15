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
  AnatomyFrame(this.faces, this.vertices, {this.auraVertices});
  final List<AnatomyFace> faces;
  final ui.Vertices vertices;

  /// A separate low-alpha copy of the body shell used to create the cyan
  /// x-ray glow without hiding the anatomical systems underneath it.
  final ui.Vertices? auraVertices;

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
    for (final AnatomyMesh mesh in model.meshes) {
      // The exported model contains only a compact aura, skeleton, vessels
      // and nerves. The aura is a glow-only silhouette; there is no skin or
      // muscle mesh to paint over the anatomical systems.
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
      final Color base = switch (mesh.layer) {
        'aura' || 'surface' => const Color(0xFF59E9FF),
        'skeleton' => const Color(0xFFE6D5BA),
        'muscles' => const Color(0xFFC98079),
        'arteries' => const Color(0xFFFF637A),
        'veins' => const Color(0xFF50B4ED),
        _ => const Color(0xFFF3D78A),
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
        final double rim = math.pow(1 - nz.abs().clamp(0, 1), 3).toDouble();
        final double spec =
            math
                .pow(math.max(0, -.22 * nx + .29 * ny + .93 * nz), 24)
                .toDouble() *
            .48;
        final double brightness = .19 + .72 * key;
        final int alpha = switch (mesh.layer) {
          'aura' || 'surface' => 18,
          'muscles' => layer == 'surface' ? 0 : 145,
          'skeleton' => 220,
          'arteries' || 'veins' || 'nervous' => 235,
          _ => 220,
        };
        colors[i ~/ 3] = Color.fromARGB(
          alpha,
          ((base.r * brightness + spec + rim * .05) * 255).round().clamp(
            0,
            255,
          ),
          ((base.g * brightness + spec + rim * .22) * 255).round().clamp(
            0,
            255,
          ),
          ((base.b * brightness + spec + rim * .24) * 255).round().clamp(
            0,
            255,
          ),
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
            selected ? const Color(0xFF51F5D4) : const Color(0xFFDCB46C),
            selected ? .53 : .28,
          )!.withValues(alpha: shell ? (selected ? .24 : .09) : 1).toARGB32();
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
          // Keep a second, additive copy for the soft blue diagnostic aura.
          auraPoints.addAll(<double>[ax, ay, bx, by, cx, cY]);
          auraColors.addAll(<int>[
            const Color(0x463EDFFF).toARGB32(),
            const Color(0x463EDFFF).toARGB32(),
            const Color(0x463EDFFF).toARGB32(),
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
      canvas.drawVertices(
        aura,
        BlendMode.plus,
        Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    canvas.drawVertices(frame.vertices, BlendMode.srcOver, Paint());
    if (aura != null) {
      // A second, lighter pass keeps the cyan silhouette readable over dense
      // anatomy without turning the organs into an opaque body.
      canvas.drawVertices(aura, BlendMode.plus, Paint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AnatomyPainter oldDelegate) => frame != oldDelegate.frame;
}
