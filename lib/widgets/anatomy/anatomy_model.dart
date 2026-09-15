import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bundled, decimated Z-Anatomy meshes. No network or platform plugin is needed.
class AnatomyModel {
  AnatomyModel(this.meshes);
  final List<AnatomyMesh> meshes;
  static Future<AnatomyModel>? _cached;

  static Future<AnatomyModel> load() => _cached ??= _load();

  static Future<AnatomyModel> _load() async {
    try {
      final ByteData data = await rootBundle.load(
        'assets/anatomy/body.mesh.json.gz',
      );
      return await compute(decodeAnatomy, data.buffer.asUint8List());
    } catch (_) {
      _cached = null;
      rethrow;
    }
  }
}

class AnatomyMesh {
  AnatomyMesh({
    required this.layer,
    required this.positions,
    required this.normals,
    required this.triangles,
    required this.zones,
  });
  final String layer;
  final Float32List positions;
  final Float32List normals;
  final Uint32List triangles;
  final Uint8List zones;
}

AnatomyModel decodeAnatomy(Uint8List bytes) {
  final Map<String, dynamic> json =
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
  if (json['format'] != 1) {
    throw const FormatException('Formato anatomico non supportato');
  }
  return AnatomyModel(
    (json['meshes'] as List<dynamic>)
        .map((dynamic value) {
          final Map<String, dynamic> m = value as Map<String, dynamic>;
          final Float32List p = Float32List.fromList(
            (m['p'] as List<dynamic>)
                .map((dynamic n) => (n as num) / 10000)
                .toList(),
          );
          final Float32List normals = Float32List.fromList(
            (m['n'] as List<dynamic>)
                .map((dynamic n) => (n as num) / 127)
                .toList(),
          );
          final Uint32List triangles = Uint32List.fromList(
            (m['t'] as List<dynamic>).cast<int>(),
          );
          final Uint8List zones = Uint8List.fromList(
            (m['z'] as List<dynamic>).cast<int>(),
          );
          if (p.length % 3 != 0 ||
              normals.length != p.length ||
              triangles.length % 3 != 0 ||
              zones.length * 3 != triangles.length ||
              triangles.any((int i) => i * 3 >= p.length) ||
              zones.any((int z) => z > 14)) {
            throw const FormatException('Geometria anatomica non valida');
          }
          return AnatomyMesh(
            layer: m['layer'] as String,
            positions: p,
            normals: normals,
            triangles: triangles,
            zones: zones,
          );
        })
        .toList(growable: false),
  );
}
