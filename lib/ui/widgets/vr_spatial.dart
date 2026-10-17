import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../domain/models/vr_spatial_pose.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';

/// Live resize, movement, and dynamic spatial placement for 3D widgets,
/// without rebuilding scene-graph nodes.
///
/// Call [initSpatial] once after the widget's nodes exist (widget
/// constructors do this). Offsets are captured per node relative to
/// [origin] at scale 1.0; [scaleTo], [moveTo], and [updateSpatialPlacement]
/// recompute transforms in-place.
mixin VrSpatial {
  /// World anchor of the widget (nodes are placed relative to it).
  vm.Vector3 origin = vm.Vector3.zero();

  /// Current scale (1.0 = design size). Big/small at runtime.
  double scale = VrWidgetConstants.defaultScale;

  /// Active spatial placement behavior in 3D space.
  VrPlacementMode placementMode = VrPlacementMode.staticWorld;

  /// Spatial pose state for dynamic placement modes.
  VrSpatialPose? spatialPose;

  /// Current horizontal yaw rotation in radians around [origin].
  double yawRadians = 0.0;

  final Map<Node, vm.Vector3> _baseOffsets = {};

  /// Whether [initSpatial] has captured node offsets for this widget.
  bool get isSpatialInitialized => _baseOffsets.isNotEmpty;

  /// Nodes managed by this mixin (provided by the widget).
  List<Node> get spatialNodes;

  /// Captures current node positions as offsets from [origin].
  /// Called by the widget constructor after placing its nodes.
  void initSpatial(vm.Vector3 origin, {VrPlacementMode? mode}) {
    this.origin = origin.clone();
    if (mode != null) {
      placementMode = mode;
    }
    _baseOffsets.clear();
    for (final n in spatialNodes) {
      _baseOffsets[n] = n.localTransform.getTranslation() - origin;
    }
    spatialPose = VrSpatialPose(
      placementMode: placementMode,
      position: this.origin,
      scale: scale,
      yawRadians: yawRadians,
    );
  }

  /// Updates the stored base offset of a specific [node] relative to [origin]
  /// (used by controls with moving internal parts such as switch/slider thumbs).
  void updateBaseOffset(Node node, vm.Vector3 offset) {
    if (_baseOffsets.containsKey(node)) {
      _baseOffsets[node] = offset.clone();
    }
  }

  /// Configures how this widget behaves in 3D space (static, billboard,
  /// head-locked HUD, or floating).
  void configurePlacement({
    required VrPlacementMode mode,
    double? followDistance,
    double? followSmoothing,
    vm.Vector3? followOffset,
    double? floatAmplitude,
    double? floatFrequencyHz,
  }) {
    placementMode = mode;
    final pose =
        spatialPose ??
        VrSpatialPose(
          placementMode: mode,
          position: origin,
          scale: scale,
          yawRadians: yawRadians,
        );
    pose.placementMode = mode;
    if (followDistance != null) pose.followDistance = followDistance;
    if (followSmoothing != null) pose.followSmoothing = followSmoothing;
    if (followOffset != null) pose.followOffset = followOffset.clone();
    if (floatAmplitude != null) pose.floatAmplitude = floatAmplitude;
    if (floatFrequencyHz != null) pose.floatFrequencyHz = floatFrequencyHz;
    spatialPose = pose;
  }

  /// Advances the widget's 3D placement according to [placementMode] and
  /// applies the resulting world transform to all [spatialNodes].
  void updateSpatialPlacement({
    required vm.Vector3 viewerPosition,
    required vm.Vector3 viewerForward,
    required double elapsedSeconds,
    required double dt,
  }) {
    final pose =
        spatialPose ??
        (spatialPose = VrSpatialPose(
          placementMode: placementMode,
          position: origin,
          scale: scale,
          yawRadians: yawRadians,
        ));
    pose
      ..placementMode = placementMode
      ..scale = scale;
    final nextPos = pose.update(
      viewerPosition: viewerPosition,
      viewerForward: viewerForward,
      elapsedSeconds: elapsedSeconds,
      dt: dt,
    );
    origin = nextPos;
    yawRadians = pose.yawRadians;
    _applySpatial();
  }

  /// Moves the whole widget to [position] (its origin).
  void moveTo(vm.Vector3 position) {
    origin = position.clone();
    spatialPose?.setBasePosition(origin);
    _applySpatial();
  }

  /// Translates the whole widget by [delta].
  void moveBy(vm.Vector3 delta) => moveTo(origin + delta);

  /// Resizes the whole widget (offsets scale out from the origin and
  /// geometry scales uniformly).
  void scaleTo(double s) {
    scale = s.clamp(VrWidgetConstants.minScale, VrWidgetConstants.maxScale);
    spatialPose?.scale = scale;
    _applySpatial();
  }

  void _applySpatial() {
    if (yawRadians == 0.0) {
      for (final entry in _baseOffsets.entries) {
        final transform = vm.Matrix4.translation(origin + entry.value * scale)
          ..multiply(vm.Matrix4.diagonal3Values(scale, scale, scale));
        entry.key.localTransform = transform;
      }
      return;
    }

    final cosYaw = math.cos(yawRadians);
    final sinYaw = math.sin(yawRadians);
    for (final entry in _baseOffsets.entries) {
      final scaled = entry.value * scale;
      final rotatedOffset = vm.Vector3(
        scaled.x * cosYaw + scaled.z * sinYaw,
        scaled.y,
        -scaled.x * sinYaw + scaled.z * cosYaw,
      );
      final transform = vm.Matrix4.translation(origin + rotatedOffset)
        ..multiply(vm.Matrix4.rotationY(yawRadians))
        ..multiply(vm.Matrix4.diagonal3Values(scale, scale, scale));
      entry.key.localTransform = transform;
    }
  }
}
