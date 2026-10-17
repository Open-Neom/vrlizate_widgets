import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A horizontal group of mutually exclusive 3D segments.
///
/// Useful for tabs, filters, quiz answers and view modes. Every segment has a
/// stable node name (`<name>_segment_<index>`) and selection is expressed with
/// PBR color plus emissive depth, so it remains legible without bloom.
class VrSegmentedControl3D extends VrControl {
  VrSegmentedControl3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    required List<String> options,
    int selectedIndex = 0,
    this.onChanged,
    this.meshBuilder,
    this.width = VrWidgetConstants.segmentedDefaultWidth,
    this.height = VrWidgetConstants.segmentedDefaultHeight,
    vm.Vector4? selectedColor,
    vm.Vector4? idleColor,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : assert(options.isNotEmpty, 'a segmented control needs options'),
       assert(
         selectedIndex >= 0 && selectedIndex < options.length,
         'selectedIndex must point to an option',
       ),
       options = List.unmodifiable(options),
       selectedIndex = selectedIndex,
       selectedColor = selectedColor ?? vm.Vector4(0.18, 0.72, 0.92, 1.0),
       idleColor = idleColor ?? vm.Vector4(0.12, 0.16, 0.24, 1.0) {
    _railMaterial = controlMaterial(vm.Vector4(0.04, 0.05, 0.08, 1.0))
      ..metallicFactor = 0.65
      ..roughnessFactor = 0.28;
    _rail =
        Node(
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(
                    vm.Vector3(width + 0.045, height + 0.04, 0.035),
                  ),
                  _railMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, 0, -0.025),
          );

    final segmentWidth = width / options.length;
    for (var i = 0; i < options.length; i++) {
      final material = controlMaterial(this.idleColor)..roughnessFactor = 0.3;
      _segmentMaterials.add(material);
      _segments.add(
        Node(
            name: _nodeName(i),
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(
                    vm.Vector3(segmentWidth - 0.012, height, 0.055),
                  ),
                  material,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(-width / 2 + segmentWidth * (i + 0.5), 0, 0.015),
          ),
      );
    }
    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  final List<String> options;
  final void Function(int index, String option)? onChanged;
  final VrControlMeshBuilder? meshBuilder;
  final double width;
  final double height;
  final vm.Vector4 selectedColor;
  final vm.Vector4 idleColor;

  int selectedIndex;
  int _hoveredIndex = -1;

  late final Node _rail;
  late final PhysicallyBasedMaterial _railMaterial;
  final List<Node> _segments = [];
  final List<PhysicallyBasedMaterial> _segmentMaterials = [];

  String _nodeName(int index) =>
      '$name${VrWidgetConstants.segmentedControlSegment}$index';

  int? _indexFromNode(String nodeName) {
    final prefix = '$name${VrWidgetConstants.segmentedControlSegment}';
    if (!nodeName.startsWith(prefix)) return null;
    final index = int.tryParse(nodeName.substring(prefix.length));
    return index != null && index >= 0 && index < options.length ? index : null;
  }

  String get selectedOption => options[selectedIndex];

  List<PhysicallyBasedMaterial> get debugSegmentMaterials =>
      List.unmodifiable(_segmentMaterials);

  /// Updates selection without firing [onChanged].
  void setSelectedIndex(int index) {
    RangeError.checkValidIndex(index, options, 'index');
    selectedIndex = index;
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [
    for (var i = 0; i < options.length; i++) _nodeName(i),
  ];

  @override
  List<Node> get nodes => [_rail, ..._segments];

  @override
  String get label =>
      '$baseLabel: ${options[_hoveredIndex >= 0 ? _hoveredIndex : selectedIndex]}';

  @override
  void applyEmissive() {
    _railMaterial.emissiveFactor = vm.Vector4.zero();
    for (var i = 0; i < _segmentMaterials.length; i++) {
      final material = _segmentMaterials[i];
      if (!enabled) {
        material.baseColorFactor = idleColor * 0.35;
        material.emissiveFactor = vm.Vector4.zero();
        continue;
      }
      final selected = i == selectedIndex;
      final hovered = i == _hoveredIndex;
      material.baseColorFactor = selected ? selectedColor : idleColor;
      final glow =
          (selected ? 0.48 : 0.05) +
          (hovered ? 0.32 : 0) +
          (selected ? flashLevel * 0.35 : 0);
      material.emissiveFactor = vm.Vector4(
        selectedColor.x * glow,
        selectedColor.y * glow,
        selectedColor.z * glow,
        0,
      );
    }
  }

  @override
  void onHoverEnter(String nodeName) {
    _hoveredIndex = _indexFromNode(nodeName) ?? -1;
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _hoveredIndex = -1;
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    final index = _indexFromNode(nodeName);
    if (index == null) return;
    final changed = index != selectedIndex;
    selectedIndex = index;
    flash();
    if (changed) onChanged?.call(index, options[index]);
  }
}
