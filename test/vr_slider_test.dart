import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

/// Headless hook: flutter_scene geometry constructors upload to Flutter GPU
/// eagerly, so tests inject empty-primitive meshes.
Mesh emptyMesh() => Mesh.primitives(primitives: const []);

void main() {
  final center = vm.Vector3(0, 1.4, -2);

  group('VrSlider3D', () {
    test('default value is 0.5 with thumb at track center', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        meshBuilder: emptyMesh,
      );
      expect(s.value, 0.5);
      expect(s.divisions, 5);
      final thumbPos = s.nodes[1].localTransform.getTranslation();
      expect(thumbPos.x, closeTo(center.x, 1e-6));
    });

    test('nodeNames include track + all segments', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        divisions: 4,
        meshBuilder: emptyMesh,
      );
      expect(s.nodeNames, [
        'vol',
        'vol_seg_0',
        'vol_seg_1',
        'vol_seg_2',
        'vol_seg_3',
      ]);
    });

    test('selecting a segment sets the value and fires onChanged', () {
      double? got;
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        divisions: 5,
        meshBuilder: emptyMesh,
        onChanged: (v) => got = v,
      );
      s.onSelect('vol_seg_0');
      expect(s.value, 0.0);
      expect(got, 0.0);
      s.onSelect('vol_seg_4');
      expect(s.value, 1.0);
      expect(got, 1.0);
      s.onSelect('vol_seg_2');
      expect(s.value, 0.5);
    });

    test('thumb glides to the selected segment', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        width: 0.4,
        meshBuilder: emptyMesh,
      );
      s.onSelect('vol_seg_4'); // value 1.0 → right end
      final thumbPos = s.nodes[1].localTransform.getTranslation();
      expect(thumbPos.x, closeTo(center.x + 0.2, 1e-6));
    });

    test('track select flashes but does not change the value', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        meshBuilder: emptyMesh,
      );
      s.onSelect('vol');
      expect(s.value, 0.5);
      expect(s.flashLevel, 1.0);
      s.update(0.25);
      expect(s.flashLevel, lessThan(1.0));
    });

    test('label shows the formatted value (default %, custom formatter)', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        meshBuilder: emptyMesh,
      );
      expect(s.label, 'Volumen: 50%');
      final months = VrSlider3D(
        name: 'mo',
        label: 'Meses',
        center: center,
        divisions: 4,
        initialValue: 1.0,
        meshBuilder: emptyMesh,
        valueFormat: (v) => '${3 + (v * 3).round() * 3 - 3}',
      );
      expect(months.label, contains('Meses:'));
    });

    test('registry routes hover and select by node name', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        meshBuilder: emptyMesh,
      );
      final registry = VrControlRegistry()..register(s);
      final seg2 = Node(name: 'vol_seg_2');
      registry.handleHover(seg2);
      expect(registry.hoveredLabel, contains('Volumen'));
      expect(registry.handleSelect(seg2), isTrue);
      expect(s.value, 0.5);
      s.onSelect('vol_seg_0');
      expect(registry.handleSelect(seg2), isTrue);
      expect(s.value, 0.5); // segment index 2 again → 0.5
    });

    test('thumb follows the track after a parent moves it', () {
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        meshBuilder: emptyMesh,
      );
      // Simulate a VrPanel3D moving all nodes +1 in x.
      for (final n in s.nodes) {
        n.localTransform = vm.Matrix4.translation(
          n.localTransform.getTranslation() + vm.Vector3(1, 0, 0),
        );
      }
      s.onSelect('vol_seg_0'); // value 0 → left end of the MOVED track
      final thumbPos = s.nodes[1].localTransform.getTranslation();
      expect(thumbPos.x, closeTo(center.x + 1 - s.width / 2, 1e-6));
    });

    test('setValue moves the thumb without firing onChanged', () {
      var fired = false;
      final s = VrSlider3D(
        name: 'vol',
        label: 'Volumen',
        center: center,
        width: 0.4,
        meshBuilder: emptyMesh,
        onChanged: (_) => fired = true,
      );
      s.setValue(1.0);
      expect(s.value, 1.0);
      expect(fired, isFalse);
      final thumbPos = s.nodes[1].localTransform.getTranslation();
      expect(thumbPos.x, closeTo(center.x + 0.2, 1e-6));
      s.setValue(2.0); // clamps
      expect(s.value, 1.0);
    });
  });
}
