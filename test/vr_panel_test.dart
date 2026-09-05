import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  Mesh fakeMesh() => Mesh.primitives(primitives: const []);
  final center = vm.Vector3(-1.1, 1.55, -2.4);

  VrPanel3D makePanel() => VrPanel3D(
    name: 'settings',
    label: 'Ajustes',
    center: center,
    meshBuilder: fakeMesh,
    children: [
      VrToggle3D(
        name: 'night',
        label: 'Noche',
        center: vm.Vector3(99, 99, 99),
        meshBuilder: fakeMesh,
      ),
      VrButton3D(
        name: 'reset',
        label: 'Reset',
        center: vm.Vector3(50, 50, 50),
        meshBuilder: fakeMesh,
      ),
    ],
  );

  group('VrPanel3D', () {
    test('registerAll registers handle and children in the registry', () {
      final panel = makePanel();
      final registry = VrControlRegistry();
      panel.registerAll(registry);

      expect(registry.handleSelect(Node(name: 'mv_settings')), isTrue);
      expect(registry.handleSelect(Node(name: 'night')), isTrue);
      expect(registry.handleSelect(Node(name: 'unknown')), isFalse);
    });

    test('children are laid out below the handle in order', () {
      final panel = makePanel();
      final handleY = panel.nodes[0].localTransform.getTranslation().y;
      final child0Y = panel.children[0].nodes.first.localTransform
          .getTranslation()
          .y;
      final child1Y = panel.children[1].nodes.first.localTransform
          .getTranslation()
          .y;
      expect(child0Y, lessThan(handleY));
      expect(child1Y, lessThan(child0Y));
    });

    test('dwell on handle grabs, gaze drags, dwell again drops', () {
      final panel = makePanel();
      final registry = VrControlRegistry();
      panel.registerAll(registry);

      final eye = vm.Vector3(0, 1.6, 0);
      final forward = vm.Vector3(0, 0, -1);

      // Grab.
      registry.handleSelect(Node(name: 'mv_settings'));
      expect(panel.grabbed, isTrue);
      expect(panel.label, contains('mirada'));

      // Drag: panel follows the gaze at the grab distance.
      panel.dragUpdateWithEye(eye, forward);
      final grabbedAt = panel.origin.clone();
      final tiltedForward = vm.Vector3(1, 0, -1).normalized();
      panel.dragUpdateWithEye(eye, tiltedForward);
      expect(panel.origin.x, greaterThan(grabbedAt.x)); // followed the gaze

      // Children moved with the panel.
      final childX = panel.children[0].nodes.first.localTransform
          .getTranslation()
          .x;
      expect(childX, greaterThan(-1.1));

      // Drop.
      registry.handleSelect(Node(name: 'mv_settings'));
      expect(panel.grabbed, isFalse);
      final droppedAt = panel.origin.clone();
      panel.dragUpdateWithEye(eye, forward);
      expect(panel.origin.x, closeTo(droppedAt.x, 1e-9)); // stays put
    });

    test('scaleTo resizes the panel and its children as a unit', () {
      final panel = makePanel();
      final beforeChild = panel.children[0].nodes.first.localTransform
          .getTranslation()
          .distanceTo(panel.origin);
      panel.scaleTo(2.0);
      final afterChild = panel.children[0].nodes.first.localTransform
          .getTranslation()
          .distanceTo(panel.origin);
      expect(afterChild, closeTo(beforeChild * 2, 1e-6));
    });
  });
}
