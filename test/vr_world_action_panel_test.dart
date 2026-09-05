import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  Mesh fakeMesh() => Mesh.primitives(primitives: const []);
  Future<Node> fakeText(VrWorldTextSpec spec) async =>
      Node(name: spec.nodeName);

  VrWorldPose defaultPose() => VrWorldPose.fromViewer(
    eye: vm.Vector3(0, 1.6, 0),
    forward: vm.Vector3(0, 0, -1),
    right: vm.Vector3(1, 0, 0),
    up: vm.Vector3(0, 1, 0),
  );

  Future<VrWorldActionPanel3D> makePanel({
    void Function()? onEnter,
    void Function()? onBack,
    bool backEnabled = true,
  }) => VrWorldActionPanel3D.create(
    name: 'demo_preview',
    pose: defaultPose(),
    title: 'Kanban VR',
    subtitle: 'Productividad',
    description: 'Organiza tareas en el espacio.',
    actions: [
      VrWorldAction(id: 'enter', label: 'Entrar', onPressed: onEnter ?? () {}),
      VrWorldAction(
        id: 'back',
        label: 'Volver',
        enabled: backEnabled,
        onPressed: onBack ?? () {},
      ),
    ],
    meshBuilder: fakeMesh,
    textNodeBuilder: fakeText,
  );

  Node actionNode(VrWorldActionPanel3D panel, String id) =>
      panel.nodes.firstWhere((node) => node.name == 'demo_preview_action_$id');

  group('VrWorldPose', () {
    test('fromViewer places an orthonormal panel on the gaze ray', () {
      final pose = defaultPose();

      expect(pose.center.x, closeTo(0, 1e-7));
      expect(pose.center.y, closeTo(1.6, 1e-7));
      expect(pose.center.z, closeTo(-1.8, 1e-7));
      expect(pose.right, closeVector(vm.Vector3(1, 0, 0)));
      expect(pose.up, closeVector(vm.Vector3(0, 1, 0)));
      expect(pose.towardViewer, closeVector(vm.Vector3(0, 0, 1)));

      final local = vm.Vector3(0.25, -0.4, 0.1);
      expect(
        pose.localToWorld(local),
        closeVector(vm.Vector3(0.25, 1.2, -1.7)),
      );
      expect(
        pose.transformAt(local).getTranslation(),
        closeVector(pose.localToWorld(local)),
      );

      expect(pose.right.dot(pose.up), closeTo(0, 1e-9));
      expect(pose.right.dot(pose.towardViewer), closeTo(0, 1e-9));
      expect(pose.up.dot(pose.towardViewer), closeTo(0, 1e-9));
    });

    test('copies inputs and does not expose mutable internal vectors', () {
      final eye = vm.Vector3(1, 2, 3);
      final forward = vm.Vector3(0, 0, -1);
      final pose = VrWorldPose.fromViewer(eye: eye, forward: forward);
      final originalCenter = pose.center;

      eye.setValues(99, 99, 99);
      forward.setValues(99, 99, 99);
      pose.center.setValues(-50, -50, -50);
      pose.right.setValues(-50, -50, -50);
      pose.transform.setZero();

      expect(pose.center, closeVector(originalCenter));
      expect(pose.right.length, closeTo(1, 1e-9));
      expect(pose.transform.getTranslation(), closeVector(originalCenter));
    });

    test('preserves a supplied rolled viewer basis', () {
      final s = math.sqrt(0.5);
      final pose = VrWorldPose.fromViewer(
        eye: vm.Vector3.zero(),
        forward: vm.Vector3(0, 0, -1),
        right: vm.Vector3(s, s, 0),
        up: vm.Vector3(-s, s, 0),
      );

      expect(pose.right, closeVector(vm.Vector3(s, s, 0)));
      expect(pose.up, closeVector(vm.Vector3(-s, s, 0)));
    });

    test('facingEye remains stable when eye is directly above panel', () {
      final pose = VrWorldPose.facingEye(
        center: vm.Vector3.zero(),
        eye: vm.Vector3(0, 3, 0),
      );

      expect(pose.towardViewer, closeVector(vm.Vector3(0, 1, 0)));
      expect(pose.right.length, closeTo(1, 1e-9));
      expect(pose.up.length, closeTo(1, 1e-9));
      expect(pose.right.dot(pose.up), closeTo(0, 1e-9));
    });

    test('fromViewer repairs a supplied up vector parallel to gaze', () {
      final pose = VrWorldPose.fromViewer(
        eye: vm.Vector3.zero(),
        forward: vm.Vector3(0, 1, 0),
        up: vm.Vector3(0, 1, 0),
      );

      expect(pose.center, closeVector(vm.Vector3(0, 1.8, 0)));
      expect(pose.towardViewer, closeVector(vm.Vector3(0, -1, 0)));
      expect(pose.right.length, closeTo(1, 1e-9));
      expect(pose.up.length, closeTo(1, 1e-9));
    });

    test('rejects degenerate or non-finite placement data', () {
      expect(
        () => VrWorldPose.fromViewer(
          eye: vm.Vector3.zero(),
          forward: vm.Vector3.zero(),
        ),
        throwsArgumentError,
      );
      expect(
        () => VrWorldPose.fromViewer(
          eye: vm.Vector3.zero(),
          forward: vm.Vector3(0, 0, -1),
          distance: double.nan,
        ),
        throwsArgumentError,
      );
      expect(
        () => VrWorldPose.facingEye(
          center: vm.Vector3.zero(),
          eye: vm.Vector3.zero(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('VrWorldActionPanel3D', () {
    test(
      'owns its nodes by identity and keeps the plate non-raycastable',
      () async {
        final panel = await makePanel();
        final enter = actionNode(panel, 'enter');

        expect(panel.ownsNode(panel.rootNode), isTrue);
        expect(panel.ownsNode(panel.plateNode), isTrue);
        expect(panel.plateNode.raycastable, isFalse);
        expect(panel.rootNode.raycastable, isFalse);
        expect(panel.ownsInteractiveNode(enter), isTrue);

        final spoofed = Node(name: enter.name);
        expect(panel.ownsNode(spoofed), isFalse);
        expect(panel.ownsInteractiveNode(spoofed), isFalse);
        expect(panel.handleSelect(spoofed), isFalse);

        for (final node in panel.nodes.where(
          (node) =>
              node.name.endsWith('_title') ||
              node.name.endsWith('_subtitle') ||
              node.name.endsWith('_description'),
        )) {
          expect(node.raycastable, isFalse);
        }
      },
    );

    test(
      'routes hover/select and synchronizes focus with the hit action',
      () async {
        var enters = 0;
        var backs = 0;
        final panel = await makePanel(
          onEnter: () => enters++,
          onBack: () => backs++,
        );
        final enter = actionNode(panel, 'enter');
        final back = actionNode(panel, 'back');

        expect(panel.focusedIndex, 0);
        expect(panel.focusedAction.id, 'enter');

        panel.handleHover(back);
        expect(panel.focusedIndex, 1);
        expect(panel.focusedAction.id, 'back');
        expect(panel.handleSelect(back), isTrue);
        expect(backs, 1);
        expect(enters, 0);

        panel.handleHover(enter);
        expect(panel.handleSelect(enter), isTrue);
        expect(enters, 1);
      },
    );

    test(
      'moveFocus skips disabled actions; explicit activation is safe',
      () async {
        var enters = 0;
        var backs = 0;
        final panel = await makePanel(
          onEnter: () => enters++,
          onBack: () => backs++,
          backEnabled: false,
        );

        expect(panel.moveFocus(-1), 0);
        panel.setFocus(1);
        expect(panel.focusedAction.id, 'back');
        expect(panel.activateFocused(), isFalse);
        expect(backs, 0);

        expect(panel.moveFocus(1), 0);
        expect(panel.activateFocused(), isTrue);
        expect(enters, 1);
        expect(() => panel.setFocus(2), throwsRangeError);
      },
    );

    test(
      'columns read left-to-right in the actual camera projection',
      () async {
        final panel = await VrWorldActionPanel3D.create(
          name: 'grid',
          pose: defaultPose(),
          title: 'Itzli',
          actions: [
            for (var i = 0; i < 8; i++)
              VrWorldAction(id: 'a$i', label: 'Acción $i', onPressed: () {}),
          ],
          columns: 2,
          columnSpacing: 0.1,
          meshBuilder: fakeMesh,
          textNodeBuilder: fakeText,
        );

        Node button(String id) => panel.rootNode.children.firstWhere(
          (node) => node.name == 'grid_action_$id',
        );
        final p0 = button('a0').localTransform.getTranslation();
        final p1 = button('a1').localTransform.getTranslation();
        final p2 = button('a2').localTransform.getTranslation();

        expect(panel.columns, 2);
        expect(p0.y, closeTo(p1.y, 1e-9));
        final camera = PerspectiveCamera(
          position: vm.Vector3(0, 1.6, 0),
          target: vm.Vector3(0, 1.6, -1),
        );
        const viewSize = Size(1200, 1080);
        final screen0 = camera.worldToScreen(
          panel.pose.localToWorld(p0),
          viewSize,
        )!;
        final screen1 = camera.worldToScreen(
          panel.pose.localToWorld(p1),
          viewSize,
        )!;
        final screen2 = camera.worldToScreen(
          panel.pose.localToWorld(p2),
          viewSize,
        )!;
        expect(screen0.dx, lessThan(screen1.dx));
        expect(screen0.dy, closeTo(screen1.dy, 1e-6));
        expect(screen2.dx, closeTo(screen0.dx, 1e-6));
        expect(screen2.dy, greaterThan(screen0.dy));
        expect(p2.x, closeTo(p0.x, 1e-9));
        expect(p2.y, lessThan(p0.y));

        for (var i = 1; i < 8; i++) {
          expect(panel.moveFocus(1), i);
        }
        expect(panel.moveFocus(1), 0);
      },
    );

    test('stationary pointer and misses do not undo joystick focus', () async {
      final panel = await makePanel();
      final enter = actionNode(panel, 'enter');
      final back = actionNode(panel, 'back');

      panel.handleHover(enter);
      panel.moveFocus(1);
      expect(panel.focusedIndex, 1);
      for (var frame = 0; frame < 120; frame++) {
        panel.handleHover(enter);
        panel.update(1 / 120);
      }
      expect(panel.focusedIndex, 1);

      panel.handleHover(null);
      expect(panel.focusedIndex, 1);
      panel.handleHover(enter);
      expect(panel.focusedIndex, 0);
      panel.handleHover(back);
      expect(panel.focusedIndex, 1);
    });

    test(
      'button labels route by identity even when their name changes',
      () async {
        var presses = 0;
        final panel = await makePanel(onBack: () => presses++);
        final label = panel.rootNode.children.last;
        expect(panel.ownsInteractiveNode(label), isTrue);
        label.name = 'renamed_by_text_backend';

        panel.handleHover(label);
        expect(panel.focusedAction.id, 'back');
        expect(panel.handleSelect(label), isTrue);
        expect(presses, 1);
        expect(panel.handleSelect(Node(name: label.name)), isFalse);
      },
    );

    test('disabled labels cannot capture pointer focus or selection', () async {
      final panel = await makePanel(backEnabled: false);
      final back = panel.rootNode.children.last;
      expect(panel.ownsNode(back), isTrue);
      expect(panel.ownsInteractiveNode(back), isFalse);
      panel.handleHover(back);
      expect(panel.focusedIndex, 0);
      expect(panel.handleSelect(back), isFalse);
    });

    test(
      'grid navigation stays on its axis across missing/disabled cells',
      () async {
        final panel = await VrWorldActionPanel3D.create(
          name: 'grid',
          pose: defaultPose(),
          title: 'Grid',
          actions: [
            for (var i = 0; i < 5; i++)
              VrWorldAction(
                id: 'a$i',
                label: 'Action $i',
                enabled: i != 0 && i != 2,
                onPressed: () {},
              ),
          ],
          columns: 2,
          meshBuilder: fakeMesh,
          textNodeBuilder: fakeText,
        );
        expect(panel.focusedIndex, 1); // First enabled action.
        expect(panel.moveGridFocus(vertical: 1), 3);
        expect(panel.moveGridFocus(vertical: 1), 1); // Missing cell 5 skipped.
        expect(panel.moveGridFocus(horizontal: -1), 1); // Disabled cell 0.
        panel.setFocus(4);
        expect(panel.moveGridFocus(horizontal: 1), 4); // Incomplete last row.
        expect(panel.moveGridFocus(vertical: -1), 4); // Disabled cells 2 and 0.
        expect(
          () => panel.moveGridFocus(horizontal: 1, vertical: 1),
          throwsArgumentError,
        );
      },
    );

    test(
      'all-disabled navigation terminates without invoking actions',
      () async {
        var presses = 0;
        final panel = await VrWorldActionPanel3D.create(
          name: 'disabled',
          pose: defaultPose(),
          title: 'Unavailable',
          actions: [
            VrWorldAction(
              id: 'only',
              label: 'Only',
              enabled: false,
              onPressed: () => presses++,
            ),
          ],
          meshBuilder: fakeMesh,
          textNodeBuilder: fakeText,
        );
        expect(panel.moveFocus(-1), 0);
        expect(panel.moveGridFocus(vertical: 1), 0);
        expect(panel.activateFocused(), isFalse);
        expect(presses, 0);
      },
    );

    test(
      'action list is snapshotted before asynchronous text creation',
      () async {
        final textReady = Completer<void>();
        var presses = 0;
        final actions = [
          VrWorldAction(
            id: 'original',
            label: 'Original',
            onPressed: () => presses++,
          ),
        ];
        final creating = VrWorldActionPanel3D.create(
          name: 'snapshot',
          pose: defaultPose(),
          title: 'Snapshot',
          actions: actions,
          meshBuilder: fakeMesh,
          textNodeBuilder: (spec) async {
            await textReady.future;
            return Node(name: spec.nodeName);
          },
        );
        actions.clear();
        textReady.complete();
        final panel = await creating;
        expect(panel.actions.single.id, 'original');
        expect(panel.activateFocused(), isTrue);
        expect(presses, 1);
      },
    );

    test('update never moves the panel; only explicit reanchor does', () async {
      final panel = await makePanel();
      final initial = panel.rootNode.localTransform.clone();

      panel.update(10);
      expect(panel.rootNode.localTransform, closeMatrix(initial));

      final nextPose = VrWorldPose.facingEye(
        center: vm.Vector3(2, 1.4, -3),
        eye: vm.Vector3.zero(),
      );
      panel.reanchor(nextPose);
      expect(
        panel.rootNode.localTransform.getTranslation(),
        closeVector(vm.Vector3(2, 1.4, -3)),
      );
      expect(panel.pose.center, closeVector(vm.Vector3(2, 1.4, -3)));

      final reanchored = panel.rootNode.localTransform.clone();
      panel.update(10);
      expect(panel.rootNode.localTransform, closeMatrix(reanchored));
    });

    test('builds one self-contained subtree for Scene mounting', () async {
      final panel = await makePanel();
      expect(panel.isMounted, isFalse);
      expect(panel.rootNode.parent, isNull);
      expect(panel.rootNode.children, isNotEmpty);
      for (final child in panel.rootNode.children) {
        expect(child.parent, same(panel.rootNode));
      }
    });

    test('validates action identifiers and required content', () async {
      Future<VrWorldActionPanel3D> createWithActions(
        List<VrWorldAction> actions,
      ) => VrWorldActionPanel3D.create(
        name: 'panel',
        pose: defaultPose(),
        title: 'Title',
        actions: actions,
        meshBuilder: fakeMesh,
        textNodeBuilder: fakeText,
      );

      await expectLater(createWithActions(const []), throwsArgumentError);
      await expectLater(
        createWithActions([
          VrWorldAction(id: 'same', label: 'A', onPressed: () {}),
          VrWorldAction(id: 'same', label: 'B', onPressed: () {}),
        ]),
        throwsArgumentError,
      );
      await expectLater(
        VrWorldActionPanel3D.create(
          name: 'panel',
          pose: defaultPose(),
          title: 'Title',
          actions: [VrWorldAction(id: 'only', label: 'Only', onPressed: () {})],
          columns: 2,
          meshBuilder: fakeMesh,
          textNodeBuilder: fakeText,
        ),
        throwsArgumentError,
      );
    });
  });
}

Matcher closeVector(vm.Vector3 expected, [double tolerance = 1e-6]) =>
    predicate<vm.Vector3>(
      (actual) => actual.distanceTo(expected) <= tolerance,
      'Vector3 within $tolerance of $expected',
    );

Matcher closeMatrix(vm.Matrix4 expected, [double tolerance = 1e-6]) =>
    predicate<vm.Matrix4>((actual) {
      for (var i = 0; i < 16; i++) {
        if ((actual.storage[i] - expected.storage[i]).abs() > tolerance) {
          return false;
        }
      }
      return true;
    }, 'Matrix4 within $tolerance of $expected');
