import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import 'vr_control.dart';
import 'vr_control_registry.dart';

/// A movable 3D panel: a container widget that lays out child controls
/// vertically, scales as a unit and can be grabbed and moved with the gaze.
class VrPanel3D extends VrControl {
  VrPanel3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    required this.children,
    this.meshBuilder,
    double width = VrWidgetConstants.panelDefaultWidth,
    double spacing = VrWidgetConstants.panelDefaultSpacing,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
    this.requireButtonBForDrag = false,
    this.dragHoldSeconds = VrWidgetConstants.defaultDragHoldSeconds,
  }) {
    final double height = 0.18 + spacing * children.length + 0.06;

    _handleMat = controlMaterial(vm.Vector4(0.35, 0.3, 0.6, 1.0));
    _handle = Node(
      name: handleName,
      mesh:
          meshBuilder?.call() ??
          Mesh(CuboidGeometry(vm.Vector3(width, 0.1, 0.05)), _handleMat),
    )..localTransform = vm.Matrix4.translation(center);

    _plateMat = controlMaterial(vm.Vector4(0.05, 0.06, 0.09, 1.0));
    _plate =
        Node(
            mesh:
                meshBuilder?.call() ??
                Mesh(
                  CuboidGeometry(vm.Vector3(width + 0.08, height, 0.02)),
                  _plateMat,
                ),
          )
          ..localTransform = vm.Matrix4.translation(
            center + vm.Vector3(0, -(height / 2) + 0.04, -0.035),
          );

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final target = center + vm.Vector3(0, -0.18 - spacing * i, 0.01);
      final offset = target - child.nodes.first.localTransform.getTranslation();
      for (final n in child.nodes) {
        n.localTransform = vm.Matrix4.translation(
          n.localTransform.getTranslation() + offset,
        );
      }
      child.initSpatial(target);
    }

    initSpatial(center, mode: placementMode);
  }

  /// Child controls (laid out vertically, moved and scaled with the panel).
  final List<VrControl> children;

  /// Test/headless hook — see [VrControlMeshBuilder].
  final VrControlMeshBuilder? meshBuilder;

  /// When true, dragging the panel requires holding Button B while gazing at
  /// the handle (preventing accidental grabs from normal gaze dwell or A clicks).
  bool requireButtonBForDrag;

  /// Deliberate hold time in seconds while gazing at the handle with Button B
  /// pressed before the panel becomes grabbed.
  double dragHoldSeconds;

  /// Whether Button B is currently held.
  bool buttonBHeld = false;

  double _dragHoldElapsed = 0.0;

  /// Normalized progress (0..1) toward grabbing the panel via Button B + gaze.
  double get dragHoldProgress => dragHoldSeconds <= 0
      ? 1.0
      : (_dragHoldElapsed / dragHoldSeconds).clamp(0.0, 1.0);

  /// Enables deliberate Button B + gaze hold mode for moving this panel.
  void enableButtonBDragMode({
    double holdSeconds = VrWidgetConstants.defaultDragHoldSeconds,
  }) {
    requireButtonBForDrag = true;
    dragHoldSeconds = holdSeconds;
  }

  /// Whether the panel is currently grabbed (following the gaze).
  bool grabbed = false;
  double _grabDistance = VrWidgetConstants.defaultGrabDistance;

  bool _hovered = false;

  late final PhysicallyBasedMaterial _handleMat;
  late final PhysicallyBasedMaterial _plateMat;
  late final Node _handle;
  late final Node _plate;

  /// The handle node name this panel answers to.
  String get handleName => '${VrWidgetConstants.panelMovePrefix}$name';

  @override
  List<Node> get spatialNodes => nodes;

  @override
  List<String> get nodeNames => [handleName];

  @override
  List<Node> get nodes => [
    _handle,
    _plate,
    for (final c in children) ...c.nodes,
  ];

  @override
  String get label {
    if (grabbed) {
      return '$baseLabel ${VrWidgetConstants.panelGrabbedSuffix}';
    }
    if (requireButtonBForDrag && _hovered) {
      return '$baseLabel ${VrWidgetConstants.panelGrabWithButtonBHint}';
    }
    return baseLabel;
  }

  /// Registers the panel handle AND every child control.
  void registerAll(VrControlRegistry registry) {
    registry.register(this);
    for (final c in children) {
      registry.register(c);
    }
  }

  /// Per-frame move while grabbed.
  void dragUpdate(vm.Vector3 eye, vm.Vector3 forward) {
    if (!grabbed) return;
    moveTo(eye + forward * _grabDistance);
  }

  @override
  void applyEmissive() {
    if (!enabled) {
      _handleMat.emissiveFactor = vm.Vector4.zero();
      _plateMat.emissiveFactor = vm.Vector4.zero();
      return;
    }
    final glow =
        (_hovered ? 0.35 : 0.1) + flashLevel * 0.5 + (grabbed ? 0.25 : 0);
    _handleMat.emissiveFactor = vm.Vector4(
      glow * 0.8,
      glow * 0.7,
      glow * 1.4,
      0,
    );
    _plateMat.emissiveFactor = vm.Vector4.zero();
  }

  @override
  void onHoverEnter(String nodeName) {
    _hovered = true;
    applyEmissive();
  }

  @override
  void onHoverExit(String nodeName) {
    _hovered = false;
    _dragHoldElapsed = 0.0;
    applyEmissive();
  }

  void _toggleGrab() {
    grabbed = !grabbed;
    if (grabbed) {
      _grabDistancePending = true;
    } else {
      _dragHoldElapsed = 0.0;
    }
    flash();
  }

  @override
  void onSelect(String nodeName) {
    if (requireButtonBForDrag && !buttonBHeld) {
      return;
    }
    _toggleGrab();
  }

  @override
  void onSecondarySelect(String nodeName) {
    buttonBHeld = true;
    _toggleGrab();
  }

  /// Updates deliberate Button B + gaze hold state for grabbing/releasing the
  /// panel handle.
  bool updateButtonBDrag({
    bool? isHovered,
    required bool buttonBHeld,
    required double dt,
  }) {
    this.buttonBHeld = buttonBHeld;
    final hovered = isHovered ?? _hovered;

    if (grabbed) {
      if (requireButtonBForDrag && !buttonBHeld) {
        grabbed = false;
        _dragHoldElapsed = 0.0;
        applyEmissive();
        return false;
      }
      return true;
    }

    if (!hovered || !buttonBHeld || !dt.isFinite || dt <= 0) {
      _dragHoldElapsed = 0.0;
      return false;
    }

    _dragHoldElapsed += dt;
    if (_dragHoldElapsed >= dragHoldSeconds) {
      grabbed = true;
      _grabDistancePending = true;
      flash();
      return true;
    }
    return false;
  }

  bool _grabDistancePending = false;

  /// Call instead of [dragUpdate] when the eye position is known, so the
  /// grab distance is captured at grab time.
  void dragUpdateWithEye(vm.Vector3 eye, vm.Vector3 forward) {
    if (!grabbed) return;
    if (_grabDistancePending) {
      _grabDistance = (origin - eye).length.clamp(
        VrWidgetConstants.minDragDistance,
        VrWidgetConstants.maxDragDistance,
      );
      _grabDistancePending = false;
    }
    moveTo(eye + forward * _grabDistance);
  }
}
