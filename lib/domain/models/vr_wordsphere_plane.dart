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

  /// Converts a 2D board point `(0..baseSize, 0..baseSize)` into 3D world space.
  vm.Vector3 worldPoint(
    Offset point, {
    double baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
  }) =>
      center +
      right * ((point.dx / baseSize - 0.5) * size) +
      up * ((0.5 - point.dy / baseSize) * size);

  /// Converts a 2D board point into a 3D cursor position lifted slightly off
  /// the board toward the viewer to prevent z-fighting.
  vm.Vector3 cursorWorldPoint(
    Offset point, {
    double baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
    double lift = VrWordsphereConstants.defaultCursorLiftMeters,
  }) => worldPoint(point, baseSize: baseSize) + normal * lift;

  /// Intersects a 3D world [ray] (head gaze or laser pointer) with the circular
  /// Wordsphere board and returns its 2D board coordinate, or `null` if missed.
  Offset? intersect(
    vm.Ray ray, {
    double baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
  }) {
    final denominator = ray.direction.dot(normal);
    if (!denominator.isFinite ||
        denominator >= VrWordsphereConstants.rayParallelEpsilon) {
      return null;
    }
    final t = (center - ray.origin).dot(normal) / denominator;
    if (!t.isFinite || t <= 0) return null;
    final offset = ray.origin + ray.direction * t - center;
    final x = offset.dot(right) / size;
    final y = -offset.dot(up) / size;
    const maxR = VrWordsphereConstants.maxHitRadiusNormalized;
    if (x * x + y * y > maxR * maxR) return null;
    return Offset((x + 0.5) * baseSize, (y + 0.5) * baseSize);
  }
}
