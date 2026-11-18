import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import '../widgets/vr_control.dart';
import '../widgets/vr_control_registry.dart';
import '../widgets/vr_panel_3d.dart';
import '../widgets/vr_stateless_widget.dart';
import '../widgets/vr_widget_base.dart';

/// A 3D vertical layout container that positions child [VrWidget]s along
/// the Y axis (top-to-bottom) around [origin] (the VR counterpart of Flutter's `Column`).
class VrColumn3D extends VrStatelessWidget {
  VrColumn3D({
    required super.name,
    String? label,
    required vm.Vector3 origin,
    required List<VrWidget> children,
    double spacing = VrWidgetConstants.columnDefaultSpacing,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : spacing = !spacing.isFinite || spacing < 0
           ? 0.0
           : (spacing > 100.0 ? 100.0 : spacing),
       _label = label ?? name,
       children = List.unmodifiable(children) {
    final safeOrigin =
        origin.x.isFinite && origin.y.isFinite && origin.z.isFinite
        ? origin
        : vm.Vector3.zero();
    for (var i = 0; i < this.children.length; i++) {
      final child = this.children[i];
      final yOffset = ((this.children.length - 1) / 2.0 - i) * this.spacing;
      final target = safeOrigin + vm.Vector3(0, yOffset, 0);
      _placeChild(child, target);
    }
    initSpatial(safeOrigin, mode: placementMode);
  }

  final String _label;
  final List<VrWidget> children;
  final double spacing;

  @override
  String get label => _label;

  @override
  List<Node> get nodes => [
    for (final child in children) ...child.nodes,
  ];

  /// Registers all interactive [VrControl] children in [registry].
  void registerAll(VrControlRegistry registry) {
    for (final child in children) {
      if (child is VrPanel3D) {
        child.registerAll(registry);
      } else if (child is VrControl) {
        registry.register(child);
      }
    }
  }

  static void _placeChild(VrWidget child, vm.Vector3 target) {
    if (child.isSpatialInitialized) {
      child.moveTo(target);
      return;
    }
    if (child.nodes.isEmpty) {
      child.initSpatial(target);
      return;
    }
    final delta = target - child.nodes.first.localTransform.getTranslation();
    for (final node in child.nodes) {
      node.localTransform = vm.Matrix4.translation(
        node.localTransform.getTranslation() + delta,
      );
    }
    child.initSpatial(target);
  }
}
