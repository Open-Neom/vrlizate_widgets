import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A spatial 3D modal dialog with a backdrop plate, header bar, confirm button,
/// and cancel button (the VR counterpart of Flutter's `AlertDialog` / `Dialog`).
class VrDialog3D extends VrControl {
  VrDialog3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    this.confirmLabel = VrWidgetConstants.dialogDefaultConfirmLabel,
    this.cancelLabel = VrWidgetConstants.dialogDefaultCancelLabel,
    this.onConfirm,
    this.onCancel,
    this.width = VrWidgetConstants.dialogDefaultWidth,
    this.height = VrWidgetConstants.dialogDefaultHeight,
    bool initialOpen = true,
    vm.Vector4? backdropColor,
    vm.Vector4? headerColor,
    vm.Vector4? confirmColor,
    vm.Vector4? cancelColor,
    this.meshBuilder,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : isOpen = initialOpen,
       backdropColor =
           backdropColor ?? VrWidgetConstants.defaultDialogBackdropColor,
       headerColor = headerColor ?? VrWidgetConstants.defaultDialogHeaderColor,
       confirmColor =
           confirmColor ?? VrWidgetConstants.defaultDialogConfirmColor,
       cancelColor = cancelColor ?? VrWidgetConstants.defaultDialogCancelColor {
    _backdropMat = controlMaterial(this.backdropColor)
      ..metallicFactor = 0.45
      ..roughnessFactor = 0.25;
    _headerMat = controlMaterial(this.headerColor);
    _confirmMat = controlMaterial(this.confirmColor);
    _cancelMat = controlMaterial(this.cancelColor);

    _backdropNode = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.panel(
              vm.Vector3(width, height, VrWidgetConstants.dialogBackdropDepth),
              cornerRadius: 0.044,
            ),
            _backdropMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    final headerY = height / 2 - VrWidgetConstants.dialogHeaderHeight / 2;
    _headerNode =
        Node(
            name: headerNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.panel(
                    vm.Vector3(
                      width,
                      VrWidgetConstants.dialogHeaderHeight,
                      VrWidgetConstants.dialogBackdropDepth + 0.012,
                    ),
                    cornerRadius: 0.036,
                  ),
                  _headerMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, headerY, 0.008),
          );

    final buttonY = -height / 2 + VrWidgetConstants.dialogButtonHeight * 0.9;
    final buttonOffsetX = width * 0.23;
    _cancelNode =
        Node(
            name: cancelNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.pill(
                    vm.Vector3(
                      VrWidgetConstants.dialogButtonWidth,
                      VrWidgetConstants.dialogButtonHeight,
                      VrWidgetConstants.dialogButtonDepth,
                    ),
                  ),
                  _cancelMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(
                  -buttonOffsetX,
                  buttonY,
                  VrWidgetConstants.dialogButtonZOffset,
                ),
          );

    _confirmNode =
        Node(
            name: confirmNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.pill(
                    vm.Vector3(
                      VrWidgetConstants.dialogButtonWidth,
                      VrWidgetConstants.dialogButtonHeight,
                      VrWidgetConstants.dialogButtonDepth,
                    ),
                  ),
                  _confirmMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(
                  buttonOffsetX,
                  buttonY,
                  VrWidgetConstants.dialogButtonZOffset,
                ),
          );

    _syncVisibility();
    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  final String confirmLabel;
  final String cancelLabel;
  final void Function()? onConfirm;
  final void Function()? onCancel;
  final double width;
  final double height;
  final vm.Vector4 backdropColor;
  final vm.Vector4 headerColor;
  final vm.Vector4 confirmColor;
  final vm.Vector4 cancelColor;
  final VrControlMeshBuilder? meshBuilder;

  bool isOpen;
  String? _hoveredNode;

  late final PhysicallyBasedMaterial _backdropMat;
  late final PhysicallyBasedMaterial _headerMat;
  late final PhysicallyBasedMaterial _confirmMat;
  late final PhysicallyBasedMaterial _cancelMat;
  late final Node _backdropNode;
  late final Node _headerNode;
  late final Node _confirmNode;
  late final Node _cancelNode;

  String get headerNodeName => '$name${VrWidgetConstants.dialogHeaderSuffix}';
  String get confirmNodeName => '$name${VrWidgetConstants.dialogConfirmSuffix}';
  String get cancelNodeName => '$name${VrWidgetConstants.dialogCancelSuffix}';

  PhysicallyBasedMaterial get debugConfirmMaterial => _confirmMat;
  PhysicallyBasedMaterial get debugCancelMaterial => _cancelMat;

  /// Shows the modal dialog in the scene.
  void show() {
    isOpen = true;
    _syncVisibility();
    applyEmissive();
  }

  /// Dismisses (hides) the modal dialog in the scene.
  void dismiss() {
    isOpen = false;
    _hoveredNode = null;
    _syncVisibility();
    applyEmissive();
  }

  void _syncVisibility() {
    for (final node in nodes) {
      node.visible = isOpen;
    }
  }

  @override
  String get label {
    if (_hoveredNode == confirmNodeName) {
      return '$baseLabel: $confirmLabel';
    }
    if (_hoveredNode == cancelNodeName) {
      return '$baseLabel: $cancelLabel';
    }
    return baseLabel;
  }

  @override
  List<String> get nodeNames => [
    name,
    headerNodeName,
    confirmNodeName,
    cancelNodeName,
  ];

  @override
  List<Node> get nodes => [
    _backdropNode,
    _headerNode,
    _cancelNode,
    _confirmNode,
  ];

  @override
  void applyEmissive() {
    _backdropMat.emissiveFactor = vm.Vector4.zero();
    if (!enabled || !isOpen) {
      _headerMat.emissiveFactor = vm.Vector4.zero();
      _confirmMat.emissiveFactor = vm.Vector4.zero();
      _cancelMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final headerGlow = 0.14 + (_hoveredNode == headerNodeName ? 0.2 : 0);
    _headerMat.emissiveFactor = vm.Vector4(
      headerColor.x * headerGlow,
      headerColor.y * headerGlow,
      headerColor.z * headerGlow,
      0,
    );
    final confirmGlow =
        0.18 + (_hoveredNode == confirmNodeName ? 0.38 : 0) + flashLevel * 0.45;
    _confirmMat.emissiveFactor = vm.Vector4(
      confirmColor.x * confirmGlow,
      confirmColor.y * confirmGlow,
      confirmColor.z * confirmGlow,
      0,
    );
    final cancelGlow =
        0.18 + (_hoveredNode == cancelNodeName ? 0.38 : 0) + flashLevel * 0.45;
    _cancelMat.emissiveFactor = vm.Vector4(
      cancelColor.x * cancelGlow,
      cancelColor.y * cancelGlow,
      cancelColor.z * cancelGlow,
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
    if (!isOpen) return;
    if (nodeName == confirmNodeName) {
      flash();
      onConfirm?.call();
      return;
    }
    if (nodeName == cancelNodeName) {
      flash();
      onCancel?.call();
      return;
    }
    flash();
  }
}
