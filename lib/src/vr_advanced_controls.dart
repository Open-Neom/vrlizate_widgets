/// High-quality compound controls for productivity and learning experiences.
///
/// These controls deliberately use small primitive meshes and material-only
/// state changes. They remain inexpensive on budget phones, integrate with
/// [VrControlRegistry], and avoid rebuilding or uploading geometry while the
/// user interacts with them.
library;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'vr_controls.dart';

/// A horizontal group of mutually exclusive 3D segments.
///
/// Useful for tabs, filters, quiz answers and view modes. Every segment has a
/// stable node name (`<name>_segment_<index>`) and selection is expressed with
/// PBR color plus emissive depth, so it remains legible without bloom.
class VrSegmentedControl3D extends VrControl {
  VrSegmentedControl3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    required List<String> options,
    int selectedIndex = 0,
    this.onChanged,
    this.meshBuilder,
    this.width = 0.72,
    this.height = 0.14,
    vm.Vector4? selectedColor,
    vm.Vector4? idleColor,
  }) : assert(options.isNotEmpty, 'a segmented control needs options'),
       assert(
         selectedIndex >= 0 && selectedIndex < options.length,
         'selectedIndex must point to an option',
       ),
       options = List.unmodifiable(options),
       selectedIndex = selectedIndex,
       selectedColor = selectedColor ?? vm.Vector4(0.18, 0.72, 0.92, 1.0),
       idleColor = idleColor ?? vm.Vector4(0.12, 0.16, 0.24, 1.0) {
    _railMaterial = controlMaterial(vm.Vector4(0.04, 0.05, 0.08, 1.0))
      ..metallicFactor = 0.65
      ..roughnessFactor = 0.28;
    _rail =
        Node(
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(
                    vm.Vector3(width + 0.045, height + 0.04, 0.035),
                  ),
                  _railMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, 0, -0.025),
          );

    final segmentWidth = width / options.length;
    for (var i = 0; i < options.length; i++) {
      final material = controlMaterial(this.idleColor)..roughnessFactor = 0.3;
      _segmentMaterials.add(material);
      _segments.add(
        Node(
            name: _nodeName(i),
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(
                    vm.Vector3(segmentWidth - 0.012, height, 0.055),
                  ),
                  material,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(-width / 2 + segmentWidth * (i + 0.5), 0, 0.015),
          ),
      );
    }
    applyEmissive();
  }

  final List<String> options;
  final void Function(int index, String option)? onChanged;
  final VrControlMeshBuilder? meshBuilder;
  final double width;
  final double height;
  final vm.Vector4 selectedColor;
  final vm.Vector4 idleColor;

  int selectedIndex;
  int _hoveredIndex = -1;

  late final Node _rail;
  late final PhysicallyBasedMaterial _railMaterial;
  final List<Node> _segments = [];
  final List<PhysicallyBasedMaterial> _segmentMaterials = [];

  String _nodeName(int index) => '${name}_segment_$index';

  int? _indexFromNode(String nodeName) {
    final prefix = '${name}_segment_';
    if (!nodeName.startsWith(prefix)) return null;
    final index = int.tryParse(nodeName.substring(prefix.length));
    return index != null && index >= 0 && index < options.length ? index : null;
  }

  String get selectedOption => options[selectedIndex];

  List<PhysicallyBasedMaterial> get debugSegmentMaterials =>
      List.unmodifiable(_segmentMaterials);

  /// Updates selection without firing [onChanged].
  void setSelectedIndex(int index) {
    RangeError.checkValidIndex(index, options, 'index');
    selectedIndex = index;
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [
    for (var i = 0; i < options.length; i++) _nodeName(i),
  ];

  @override
  List<Node> get nodes => [_rail, ..._segments];

  @override
  String get label =>
      '$baseLabel: ${options[_hoveredIndex >= 0 ? _hoveredIndex : selectedIndex]}';

  @override
  void applyEmissive() {
    _railMaterial.emissiveFactor = vm.Vector4.zero();
    for (var i = 0; i < _segmentMaterials.length; i++) {
      final material = _segmentMaterials[i];
      if (!enabled) {
        material.baseColorFactor = idleColor * 0.35;
        material.emissiveFactor = vm.Vector4.zero();
        continue;
      }
      final selected = i == selectedIndex;
      final hovered = i == _hoveredIndex;
      material.baseColorFactor = selected ? selectedColor : idleColor;
      final glow =
          (selected ? 0.48 : 0.05) +
          (hovered ? 0.32 : 0) +
          (selected ? flashLevel * 0.35 : 0);
      material.emissiveFactor = vm.Vector4(
        selectedColor.x * glow,
        selectedColor.y * glow,
        selectedColor.z * glow,
        0,
      );
    }
  }

  @override
  void onHoverEnter(String nodeName) {
    _hoveredIndex = _indexFromNode(nodeName) ?? -1;
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _hoveredIndex = -1;
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    final index = _indexFromNode(nodeName);
    if (index == null) return;
    final changed = index != selectedIndex;
    selectedIndex = index;
    flash();
    if (changed) onChanged?.call(index, options[index]);
  }
}

/// A gaze-inspectable segmented progress bar.
///
/// Progress changes only material state, never geometry. This avoids runtime
/// mesh uploads and survives a parent [VrPanel3D] moving or scaling its nodes.
class VrProgressBar3D extends VrControl {
  VrProgressBar3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    double initialValue = 0,
    this.segments = 10,
    this.valueFormat,
    this.onPressed,
    this.meshBuilder,
    this.width = 0.66,
    vm.Vector4? fillColor,
    vm.Vector4? emptyColor,
  }) : assert(segments >= 2, 'a progress bar needs at least 2 segments'),
       value = initialValue.clamp(0.0, 1.0),
       fillColor = fillColor ?? vm.Vector4(0.16, 0.88, 0.62, 1.0),
       emptyColor = emptyColor ?? vm.Vector4(0.08, 0.11, 0.17, 1.0) {
    _backMaterial = controlMaterial(vm.Vector4(0.025, 0.035, 0.055, 1.0))
      ..metallicFactor = 0.55;
    _back =
        Node(
            name: name,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(vm.Vector3(width + 0.05, 0.13, 0.035)),
                  _backMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, 0, -0.025),
          );

    final segmentWidth = width / segments;
    for (var i = 0; i < segments; i++) {
      final material = controlMaterial(this.emptyColor)..roughnessFactor = 0.25;
      _segmentMaterials.add(material);
      _segmentNodes.add(
        Node(
            name: name,
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(vm.Vector3(segmentWidth - 0.01, 0.085, 0.045)),
                  material,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center +
                vm.Vector3(-width / 2 + segmentWidth * (i + 0.5), 0, 0.012),
          ),
      );
    }
    applyEmissive();
  }

  final int segments;
  final String Function(double value)? valueFormat;
  final void Function()? onPressed;
  final VrControlMeshBuilder? meshBuilder;
  final double width;
  final vm.Vector4 fillColor;
  final vm.Vector4 emptyColor;

  double value;
  bool _hovered = false;

  late final Node _back;
  late final PhysicallyBasedMaterial _backMaterial;
  final List<Node> _segmentNodes = [];
  final List<PhysicallyBasedMaterial> _segmentMaterials = [];

  int get filledSegments => (value * segments).round();

  List<PhysicallyBasedMaterial> get debugSegmentMaterials =>
      List.unmodifiable(_segmentMaterials);

  /// Updates progress without firing [onPressed].
  void setValue(double nextValue) {
    value = nextValue.clamp(0.0, 1.0);
    applyEmissive();
  }

  @override
  List<String> get nodeNames => [name];

  @override
  List<Node> get nodes => [_back, ..._segmentNodes];

  @override
  String get label {
    final formatted = valueFormat?.call(value) ?? '${(value * 100).round()}%';
    return '$baseLabel: $formatted';
  }

  @override
  void applyEmissive() {
    _backMaterial.emissiveFactor = vm.Vector4.zero();
    for (var i = 0; i < _segmentMaterials.length; i++) {
      final filled = i < filledSegments;
      final material = _segmentMaterials[i];
      if (!enabled) {
        material.baseColorFactor = emptyColor * 0.45;
        material.emissiveFactor = vm.Vector4.zero();
        continue;
      }
      material.baseColorFactor = filled ? fillColor : emptyColor;
      final glow =
          (filled ? 0.42 : 0.025) + (_hovered ? 0.15 : 0) + flashLevel * 0.12;
      final color = filled ? fillColor : emptyColor;
      material.emissiveFactor = vm.Vector4(
        color.x * glow,
        color.y * glow,
        color.z * glow,
        0,
      );
    }
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
    this.min = 0,
    this.max = 10,
    this.step = 1,
    this.onChanged,
    this.valueFormat,
    this.meshBuilder,
    this.width = 0.58,
    vm.Vector4? accentColor,
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
            CuboidGeometry(vm.Vector3(centerWidth, 0.15, 0.055)),
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
                  CuboidGeometry(vm.Vector3(padWidth, 0.15, 0.065)),
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
                  CuboidGeometry(vm.Vector3(padWidth, 0.15, 0.065)),
                  _incrementMaterial,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            vm.Vector3(rightX, center.y, center.z + 0.006),
          );

    // Raised minus/plus symbols remain visible in stereo even without text.
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

  String get decrementNodeName => '${name}_decrement';
  String get incrementNodeName => '${name}_increment';

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
            CuboidGeometry(
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
      final node when node == decrementNodeName => '−',
      final node when node == incrementNodeName => '+',
      _ => '=',
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
