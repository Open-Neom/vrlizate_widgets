import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

/// Minimal stateless 3D widget for framework tests.
class _Chip extends VrStatelessWidget {
  _Chip({required super.name, required vm.Vector3 center}) {
    _node = Node(name: name)..localTransform = vm.Matrix4.translation(center);
    initSpatial(center);
  }

  late final Node _node;

  @override
  String get label => name;

  @override
  List<Node> get nodes => [_node];
}

/// Minimal stateful 3D widget for framework tests.
class _Counter extends VrStatefulWidget {
  _Counter({required super.name, required vm.Vector3 center}) {
    _node = Node(name: name)..localTransform = vm.Matrix4.translation(center);
    initSpatial(center);
  }

  late final Node _node;

  @override
  String get label => name;

  @override
  List<Node> get nodes => [_node];

  @override
  VrWidgetState createState() => _CounterState()..mount(this);
}

class _CounterState extends VrWidgetState {
  int count = 0;
}

void main() {
  group('VrSpatial (resize + move)', () {
    test('scaleTo scales offsets and geometry live, without rebuild', () {
      final chip = _Chip(name: 'chip', center: vm.Vector3(1, 2, -3));
      final node = chip.nodes.first;
      // Re-anchor at the world origin so the offset is non-zero.
      chip.initSpatial(vm.Vector3.zero());

      chip.scaleTo(2.0);
      var t = node.localTransform.getTranslation();
      expect(t.x, closeTo(2, 1e-9));
      expect(t.y, closeTo(4, 1e-9));
      expect(t.z, closeTo(-6, 1e-9));
      expect(node.localTransform.entry(0, 0), closeTo(2.0, 1e-9));

      chip.scaleTo(0.5);
      t = node.localTransform.getTranslation();
      expect(t.x, closeTo(0.5, 1e-9));
      expect(node.localTransform.entry(0, 0), closeTo(0.5, 1e-9));
    });

    test('scale is clamped to a sane range', () {
      final chip = _Chip(name: 'chip', center: vm.Vector3.zero());
      chip.scaleTo(100);
      expect(chip.scale, 4.0);
      chip.scaleTo(0.01);
      expect(chip.scale, 0.25);
    });

    test('moveTo/moveBy move the whole widget', () {
      final chip = _Chip(name: 'chip', center: vm.Vector3(0, 1, 0));
      chip.moveTo(vm.Vector3(5, 1, -2));
      expect(
        chip.nodes.first.localTransform.getTranslation().x,
        closeTo(5, 1e-9),
      );
      chip.moveBy(vm.Vector3(1, 0, 0));
      expect(
        chip.nodes.first.localTransform.getTranslation().x,
        closeTo(6, 1e-9),
      );
    });

    test('move + scale compose (scale around origin)', () {
      final chip = _Chip(name: 'chip', center: vm.Vector3(1, 0, 0));
      chip.scaleTo(2.0);
      chip.moveTo(vm.Vector3(10, 0, 0));
      final t = chip.nodes.first.localTransform.getTranslation();
      // Offset (1,0,0) × 2 around new origin (10,0,0) → x = 10? No: offset
      // is relative to origin, so node lands exactly at origin when offset 0;
      // here offset was 0 (node at center), so translation = origin.
      expect(t.x, closeTo(10, 1e-9));
    });
  });

  group('Stateful / stateless semantics', () {
    test('stateful widget keeps state and setState notifies the host', () {
      final counter = _Counter(name: 'c', center: vm.Vector3.zero());
      final state = counter.createState() as _CounterState;
      var notifications = 0;
      state.onChanged = () => notifications++;

      expect(state.count, 0);
      state.setState(() => state.count++);
      expect(state.count, 1);
      expect(notifications, 1);

      state.setState(() => state.count += 2);
      expect(state.count, 3);
      expect(notifications, 2);
      expect(state.widget, same(counter));
    });
  });
}
