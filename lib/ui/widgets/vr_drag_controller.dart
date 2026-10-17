import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';

/// Reusable gaze drag-and-drop for 3D scene nodes.
///
/// The VR counterpart of Flutter's `Draggable`: supports deliberate gaze
/// dragging coupled with holding Button B (`requireButtonB = true`, default
/// hold `0.85s`) or deliberate gaze-only hold (`2.8s`), preventing accidental
/// grabs while scanning a scene.
class VrDragController {
  VrDragController({
    this.requireButtonB = true,
    double? holdDurationSeconds,
  }) : holdDurationSeconds =
           holdDurationSeconds ??
           (requireButtonB
               ? VrWidgetConstants.defaultDragHoldSeconds
               : VrWidgetConstants.defaultGazeOnlyDragHoldSeconds);

  /// Whether holding Button B is required to initiate and sustain a gaze drag.
  bool requireButtonB;

  /// Deliberate hold duration in seconds while gazing at a candidate before
  /// the drag starts.
  double holdDurationSeconds;

  /// Current state of Button B as reported by the scene input loop.
  bool isButtonBHeld = false;

  /// Name of the node being dragged (null = idle).
  String? grabbedName;

  String? _candidateName;
  double _holdElapsed = 0.0;

  /// Name of the hovered candidate currently accumulating hold time.
  String? get candidateName => _candidateName;

  /// Seconds accumulated toward [holdDurationSeconds] on [candidateName].
  double get holdElapsed => _holdElapsed;

  /// Normalized progress (0..1) toward starting a drag on [candidateName].
  double get holdProgress => holdDurationSeconds <= 0
      ? 1.0
      : (_holdElapsed / holdDurationSeconds).clamp(0.0, 1.0);

  bool _pendingDistance = false;
  double _distance = VrWidgetConstants.defaultDragDistance;
  vm.Vector3 _last = vm.Vector3.zero();

  /// Whether a node is currently being dragged.
  bool get isDragging => grabbedName != null;

  /// Last computed drag position (valid while [isDragging]).
  vm.Vector3 get position => _last;

  /// Minimum / maximum distance the dragged node keeps from the eye.
  double minDistance = VrWidgetConstants.minDragDistance;
  double maxDistance = VrWidgetConstants.maxDragDistance;

  /// Starts dragging [name], currently at [currentPos]. The eye distance is
  /// captured on the first [update] so callers may begin the drag before the
  /// frame's eye pose is known.
  void begin(String name, vm.Vector3 currentPos) {
    grabbedName = name;
    _candidateName = name;
    _holdElapsed = holdDurationSeconds;
    _last = currentPos.clone();
    _pendingDistance = true;
  }

  /// Starts dragging [name] only if [buttonBHeld] satisfies [requireButtonB]
  /// and (when [holdElapsed] is supplied) the deliberate hold threshold has
  /// been met.
  bool tryBeginWithInput(
    String name,
    vm.Vector3 currentPos, {
    required bool buttonBHeld,
    double? holdElapsed,
  }) {
    isButtonBHeld = buttonBHeld;
    if (requireButtonB && !buttonBHeld) return false;
    if (holdElapsed != null && holdElapsed < holdDurationSeconds) return false;
    begin(name, currentPos);
    return true;
  }

  /// Per-frame candidate hold accumulator for deliberate gaze + Button B drag.
  ///
  /// - Requires [hoveredName] and [candidatePosition] to be non-null and
  ///   ([buttonBHeld] to be true when [requireButtonB] is true).
  /// - Only begins dragging after [holdDurationSeconds] of continuous hold on
  ///   the same [hoveredName].
  /// - Automatically releases an active drag when [requireButtonB] is true and
  ///   [buttonBHeld] becomes false.
  bool updateDragCandidate({
    required String? hoveredName,
    required vm.Vector3? candidatePosition,
    required bool buttonBHeld,
    required double dt,
  }) {
    isButtonBHeld = buttonBHeld;
    if (isDragging) {
      if (requireButtonB && !buttonBHeld) {
        cancel();
        return false;
      }
      return true;
    }

    if (!dt.isFinite ||
        dt <= 0 ||
        hoveredName == null ||
        candidatePosition == null ||
        (requireButtonB && !buttonBHeld)) {
      _candidateName = null;
      _holdElapsed = 0.0;
      return false;
    }

    if (_candidateName != hoveredName) {
      _candidateName = hoveredName;
      _holdElapsed = 0.0;
    }

    _holdElapsed += dt;
    if (_holdElapsed >= holdDurationSeconds) {
      begin(hoveredName, candidatePosition);
      return true;
    }
    return false;
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
    _candidateName = null;
    _holdElapsed = 0.0;
    _pendingDistance = false;
    return pos;
  }

  /// Cancels the drag without reporting a drop (host restores the node).
  void cancel() {
    grabbedName = null;
    _candidateName = null;
    _holdElapsed = 0.0;
    _pendingDistance = false;
  }
}
