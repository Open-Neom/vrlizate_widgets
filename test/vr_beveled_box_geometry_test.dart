import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  group('VrBeveledBoxGeometry', () {
    test(
      'generates exact bounds, unit normals, outward CCW winding, and orthonormal tangents',
      () {
        final specs = <(String, vm.Vector3, double?, double?)>[
          ('button slab', vm.Vector3(0.42, 0.14, 0.055), null, null),
          ('stadium pill', vm.Vector3(0.36, 0.10, 0.04), 0.048, 0.012),
          ('large dialog panel', vm.Vector3(1.10, 0.72, 0.045), 0.044, 0.010),
          ('micro symbol bar', vm.Vector3(0.055, 0.012, 0.012), 0.0055, 0.003),
        ];

        for (final (label, size, cornerR, bevelZ) in specs) {
          final a = VrBeveledBoxGeometry.buildArrays(
            size,
            cornerRadius: cornerR,
            bevelZ: bevelZ,
          );
          expect(a.vertexCount, greaterThan(24), reason: label);
          expect(a.triangleCount, greaterThan(32), reason: label);
          expect(a.colors.length, a.vertexCount * 4, reason: label);

          var maxTopShade = 0.0;
          var minBottomShade = 1.0;
          for (var v = 0; v < a.vertexCount; v++) {
            final ny = a.normals[v * 3 + 1];
            final shade = a.colors[v * 4];
            expect(a.colors[v * 4 + 3], 1.0);
            if (ny > 0.7) maxTopShade = math.max(maxTopShade, shade);
            if (ny < -0.7) minBottomShade = math.min(minBottomShade, shade);
          }
          expect(
            maxTopShade,
            greaterThan(minBottomShade),
            reason: '$label top bevel highlight vs bottom self-occlusion',
          );

          var minX = double.infinity, maxX = -double.infinity;
          var minY = double.infinity, maxY = -double.infinity;
          var minZ = double.infinity, maxZ = -double.infinity;

          for (var v = 0; v < a.vertexCount; v++) {
            final p = v * 3;
            final x = a.positions[p];
            final y = a.positions[p + 1];
            final z = a.positions[p + 2];
            expect(x.isFinite && y.isFinite && z.isFinite, isTrue);
            minX = math.min(minX, x);
            maxX = math.max(maxX, x);
            minY = math.min(minY, y);
            maxY = math.max(maxY, y);
            minZ = math.min(minZ, z);
            maxZ = math.max(maxZ, z);

            final nx = a.normals[p];
            final ny = a.normals[p + 1];
            final nz = a.normals[p + 2];
            final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
            expect(nLen, closeTo(1.0, 1e-4), reason: '$label normal $v');

            final o = v * 4;
            final tx = a.tangents[o];
            final ty = a.tangents[o + 1];
            final tz = a.tangents[o + 2];
            final tw = a.tangents[o + 3];
            final tLen = math.sqrt(tx * tx + ty * ty + tz * tz);
            expect(tLen, closeTo(1.0, 1e-4), reason: '$label tangent $v');
            expect(
              (nx * tx + ny * ty + nz * tz).abs(),
              lessThan(1e-3),
              reason: '$label T⊥N $v',
            );
            expect(tw.abs(), closeTo(1.0, 1e-5));
          }

          expect(minX, closeTo(-size.x * 0.5, 1e-4), reason: label);
          expect(maxX, closeTo(size.x * 0.5, 1e-4), reason: label);
          expect(minY, closeTo(-size.y * 0.5, 1e-4), reason: label);
          expect(maxY, closeTo(size.y * 0.5, 1e-4), reason: label);
          expect(minZ, closeTo(-size.z * 0.5, 1e-4), reason: label);
          expect(maxZ, closeTo(size.z * 0.5, 1e-4), reason: label);

          // Every non-degenerate triangle must wind outward (CCW from outside).
          for (var t = 0; t < a.triangleCount; t++) {
            final i0 = a.indices[t * 3];
            final i1 = a.indices[t * 3 + 1];
            final i2 = a.indices[t * 3 + 2];

            final p0 = vm.Vector3(
              a.positions[i0 * 3],
              a.positions[i0 * 3 + 1],
              a.positions[i0 * 3 + 2],
            );
            final p1 = vm.Vector3(
              a.positions[i1 * 3],
              a.positions[i1 * 3 + 1],
              a.positions[i1 * 3 + 2],
            );
            final p2 = vm.Vector3(
              a.positions[i2 * 3],
              a.positions[i2 * 3 + 1],
              a.positions[i2 * 3 + 2],
            );
            final cross = (p1 - p0).cross(p2 - p0);
            if (cross.length2 <= 1e-14) continue;

            final avgNormal = vm.Vector3(
              a.normals[i0 * 3] + a.normals[i1 * 3] + a.normals[i2 * 3],
              a.normals[i0 * 3 + 1] +
                  a.normals[i1 * 3 + 1] +
                  a.normals[i2 * 3 + 1],
              a.normals[i0 * 3 + 2] +
                  a.normals[i1 * 3 + 2] +
                  a.normals[i2 * 3 + 2],
            );
            expect(
              cross.dot(avgNormal),
              greaterThan(0.0),
              reason: '$label triangle $t inverted winding',
            );
          }
        }
      },
    );
  });
}
