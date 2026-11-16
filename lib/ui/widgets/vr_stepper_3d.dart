import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../src/vr_beveled_box_geometry.dart';
import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';

/// A bounded numeric input with separate decrement and increment pads.
///
/// The middle plate is gaze-readable through [label]; the side pads have
/// stable names (`<name>_decrement` and `<name>_increment`) and automatically
/// dim at their respective bounds.
class VrStepper3D extends VrControl {
  VrStepper3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    double initialValue = 0,
    this.min = VrWidgetConstants.stepperDefaultMin,
    this.max = VrWidgetConstants.stepperDefaultMax,
    this.step = VrWidgetConstants.stepperDefaultStep,
    this.onChanged,
    this.valueFormat,
    this.meshBuilder,
    this.width = VrWidgetConstants.stepperDefaultWidth,
    vm.Vector4? accentColor,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : assert(max > min, 'max must be greater than min'),
       assert(step > 0, 'step must be positive'),
       value = initialValue.clamp(min, max).toDouble(),
       accentColor = accentColor ?? vm.Vector4(0.48, 0.38, 0.96, 1.0) {
    _centerMaterial = controlMaterial(vm.Vector4(0.09, 0.11, 0.18, 1.0));
    _decrementMaterial = controlMaterial(this.accentColor);
    _incrementMaterial = controlMaterial(this.accentColor);
    _decrementSymbolMaterial = controlMaterial(vm.Vector4(0.78, 0.86, 1.0, 1.0))
      ..metallicFactor = 0.1
      ..roughnessFactor = 0.25;
    _incrementSymbolMaterial = controlMaterial(vm.Vector4(0.78, 0.86, 1.0, 1.0))
      ..metallicFactor = 0.1
      ..roughnessFactor = 0.25;

    final padWidth = width * 0.25;
    final centerWidth = width - padWidth * 2 - 0.025;
    _center = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.create(vm.Vector3(centerWidth, 0.15, 0.055)),
            _centerMaterial,
          ),
    )..localTransform = vm.Matrix4.translation(center);

    final leftX = center.x - width / 2 + padWidth / 2;
    final rightX = center.x + width / 2 - padWidth / 2;
    _decrement =
        Node(
            name: decrementNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.create(
                    vm.Vector3(padWidth, 0.15, 0.065),
                  ),
                  _decrementMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            vm.Vector3(leftX, center.y, center.z + 0.006),
          );
    _increment =
        Node(
            name: incrementNodeName,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  VrBeveledBoxGeometry.create(
                    vm.Vector3(padWidth, 0.15, 0.065),
                  ),
                  _incrementMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            vm.Vector3(rightX, center.y, center.z + 0.006),
          );

    _minus = _symbolBar(
      decrementNodeName,
      vm.Vector3(leftX, center.y, center.z + 0.052),
      _decrementSymbolMaterial,
      horizontal: true,
    );
    _plusHorizontal = _symbolBar(
      incrementNodeName,
      vm.Vector3(rightX, center.y, center.z + 0.052),
      _incrementSymbolMaterial,
      horizontal: true,
    );
    _plusVertical = _symbolBar(
      incrementNodeName,
      vm.Vector3(rightX, center.y, center.z + 0.053),
      _incrementSymbolMaterial,
      horizontal: false,
    );
    initSpatial(center, mode: placementMode);
    applyEmissive();
  }

  final double min;
  final double max;
  final double step;
  final void Function(double value)? onChanged;
  final String Function(double value)? valueFormat;
  final VrControlMeshBuilder? meshBuilder;
  final double width;
  final vm.Vector4 accentColor;

  double value;
  String? _hoveredNode;

  late final Node _center;
  late final Node _decrement;
  late final Node _increment;
  late final Node _minus;
  late final Node _plusHorizontal;
  late final Node _plusVertical;
  late final PhysicallyBasedMaterial _centerMaterial;
  late final PhysicallyBasedMaterial _decrementMaterial;
  late final PhysicallyBasedMaterial _incrementMaterial;
  late final PhysicallyBasedMaterial _decrementSymbolMaterial;
  late final PhysicallyBasedMaterial _incrementSymbolMaterial;

  String get decrementNodeName =>
      '$name${VrWidgetConstants.stepperDecrementSuffix}';
  String get incrementNodeName =>
      '$name${VrWidgetConstants.stepperIncrementSuffix}';

  PhysicallyBasedMaterial get debugDecrementMaterial => _decrementMaterial;
  PhysicallyBasedMaterial get debugIncrementMaterial => _incrementMaterial;

  Node _symbolBar(
    String nodeName,
    vm.Vector3 center,
    PhysicallyBasedMaterial material, {
    required bool horizontal,
  }) {
    return Node(
      name: nodeName,
      mesh:
          meshBuilder?.call() ??
          Mesh(
            VrBeveledBoxGeometry.pill(
              horizontal
                  ? vm.Vector3(0.055, 0.012, 0.012)
                  : vm.Vector3(0.012, 0.055, 0.012),
            ),
            material,
          ),
    )..localTransform = vm.Matrix4.translation(center);
  }

  String _formattedValue() =>
      valueFormat?.call(value) ??
      (value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2));

  /// Updates value without firing [onChanged].
  void setValue(double nextValue) {
    value = nextValue.clamp(min, max).toDouble();
    applyEmissive();
  }

  void _changeBy(double delta) {
    final next = (value + delta).clamp(min, max).toDouble();
    if (next == value) {
      flash();
      return;
    }
    value = next;
    flash();
    onChanged?.call(value);
  }

  @override
  List<String> get nodeNames => [name, decrementNodeName, incrementNodeName];

  @override
  List<Node> get nodes => [
    _center,
    _decrement,
    _increment,
    _minus,
    _plusHorizontal,
    _plusVertical,
  ];

  @override
  String get label {
    final action = switch (_hoveredNode) {
      final node when node == decrementNodeName =>
        VrWidgetConstants.stepperMinusSymbol,
      final node when node == incrementNodeName =>
        VrWidgetConstants.stepperPlusSymbol,
      _ => VrWidgetConstants.stepperEqualsSymbol,
    };
    return '$baseLabel $action ${_formattedValue()}';
  }

  @override
  void applyEmissive() {
    if (!enabled) {
      _centerMaterial.emissiveFactor = vm.Vector4.zero();
      _decrementMaterial.emissiveFactor = vm.Vector4.zero();
      _incrementMaterial.emissiveFactor = vm.Vector4.zero();
      _decrementSymbolMaterial.emissiveFactor = vm.Vector4.zero();
      _incrementSymbolMaterial.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final centerGlow = (_hoveredNode == name ? 0.2 : 0.055) + flashLevel * 0.12;
    _centerMaterial.emissiveFactor = vm.Vector4(
      centerGlow,
      centerGlow,
      centerGlow * 1.4,
      0,
    );

    final canDecrement = value > min;
    final canIncrement = value < max;
    final decrementGlow = canDecrement
        ? 0.13 + (_hoveredNode == decrementNodeName ? 0.42 : 0)
        : 0.015;
    final incrementGlow = canIncrement
        ? 0.13 + (_hoveredNode == incrementNodeName ? 0.42 : 0)
        : 0.015;
    _decrementMaterial.emissiveFactor = vm.Vector4(
      accentColor.x * decrementGlow,
      accentColor.y * decrementGlow,
      accentColor.z * decrementGlow,
      0,
    );
    _incrementMaterial.emissiveFactor = vm.Vector4(
      accentColor.x * incrementGlow,
      accentColor.y * incrementGlow,
      accentColor.z * incrementGlow,
      0,
    );
    final decrementSymbolGlow = decrementGlow + 0.15;
    _decrementSymbolMaterial.emissiveFactor = vm.Vector4(
      decrementSymbolGlow,
      decrementSymbolGlow,
      decrementSymbolGlow,
      0,
    );
    final incrementSymbolGlow = incrementGlow + 0.15;
    _incrementSymbolMaterial.emissiveFactor = vm.Vector4(
      incrementSymbolGlow,
      incrementSymbolGlow,
      incrementSymbolGlow,
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
    if (nodeName == decrementNodeName) {
      _changeBy(-step);
    } else if (nodeName == incrementNodeName) {
      _changeBy(step);
    } else {
      flash();
    }
  }
}
