import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../utils/constants/vr_widget_constants.dart';
import '../../utils/enums/vr_placement_mode.dart';
import '../widgets/vr_control.dart';
import '../widgets/vr_control_registry.dart';
import '../widgets/vr_panel_3d.dart';
import '../widgets/vr_stateless_widget.dart';
import '../widgets/vr_widget_base.dart';

/// A 3D 2D-grid layout container that positions child [VrWidget]s across
/// columns (X axis, left-to-right) and rows (Y axis, top-to-bottom) around
/// [origin] (the VR counterpart of Flutter's `GridView` / `Wrap`).
class VrGrid3D extends VrStatelessWidget {
  VrGrid3D({
    required super.name,
    String? label,
    required vm.Vector3 origin,
    required List<VrWidget> children,
    int columns = VrWidgetConstants.gridDefaultColumns,
    double columnSpacing = VrWidgetConstants.gridDefaultColumnSpacing,
    double rowSpacing = VrWidgetConstants.gridDefaultRowSpacing,
    VrPlacementMode placementMode = VrPlacementMode.staticWorld,
  }) : columns = !columns.isFinite || columns < 1
           ? 1
           : (columns > 256 ? 256 : columns),
       columnSpacing = !columnSpacing.isFinite || columnSpacing < 0
           ? 0.0
           : (columnSpacing > 100.0 ? 100.0 : columnSpacing),
       rowSpacing = !rowSpacing.isFinite || rowSpacing < 0
           ? 0.0
           : (rowSpacing > 100.0 ? 100.0 : rowSpacing),
       _label = label ?? name,
       children = List.unmodifiable(children) {
    final safeOrigin =
        origin.x.isFinite && origin.y.isFinite && origin.z.isFinite
        ? origin
        : vm.Vector3.zero();
    final rows = this.children.isEmpty
        ? 0
        : (this.children.length + this.columns - 1) ~/ this.columns;
    for (var i = 0; i < this.children.length; i++) {
      final child = this.children[i];
      final col = i % this.columns;
      final row = i ~/ this.columns;
      final xOffset = (col - (this.columns - 1) / 2.0) * this.columnSpacing;
      final yOffset = ((rows - 1) / 2.0 - row) * this.rowSpacing;
      final target = safeOrigin + vm.Vector3(xOffset, yOffset, 0);
      _placeChild(child, target);
    }
    initSpatial(safeOrigin, mode: placementMode);
  }

  final String _label;
  final List<VrWidget> children;
  final int columns;
  final double columnSpacing;
  final double rowSpacing;

  /// Number of rows computed from [children] and [columns].
  int get rows =>
      children.isEmpty ? 0 : (children.length + columns - 1) ~/ columns;

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
