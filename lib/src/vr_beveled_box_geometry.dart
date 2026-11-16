import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// CPU-side vertex and index buffers produced by [VrBeveledBoxGeometry],
/// allowing deterministic geometric, normal, winding, and tangent verification
/// in headless tests without an active GPU context.
final class VrBeveledBoxArrays {
  const VrBeveledBoxArrays({
    required this.positions,
    required this.normals,
    required this.texCoords,
    required this.colors,
    required this.tangents,
    required this.indices,
  });

  final Float32List positions;
  final Float32List normals;
  final Float32List texCoords;
  final Float32List colors;
  final Float32List tangents;
  final List<int> indices;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;
}

/// Machined 3D rounded/beveled box & stadium-pill geometry generator for
/// spatial UI controls (`VrButton3D`, `VrCard3D`, `VrPanel3D`, `VrChip3D`,
/// `VrSwitch3D`, `VrDialog3D`, etc.) and architectural/prop slabs.
///
/// Replaces sharp 24-vertex boxes with smooth XY corner fillets (`cornerRadius`)
/// and front/back Z chamfers/fillets (`bevelZ`) so grazing IBL and directional
/// lights catch realistic specular rim highlights in stereoscopic VR.
///
/// Uploaded [MeshGeometry] instances are deduplicated in a bounded LRU cache
/// keyed by quantized dimensions (`0.1 mm` precision), so dozens of controls of
/// the same size share a single GPU buffer upload.
abstract final class VrBeveledBoxGeometry {
  static const int _maxCachedGeometries = 96;
  static final LinkedHashMap<Object, MeshGeometry> _gpuCache =
      LinkedHashMap<Object, MeshGeometry>();

  /// Clears cached GPU geometries (useful in tests or low-memory teardowns).
  static void clearCache() => _gpuCache.clear();

  static int get cachedCount => _gpuCache.length;

  /// Creates (or returns cached) a filleted 3D box centered at the origin with
  /// exact outer extents [size] (`x = width`, `y = height`, `z = depth`).
  static MeshGeometry create(
    vm.Vector3 size, {
    double? cornerRadius,
    double? bevelZ,
    int cornerSegments = 3,
    int bevelSegments = 2,
  }) {
    final w = math.max(size.x.abs(), 1e-4);
    final h = math.max(size.y.abs(), 1e-4);
    final d = math.max(size.z.abs(), 1e-4);
    final minPlanar = math.min(w, h);
    final resolvedCorner =
        (cornerRadius ?? (minPlanar * 0.16).clamp(0.004, 0.045))
            .clamp(0.0005, minPlanar * 0.49)
            .toDouble();
    final resolvedBevel = (bevelZ ?? (d * 0.24).clamp(0.002, 0.016))
        .clamp(0.0002, math.min(d * 0.48, resolvedCorner * 0.98))
        .toDouble();
    final cSegs = cornerSegments.clamp(1, 8);
    final bSegs = bevelSegments.clamp(1, 4);

    final key = (
      (w * 10000).round(),
      (h * 10000).round(),
      (d * 10000).round(),
      (resolvedCorner * 10000).round(),
      (resolvedBevel * 10000).round(),
      cSegs,
      bSegs,
    );

    final existing = _gpuCache.remove(key);
    if (existing != null) {
      _gpuCache[key] = existing;
      return existing;
    }

    final arrays = buildArrays(
      vm.Vector3(w, h, d),
      cornerRadius: resolvedCorner,
      bevelZ: resolvedBevel,
      cornerSegments: cSegs,
      bevelSegments: bSegs,
    );
    final geo = MeshGeometry.fromArrays(
      positions: arrays.positions,
      normals: arrays.normals,
      texCoords: arrays.texCoords,
      colors: arrays.colors,
      tangents: arrays.tangents,
      indices: arrays.indices,
    );

    while (_gpuCache.length >= _maxCachedGeometries) {
      _gpuCache.remove(_gpuCache.keys.first);
    }
    _gpuCache[key] = geo;
    return geo;
  }

  /// Convenience preset for stadium-shaped 3D pills (`VrChip3D`, `VrSwitch3D`,
  /// slider tracks, segmented indicators).
  static MeshGeometry pill(
    vm.Vector3 size, {
    double? bevelZ,
    int cornerSegments = 4,
    int bevelSegments = 2,
  }) {
    final minPlanar = math.min(size.x.abs(), size.y.abs());
    return create(
      size,
      cornerRadius: minPlanar * 0.48,
      bevelZ: bevelZ ?? (size.z.abs() * 0.30).clamp(0.002, 0.018),
      cornerSegments: cornerSegments,
      bevelSegments: bevelSegments,
    );
  }

  /// Convenience preset for architectural/UI spatial slabs (`VrCard3D`,
  /// `VrPanel3D`, `VrDialog3D`, `VrWorldActionPanel3D`).
  static MeshGeometry panel(
    vm.Vector3 size, {
    double cornerRadius = 0.036,
    double? bevelZ,
    int cornerSegments = 3,
    int bevelSegments = 2,
  }) => create(
    size,
    cornerRadius: cornerRadius,
    bevelZ: bevelZ ?? (size.z.abs() * 0.22).clamp(0.002, 0.014),
    cornerSegments: cornerSegments,
    bevelSegments: bevelSegments,
  );

  /// Pure-Dart builder generating watertight CCW positions, smooth normals,
  /// distortion-free UVs, and orthonormal glTF 2.0 tangents (`vec4`).
  static VrBeveledBoxArrays buildArrays(
    vm.Vector3 size, {
    double? cornerRadius,
    double? bevelZ,
    int cornerSegments = 3,
    int bevelSegments = 2,
  }) {
    final w = math.max(size.x.abs(), 1e-4);
    final h = math.max(size.y.abs(), 1e-4);
    final d = math.max(size.z.abs(), 1e-4);
    final hx = w * 0.5;
    final hy = h * 0.5;
    final hz = d * 0.5;

    final cSegs = cornerSegments.clamp(1, 12);
    final bSegs = bevelSegments.clamp(1, 6);

    final minHalfPlanar = math.min(hx, hy);
    final defaultCorner = (math.min(w, h) * 0.16).clamp(0.004, 0.045);
    var rx = (cornerRadius ?? defaultCorner)
        .clamp(0.0005, minHalfPlanar * 0.98)
        .toDouble();
    final defaultBevel = (d * 0.24).clamp(0.002, 0.016);
    var rz = (bevelZ ?? defaultBevel)
        .clamp(0.0002, math.min(hz * 0.96, rx * 0.98))
        .toDouble();
    if (rx < rz) rx = rz;

    // 1. Build 2D CCW rounded-rectangle outer stations + wrap seam station.
    final cxAbs = math.max(0.0, hx - rx);
    final cyAbs = math.max(0.0, hy - rx);
    const quadSigns = <(double, double)>[
      (1.0, 1.0),
      (-1.0, 1.0),
      (-1.0, -1.0),
      (1.0, -1.0),
    ];

    final outerX = <double>[];
    final outerY = <double>[];
    final norm2X = <double>[];
    final norm2Y = <double>[];

    for (var q = 0; q < 4; q++) {
      final (sx, sy) = quadSigns[q];
      final baseAngle = q * (math.pi * 0.5);
      for (var k = 0; k <= cSegs; k++) {
        final theta = baseAngle + (k / cSegs) * (math.pi * 0.5);
        final ct = math.cos(theta);
        final st = math.sin(theta);
        outerX.add(sx * cxAbs + rx * ct);
        outerY.add(sy * cyAbs + rx * st);
        norm2X.add(ct);
        norm2Y.add(st);
      }
    }
    final perimCount = outerX.length; // 4 * (cSegs + 1)
    // Duplicate station 0 at wrap seam for continuous UVs around perimeter:
    outerX.add(outerX[0]);
    outerY.add(outerY[0]);
    norm2X.add(norm2X[0]);
    norm2Y.add(norm2Y[0]);
    final stride = perimCount + 1;

    final perimArc = List<double>.filled(stride, 0.0);
    for (var j = 1; j < stride; j++) {
      final dx = outerX[j] - outerX[j - 1];
      final dy = outerY[j] - outerY[j - 1];
      perimArc[j] = perimArc[j - 1] + math.sqrt(dx * dx + dy * dy);
    }
    final totalPerim = perimArc.last > 1e-9 ? perimArc.last : 1.0;

    // 2. Build Z-profile slices `(cosPhi, sinPhi, zCoord)` from back (-hz) to front (+hz).
    final zInner = math.max(0.0, hz - rz);
    final zSlices = <(double cosP, double sinP, double z)>[];

    // Back bevel: phi in [-pi/2 .. 0]
    for (var b = 0; b <= bSegs; b++) {
      final phi = -math.pi * 0.5 + (b / bSegs) * (math.pi * 0.5);
      final cp = b == 0 ? 0.0 : (b == bSegs ? 1.0 : math.cos(phi));
      final sp = b == 0 ? -1.0 : (b == bSegs ? 0.0 : math.sin(phi));
      zSlices.add((cp, sp, -zInner + rz * sp));
    }
    // Flat equator wall if zInner > 0, then front bevel phi in (0 .. +pi/2]:
    final startFront = zInner > 1e-6 ? 0 : 1;
    for (var b = startFront; b <= bSegs; b++) {
      final phi = (b / bSegs) * (math.pi * 0.5);
      final cp = b == 0 ? 1.0 : (b == bSegs ? 0.0 : math.cos(phi));
      final sp = b == 0 ? 0.0 : (b == bSegs ? 1.0 : math.sin(phi));
      zSlices.add((cp, sp, zInner + rz * sp));
    }

    final ringCount = zSlices.length;
    final zArc = List<double>.filled(ringCount, 0.0);
    for (var r = 1; r < ringCount; r++) {
      final dr = (zSlices[r].$1 - zSlices[r - 1].$1) * rz;
      final dz = zSlices[r].$3 - zSlices[r - 1].$3;
      zArc[r] = zArc[r - 1] + math.sqrt(dr * dr + dz * dz);
    }
    final totalZArc = zArc.last > 1e-9 ? zArc.last : 1.0;

    // Vertex budget:
    // - `ringCount * stride` side/bevel vertices
    // - `1 + perimCount` front cap vertices (planar UVs)
    // - `1 + perimCount` back cap vertices (planar UVs)
    final sideVerts = ringCount * stride;
    final capVertsEach = 1 + perimCount;
    final totalVerts = sideVerts + capVertsEach * 2;

    final positions = Float32List(totalVerts * 3);
    final normals = Float32List(totalVerts * 3);
    final uvs = Float32List(totalVerts * 2);

    var vp = 0;
    var vuv = 0;

    for (var r = 0; r < ringCount; r++) {
      final (cp, sp, zVal) = zSlices[r];
      final vCoord = 1.0 - (zArc[r] / totalZArc);
      for (var j = 0; j < stride; j++) {
        final nx2 = norm2X[j];
        final ny2 = norm2Y[j];
        final bx = outerX[j] - rz * nx2;
        final by = outerY[j] - rz * ny2;

        positions[vp] = bx + rz * cp * nx2;
        positions[vp + 1] = by + rz * cp * ny2;
        positions[vp + 2] = zVal;

        var nx = cp * nx2;
        var ny = cp * ny2;
        var nz = sp;
        final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
        if (nLen > 1e-9) {
          nx /= nLen;
          ny /= nLen;
          nz /= nLen;
        } else {
          nz = zVal >= 0 ? 1.0 : -1.0;
        }
        normals[vp] = nx;
        normals[vp + 1] = ny;
        normals[vp + 2] = nz;
        vp += 3;

        uvs[vuv] = perimArc[j] / totalPerim;
        uvs[vuv + 1] = vCoord;
        vuv += 2;
      }
    }

    // Front cap (+hz, normal = (0, 0, +1)):
    final frontCenterIdx = vp ~/ 3;
    positions[vp] = 0.0;
    positions[vp + 1] = 0.0;
    positions[vp + 2] = hz;
    normals[vp] = 0.0;
    normals[vp + 1] = 0.0;
    normals[vp + 2] = 1.0;
    vp += 3;
    uvs[vuv] = 0.5;
    uvs[vuv + 1] = 0.5;
    vuv += 2;

    final frontRingStart = vp ~/ 3;
    for (var j = 0; j < perimCount; j++) {
      final bx = outerX[j] - rz * norm2X[j];
      final by = outerY[j] - rz * norm2Y[j];
      positions[vp] = bx;
      positions[vp + 1] = by;
      positions[vp + 2] = hz;
      normals[vp] = 0.0;
      normals[vp + 1] = 0.0;
      normals[vp + 2] = 1.0;
      vp += 3;
      uvs[vuv] = (0.5 + bx / w).clamp(0.0, 1.0);
      uvs[vuv + 1] = (0.5 - by / h).clamp(0.0, 1.0);
      vuv += 2;
    }

    // Back cap (-hz, normal = (0, 0, -1)):
    final backCenterIdx = vp ~/ 3;
    positions[vp] = 0.0;
    positions[vp + 1] = 0.0;
    positions[vp + 2] = -hz;
    normals[vp] = 0.0;
    normals[vp + 1] = 0.0;
    normals[vp + 2] = -1.0;
    vp += 3;
    uvs[vuv] = 0.5;
    uvs[vuv + 1] = 0.5;
    vuv += 2;

    final backRingStart = vp ~/ 3;
    for (var j = 0; j < perimCount; j++) {
      final bx = outerX[j] - rz * norm2X[j];
      final by = outerY[j] - rz * norm2Y[j];
      positions[vp] = bx;
      positions[vp + 1] = by;
      positions[vp + 2] = -hz;
      normals[vp] = 0.0;
      normals[vp + 1] = 0.0;
      normals[vp + 2] = -1.0;
      vp += 3;
      uvs[vuv] = (0.5 - bx / w).clamp(0.0, 1.0);
      uvs[vuv + 1] = (0.5 - by / h).clamp(0.0, 1.0);
      vuv += 2;
    }

    // 3. Build outward CCW triangle indices, skipping zero-length perimeter seams.
    final indices = <int>[];
    for (var j = 0; j < perimCount; j++) {
      final dx = outerX[j + 1] - outerX[j];
      final dy = outerY[j + 1] - outerY[j];
      if (dx * dx + dy * dy <= 1e-12) continue;

      for (var r = 0; r < ringCount - 1; r++) {
        final a = r * stride + j;
        final b = a + 1;
        final c = a + stride;
        final dIdx = c + 1;
        indices
          ..add(a)
          ..add(b)
          ..add(c)
          ..add(b)
          ..add(dIdx)
          ..add(c);
      }

      final nextJ = (j + 1) % perimCount;
      // Front cap (+Z): CCW (center, j, nextJ)
      indices
        ..add(frontCenterIdx)
        ..add(frontRingStart + j)
        ..add(frontRingStart + nextJ);
      // Back cap (-Z): CCW seen from -Z (center, nextJ, j)
      indices
        ..add(backCenterIdx)
        ..add(backRingStart + nextJ)
        ..add(backRingStart + j);
    }

    final tangents = _computeOrthonormalTangents(
      positions: positions,
      normals: normals,
      texCoords: uvs,
      indices: indices,
    );

    // Subtle directional bevel shading & cavity self-occlusion so untextured
    // spatial controls (buttons, pills, dialogs, sliders) read with crisp
    // machined 3D depth even under flat ambient lighting.
    final colors = Float32List(totalVerts * 4);
    for (var v = 0; v < totalVerts; v++) {
      final p = v * 3;
      final c = v * 4;
      final ny = normals[p + 1];
      final nz = normals[p + 2];
      // Front face (+Z) stays neutral ~1.0; top bevel (+Y/+Z) catches a gentle
      // rim lift; underside (-Y) and rear (-Z) darken slightly for depth.
      final shade = (0.93 + 0.05 * nz + 0.08 * ny).clamp(0.78, 1.0);
      colors[c] = shade;
      colors[c + 1] = shade;
      colors[c + 2] = shade;
      colors[c + 3] = 1.0;
    }

    return VrBeveledBoxArrays(
      positions: positions,
      normals: normals,
      texCoords: uvs,
      colors: colors,
      tangents: tangents,
      indices: indices,
    );
  }

  static Float32List _computeOrthonormalTangents({
    required Float32List positions,
    required Float32List normals,
    required Float32List texCoords,
    required List<int> indices,
  }) {
    final vertexCount = positions.length ~/ 3;
    final tan1 = Float32List(vertexCount * 3);
    final tan2 = Float32List(vertexCount * 3);
    final triCount = indices.length ~/ 3;

    for (var t = 0; t < triCount; t++) {
      final i0 = indices[t * 3];
      final i1 = indices[t * 3 + 1];
      final i2 = indices[t * 3 + 2];

      final p0 = i0 * 3, p1 = i1 * 3, p2 = i2 * 3;
      final uv0 = i0 * 2, uv1 = i1 * 2, uv2 = i2 * 2;

      final e1x = positions[p1] - positions[p0];
      final e1y = positions[p1 + 1] - positions[p0 + 1];
      final e1z = positions[p1 + 2] - positions[p0 + 2];

      final e2x = positions[p2] - positions[p0];
      final e2y = positions[p2 + 1] - positions[p0 + 1];
      final e2z = positions[p2 + 2] - positions[p0 + 2];

      final du1 = texCoords[uv1] - texCoords[uv0];
      final dv1 = texCoords[uv1 + 1] - texCoords[uv0 + 1];
      final du2 = texCoords[uv2] - texCoords[uv0];
      final dv2 = texCoords[uv2 + 1] - texCoords[uv0 + 1];

      final det = du1 * dv2 - du2 * dv1;
      if (!det.isFinite || det.abs() <= 1e-10) continue;
      final inv = 1.0 / det;

      final sx = (dv2 * e1x - dv1 * e2x) * inv;
      final sy = (dv2 * e1y - dv1 * e2y) * inv;
      final sz = (dv2 * e1z - dv1 * e2z) * inv;

      final tx = (du1 * e2x - du2 * e1x) * inv;
      final ty = (du1 * e2y - du2 * e1y) * inv;
      final tz = (du1 * e2z - du2 * e1z) * inv;

      for (final p in [p0, p1, p2]) {
        tan1[p] += sx;
        tan1[p + 1] += sy;
        tan1[p + 2] += sz;
        tan2[p] += tx;
        tan2[p + 1] += ty;
        tan2[p + 2] += tz;
      }
    }

    final out = Float32List(vertexCount * 4);
    for (var v = 0; v < vertexCount; v++) {
      final p = v * 3;
      final o = v * 4;
      final nx = normals[p], ny = normals[p + 1], nz = normals[p + 2];
      final t1x = tan1[p], t1y = tan1[p + 1], t1z = tan1[p + 2];
      final dot = nx * t1x + ny * t1y + nz * t1z;
      var ox = t1x - nx * dot;
      var oy = t1y - ny * dot;
      var oz = t1z - nz * dot;
      final len = math.sqrt(ox * ox + oy * oy + oz * oz);
      if (len > 1e-7 && len.isFinite) {
        ox /= len;
        oy /= len;
        oz /= len;
        final cx = ny * oz - nz * oy;
        final cy = nz * ox - nx * oz;
        final cz = nx * oy - ny * ox;
        final w = (cx * tan2[p] + cy * tan2[p + 1] + cz * tan2[p + 2]) < 0.0
            ? -1.0
            : 1.0;
        out[o] = ox;
        out[o + 1] = oy;
        out[o + 2] = oz;
        out[o + 3] = w;
      } else {
        final sign = nz >= 0.0 ? 1.0 : -1.0;
        final a = -1.0 / (sign + nz);
        final b = nx * ny * a;
        var fx = 1.0 + sign * nx * nx * a;
        var fy = sign * b;
        var fz = -sign * nx;
        final fLen = math.sqrt(fx * fx + fy * fy + fz * fz);
        if (fLen > 1e-9) {
          fx /= fLen;
          fy /= fLen;
          fz /= fLen;
        } else {
          fx = 1.0;
          fy = 0.0;
          fz = 0.0;
        }
        out[o] = fx;
        out[o + 1] = fy;
        out[o + 2] = fz;
        out[o + 3] = 1.0;
      }
    }
    return out;
  }
}
