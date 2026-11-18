import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_wordsphere_constants.dart';

/// Fixed 3D world plane shared by stereoscopic rendering and ray hit-tests
/// for the Wordsphere radial keyboard in the VRlizate SDK.
class VrWordspherePlane {
  const VrWordspherePlane({
    required this.center,
    required this.right,
    required this.up,
    required this.normal,
    this.size = VrWordsphereConstants.defaultBoardSizeMeters,
  });

  /// Creates a fixed world plane in front of the viewer's initial eye pose.
  factory VrWordspherePlane.inFrontOfViewer({
    required vm.Vector3 eyeCenter,
    required vm.Vector3 forward,
    required vm.Vector3 screenRight,
    required vm.Vector3 up,
    double size = VrWordsphereConstants.defaultBoardSizeMeters,
    double distance = VrWordsphereConstants.defaultBoardDistanceMeters,
  }) => VrWordspherePlane(
    center: eyeCenter + forward * distance,
    right: screenRight.clone(),
    up: up.clone(),
    normal: -forward,
    size: size,
  );

  final vm.Vector3 center;
  final vm.Vector3 right;
  final vm.Vector3 up;
  final vm.Vector3 normal;
  final double size;

  /// World transform mapping PlaneGeometry (+X to screen-right, -Z to world-up).
  vm.Matrix4 get transform => vm.Matrix4.columns(
    vm.Vector4(right.x, right.y, right.z, 0),
    vm.Vector4(normal.x, normal.y, normal.z, 0),
    vm.Vector4(-up.x, -up.y, -up.z, 0),
    vm.Vector4(center.x, center.y, center.z, 1),
  );

  /// Converts a 2D board point `(0..baseSize, 0..baseSize)` into 3D world space
  /// with a single `Vector3` allocation (no intermediate operator temporaries).
  vm.Vector3 worldPoint(
    Offset point, {
    double baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
  }) {
    final u = (point.dx / baseSize - 0.5) * size;
    final v = (0.5 - point.dy / baseSize) * size;
    return vm.Vector3(
      center.x + right.x * u + up.x * v,
      center.y + right.y * u + up.y * v,
      center.z + right.z * u + up.z * v,
    );
  }

  /// Converts a 2D board point into a 3D cursor position lifted slightly off
  /// the board toward the viewer to prevent z-fighting (`1` allocation).
  vm.Vector3 cursorWorldPoint(
    Offset point, {
    double baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
    double lift = VrWordsphereConstants.defaultCursorLiftMeters,
  }) {
    final u = (point.dx / baseSize - 0.5) * size;
    final v = (0.5 - point.dy / baseSize) * size;
    return vm.Vector3(
      center.x + right.x * u + up.x * v + normal.x * lift,
      center.y + right.y * u + up.y * v + normal.y * lift,
      center.z + right.z * u + up.z * v + normal.z * lift,
    );
  }

  /// Intersects a 3D world [ray] (head gaze or laser pointer) with the circular
  /// Wordsphere board and returns its 2D board coordinate, or `null` if missed.
  ///
  /// Uses direct scalar dot products (`0` intermediate `Vector3` allocations per 120 Hz frame).
  Offset? intersect(
    vm.Ray ray, {
    double baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
  }) {
    final dir = ray.direction;
    final orig = ray.origin;
    final denominator =
        dir.x * normal.x + dir.y * normal.y + dir.z * normal.z;
    if (!denominator.isFinite ||
        denominator >= VrWordsphereConstants.rayParallelEpsilon) {
      return null;
    }
    final toCx = center.x - orig.x;
    final toCy = center.y - orig.y;
    final toCz = center.z - orig.z;
    final t = (toCx * normal.x + toCy * normal.y + toCz * normal.z) / denominator;
    if (!t.isFinite || t <= 0) return null;

    final ox = orig.x + dir.x * t - center.x;
    final oy = orig.y + dir.y * t - center.y;
    final oz = orig.z + dir.z * t - center.z;
    final x = (ox * right.x + oy * right.y + oz * right.z) / size;
    final y = -(ox * up.x + oy * up.y + oz * up.z) / size;
    const maxR = VrWordsphereConstants.maxHitRadiusNormalized;
    if (x * x + y * y > maxR * maxR) return null;
    return Offset((x + 0.5) * baseSize, (y + 0.5) * baseSize);
  }
}
