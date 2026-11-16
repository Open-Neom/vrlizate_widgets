import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A selectable 3D filter/choice chip pill with a leading selection dot
/// (the VR counterpart of Flutter's `FilterChip` / `ChoiceChip`).
class VrChip3D extends VrControl {
  VrChip3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    bool initialSelected = false,
    this.onSelected,
    this.width = VrWidgetConstants.chipDefaultWidth,
    this.height = VrWidgetConstants.chipDefaultHeight,
    vm.Vector4? selectedColor,
    vm.Vector4? unselectedColor,
    this.meshBuilder,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : selected = initialSelected,
       selectedColor =
           selectedColor ?? VrWidgetConstants.defaultChipSelectedColor,
       unselectedColor =
           unselectedColor ?? VrWidgetConstants.defaultChipUnselectedColor {
    _pillMat = controlMaterial(
      selected ? this.selectedColor : this.unselectedColor,
    );
    _indicatorMat = controlMaterial(this.selectedColor)..roughnessFactor = 0.2;

    _pillNode = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.pill(
              vm.Vector3(width, height, VrWidgetConstants.chipDefaultDepth),
            ),
            _pillMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    final dotX = -width / 2 + VrWidgetConstants.chipIndicatorRadius * 2.2;
    _indicatorNode =
        Node(
            name: indicatorNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  SphereGeometry(radius: VrWidgetConstants.chipIndicatorRadius),
                  _indicatorMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(dotX, 0, VrWidgetConstants.chipIndicatorZOffset),
          )
          ..visible = selected;

    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  bool selected;
  final void Function(bool selected)? onSelected;
  final double width;
  final double height;
  final vm.Vector4 selectedColor;
  final vm.Vector4 unselectedColor;
  final VrControlMeshBuilder? meshBuilder;

  bool _hovered = false;

  late final PhysicallyBasedMaterial _pillMat;
  late final PhysicallyBasedMaterial _indicatorMat;
  late final Node _pillNode;
  late final Node _indicatorNode;

  String get indicatorNodeName =>
      '$name${VrWidgetConstants.chipIndicatorSuffix}';

  PhysicallyBasedMaterial get debugMaterial => _pillMat;

  /// Updates [selected] and indicator visibility without firing [onSelected].
  void setSelected(bool nextSelected) {
    selected = nextSelected;
    _indicatorNode.visible = selected;
    applyEmissive();
  }

  @override
  String get label => selected
      ? '$baseLabel ${VrWidgetConstants.chipSelectedSuffix}'
      : baseLabel;

  @override
  List<String> get nodeNames => [name, indicatorNodeName];

  @override
  List<Node> get nodes => [_pillNode, _indicatorNode];

  @override
  void applyEmissive() {
    if (!enabled) {
      _pillMat.baseColorFactor = unselectedColor * 0.4;
      _pillMat.emissiveFactor = vm.Vector4.zero();
      _indicatorMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final activeColor = selected ? selectedColor : unselectedColor;
    _pillMat.baseColorFactor = activeColor;
    final glow =
        (selected ? 0.38 : 0.07) + (_hovered ? 0.28 : 0) + flashLevel * 0.42;
    _pillMat.emissiveFactor = vm.Vector4(
      activeColor.x * glow,
      activeColor.y * glow,
      activeColor.z * glow,
      0,
    );
    final dotGlow = (selected ? 0.75 : 0.1) + flashLevel * 0.4;
    _indicatorMat.emissiveFactor = vm.Vector4(
      selectedColor.x * dotGlow,
      selectedColor.y * dotGlow,
      selectedColor.z * dotGlow,
      0,
    );
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
    selected = !selected;
    _indicatorNode.visible = selected;
    flash();
    onSelected?.call(selected);
  }
}
