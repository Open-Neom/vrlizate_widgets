import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  Mesh fakeMesh() => Mesh.primitives(primitives: const []);

  group('VrPlacementMode & VrSpatialPose', () {
    test('staticWorld keeps position and yaw fixed across updates', () {
      final pose = VrSpatialPose(
        placementMode: VrPlacementMode.staticWorld,
        position: vm.Vector3(1.5, 2.0, -3.0),
      );

      final updated = pose.update(
        viewerPosition: vm.Vector3(4.0, 1.6, 0.0),
        viewerForward: vm.Vector3(0, 0, -1),
        elapsedSeconds: 2.5,
        dt: 0.016,
      );

      expect(updated.x, closeTo(1.5, 1e-6));
      expect(updated.y, closeTo(2.0, 1e-6));
      expect(updated.z, closeTo(-3.0, 1e-6));
      expect(pose.yawRadians, closeTo(0.0, 1e-6));
    });

    test('dynamicBillboard keeps position fixed and rotates yaw toward viewer', () {
      final pose = VrSpatialPose(
        placementMode: VrPlacementMode.dynamicBillboard,
        position: vm.Vector3(0, 1.5, -2.0),
      );

      // Viewer stands at (+2, 1.5, 0) → dx = 2, dz = 2 → yaw = +pi/4.
      pose.update(
        viewerPosition: vm.Vector3(2.0, 1.5, 0.0),
        viewerForward: vm.Vector3(-1, 0, -1).normalized(),
        elapsedSeconds: 1.0,
        dt: 0.016,
      );

      expect(pose.position.x, closeTo(0.0, 1e-6));
      expect(pose.position.z, closeTo(-2.0, 1e-6));
      expect(pose.yawRadians, closeTo(math.pi / 4, 1e-6));
    });

    test('headLockedHud smoothly follows viewer position + forward * distance', () {
      final pose = VrSpatialPose(
        placementMode: VrPlacementMode.headLockedHud,
        position: vm.Vector3(0, 1.5, -1.8),
        followDistance: 2.0,
        followSmoothing: 12.0,
        followOffset: vm.Vector3(0, -0.1, 0),
      );

      final viewerPos = vm.Vector3(3.0, 1.7, -1.0);
      final viewerFwd = vm.Vector3(0, 0, -1);

      for (var i = 0; i < 60; i++) {
        pose.update(
          viewerPosition: viewerPos,
          viewerForward: viewerFwd,
          elapsedSeconds: i * (1 / 60),
          dt: 1 / 60,
        );
      }

      // Target = (3.0, 1.7, -1.0) + (0, 0, -2.0) + (0, -0.1, 0) = (3.0, 1.6, -3.0).
      expect(pose.position.x, closeTo(3.0, 1e-2));
      expect(pose.position.y, closeTo(1.6, 1e-2));
      expect(pose.position.z, closeTo(-3.0, 1e-2));
    });

    test('dynamicFloating bobs vertically and preserves new anchor after moveTo', () {
      final card = VrCard3D(
        name: 'floating_card',
        label: 'Floating Card',
        center: vm.Vector3(0, 1.5, -2.2),
        placementMode: VrPlacementMode.dynamicFloating,
        meshBuilder: fakeMesh,
      );
      card.configurePlacement(
        mode: VrPlacementMode.dynamicFloating,
        floatAmplitude: 0.10,
        floatFrequencyHz: 1.0,
      );

      // At t = 0.25s (quarter cycle of 1 Hz), sin(pi/2) = 1.0 → y = 1.5 + 0.10 = 1.60.
      card.updateSpatialPlacement(
        viewerPosition: vm.Vector3.zero(),
        viewerForward: vm.Vector3(0, 0, -1),
        elapsedSeconds: 0.25,
        dt: 0.016,
      );
      expect(card.origin.y, closeTo(1.60, 1e-5));

      // Drag/move card to a new anchor at y = 2.0; subsequent float bobs around 2.0.
      card.moveTo(vm.Vector3(1.0, 2.0, -2.5));
      card.updateSpatialPlacement(
        viewerPosition: vm.Vector3.zero(),
        viewerForward: vm.Vector3(0, 0, -1),
        elapsedSeconds: 0.75, // sin(3*pi/2) = -1.0 → y = 2.0 - 0.10 = 1.90
        dt: 0.016,
      );
      expect(card.origin.x, closeTo(1.0, 1e-5));
      expect(card.origin.y, closeTo(1.90, 1e-5));
    });

    test('VrControlRegistry.updateSpatial advances both flash decay and spatial pose', () {
      final registry = VrControlRegistry();
      final button = VrButton3D(
        name: 'hud_btn',
        label: 'HUD Action',
        center: vm.Vector3(0, 1.5, -2.0),
        placementMode: VrPlacementMode.headLockedHud,
        meshBuilder: fakeMesh,
      );
      button.configurePlacement(
        mode: VrPlacementMode.headLockedHud,
        followDistance: 1.5,
        followSmoothing: 0, // instant follow when <= 0
      );
      registry.register(button);
      registry.handleSelect(Node(name: 'hud_btn'));
      expect(button.flashLevel, closeTo(1.0, 1e-6));

      registry.updateSpatial(
        viewerPosition: vm.Vector3(2.0, 1.8, 0.0),
        viewerForward: vm.Vector3(0, 0, -1),
        elapsedSeconds: 1.0,
        dt: 0.25,
      );

      expect(button.flashLevel, closeTo(0.0, 1e-6));
      expect(button.origin.x, closeTo(2.0, 1e-5));
      expect(button.origin.y, closeTo(1.8, 1e-5));
      expect(button.origin.z, closeTo(-1.5, 1e-5));
    });
  });
}
