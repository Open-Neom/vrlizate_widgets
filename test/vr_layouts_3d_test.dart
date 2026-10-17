import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  Mesh fakeMesh() => Mesh.primitives(primitives: const []);
  final origin = vm.Vector3(0, 1.5, -2.4);

  group('VrRow3D', () {
    test('positions children horizontally along X around origin and scales/moves as a unit', () {
      final b0 = VrButton3D(
        name: 'b0',
        label: 'B0',
        center: vm.Vector3.zero(),
        meshBuilder: fakeMesh,
      );
      final b1 = VrButton3D(
        name: 'b1',
        label: 'B1',
        center: vm.Vector3.zero(),
        meshBuilder: fakeMesh,
      );
      final b2 = VrButton3D(
        name: 'b2',
        label: 'B2',
        center: vm.Vector3.zero(),
        meshBuilder: fakeMesh,
      );

      final row = VrRow3D(
        name: 'toolbar_row',
        origin: origin,
        spacing: 0.5,
        children: [b0, b1, b2],
      );

      expect(b0.origin.x, closeTo(-0.5, 1e-6));
      expect(b1.origin.x, closeTo(0.0, 1e-6));
      expect(b2.origin.x, closeTo(0.5, 1e-6));
      expect(b0.origin.y, closeTo(origin.y, 1e-6));

      final registry = VrControlRegistry();
      row.registerAll(registry);
      expect(registry.handleSelect(Node(name: 'b1')), isTrue);

      row.moveTo(vm.Vector3(2.0, 1.5, -2.4));
      expect(
        b0.nodes.first.localTransform.getTranslation().x,
        closeTo(1.5, 1e-6),
      );
      expect(
        b2.nodes.first.localTransform.getTranslation().x,
        closeTo(2.5, 1e-6),
      );
    });
  });

  group('VrColumn3D', () {
    test('positions children vertically top-to-bottom along Y around origin', () {
      final t0 = VrListTile3D(
        name: 't0',
        label: 'T0',
        center: vm.Vector3.zero(),
        meshBuilder: fakeMesh,
      );
      final t1 = VrListTile3D(
        name: 't1',
        label: 'T1',
        center: vm.Vector3.zero(),
        meshBuilder: fakeMesh,
      );
      final t2 = VrListTile3D(
        name: 't2',
        label: 'T2',
        center: vm.Vector3.zero(),
        meshBuilder: fakeMesh,
      );

      final column = VrColumn3D(
        name: 'menu_col',
        origin: origin,
        spacing: 0.3,
        children: [t0, t1, t2],
      );

      expect(t0.origin.y, closeTo(origin.y + 0.3, 1e-6));
      expect(t1.origin.y, closeTo(origin.y, 1e-6));
      expect(t2.origin.y, closeTo(origin.y - 0.3, 1e-6));
      expect(column.nodes.length, t0.nodes.length * 3);
    });
  });

  group('VrGrid3D', () {
    test('arranges children into rows and columns and updates dynamic placement', () {
      final chips = List.generate(
        4,
        (i) => VrChip3D(
          name: 'chip_$i',
          label: 'Chip $i',
          center: vm.Vector3.zero(),
          meshBuilder: fakeMesh,
        ),
      );

      final grid = VrGrid3D(
        name: 'chip_grid',
        origin: origin,
        columns: 2,
        columnSpacing: 0.4,
        rowSpacing: 0.2,
        placementMode: VrPlacementMode.dynamicBillboard,
        children: chips,
      );

      expect(grid.rows, 2);
      expect(chips[0].origin.x, closeTo(origin.x - 0.2, 1e-6));
      expect(chips[0].origin.y, closeTo(origin.y + 0.1, 1e-6));
      expect(chips[1].origin.x, closeTo(origin.x + 0.2, 1e-6));
      expect(chips[1].origin.y, closeTo(origin.y + 0.1, 1e-6));
      expect(chips[2].origin.x, closeTo(origin.x - 0.2, 1e-6));
      expect(chips[2].origin.y, closeTo(origin.y - 0.1, 1e-6));
      expect(chips[3].origin.x, closeTo(origin.x + 0.2, 1e-6));
      expect(chips[3].origin.y, closeTo(origin.y - 0.1, 1e-6));

      grid.updateSpatialPlacement(
        viewerPosition: vm.Vector3(2.4, 1.5, 0.0),
        viewerForward: vm.Vector3(0, 0, -1),
        elapsedSeconds: 0.5,
        dt: 0.016,
      );
      expect(grid.yawRadians, greaterThan(0.0));
    });
  });
}
