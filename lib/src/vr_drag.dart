import 'package:vector_math/vector_math.dart' as vm;

/// Reusable gaze drag-and-drop for 3D scene nodes.
///
/// The VR counterpart of Flutter's `Draggable`: the host tells the
/// controller when a drag starts (e.g. gaze-dwell on a card), feeds the eye
/// position and gaze direction every frame, and decides what to do with the
/// drop position (snap to a column, delete over a trash zone, …).
///
/// Pure math over positions — no geometry, no GPU — so it is fully testable
/// headless and works with any node the host moves.
///
/// ```dart
/// final drag = VrDragController();
/// // onSelect(card): drag.begin('card_1', card.position, rig.eyeCenter);
/// // onTick: final pos = drag.update(eye, forward); if (pos != null) card.position = pos;
/// // onTap:  final drop = drag.end(eye, forward); if (drop != null) snapOrDelete(drop);
/// ```
class VrDragController {
  /// Name of the node being dragged (null = idle).
  String? grabbedName;

  bool _pendingDistance = false;
  double _distance = 2.0;
  vm.Vector3 _last = vm.Vector3.zero();

  /// Whether a node is currently being dragged.
  bool get isDragging => grabbedName != null;

  /// Last computed drag position (valid while [isDragging]).
  vm.Vector3 get position => _last;

  /// Minimum / maximum distance the dragged node keeps from the eye.
  double minDistance = 0.8;
  double maxDistance = 8.0;

  /// Starts dragging [name], currently at [currentPos]. The eye distance is
  /// captured on the first [update] so callers may begin the drag before the
  /// frame's eye pose is known.
  void begin(String name, vm.Vector3 currentPos) {
    grabbedName = name;
    _last = currentPos.clone();
    _pendingDistance = true;
  }

  /// Per-frame update while dragging: returns the new position following the
  /// gaze ray at the captured distance, or null when idle.
  vm.Vector3? update(vm.Vector3 eye, vm.Vector3 forward) {
    final name = grabbedName;
    if (name == null) return null;
    if (_pendingDistance) {
      _distance = (_last - eye).length.clamp(minDistance, maxDistance);
      _pendingDistance = false;
    }
    _last = eye + forward * _distance;
    return _last;
  }

  /// Ends the drag and returns the final drop position (following the gaze
  /// one last time), or null when idle.
  vm.Vector3? end(vm.Vector3 eye, vm.Vector3 forward) {
    if (grabbedName == null) return null;
    final pos = update(eye, forward);
    grabbedName = null;
    _pendingDistance = false;
    return pos;
  }

  /// Cancels the drag without reporting a drop (host restores the node).
  void cancel() {
    grabbedName = null;
    _pendingDistance = false;
  }
}
