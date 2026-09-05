/// Segmented 3D slider for gaze input.
///
/// Why segmented: `StereoSceneView`'s gaze raycast reports the **node name**
/// under the reticle, not the hit coordinates — a continuous slider thumb
/// cannot be tracked through it. Instead the track is divided into
/// [divisions] gaze-selectable pads (`<name>_seg_<i>`): dwell a pad and the
/// value jumps to that step while the thumb glides there.
///
/// ```dart
/// VrSlider3D(
///   name: 'volume', label: 'Volumen', center: Vector3(0, 1.4, -2),
///   divisions: 5, initialValue: 0.6,
///   onChanged: (v) => setVolume(v),
/// );
/// ```
///
/// The thumb position is recomputed from the track's **current** transform
/// (translation + scale), so the slider stays consistent when a parent
/// [VrPanel3D] moves or scales it.
library;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'vr_controls.dart';

/// A gaze-interactive segmented slider (the VR counterpart of `Slider`).
class VrSlider3D extends VrControl {
  VrSlider3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    this.divisions = 5,
    double initialValue = 0.5,
    this.onChanged,
    this.valueFormat,
    this.meshBuilder,
    this.width = 0.42,
  }) : assert(divisions >= 2, 'a slider needs at least 2 divisions'),
       value = initialValue.clamp(0.0, 1.0) {
    _trackMat = controlMaterial(vm.Vector4(0.30, 0.32, 0.40, 1.0));
    _track = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(CuboidGeometry(vm.Vector3(width, 0.035, 0.035)), _trackMat),
    )..localTransform = vm.Matrix4.translation(center);

    for (var i = 0; i < divisions; i++) {
      final t = i / (divisions - 1);
      final mat = controlMaterial(vm.Vector4(0.20, 0.55, 0.70, 1.0));
      _segmentMats.add(mat);
      _segmentOffsets.add(vm.Vector3((t - 0.5) * width, 0, 0.012));
      _segments.add(
        Node(
          name: '${name}_seg_$i',
          mesh:
              meshBuilder?.call() ??
              Mesh(
                CuboidGeometry(vm.Vector3(width / (divisions + 2), 0.05, 0.02)),
                mat,
              ),
        )..localTransform = vm.Matrix4.translation(center + _segmentOffsets[i]),
      );
    }

    _thumbMat = controlMaterial(vm.Vector4(0.35, 0.85, 0.95, 1.0));
    _thumb = Node(
      name: name, // same name as the track: gaze on it = slider context
      mesh:
          meshBuilder?.call() ?? Mesh(SphereGeometry(radius: 0.05), _thumbMat),
    );
    _placeThumb();
  }

  /// Number of selectable steps (≥ 2).
  final int divisions;

  /// Current value, 0.0–1.0.
  double value;

  final void Function(double value)? onChanged;

  /// Custom formatter for the HUD label (e.g. months instead of %).
  final String Function(double value)? valueFormat;

  /// Test/headless hook — see [VrControlMeshBuilder].
  final VrControlMeshBuilder? meshBuilder;

  /// Track length in meters (before any parent scaling).
  final double width;

  bool _hovered = false;
  int _hoveredSegment = -1;

  late final PhysicallyBasedMaterial _trackMat;
  late final PhysicallyBasedMaterial _thumbMat;
  late final Node _track;
  late final Node _thumb;
  final List<Node> _segments = [];
  final List<PhysicallyBasedMaterial> _segmentMats = [];
  final List<vm.Vector3> _segmentOffsets = [];

  /// Track material (state inspection in tests and demos).
  PhysicallyBasedMaterial get debugMaterial => _trackMat;

  /// Programmatic set (e.g. loading a saved configuration): moves the
  /// thumb and refreshes emissive WITHOUT firing [onChanged].
  void setValue(double v) {
    value = v.clamp(0.0, 1.0);
    _placeThumb();
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [
    name,
    for (var i = 0; i < divisions; i++) '${name}_seg_$i',
  ];

  @override
  List<Node> get nodes => [_track, _thumb, ..._segments];

  /// HUD label includes the formatted value.
  @override
  String get label {
    final formatted = valueFormat?.call(value) ?? '${(value * 100).round()}%';
    return '$baseLabel: $formatted';
  }

  /// Thumb glide position derived from the track's live transform (survives
  /// parent panel moves and scales).
  void _placeThumb() {
    final trackPos = _track.localTransform.getTranslation();
    final scale = _track.localTransform.getMaxScaleOnAxis();
    final x = trackPos.x + (value - 0.5) * width * scale;
    _thumb.localTransform = vm.Matrix4.translation(
      vm.Vector3(x, trackPos.y, trackPos.z + 0.05),
    );
  }

  /// The value a segment index maps to.
  double valueForSegment(int i) => i / (divisions - 1);

  @override
  void applyEmissive() {
    _trackMat.emissiveFactor = vm.Vector4.zero();
    if (!enabled) {
      for (final material in _segmentMats) {
        material.emissiveFactor = vm.Vector4.zero();
      }
      _thumbMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    for (var i = 0; i < divisions; i++) {
      final filled = valueForSegment(i) <= value + 1e-6;
      var glow = filled ? 0.35 : 0.06;
      if (i == _hoveredSegment) glow += 0.35;
      _segmentMats[i].emissiveFactor = vm.Vector4(
        glow * 0.3,
        glow * 0.8,
        glow,
        0,
      );
    }
    final thumbGlow = (_hovered ? 0.45 : 0.2) + flashLevel * 0.5;
    _thumbMat.emissiveFactor = vm.Vector4(
      thumbGlow * 0.5,
      thumbGlow,
      thumbGlow,
      0,
    );
  }

  @override
  void onHoverEnter(String nodeName) {
    if (nodeName.startsWith('${name}_seg_')) {
      _hoveredSegment = int.parse(nodeName.substring('${name}_seg_'.length));
      _hovered = false;
    } else {
      _hoveredSegment = -1;
      _hovered = true;
    }
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _hovered = false;
    _hoveredSegment = -1;
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    if (nodeName.startsWith('${name}_seg_')) {
      final i = int.parse(nodeName.substring('${name}_seg_'.length));
      value = valueForSegment(i);
      _placeThumb();
      flash();
      onChanged?.call(value);
      return;
    }
    // Track/thumb select: context flash only (value changes via segments).
    flash();
  }
}
