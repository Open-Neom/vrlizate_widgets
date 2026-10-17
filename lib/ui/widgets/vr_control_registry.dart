import 'dart:collection';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'vr_control.dart';

/// Routes gaze hover/select events to registered controls by node name.
class VrControlRegistry {
  final Map<String, VrControl> _controls = {};
  final List<VrControl> _activeControls = [];
  late final List<VrControl> _controlsView = UnmodifiableListView<VrControl>(
    _activeControls,
  );

  /// Name of the node under the gaze right now (null = none).
  String? hoveredName;

  /// HUD label of the hovered control (null = none).
  String? get hoveredLabel =>
      hoveredName != null ? _controls[hoveredName]?.label : null;

  /// A stable read-only view, rebuilt only when registrations change.
  Iterable<VrControl> get controls => _controlsView;

  void register(VrControl control) {
    for (final nodeName in control.nodeNames) {
      if (hoveredName == nodeName && !identical(_controls[nodeName], control)) {
        _controls[nodeName]?.onHoverExit(nodeName);
        hoveredName = null;
      }
      _controls[nodeName] = control;
    }
    _refreshActiveControls();
  }

  /// Removes [control] without disturbing a newer control that may have
  /// reused one of its node names. Dynamic panels should call this when they
  /// leave the scene so stale gaze routes are not retained.
  void unregister(VrControl control) {
    for (final nodeName in control.nodeNames) {
      if (identical(_controls[nodeName], control)) {
        _controls.remove(nodeName);
        if (hoveredName == nodeName) {
          control.onHoverExit(nodeName);
          hoveredName = null;
        }
      }
    }
    _refreshActiveControls();
  }

  void clear() {
    handleHover(null);
    _controls.clear();
    _activeControls.clear();
  }

  void _refreshActiveControls() {
    final unique = HashSet<VrControl>.identity();
    _activeControls.clear();
    for (final control in _controls.values) {
      if (unique.add(control)) _activeControls.add(control);
    }
  }

  /// Forward of `StereoSceneView.onGazeHoverChanged`.
  void handleHover(Node? node) {
    final name = node?.name;
    if (name == hoveredName) return;
    final previous = _controls[hoveredName];
    if (previous != null) previous.onHoverExit(hoveredName!);
    hoveredName = _controls.containsKey(name) ? name : null;
    if (hoveredName != null) _controls[hoveredName]!.onHoverEnter(hoveredName!);
  }

  /// Forward of `StereoSceneView.onGazeSelect`. Returns true if a control
  /// consumed the selection.
  bool handleSelect(Node node) {
    final control = _controls[node.name];
    if (control == null || !control.enabled) return false;
    control.onSelect(node.name);
    return true;
  }

  /// Decays press flashes — call once per frame from `onTick`.
  void update(double dt) {
    for (var i = 0; i < _activeControls.length; i++) {
      _activeControls[i].update(dt);
    }
  }

  /// Advances both press flashes and dynamic spatial placement for all
  /// registered controls.
  void updateSpatial({
    required vm.Vector3 viewerPosition,
    required vm.Vector3 viewerForward,
    required double elapsedSeconds,
    required double dt,
  }) {
    for (var i = 0; i < _activeControls.length; i++) {
      final control = _activeControls[i];
      control.update(dt);
      if (control.isSpatialInitialized) {
        control.updateSpatialPlacement(
          viewerPosition: viewerPosition,
          viewerForward: viewerForward,
          elapsedSeconds: elapsedSeconds,
          dt: dt,
        );
      }
    }
  }
}
