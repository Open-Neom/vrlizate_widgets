import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A 3D toggle switch with a pill track and a sliding thumb node
/// (the VR counterpart of Flutter's `Switch`).
class VrSwitch3D extends VrControl {
  VrSwitch3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    bool initialValue = false,
    this.onChanged,
    this.width = VrWidgetConstants.switchDefaultWidth,
    this.height = VrWidgetConstants.switchDefaultHeight,
    vm.Vector4? activeColor,
    vm.Vector4? inactiveColor,
    vm.Vector4? thumbColor,
    this.meshBuilder,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : value = initialValue,
       activeColor = activeColor ?? VrWidgetConstants.defaultSwitchActiveColor,
       inactiveColor =
           inactiveColor ?? VrWidgetConstants.defaultSwitchInactiveColor,
       thumbColor = thumbColor ?? VrWidgetConstants.defaultSwitchThumbColor {
    _trackMat = controlMaterial(value ? this.activeColor : this.inactiveColor);
    _thumbMat = controlMaterial(this.thumbColor)..roughnessFactor = 0.2;

    _trackNode = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.pill(
              vm.Vector3(width, height, VrWidgetConstants.switchTrackDepth),
            ),
            _trackMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    final thumbRadius = height * VrWidgetConstants.switchThumbRadiusFactor;
    _thumbNode = Node(
      name: thumbNodeName,
      mesh:
          meshBuilder?.call() ??
          Mesh(SphereGeometry(radius: thumbRadius), _thumbMat),
    );
    _placeThumb();
    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  bool value;
  final void Function(bool value)? onChanged;
  final double width;
  final double height;
  final vm.Vector4 activeColor;
  final vm.Vector4 inactiveColor;
  final vm.Vector4 thumbColor;
  final VrControlMeshBuilder? meshBuilder;

  bool _hovered = false;

  late final PhysicallyBasedMaterial _trackMat;
  late final PhysicallyBasedMaterial _thumbMat;
  late final Node _trackNode;
  late final Node _thumbNode;

  String get thumbNodeName => '$name${VrWidgetConstants.switchThumbSuffix}';

  PhysicallyBasedMaterial get debugTrackMaterial => _trackMat;
  PhysicallyBasedMaterial get debugThumbMaterial => _thumbMat;

  /// Updates the switch value and slides the thumb without firing [onChanged].
  void setValue(bool nextValue) {
    value = nextValue;
    _placeThumb();
    applyEmissive();
  }

  void _placeThumb() {
    final trackPos = _trackNode.localTransform.getTranslation();
    final currentScale = _trackNode.localTransform.getMaxScaleOnAxis();
    final localX =
        (value ? 1.0 : -1.0) *
        (width * VrWidgetConstants.switchThumbTravelFactor);
    final localOffset = vm.Vector3(
      localX,
      0,
      VrWidgetConstants.switchThumbZOffset,
    );
    _thumbNode.localTransform = vm.Matrix4.translation(
      trackPos + localOffset * currentScale,
    )..multiply(
      vm.Matrix4.diagonal3Values(currentScale, currentScale, currentScale),
    );
    updateBaseOffset(_thumbNode, localOffset);
  }

  @override
  String get label =>
      '$baseLabel: ${value ? VrWidgetConstants.stateOnLabel : VrWidgetConstants.stateOffLabel}';

  @override
  List<String> get nodeNames => [name, thumbNodeName];

  @override
  List<Node> get nodes => [_trackNode, _thumbNode];

  @override
  void applyEmissive() {
    final currentTrackColor = value ? activeColor : inactiveColor;
    if (!enabled) {
      _trackMat.baseColorFactor = inactiveColor * 0.4;
      _trackMat.emissiveFactor = vm.Vector4.zero();
      _thumbMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    _trackMat.baseColorFactor = currentTrackColor;
    final trackGlow =
        (value ? 0.36 : 0.08) + (_hovered ? 0.25 : 0) + flashLevel * 0.4;
    _trackMat.emissiveFactor = vm.Vector4(
      currentTrackColor.x * trackGlow,
      currentTrackColor.y * trackGlow,
      currentTrackColor.z * trackGlow,
      0,
    );
    final thumbGlow = (_hovered ? 0.42 : 0.18) + flashLevel * 0.45;
    _thumbMat.emissiveFactor = vm.Vector4(
      thumbColor.x * thumbGlow,
      thumbColor.y * thumbGlow,
      thumbColor.z * thumbGlow,
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
    value = !value;
    _placeThumb();
    flash();
    onChanged?.call(value);
  }
}
