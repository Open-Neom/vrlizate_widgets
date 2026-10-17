import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';

/// Spatial state and per-frame placement solver for a 3D widget or layout.
///
/// Supports [VrPlacementMode.staticWorld], [VrPlacementMode.dynamicBillboard],
/// [VrPlacementMode.headLockedHud], and [VrPlacementMode.dynamicFloating].
class VrSpatialPose {
  VrSpatialPose({
    this.placementMode = VrPlacementMode.staticWorld,
    vm.Vector3? position,
    vm.Quaternion? rotation,
    this.scale = VrWidgetConstants.defaultScale,
    this.followDistance = VrWidgetConstants.defaultFollowDistance,
    this.followSmoothing = VrWidgetConstants.defaultFollowSmoothing,
    vm.Vector3? followOffset,
    this.floatAmplitude = VrWidgetConstants.defaultFloatAmplitude,
    this.floatFrequencyHz = VrWidgetConstants.defaultFloatFrequencyHz,
    this.yawRadians = 0.0,
  }) : _basePosition = (position ?? vm.Vector3.zero()).clone(),
       position = (position ?? vm.Vector3.zero()).clone(),
       rotation = (rotation ?? vm.Quaternion.identity()).clone(),
       followOffset = (followOffset ?? vm.Vector3.zero()).clone();

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
    switch (placementMode) {
      case VrPlacementMode.staticWorld:
        position = _basePosition.clone();
        break;

      case VrPlacementMode.dynamicBillboard:
        position = _basePosition.clone();
        _faceViewerHorizontally(viewerPosition);
        break;

      case VrPlacementMode.headLockedHud:
        final forwardDir =
            viewerForward.length2 > VrWidgetConstants.directionEpsilon
            ? viewerForward.normalized()
            : vm.Vector3(0, 0, -1);
        final target =
            viewerPosition + forwardDir * followDistance + followOffset;
        final clampedDt = math.max(0.0, dt);
        final alpha = followSmoothing <= 0
            ? 1.0
            : (1.0 - math.exp(-followSmoothing * clampedDt)).clamp(0.0, 1.0);
        position = position + (target - position) * alpha;
        _basePosition = position.clone();
        _faceViewerHorizontally(viewerPosition);
        break;

      case VrPlacementMode.dynamicFloating:
        final dy =
            math.sin(elapsedSeconds * floatFrequencyHz * 2.0 * math.pi) *
            floatAmplitude;
        position = _basePosition + vm.Vector3(0, dy, 0);
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
