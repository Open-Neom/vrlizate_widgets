import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A 3D checkbox: frame + glowing inner sphere visible when checked.
class VrToggle3D extends VrControl {
  VrToggle3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    bool initialValue = false,
    this.onChanged,
    this.meshBuilder,
    double size = VrWidgetConstants.toggleDefaultSize,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : value = initialValue {
    _frameMat = controlMaterial(vm.Vector4(0.4, 0.4, 0.45, 1.0));
    _checkMat = controlMaterial(vm.Vector4(0.2, 0.95, 0.5, 1.0));

    _frame = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            CuboidGeometry(
              vm.Vector3(size, size, VrWidgetConstants.toggleDefaultDepth),
            ),
            _frameMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    _check =
        Node(
            name: name,
            mesh:
                meshBuilder?.call() ??
                Mesh(SphereGeometry(radius: size * 0.32), _checkMat),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, 0, 0.045),
          )
          ..visible = value;

    initSpatial(center, mode: placementMode);
  }

  bool value;
  final void Function(bool value)? onChanged;

  /// Test/headless hook — see [VrControlMeshBuilder].
  final VrControlMeshBuilder? meshBuilder;
  bool _hovered = false;

  late final PhysicallyBasedMaterial _frameMat;
  late final PhysicallyBasedMaterial _checkMat;
  late final Node _frame;
  late final Node _check;

  /// Frame material (state inspection in tests and demos).
  PhysicallyBasedMaterial get debugMaterial => _frameMat;

  /// Programmatic set (e.g. loading a saved configuration): updates the
  /// value, the check visibility and emissive WITHOUT firing [onChanged].
  void setValue(bool v) {
    value = v;
    _check.visible = v;
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [name];

  @override
  List<Node> get nodes => [_frame, _check];

  @override
  void applyEmissive() {
    if (!enabled) {
      _frameMat.emissiveFactor = vm.Vector4.zero();
      _checkMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final glow = (_hovered ? 0.3 : 0.08) + flashLevel * 0.5;
    _frameMat.emissiveFactor = vm.Vector4(glow, glow, glow, 0);
    final checkGlow = value ? glow + 0.8 : glow * 0.3;
    _checkMat.emissiveFactor = vm.Vector4(
      checkGlow * 0.2,
      checkGlow,
      checkGlow * 0.5,
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
    _check.visible = value;
    flash();
    onChanged?.call(value);
  }
}
