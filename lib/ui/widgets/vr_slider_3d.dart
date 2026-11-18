import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A gaze-interactive segmented slider (the VR counterpart of `Slider`).
class VrSlider3D extends VrControl {
  static double _clamp01(double v) => !v.isFinite ? 0.0 : v.clamp(0.0, 1.0);

  VrSlider3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    int divisions = VrWidgetConstants.sliderDefaultDivisions,
    double initialValue = VrWidgetConstants.sliderDefaultInitialValue,
    this.onChanged,
    this.valueFormat,
    this.meshBuilder,
    double width = VrWidgetConstants.sliderDefaultWidth,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : assert(divisions >= 2, 'a slider needs at least 2 divisions'),
       divisions = !divisions.isFinite || divisions < 2
           ? 2
           : (divisions > 1024 ? 1024 : divisions),
       width = !width.isFinite || width <= 0
           ? VrWidgetConstants.sliderDefaultWidth
           : width,
       value = _clamp01(initialValue) {
    final safeCenter =
        center.x.isFinite && center.y.isFinite && center.z.isFinite
        ? center
        : vm.Vector3.zero();
    _trackMat = controlMaterial(vm.Vector4(0.30, 0.32, 0.40, 1.0));
    _track = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.pill(vm.Vector3(this.width, 0.035, 0.035)),
            _trackMat,
          ),
    )..localTransform = vm.Matrix4.translation(safeCenter);

    for (var i = 0; i < this.divisions; i++) {
      final t = i / (this.divisions - 1);
      final mat = controlMaterial(vm.Vector4(0.20, 0.55, 0.70, 1.0));
      _segmentMats.add(mat);
      _segmentOffsets.add(vm.Vector3((t - 0.5) * this.width, 0, 0.012));
      _segments.add(
        Node(
          name: '$_segmentPrefix$i',
          mesh:
              meshBuilder?.call() ??
              Mesh(
                VrBeveledBoxGeometry.pill(
                  vm.Vector3(this.width / (this.divisions + 2), 0.05, 0.02),
                ),
                mat,
              ),
        )..localTransform = vm.Matrix4.translation(
          safeCenter + _segmentOffsets[i],
        ),
      );
    }

    _thumbMat = controlMaterial(vm.Vector4(0.35, 0.85, 0.95, 1.0));
    _thumb = Node(
      name: name,
      mesh:
          meshBuilder?.call() ?? Mesh(SphereGeometry(radius: 0.05), _thumbMat),
    );
    _placeThumb();
    initSpatial(safeCenter, mode: placementMode);
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

  String get _segmentPrefix => '$name${VrWidgetConstants.sliderSegment}';

  /// Programmatic set (e.g. loading a saved configuration): moves the
  /// thumb and refreshes emissive WITHOUT firing [onChanged].
  void setValue(double v) {
    value = _clamp01(v);
    _placeThumb();
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [
    name,
    for (var i = 0; i < divisions; i++) '$_segmentPrefix$i',
  ];

  @override
  List<Node> get nodes => [_track, _thumb, ..._segments];

  /// HUD label includes the formatted value.
  @override
  String get label {
    final safeVal = _clamp01(value);
    final formatted =
        valueFormat?.call(safeVal) ?? '${(safeVal * 100).round()}%';
    return '$baseLabel: $formatted';
  }

  /// Thumb glide position derived from the track's live transform (survives
  /// parent panel moves and scales).
  void _placeThumb() {
    final trackPos = _track.localTransform.getTranslation();
    final currentScale = _track.localTransform.getMaxScaleOnAxis();
    final localX = (value - 0.5) * width;
    final x = trackPos.x + localX * currentScale;
    _thumb.localTransform = vm.Matrix4.translation(
      vm.Vector3(x, trackPos.y, trackPos.z + 0.05),
    );
    updateBaseOffset(_thumb, vm.Vector3(localX, 0, 0.05));
  }

  /// The value a segment index maps to.
  double valueForSegment(int i) {
    final safeIdx = !i.isFinite ? 0 : i.clamp(0, divisions - 1);
    return safeIdx / (divisions - 1);
  }

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
    if (nodeName.startsWith(_segmentPrefix)) {
      final parsed = int.tryParse(nodeName.substring(_segmentPrefix.length));
      if (parsed != null && parsed >= 0 && parsed < divisions) {
        _hoveredSegment = parsed;
        _hovered = false;
      } else {
        _hoveredSegment = -1;
        _hovered = false;
      }
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
    if (nodeName.startsWith(_segmentPrefix)) {
      final i = int.tryParse(nodeName.substring(_segmentPrefix.length));
      if (i == null || i < 0 || i >= divisions) return;
      value = valueForSegment(i);
      _placeThumb();
      flash();
      onChanged?.call(value);
      return;
    }
    flash();
  }
}
