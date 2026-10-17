import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A 3D push button: gaze-dwell presses it.
class VrButton3D extends VrControl {
  VrButton3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    vm.Vector4? color,
    this.onPressed,
    this.meshBuilder,
    double width = VrWidgetConstants.buttonDefaultWidth,
    double height = VrWidgetConstants.buttonDefaultHeight,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : color = color ?? VrWidgetConstants.defaultButtonColor {
    _mat = controlMaterial(this.color);
    _node = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            CuboidGeometry(
              vm.Vector3(width, height, VrWidgetConstants.buttonDefaultDepth),
            ),
            _mat,
          ),
    )..localTransform = vm.Matrix4.translation(center);
    initSpatial(center, mode: placementMode);
  }

  final vm.Vector4 color;
  final void Function()? onPressed;

  /// Test/headless hook — see [VrControlMeshBuilder].
  final VrControlMeshBuilder? meshBuilder;
  bool _hovered = false;

  late final PhysicallyBasedMaterial _mat;
  late final Node _node;

  /// The control's material (state inspection in tests and demos).
  PhysicallyBasedMaterial get debugMaterial => _mat;

  @override
  List<String> get nodeNames => [name];

  @override
  List<Node> get nodes => [_node];

  @override
  void applyEmissive() {
    if (!enabled) {
      _mat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final glow = 0.12 + (_hovered ? 0.25 : 0) + flashLevel * 0.5;
    _mat.emissiveFactor = vm.Vector4(
      color.x * glow,
      color.y * glow,
      color.z * glow,
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
