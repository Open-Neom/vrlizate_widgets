import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';

/// An immutable world-space basis for spatial UI.
///
/// Local +X is basis-right, local +Y is panel-up, and local +Z points out of
/// the panel toward its viewer.
class VrWorldPose {
  VrWorldPose._({
    required vm.Vector3 center,
    required vm.Vector3 right,
    required vm.Vector3 up,
    required vm.Vector3 towardViewer,
  }) : _center = center.clone(),
       _right = right.clone(),
       _up = up.clone(),
       _towardViewer = towardViewer.clone(),
       _transform = _basisTransform(center, right, up, towardViewer);

  /// Creates a pose from an explicit orthonormal basis.
  factory VrWorldPose.basis({
    required vm.Vector3 center,
    required vm.Vector3 right,
    required vm.Vector3 up,
    required vm.Vector3 towardViewer,
  }) {
    _requireFinite(center, 'center');
    _requireDirection(right, 'right');
    _requireDirection(up, 'up');
    _requireDirection(towardViewer, 'towardViewer');

    final front = towardViewer.normalized();
    var panelRight = right - front * right.dot(front);
    if (panelRight.length2 < VrWidgetConstants.directionEpsilon) {
      panelRight = up.cross(front);
    }
    if (panelRight.length2 < VrWidgetConstants.directionEpsilon) {
      panelRight = _fallbackUp(front).cross(front);
    }
    panelRight.normalize();

    var panelUp = front.cross(panelRight)..normalize();
    if (panelUp.dot(up) < 0) {
      panelRight = -panelRight;
      panelUp = -panelUp;
    }
    return VrWorldPose._(
      center: center,
      right: panelRight,
      up: panelUp,
      towardViewer: front,
    );
  }

  /// Places a panel [distance] metres along the viewer's gaze direction.
  factory VrWorldPose.fromViewer({
    required vm.Vector3 eye,
    required vm.Vector3 forward,
    vm.Vector3? right,
    vm.Vector3? up,
    double distance = VrWidgetConstants.defaultFollowDistance,
  }) {
    _requireFinite(eye, 'eye');
    _requireDirection(forward, 'forward');
    if (!distance.isFinite || distance <= 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'Must be finite and greater than zero.',
      );
    }

    final gaze = forward.normalized();
    final center = eye + gaze * distance;
    final front = -gaze;
    final preferredUp = up?.clone() ?? _fallbackUp(front);
    var preferredRight = right?.clone() ?? preferredUp.cross(front);
    if (preferredRight.length2 < VrWidgetConstants.directionEpsilon) {
      preferredRight = _fallbackUp(front).cross(front);
    }
    return VrWorldPose.basis(
      center: center,
      right: preferredRight,
      up: preferredUp,
      towardViewer: front,
    );
  }

  /// Creates an upright pose at [center] facing [eye].
  factory VrWorldPose.facingEye({
    required vm.Vector3 center,
    required vm.Vector3 eye,
    vm.Vector3? worldUp,
  }) {
    _requireFinite(center, 'center');
    _requireFinite(eye, 'eye');
    final towardViewer = eye - center;
    _requireDirection(towardViewer, 'eye - center');
    final front = towardViewer.normalized();
    var preferredUp = worldUp?.clone() ?? vm.Vector3(0, 1, 0);
    _requireDirection(preferredUp, 'worldUp');
    if (preferredUp.cross(front).length2 < VrWidgetConstants.directionEpsilon) {
      preferredUp = _fallbackUp(front);
    }
    return VrWorldPose.basis(
      center: center,
      right: preferredUp.cross(front),
      up: preferredUp,
      towardViewer: front,
    );
  }

  final vm.Vector3 _center;
  final vm.Vector3 _right;
  final vm.Vector3 _up;
  final vm.Vector3 _towardViewer;
  final vm.Matrix4 _transform;

  vm.Vector3 get center => _center.clone();
  vm.Vector3 get right => _right.clone();
  vm.Vector3 get up => _up.clone();
  vm.Vector3 get towardViewer => _towardViewer.clone();

  /// A copy of the local-to-world transform represented by this pose.
  vm.Matrix4 get transform => _transform.clone();

  /// Converts a panel-local point into world space.
  vm.Vector3 localToWorld(vm.Vector3 local) =>
      _center + _right * local.x + _up * local.y + _towardViewer * local.z;

  /// Returns a local-to-world transform translated by [localOffset].
  vm.Matrix4 transformAt(vm.Vector3 localOffset) {
    final result = _transform.clone();
    result.setTranslation(localToWorld(localOffset));
    return result;
  }

  static vm.Matrix4 _basisTransform(
    vm.Vector3 center,
    vm.Vector3 right,
    vm.Vector3 up,
    vm.Vector3 towardViewer,
  ) {
    final result = vm.Matrix4.identity();
    result.setColumn(0, vm.Vector4(right.x, right.y, right.z, 0));
    result.setColumn(1, vm.Vector4(up.x, up.y, up.z, 0));
    result.setColumn(
      2,
      vm.Vector4(towardViewer.x, towardViewer.y, towardViewer.z, 0),
    );
    result.setColumn(3, vm.Vector4(center.x, center.y, center.z, 1));
    return result;
  }

  static vm.Vector3 _fallbackUp(vm.Vector3 front) {
    final worldUp = vm.Vector3(0, 1, 0);
    if (front.dot(worldUp).abs() < 0.95) return worldUp;
    return vm.Vector3(0, 0, 1);
  }

  static void _requireDirection(vm.Vector3 value, String name) {
    _requireFinite(value, name);
    if (value.length2 < VrWidgetConstants.directionEpsilon) {
      throw ArgumentError.value(value, name, 'Must not be a zero vector.');
    }
  }

  static void _requireFinite(vm.Vector3 value, String name) {
    if (!value.x.isFinite || !value.y.isFinite || !value.z.isFinite) {
      throw ArgumentError.value(value, name, 'Must contain finite values.');
    }
  }
}
