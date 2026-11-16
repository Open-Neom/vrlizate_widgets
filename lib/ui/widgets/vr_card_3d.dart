import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A 3D beveled card with configurable elevation, header accent strip, and
/// optional press handler (the VR counterpart of Flutter's `Card`).
class VrCard3D extends VrControl {
  VrCard3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    this.subtitle = '',
    this.elevation = VrWidgetConstants.cardDefaultElevation,
    this.width = VrWidgetConstants.cardDefaultWidth,
    this.height = VrWidgetConstants.cardDefaultHeight,
    vm.Vector4? color,
    vm.Vector4? bevelColor,
    vm.Vector4? accentColor,
    this.onPressed,
    this.meshBuilder,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : color = color ?? VrWidgetConstants.defaultCardColor,
       bevelColor = bevelColor ?? VrWidgetConstants.defaultCardBevelColor,
       accentColor = accentColor ?? VrWidgetConstants.defaultCardAccentColor {
    _bevelMat = controlMaterial(this.bevelColor)
      ..metallicFactor = 0.55
      ..roughnessFactor = 0.3;
    _plateMat = controlMaterial(this.color)..roughnessFactor = 0.28;
    _accentMat = controlMaterial(this.accentColor)..roughnessFactor = 0.22;

    _bevelNode = Node(
      name: bevelNodeName,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.panel(
              vm.Vector3(
                width + VrWidgetConstants.cardBevelPadding,
                height + VrWidgetConstants.cardBevelPadding,
                VrWidgetConstants.cardBevelDepth,
              ),
              cornerRadius: 0.042,
            ),
            _bevelMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    _plateNode =
        Node(
            name: name,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.panel(
                    vm.Vector3(
                      width,
                      height,
                      VrWidgetConstants.cardDefaultDepth,
                    ),
                    cornerRadius: 0.036,
                  ),
                  _plateMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, 0, elevation),
          );

    final accentY =
        height / 2 - VrWidgetConstants.cardAccentHeight / 2 - 0.018;
    final accentZ =
        elevation +
        VrWidgetConstants.cardDefaultDepth / 2 +
        VrWidgetConstants.cardAccentDepth / 2;
    _accentStripNode =
        Node(
            name: accentNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.pill(
                    vm.Vector3(
                      width - 0.04,
                      VrWidgetConstants.cardAccentHeight,
                      VrWidgetConstants.cardAccentDepth,
                    ),
                  ),
                  _accentMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, accentY, accentZ),
          );

    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  final String subtitle;
  double elevation;
  final double width;
  final double height;
  final vm.Vector4 color;
  final vm.Vector4 bevelColor;
  final vm.Vector4 accentColor;
  final void Function()? onPressed;
  final VrControlMeshBuilder? meshBuilder;

  bool _hovered = false;

  late final PhysicallyBasedMaterial _bevelMat;
  late final PhysicallyBasedMaterial _plateMat;
  late final PhysicallyBasedMaterial _accentMat;
  late final Node _bevelNode;
  late final Node _plateNode;
  late final Node _accentStripNode;

  String get bevelNodeName => '$name${VrWidgetConstants.cardBevelSuffix}';
  String get accentNodeName => '$name${VrWidgetConstants.cardAccentSuffix}';

  PhysicallyBasedMaterial get debugMaterial => _plateMat;
  PhysicallyBasedMaterial get debugAccentMaterial => _accentMat;

  /// Updates the card elevation in meters along local +Z without rebuilding.
  void setElevation(double nextElevation) {
    elevation = nextElevation;
    final accentY =
        height / 2 - VrWidgetConstants.cardAccentHeight / 2 - 0.018;
    final accentZ =
        elevation +
        VrWidgetConstants.cardDefaultDepth / 2 +
        VrWidgetConstants.cardAccentDepth / 2;
    updateBaseOffset(_plateNode, vm.Vector3(0, 0, elevation));
    updateBaseOffset(_accentStripNode, vm.Vector3(0, accentY, accentZ));
    moveTo(origin);
  }

  @override
  String get label =>
      subtitle.isEmpty ? baseLabel : '$baseLabel — $subtitle';

  @override
  List<String> get nodeNames => [name, bevelNodeName, accentNodeName];

  @override
  List<Node> get nodes => [_bevelNode, _plateNode, _accentStripNode];

  @override
  void applyEmissive() {
    _bevelMat.emissiveFactor = vm.Vector4.zero();
    if (!enabled) {
      _plateMat.emissiveFactor = vm.Vector4.zero();
      _accentMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final plateGlow = (_hovered ? 0.24 : 0.06) + flashLevel * 0.4;
    _plateMat.emissiveFactor = vm.Vector4(
      color.x * plateGlow,
      color.y * plateGlow,
      color.z * plateGlow,
      0,
    );
    final accentGlow = (_hovered ? 0.55 : 0.28) + flashLevel * 0.45;
    _accentMat.emissiveFactor = vm.Vector4(
      accentColor.x * accentGlow,
      accentColor.y * accentGlow,
      accentColor.z * accentGlow,
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
