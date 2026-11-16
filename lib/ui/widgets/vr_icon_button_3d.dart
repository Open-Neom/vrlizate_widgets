import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A circular or cubic 3D floating action / icon button with a raised center
/// emblem (the VR counterpart of Flutter's `IconButton` / `FloatingActionButton`).
class VrIconButton3D extends VrControl {
  VrIconButton3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    this.size = VrWidgetConstants.iconButtonDefaultSize,
    this.isCircular = true,
    vm.Vector4? backgroundColor,
    vm.Vector4? iconColor,
    this.onPressed,
    this.meshBuilder,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : backgroundColor =
           backgroundColor ?? VrWidgetConstants.defaultIconButtonColor,
       iconColor = iconColor ?? VrWidgetConstants.defaultIconEmblemColor {
    _baseMat = controlMaterial(this.backgroundColor);
    _emblemMat = controlMaterial(this.iconColor)..roughnessFactor = 0.2;

    _baseNode = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            isCircular
                ? VrBeveledBoxGeometry.pill(
                    vm.Vector3(size, size, VrWidgetConstants.iconButtonDepth),
                  )
                : VrBeveledBoxGeometry.create(
                    vm.Vector3(size, size, VrWidgetConstants.iconButtonDepth),
                    cornerRadius: size * 0.24,
                  ),
            _baseMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    final emblemSize = size * VrWidgetConstants.iconButtonEmblemFactor;
    _emblemNode =
        Node(
            name: emblemNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.create(
                    vm.Vector3(emblemSize, emblemSize, emblemSize * 0.45),
                    cornerRadius: emblemSize * 0.28,
                  ),
                  _emblemMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(0, 0, VrWidgetConstants.iconButtonEmblemZOffset),
          );

    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  final double size;
  final bool isCircular;
  final vm.Vector4 backgroundColor;
  final vm.Vector4 iconColor;
  final void Function()? onPressed;
  final VrControlMeshBuilder? meshBuilder;

  bool _hovered = false;

  late final PhysicallyBasedMaterial _baseMat;
  late final PhysicallyBasedMaterial _emblemMat;
  late final Node _baseNode;
  late final Node _emblemNode;

  String get emblemNodeName => '$name${VrWidgetConstants.iconEmblemSuffix}';

  PhysicallyBasedMaterial get debugMaterial => _baseMat;
  PhysicallyBasedMaterial get debugEmblemMaterial => _emblemMat;

  @override
  List<String> get nodeNames => [name, emblemNodeName];

  @override
  List<Node> get nodes => [_baseNode, _emblemNode];

  @override
  void applyEmissive() {
    if (!enabled) {
      _baseMat.emissiveFactor = vm.Vector4.zero();
      _emblemMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final baseGlow = (_hovered ? 0.36 : 0.12) + flashLevel * 0.5;
    _baseMat.emissiveFactor = vm.Vector4(
      backgroundColor.x * baseGlow,
      backgroundColor.y * baseGlow,
      backgroundColor.z * baseGlow,
      0,
    );
    final emblemGlow = (_hovered ? 0.6 : 0.25) + flashLevel * 0.45;
    _emblemMat.emissiveFactor = vm.Vector4(
      iconColor.x * emblemGlow,
      iconColor.y * emblemGlow,
      iconColor.z * emblemGlow,
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
    flash();
    onPressed?.call();
  }
}
