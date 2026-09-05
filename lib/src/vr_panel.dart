import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'vr_controls.dart';
import 'vr_widget.dart';

/// A movable 3D panel: a container widget that lays out child controls
/// vertically, scales as a unit and can be grabbed and moved with the gaze.
///
/// - The top bar (node `mv_<name>`) is the move handle: gaze-dwell toggles
///   the grab; while grabbed, [dragUpdate] (called each frame by the host)
///   moves the whole panel so it follows the gaze at the grab distance;
///   dwell again to drop.
/// - Children are regular [VrControl]s registered in the host's
///   [VrControlRegistry] via [registerAll]; the panel handles layout,
///   backdrop and grab/move/scale for the whole group.
/// - [scaleTo] (from [VrSpatial]) resizes the panel **and** its children.
///
/// ```dart
/// final panel = VrPanel3D(
///   name: 'settings', label: 'Ajustes',
///   center: Vector3(-1.1, 1.55, -2.4),
///   children: [VrToggle3D(...), VrButton3D(...)],
/// );
/// panel.registerAll(registry);
/// scene.addAll... // panel.nodes includes children nodes
/// // onTick: panel.dragUpdate(rig.eyeCenter, rig.cameraRig.rotation.rotated(Vector3(0,0,-1)));
/// ```
class VrPanel3D extends VrControl with VrSpatial {
  VrPanel3D({
    required super.name,
    required super.label,
    required vm.Vector3 center,
    required this.children,
    this.meshBuilder,
    double width = 0.72,
    double spacing = 0.22,
  }) {
    final double height = 0.18 + spacing * children.length + 0.06;

    // Move handle (top bar).
    _handleMat = controlMaterial(vm.Vector4(0.35, 0.3, 0.6, 1.0));
    _handle = Node(
      name: 'mv_$name',
      mesh:
          meshBuilder?.call() ??
          Mesh(CuboidGeometry(vm.Vector3(width, 0.1, 0.05)), _handleMat),
    )..localTransform = vm.Matrix4.translation(center);

    // Backdrop plate (unnamed: not gaze-interactive, children sit in front).
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

    // Children stacked below the handle.
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final target = center + vm.Vector3(0, -0.18 - spacing * i, 0.01);
      final offset = target - child.nodes.first.localTransform.getTranslation();
      for (final n in child.nodes) {
        n.localTransform = vm.Matrix4.translation(
          n.localTransform.getTranslation() + offset,
        );
      }
    }

    initSpatial(center);
  }

  /// Child controls (laid out vertically, moved and scaled with the panel).
  final List<VrControl> children;

  /// Test/headless hook — see [VrControlMeshBuilder].
  final VrControlMeshBuilder? meshBuilder;

  /// Whether the panel is currently grabbed (following the gaze).
  bool grabbed = false;
  double _grabDistance = 2.5;

  bool _hovered = false;

  late final PhysicallyBasedMaterial _handleMat;
  late final PhysicallyBasedMaterial _plateMat;
  late final Node _handle;
  late final Node _plate;

  /// The handle node name this panel answers to.
  String get handleName => 'mv_$name';

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
  String get label =>
      grabbed ? '$baseLabel (muévelo con la mirada)' : baseLabel;

  /// Registers the panel handle AND every child control.
  void registerAll(VrControlRegistry registry) {
    registry.register(this);
    for (final c in children) {
      registry.register(c);
    }
  }

  /// Per-frame move while grabbed. [eye] is the head position and
  /// [forward] the gaze direction (e.g. `rig.cameraRig.rotation.rotated(
  /// Vector3(0, 0, -1))`). The panel keeps the grab distance.
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
    applyEmissive();
  }

  @override
  void onSelect(String nodeName) {
    grabbed = !grabbed;
    if (grabbed) {
      // Capture the current distance so dragUpdate keeps it.
      _grabDistancePending = true;
    }
    flash();
  }

  bool _grabDistancePending = false;

  /// Call instead of [dragUpdate] when the eye position is known, so the
  /// grab distance is captured at grab time.
  void dragUpdateWithEye(vm.Vector3 eye, vm.Vector3 forward) {
    if (!grabbed) return;
    if (_grabDistancePending) {
      _grabDistance = (origin - eye).length.clamp(0.8, 8.0);
      _grabDistancePending = false;
    }
    moveTo(eye + forward * _grabDistance);
  }
}
