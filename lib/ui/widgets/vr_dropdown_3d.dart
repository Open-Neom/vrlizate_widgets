import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A 3D dropdown: dwell the header to open, dwell an option to select.
/// Option nodes hide while closed ([Node.visible] = false).
class VrDropdown3D extends VrControl {
  VrDropdown3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    required this.options,
    this.selectedIndex = 0,
    this.onChanged,
    this.optionColors,
    this.meshBuilder,
    double width = VrWidgetConstants.dropdownDefaultWidth,
    double optionHeight = VrWidgetConstants.dropdownDefaultOptionHeight,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) {
    _headerMat = controlMaterial(vm.Vector4(0.35, 0.3, 0.6, 1.0));
    _header = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            CuboidGeometry(vm.Vector3(width, optionHeight + 0.02, 0.06)),
            _headerMat,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    for (var i = 0; i < options.length; i++) {
      final color = (optionColors != null && i < optionColors!.length)
          ? optionColors![i]
          : vm.Vector4(0.18, 0.22, 0.3, 1.0);
      final mat = controlMaterial(color);
      _optionMats.add(mat);
      _optionNodes.add(
        Node(
            name: '$name${VrWidgetConstants.dropdownOptionSegment}$i',
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(vm.Vector3(width * 0.92, optionHeight, 0.05)),
                  mat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, -(optionHeight + 0.025) * (i + 1), 0),
          )
          ..visible = false,
      );
    }

    initSpatial(center, mode: placementMode);
  }

  /// Option labels.
  final List<String> options;
  final void Function(int index, String option)? onChanged;
  final List<vm.Vector4>? optionColors;

  /// Test/headless hook — see [VrControlMeshBuilder].
  final VrControlMeshBuilder? meshBuilder;

  int selectedIndex;
  bool isOpen = false;
  bool _headerHovered = false;
  int _hoveredOption = -1;

  late final PhysicallyBasedMaterial _headerMat;
  late final Node _header;
  final List<Node> _optionNodes = [];
  final List<PhysicallyBasedMaterial> _optionMats = [];

  String get selectedOption => options[selectedIndex];

  /// Header material (state inspection in tests and demos).
  PhysicallyBasedMaterial get debugMaterial => _headerMat;

  String get _optionPrefix => '$name${VrWidgetConstants.dropdownOptionSegment}';

  @override
  List<String> get nodeNames => [
    name,
    for (var i = 0; i < options.length; i++) '$_optionPrefix$i',
  ];

  @override
  List<Node> get nodes => [_header, ..._optionNodes];

  /// HUD label reflects the hovered option while open.
  @override
  String get label {
    if (isOpen && _hoveredOption >= 0) {
      return '$baseLabel: ${options[_hoveredOption]}';
    }
    return isOpen
        ? '$baseLabel ${VrWidgetConstants.dropdownOpenSuffix}'
        : '$baseLabel: ${options[selectedIndex]}';
  }

  @override
  void applyEmissive() {
    if (!enabled) {
      _headerMat.emissiveFactor = vm.Vector4.zero();
      for (final material in _optionMats) {
        material.emissiveFactor = vm.Vector4.zero();
      }
      return;
    }
    final headerGlow =
        (_headerHovered ? 0.3 : 0.08) + flashLevel * 0.5 + (isOpen ? 0.15 : 0);
    _headerMat.emissiveFactor = vm.Vector4(
      headerGlow * 0.8,
      headerGlow * 0.7,
      headerGlow * 1.4,
      0,
    );
    for (var i = 0; i < _optionMats.length; i++) {
      final glow =
          (i == selectedIndex ? 0.2 : 0.04) + (i == _hoveredOption ? 0.3 : 0);
      _optionMats[i].emissiveFactor = vm.Vector4(glow, glow, glow, 0);
    }
  }

  @override
  void onHoverEnter(String nodeName) {
    if (nodeName.startsWith(_optionPrefix)) {
      _hoveredOption = int.parse(nodeName.substring(_optionPrefix.length));
      _headerHovered = false;
    } else {
      _hoveredOption = -1;
      _headerHovered = true;
    }
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _headerHovered = false;
    _hoveredOption = -1;
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    if (nodeName == name) {
      isOpen = !isOpen;
      for (final n in _optionNodes) {
        n.visible = isOpen;
      }
      flash();
      return;
    }
    if (nodeName.startsWith(_optionPrefix)) {
      final i = int.parse(nodeName.substring(_optionPrefix.length));
      selectedIndex = i;
      isOpen = false;
      for (final n in _optionNodes) {
        n.visible = false;
      }
      flash();
      onChanged?.call(i, options[i]);
    }
  }
}
