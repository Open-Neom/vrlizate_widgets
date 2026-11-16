import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import 'vr_widget_base.dart';

/// Builds a control mesh. Overridable per control because `flutter_scene`
/// geometry constructors upload to Flutter GPU eagerly — in headless tests
/// (no Impeller) pass `Mesh.primitives(primitives: const [])`.
typedef VrControlMeshBuilder = Mesh Function();

/// Shared PBR material factory for 3D controls.
PhysicallyBasedMaterial controlMaterial(vm.Vector4 color) {
  return PhysicallyBasedMaterial()
    ..baseColorFactor = color
    ..metallicFactor = VrWidgetConstants.defaultMetallicFactor
    ..roughnessFactor = VrWidgetConstants.defaultRoughnessFactor
    ..emissiveFactor = vm.Vector4.zero()
    ..vertexColorWeight = 1.0;
}

/// A gaze-interactive 3D control that is also a [VrWidget] with `VrSpatial`.
abstract class VrControl extends VrWidget {
  VrControl({required super.name, required String label}) : _label = label;

  /// Human label for HUD hover feedback.
  @override
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

  void onHoverEnter(String nodeName);
  void onHoverExit(String nodeName);
  void onSelect(String nodeName);

  /// Secondary action hook (e.g. Button B + Gaze for panel/node dragging).
  void onSecondarySelect(String nodeName) {}

  /// Per-frame decay of the press flash.
  void update(double dt) {
    if (_flash <= 0) return;
    _flash = (_flash - dt * VrWidgetConstants.flashDecayPerSecond).clamp(
      0.0,
      1.0,
    );
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
