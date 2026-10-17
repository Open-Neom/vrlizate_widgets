import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A 3D list item row with a leading indicator node, main plate, and trailing
/// action node (the VR counterpart of Flutter's `ListTile`).
class VrListTile3D extends VrControl {
  VrListTile3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    this.subtitle = '',
    this.selected = false,
    this.onTap,
    this.onTrailingTap,
    this.width = VrWidgetConstants.listTileDefaultWidth,
    this.height = VrWidgetConstants.listTileDefaultHeight,
    vm.Vector4? tileColor,
    vm.Vector4? leadingColor,
    vm.Vector4? trailingColor,
    this.meshBuilder,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : tileColor = tileColor ?? VrWidgetConstants.defaultListTileColor,
       leadingColor =
           leadingColor ?? VrWidgetConstants.defaultListTileLeadingColor,
       trailingColor =
           trailingColor ?? VrWidgetConstants.defaultListTileTrailingColor {
    _plateMat = controlMaterial(this.tileColor);
    _leadingMat = controlMaterial(this.leadingColor)..roughnessFactor = 0.22;
    _trailingMat = controlMaterial(this.trailingColor)..roughnessFactor = 0.25;

    _plateNode = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            CuboidGeometry(
              vm.Vector3(width, height, VrWidgetConstants.listTilePlateDepth),
            ),
            _plateMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    final leadingX = -width / 2 + VrWidgetConstants.listTileLeadingSize * 0.9;
    _leadingNode =
        Node(
            name: leadingNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  SphereGeometry(
                    radius: VrWidgetConstants.listTileLeadingSize * 0.5,
                  ),
                  _leadingMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(
                  leadingX,
                  0,
                  VrWidgetConstants.listTileAccessoryZOffset,
                ),
          );

    final trailingX = width / 2 - VrWidgetConstants.listTileTrailingSize * 0.85;
    _trailingNode =
        Node(
            name: trailingNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(
                    vm.Vector3(
                      VrWidgetConstants.listTileTrailingSize,
                      VrWidgetConstants.listTileTrailingSize,
                      VrWidgetConstants.listTilePlateDepth,
                    ),
                  ),
                  _trailingMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(
                  trailingX,
                  0,
                  VrWidgetConstants.listTileAccessoryZOffset,
                ),
          );

    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  final String subtitle;
  bool selected;
  final void Function()? onTap;
  final void Function()? onTrailingTap;
  final double width;
  final double height;
  final vm.Vector4 tileColor;
  final vm.Vector4 leadingColor;
  final vm.Vector4 trailingColor;
  final VrControlMeshBuilder? meshBuilder;

  String? _hoveredNode;

  late final PhysicallyBasedMaterial _plateMat;
  late final PhysicallyBasedMaterial _leadingMat;
  late final PhysicallyBasedMaterial _trailingMat;
  late final Node _plateNode;
  late final Node _leadingNode;
  late final Node _trailingNode;

  String get leadingNodeName =>
      '$name${VrWidgetConstants.listTileLeadingSuffix}';
  String get trailingNodeName =>
      '$name${VrWidgetConstants.listTileTrailingSuffix}';

  PhysicallyBasedMaterial get debugMaterial => _plateMat;
  PhysicallyBasedMaterial get debugTrailingMaterial => _trailingMat;

  /// Updates [selected] state without firing [onTap].
  void setSelected(bool nextSelected) {
    selected = nextSelected;
    applyEmissive();
  }

  @override
  String get label =>
      subtitle.isEmpty ? baseLabel : '$baseLabel: $subtitle';

  @override
  List<String> get nodeNames => [name, leadingNodeName, trailingNodeName];

  @override
  List<Node> get nodes => [_plateNode, _leadingNode, _trailingNode];

  @override
  void applyEmissive() {
    if (!enabled) {
      _plateMat.emissiveFactor = vm.Vector4.zero();
      _leadingMat.emissiveFactor = vm.Vector4.zero();
      _trailingMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final plateHovered =
        _hoveredNode == name || _hoveredNode == leadingNodeName;
    final trailingHovered = _hoveredNode == trailingNodeName;
    final plateGlow =
        (selected ? 0.28 : 0.06) +
        (plateHovered ? 0.24 : 0) +
        flashLevel * 0.35;
    _plateMat.emissiveFactor = vm.Vector4(
      tileColor.x * plateGlow,
      tileColor.y * plateGlow,
      tileColor.z * plateGlow,
      0,
    );
    final leadingGlow = (selected ? 0.52 : 0.22) + (plateHovered ? 0.3 : 0);
    _leadingMat.emissiveFactor = vm.Vector4(
      leadingColor.x * leadingGlow,
      leadingColor.y * leadingGlow,
      leadingColor.z * leadingGlow,
      0,
    );
    final trailingGlow =
        0.16 + (trailingHovered ? 0.42 : 0) + flashLevel * 0.4;
    _trailingMat.emissiveFactor = vm.Vector4(
      trailingColor.x * trailingGlow,
      trailingColor.y * trailingGlow,
      trailingColor.z * trailingGlow,
      0,
    );
  }

  @override
  void onHoverEnter(String nodeName) {
    _hoveredNode = nodeName;
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _hoveredNode = null;
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    flash();
    if (nodeName == trailingNodeName && onTrailingTap != null) {
      onTrailingTap!();
      return;
    }
    onTap?.call();
  }
}
