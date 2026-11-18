import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A gaze-inspectable segmented progress bar.
///
/// Progress changes only material state, never geometry. This avoids runtime
/// mesh uploads and survives a parent `VrPanel3D` moving or scaling its nodes.
class VrProgressBar3D extends VrControl {
  static double _clamp01(double v) => !v.isFinite ? 0.0 : v.clamp(0.0, 1.0);

  VrProgressBar3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    double initialValue = 0,
    int segments = VrWidgetConstants.progressDefaultSegments,
    this.valueFormat,
    this.onPressed,
    this.meshBuilder,
    double width = VrWidgetConstants.progressDefaultWidth,
    vm.Vector4? fillColor,
    vm.Vector4? emptyColor,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : assert(segments >= 2, 'a progress bar needs at least 2 segments'),
       segments = !segments.isFinite || segments < 2
           ? 2
           : (segments > 1024 ? 1024 : segments),
       width = !width.isFinite || width <= 0
           ? VrWidgetConstants.progressDefaultWidth
           : width,
       value = _clamp01(initialValue),
       fillColor = fillColor ?? vm.Vector4(0.16, 0.88, 0.62, 1.0),
       emptyColor = emptyColor ?? vm.Vector4(0.08, 0.11, 0.17, 1.0) {
    final safeCenter =
        center.x.isFinite && center.y.isFinite && center.z.isFinite
        ? center
        : vm.Vector3.zero();
    _backMaterial = controlMaterial(vm.Vector4(0.025, 0.035, 0.055, 1.0))
      ..metallicFactor = 0.55;
    _back =
        Node(
            name: name,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.pill(
                    vm.Vector3(this.width + 0.05, 0.13, 0.035),
                  ),
                  _backMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            safeCenter + vm.Vector3(0, 0, -0.025),
          );

    final segmentWidth = this.width / this.segments;
    for (var i = 0; i < this.segments; i++) {
      final material = controlMaterial(this.emptyColor)..roughnessFactor = 0.25;
      _segmentMaterials.add(material);
      _segmentNodes.add(
        Node(
            name: name,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.create(
                    vm.Vector3(segmentWidth - 0.01, 0.085, 0.045),
                  ),
                  material,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            safeCenter +
                vm.Vector3(
                  -this.width / 2 + segmentWidth * (i + 0.5),
                  0,
                  0.012,
                ),
          ),
      );
    }
    initSpatial(safeCenter, mode: placementMode);
    applyEmissive();
  }

  final int segments;
  final String Function(double value)? valueFormat;
  final void Function()? onPressed;
  final VrControlMeshBuilder? meshBuilder;
  final double width;
  final vm.Vector4 fillColor;
  final vm.Vector4 emptyColor;

  double value;
  bool _hovered = false;

  late final Node _back;
  late final PhysicallyBasedMaterial _backMaterial;
  final List<Node> _segmentNodes = [];
  final List<PhysicallyBasedMaterial> _segmentMaterials = [];

  int get filledSegments => (_clamp01(value) * segments).round();

  List<PhysicallyBasedMaterial> get debugSegmentMaterials =>
      List.unmodifiable(_segmentMaterials);

  /// Updates progress without firing [onPressed].
  void setValue(double nextValue) {
    value = _clamp01(nextValue);
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [name];

  @override
  List<Node> get nodes => [_back, ..._segmentNodes];

  @override
  String get label {
    final safeVal = _clamp01(value);
    final formatted =
        valueFormat?.call(safeVal) ?? '${(safeVal * 100).round()}%';
    return '$baseLabel: $formatted';
  }

  @override
  void applyEmissive() {
    _backMaterial.emissiveFactor = vm.Vector4.zero();
    for (var i = 0; i < _segmentMaterials.length; i++) {
      final filled = i < filledSegments;
      final material = _segmentMaterials[i];
      if (!enabled) {
        material.baseColorFactor = emptyColor * 0.45;
        material.emissiveFactor = vm.Vector4.zero();
        continue;
      }
      material.baseColorFactor = filled ? fillColor : emptyColor;
      final glow =
          (filled ? 0.42 : 0.025) + (_hovered ? 0.15 : 0) + flashLevel * 0.12;
      final color = filled ? fillColor : emptyColor;
      material.emissiveFactor = vm.Vector4(
        color.x * glow,
        color.y * glow,
        color.z * glow,
        0,
      );
    }
  }

  @override
  void onHoverEnter(String nodeName) {
    _hovered = true;
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _hovered = false;
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    flash();
    onPressed?.call();
  }
}
