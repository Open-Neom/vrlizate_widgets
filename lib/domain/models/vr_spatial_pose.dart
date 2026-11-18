import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';

/// Spatial state and per-frame placement solver for a 3D widget or layout.
///
/// Supports [VrPlacementMode.staticWorld], [VrPlacementMode.dynamicBillboard],
/// [VrPlacementMode.headLockedHud], and [VrPlacementMode.dynamicFloating].
class VrSpatialPose {
  static bool _isFiniteVec3(vm.Vector3 v) =>
      v.x.isFinite && v.y.isFinite && v.z.isFinite;

  static vm.Vector3 _sanitizeVec3(vm.Vector3? v) =>
      (v != null && _isFiniteVec3(v)) ? v.clone() : vm.Vector3.zero();

  VrSpatialPose({
    this.placementMode = VrPlacementMode.staticWorld,
    vm.Vector3? position,
    vm.Quaternion? rotation,
    double scale = VrWidgetConstants.defaultScale,
    double followDistance = VrWidgetConstants.defaultFollowDistance,
    double followSmoothing = VrWidgetConstants.defaultFollowSmoothing,
    vm.Vector3? followOffset,
    double floatAmplitude = VrWidgetConstants.defaultFloatAmplitude,
    double floatFrequencyHz = VrWidgetConstants.defaultFloatFrequencyHz,
    double yawRadians = 0.0,
  }) : _basePosition = _sanitizeVec3(position),
       position = _sanitizeVec3(position),
       rotation = (rotation != null &&
               rotation.x.isFinite &&
               rotation.y.isFinite &&
               rotation.z.isFinite &&
               rotation.w.isFinite)
           ? rotation.clone()
           : vm.Quaternion.identity(),
       scale = (scale.isFinite && scale > 0)
           ? scale
           : VrWidgetConstants.defaultScale,
       followDistance = (followDistance.isFinite && followDistance >= 0)
           ? followDistance
           : VrWidgetConstants.defaultFollowDistance,
       followSmoothing = followSmoothing.isFinite
           ? followSmoothing
           : VrWidgetConstants.defaultFollowSmoothing,
       followOffset = _sanitizeVec3(followOffset),
       floatAmplitude = floatAmplitude.isFinite
           ? floatAmplitude
           : VrWidgetConstants.defaultFloatAmplitude,
       floatFrequencyHz = floatFrequencyHz.isFinite
           ? floatFrequencyHz
           : VrWidgetConstants.defaultFloatFrequencyHz,
       yawRadians = yawRadians.isFinite ? yawRadians : 0.0;

  /// Active placement behavior in the 3D scene.
  VrPlacementMode placementMode;

  /// Anchor position around which static/floating/billboard widgets rest.
  vm.Vector3 _basePosition;

  /// Current computed world position.
  vm.Vector3 position;

  /// Current computed world rotation.
  vm.Quaternion rotation;

  /// Current uniform scale factor.
  double scale;

  /// Distance in meters in front of the viewer for [VrPlacementMode.headLockedHud].
  double followDistance;

  /// Exponential smoothing speed for [VrPlacementMode.headLockedHud].
  double followSmoothing;

  /// Additional world-space offset applied in [VrPlacementMode.headLockedHud].
  vm.Vector3 followOffset;

  /// Vertical bobbing amplitude in meters for [VrPlacementMode.dynamicFloating].
  double floatAmplitude;

  /// Bobbing frequency in Hz for [VrPlacementMode.dynamicFloating].
  double floatFrequencyHz;

  /// Computed horizontal yaw angle in radians (facing the viewer when applicable).
  double yawRadians;

  /// Returns a copy of the anchor position.
  vm.Vector3 get basePosition => _basePosition.clone();

  /// Updates the anchor position (e.g. when moved via `moveTo` or drag-and-drop).
  void setBasePosition(vm.Vector3 nextBase) {
    if (!_isFiniteVec3(nextBase)) return;
    _basePosition = nextBase.clone();
    position = nextBase.clone();
  }

  /// Advances the spatial pose for the current frame and returns [position].
  vm.Vector3 update({
    required vm.Vector3 viewerPosition,
    required vm.Vector3 viewerForward,
    required double elapsedSeconds,
    required double dt,
  }) {
    final safeViewerPos = _isFiniteVec3(viewerPosition)
        ? viewerPosition
        : position;
    final safeElapsed = elapsedSeconds.isFinite ? elapsedSeconds : 0.0;
    final safeDt = (dt.isFinite && dt > 0.0) ? math.min(dt, 1.0) : 0.0;

    switch (placementMode) {
      case VrPlacementMode.staticWorld:
        position = _basePosition.clone();
        break;

      case VrPlacementMode.dynamicBillboard:
        position = _basePosition.clone();
        _faceViewerHorizontally(safeViewerPos);
        break;

      case VrPlacementMode.headLockedHud:
        final forwardDir =
            _isFiniteVec3(viewerForward) &&
                viewerForward.length2 > VrWidgetConstants.directionEpsilon
            ? viewerForward.normalized()
            : vm.Vector3(0, 0, -1);
        final safeDist = followDistance.isFinite ? followDistance : 0.0;
        final safeOffset = _isFiniteVec3(followOffset)
            ? followOffset
            : vm.Vector3.zero();
        final target = safeViewerPos + forwardDir * safeDist + safeOffset;
        final safeSmooth = followSmoothing.isFinite ? followSmoothing : 0.0;
        final alpha = safeSmooth <= 0
            ? 1.0
            : (1.0 - math.exp(-safeSmooth * safeDt)).clamp(0.0, 1.0);
        position = position + (target - position) * alpha;
        _basePosition = position.clone();
        _faceViewerHorizontally(safeViewerPos);
        break;

      case VrPlacementMode.dynamicFloating:
        final safeFreq = floatFrequencyHz.isFinite ? floatFrequencyHz : 0.0;
        final safeAmp = floatAmplitude.isFinite ? floatAmplitude : 0.0;
        final angle = (safeElapsed * safeFreq * 2.0 * math.pi).remainder(
          2.0 * math.pi,
        );
        final dy = math.sin(angle) * safeAmp;
        position = _basePosition + vm.Vector3(0, dy.isFinite ? dy : 0.0, 0);
        break;
    }
    return position.clone();
  }

  void _faceViewerHorizontally(vm.Vector3 viewerPosition) {
    final dx = viewerPosition.x - position.x;
    final dz = viewerPosition.z - position.z;
    if (dx * dx + dz * dz <= VrWidgetConstants.directionEpsilon) {
      return;
    }
    yawRadians = math.atan2(dx, dz);
    rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yawRadians);
  }
}
