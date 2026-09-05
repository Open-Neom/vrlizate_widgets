/// Reusable gaze-interactive 3D controls for vrlizate_scene demos and apps.
///
/// The VR equivalent of buttons, checkboxes and dropdowns: plain
/// flutter_scene scene-graph objects with named nodes (so `StereoSceneView`'s
/// built-in gaze raycast can hit them), emissive hover/press feedback, and a
/// [VrControlRegistry] that routes gaze events by node name:
///
/// ```dart
/// final controls = VrControlRegistry();
/// controls.register(VrButton3D(
///   name: 'day_night', label: 'Día/Noche',
///   center: Vector3(0, 1.4, -2.5),
///   onPressed: () => toggleDayNight(),
/// ));
/// // In StereoSceneView:
/// //   onGazeHoverChanged: controls.handleHover,
/// //   onGazeSelect: controls.handleSelect,
/// //   onTick: (e, dt) => controls.update(dt),
/// ```
///
/// Since flutter_scene has no 3D text yet, every control carries a [label]
/// the host HUD shows for the currently hovered control
/// ([VrControlRegistry.hoveredLabel]).
library;

import 'dart:collection';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

// ─── Registry ─────────────────────────────────────────────────────

/// Routes gaze hover/select events to registered controls by node name.
class VrControlRegistry {
  final Map<String, VrControl> _controls = {};
  final List<VrControl> _activeControls = [];
  late final List<VrControl> _controlsView = UnmodifiableListView<VrControl>(
    _activeControls,
  );

  /// Name of the node under the gaze right now (null = none).
  String? hoveredName;

  /// HUD label of the hovered control (null = none).
  String? get hoveredLabel =>
      hoveredName != null ? _controls[hoveredName]?.label : null;

  /// A stable read-only view, rebuilt only when registrations change.
  Iterable<VrControl> get controls => _controlsView;

  void register(VrControl control) {
    for (final nodeName in control.nodeNames) {
      if (hoveredName == nodeName && !identical(_controls[nodeName], control)) {
        _controls[nodeName]?.onHoverExit(nodeName);
        hoveredName = null;
      }
      _controls[nodeName] = control;
    }
    _refreshActiveControls();
  }

  /// Removes [control] without disturbing a newer control that may have
  /// reused one of its node names. Dynamic panels should call this when they
  /// leave the scene so stale gaze routes are not retained.
  void unregister(VrControl control) {
    for (final nodeName in control.nodeNames) {
      if (identical(_controls[nodeName], control)) {
        _controls.remove(nodeName);
        if (hoveredName == nodeName) {
          control.onHoverExit(nodeName);
          hoveredName = null;
        }
      }
    }
    _refreshActiveControls();
  }

  void clear() {
    handleHover(null);
    _controls.clear();
    _activeControls.clear();
  }

  void _refreshActiveControls() {
    // Registration is infrequent; deduplicate here rather than allocating a
    // Set on every frame for every registry in the scene.
    final unique = HashSet<VrControl>.identity();
    _activeControls.clear();
    for (final control in _controls.values) {
      if (unique.add(control)) _activeControls.add(control);
    }
  }

  /// Forward of `StereoSceneView.onGazeHoverChanged`.
  void handleHover(Node? node) {
    final name = node?.name;
    if (name == hoveredName) return;
    final previous = _controls[hoveredName];
    if (previous != null) previous.onHoverExit(hoveredName!);
    hoveredName = _controls.containsKey(name) ? name : null;
    if (hoveredName != null) _controls[hoveredName]!.onHoverEnter(hoveredName!);
  }

  /// Forward of `StereoSceneView.onGazeSelect`. Returns true if a control
  /// consumed the selection.
  bool handleSelect(Node node) {
    final control = _controls[node.name];
    if (control == null || !control.enabled) return false;
    control.onSelect(node.name);
    return true;
  }

  /// Decays press flashes — call once per frame from `onTick`.
  void update(double dt) {
    for (var i = 0; i < _activeControls.length; i++) {
      _activeControls[i].update(dt);
    }
  }
}

// ─── Base ─────────────────────────────────────────────────────────

/// A gaze-interactive 3D control.
abstract class VrControl {
  VrControl({required this.name, required String label}) : _label = label;

  /// Unique control id (node names derive from it).
  final String name;

  /// Human label for HUD hover feedback (no 3D text in flutter_scene yet).
  String get label => _label;
  final String _label;

  /// Base label for subclasses that override [label] (e.g. panels whose
  /// label reflects grab state).
  String get baseLabel => _label;

  /// Current press-flash level (0–1), for subclasses composing emissive.
  double get flashLevel => _flash;

  /// Disabled controls ignore selection and immediately refresh their visual
  /// state. Subclasses implement the actual dimming in [applyEmissive].
  bool get enabled => _enabled;
  bool _enabled = true;

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    applyEmissive();
  }

  double _flash = 0;

  /// All scene node names this control answers to.
  List<String> get nodeNames;

  /// All scene nodes of this control (add them to the scene).
  List<Node> get nodes;

  void onHoverEnter(String nodeName);
  void onHoverExit(String nodeName);
  void onSelect(String nodeName);

  /// Per-frame decay of the press flash.
  void update(double dt) {
    if (_flash <= 0) return;
    _flash = (_flash - dt * 4).clamp(0.0, 1.0);
    applyEmissive();
  }

  /// Recomputes emissive from current state (hover/flash/checked/enabled).
  void applyEmissive();

  /// Triggers the press flash (called by [onSelect] implementations).
  void flash() {
    _flash = 1.0;
    applyEmissive();
  }
}

// ─── Shared material factory ──────────────────────────────────────

PhysicallyBasedMaterial controlMaterial(vm.Vector4 color) {
  return PhysicallyBasedMaterial()
    ..baseColorFactor = color
    ..metallicFactor = 0.3
    ..roughnessFactor = 0.4
    ..emissiveFactor = vm.Vector4.zero()
    ..vertexColorWeight = 0.0;
}

/// Builds a control mesh. Overridable per control because flutter_scene
/// geometry constructors upload to Flutter GPU eagerly — in headless tests
/// (no Impeller) pass `Mesh.primitives(primitives: const [])`.
typedef VrControlMeshBuilder = Mesh Function();

// ─── Button ───────────────────────────────────────────────────────

/// A 3D push button: gaze-dwell presses it.
class VrButton3D extends VrControl {
  VrButton3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    vm.Vector4? color,
    this.onPressed,
    this.meshBuilder,
    double width = 0.34,
    double height = 0.14,
  }) : color = color ?? vm.Vector4(0.15, 0.5, 0.65, 1.0) {
    _mat = controlMaterial(this.color);
    _node = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(CuboidGeometry(vm.Vector3(width, height, 0.06)), _mat),
    )..localTransform = vm.Matrix4.translation(center);
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
    final glow = 0.12 + (_hovered ? 0.25 : 0) + _flash * 0.5;
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

// ─── Toggle (checkbox) ────────────────────────────────────────────

/// A 3D checkbox: frame + glowing inner sphere visible when checked.
class VrToggle3D extends VrControl {
  VrToggle3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    bool initialValue = false,
    this.onChanged,
    this.meshBuilder,
    double size = 0.16,
  }) : value = initialValue {
    _frameMat = controlMaterial(vm.Vector4(0.4, 0.4, 0.45, 1.0));
    _checkMat = controlMaterial(vm.Vector4(0.2, 0.95, 0.5, 1.0));

    _frame = Node(
      name: name,
      mesh:
          meshBuilder?.call() ??
          Mesh(CuboidGeometry(vm.Vector3(size, size, 0.05)), _frameMat),
    )..localTransform = vm.Matrix4.translation(center);

    _check =
        Node(
            name: name, // same name: gaze on either part toggles
            mesh:
                meshBuilder?.call() ??
                Mesh(SphereGeometry(radius: size * 0.32), _checkMat),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, 0, 0.045),
          )
          ..visible = value;
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

  /// Frame and check materials (state inspection in tests and demos).
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
    final glow = (_hovered ? 0.3 : 0.08) + _flash * 0.5;
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

// ─── Dropdown ─────────────────────────────────────────────────────

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
    double width = 0.4,
    double optionHeight = 0.12,
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
            name: '${name}_opt_$i',
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
  }

  /// Option labels (HUD only — no 3D text yet).
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

  @override
  List<String> get nodeNames => [
    name,
    for (var i = 0; i < options.length; i++) '${name}_opt_$i',
  ];

  @override
  List<Node> get nodes => [_header, ..._optionNodes];

  /// HUD label reflects the hovered option while open.
  @override
  String get label {
    if (isOpen && _hoveredOption >= 0) {
      return '$_label: ${options[_hoveredOption]}';
    }
    return isOpen ? '$_label (abierto)' : '$_label: ${options[selectedIndex]}';
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
        (_headerHovered ? 0.3 : 0.08) + _flash * 0.5 + (isOpen ? 0.15 : 0);
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
    if (nodeName.startsWith('${name}_opt_')) {
      _hoveredOption = int.parse(nodeName.substring('${name}_opt_'.length));
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
      // Header toggles open/closed.
      isOpen = !isOpen;
      for (final n in _optionNodes) {
        n.visible = isOpen;
      }
      flash();
      return;
    }
    if (nodeName.startsWith('${name}_opt_')) {
      final i = int.parse(nodeName.substring('${name}_opt_'.length));
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
