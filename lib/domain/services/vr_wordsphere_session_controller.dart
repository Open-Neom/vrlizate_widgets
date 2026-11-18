import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_wordsphere_constants.dart';
import '../models/vr_wordsphere_plane.dart';

/// Session controller for spatial Wordsphere text entry in VRlizate using
/// **Head Gaze + Joystick**.
///
/// Combines 3D ray intersections on [VrWordspherePlane] with thumbstick
/// deflection so users can aim with their head, steer across polar rings with
/// the joystick, toggle/hold strokes with A/X/R2, and cancel/delete with B.
class VrWordsphereSessionController {
  VrWordsphereSessionController({
    required this.plane,
    this.baseSize = VrWordsphereConstants.defaultBaseSizeTexels,
    this.stickSpeed = VrWordsphereConstants.defaultStickSpeed,
    this.stickDeadzone = VrWordsphereConstants.defaultStickDeadzone,
  }) : _stickPoint = Offset(baseSize / 2, baseSize / 2);

  final VrWordspherePlane plane;
  final double baseSize;
  final double stickSpeed;
  final double stickDeadzone;

  Offset _stickPoint;
  bool _stickAim = false;
  bool _tracing = false;

  Offset get stickPoint => _stickPoint;
  bool get stickAim => _stickAim;
  bool get isTracing => _tracing;

  void reset() {
    _stickPoint = Offset(baseSize / 2, baseSize / 2);
    _stickAim = false;
    _tracing = false;
  }

  /// Resolves the active 2D cursor coordinate on the Wordsphere board from
  /// head/pointer [ray] and thumbstick deflection `(stickX, stickY)`.
  Offset? updateCursor({
    required vm.Ray ray,
    double stickX = 0.0,
    double stickY = 0.0,
    required double dt,
    bool pointerActive = false,
  }) {
    final safeBaseSize = baseSize.isFinite && baseSize > 0
        ? baseSize
        : VrWordsphereConstants.defaultBaseSizeTexels;
    final safeDeadzone = stickDeadzone.isFinite && stickDeadzone >= 0
        ? stickDeadzone.clamp(0.0, 0.99)
        : VrWordsphereConstants.defaultStickDeadzone;
    final safeSpeed = stickSpeed.isFinite && stickSpeed >= 0
        ? stickSpeed
        : VrWordsphereConstants.defaultStickSpeed;
    final sx = stickX.isFinite ? stickX.clamp(-1.0, 1.0) : 0.0;
    final sy = stickY.isFinite ? stickY.clamp(-1.0, 1.0) : 0.0;

    final hasStickInput = sx.abs() > safeDeadzone || sy.abs() > safeDeadzone;
    if (hasStickInput && !pointerActive) {
      if (!_stickAim) {
        final initialGaze = plane.intersect(ray, baseSize: safeBaseSize);
        if (initialGaze != null) _stickPoint = initialGaze;
      }
      _stickAim = true;
    }

    if (_stickAim && !pointerActive && dt.isFinite && dt > 0) {
      final x = sx.abs() > safeDeadzone ? sx : 0.0;
      final y = sy.abs() > safeDeadzone ? sy : 0.0;
      final scale =
          safeSpeed *
          dt.clamp(0.0, 0.1) /
          math.max(1.0, math.sqrt(x * x + y * y));
      final half = safeBaseSize / 2;
      final prevX = _stickPoint.dx.isFinite ? _stickPoint.dx : half;
      final prevY = _stickPoint.dy.isFinite ? _stickPoint.dy : half;
      var px = prevX - half + x * scale;
      var py = prevY - half - y * scale;
      final radius = math.sqrt(px * px + py * py);
      final limit =
          safeBaseSize * VrWordsphereConstants.maxCursorRadiusNormalized;
      if (radius > limit && radius > 0) {
        px *= limit / radius;
        py *= limit / radius;
      }
      _stickPoint = Offset(px + half, py + half);
    }

    if (pointerActive) {
      return plane.intersect(ray, baseSize: safeBaseSize);
    }
    if (_stickAim) {
      return _stickPoint;
    }
    return plane.intersect(ray, baseSize: safeBaseSize);
  }

  /// Toggles deliberate controller tracing (Button X / A).
  bool toggleTracing() {
    _tracing = !_tracing;
    return _tracing;
  }

  /// Cancels an active stroke when tracing, or invokes [onDeleteWord] when idle
  /// (Button B). Returns `true` if an active stroke was cancelled.
  bool handleCancelOrDelete({void Function()? onDeleteWord}) {
    if (_tracing) {
      _tracing = false;
      return true;
    }
    onDeleteWord?.call();
    return false;
  }
}
