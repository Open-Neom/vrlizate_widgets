import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

Mesh _emptyMesh() => Mesh.primitives(primitives: const []);

void main() {
  group('Lote 87 vrlizate_widgets 3D Controls & Layouts Hardening', () {
    test(
      'VrSlider3D and VrProgressBar3D survive NaN values, extreme divisions/segments, non-finite centers, and out-of-range segment IDs',
      () {
        final slider = VrSlider3D(
          name: 's',
          label: 'S',
          center: vm.Vector3(double.nan, 1.2, -2.0),
          initialValue: double.nan,
          divisions: 50000,
          width: double.nan,
          meshBuilder: _emptyMesh,
        );
        expect(slider.divisions, 1024);
        expect(slider.value.isFinite, isTrue);
        expect(
          slider.nodes.first.localTransform.getTranslation().x.isFinite,
          isTrue,
        );

        slider.setValue(double.nan);
        expect(slider.value.isFinite, isTrue);

        // Out-of-bounds and non-numeric segment names never throw RangeError/FormatException
        slider.onHoverEnter('s_seg_999999');
        slider.onHoverEnter('s_seg_-1');
        slider.onHoverEnter('s_seg_notanint');
        slider.onSelect('s_seg_999999');
        slider.onSelect('s_seg_-3');
        slider.onSelect('s_seg_bad');
        expect(slider.value.isFinite, isTrue);

        final bar = VrProgressBar3D(
          name: 'p',
          label: 'P',
          center: vm.Vector3(0, double.infinity, -2.0),
          initialValue: double.nan,
          segments: 99999,
          width: -5.0,
          meshBuilder: _emptyMesh,
        );
        expect(bar.segments, 1024);
        expect(bar.value, 0.0);
        bar.setValue(double.nan);
        expect(bar.value, 0.0);
      },
    );

    test(
      'VrGrid3D, VrRow3D, and VrColumn3D clamp non-positive columns and non-finite spacing/origin',
      () {
        VrButton3D btn(String id) => VrButton3D(
          name: id,
          label: id,
          center: vm.Vector3.zero(),
          meshBuilder: _emptyMesh,
        );

        final b0 = btn('g0');
        final b1 = btn('g1');
        final grid = VrGrid3D(
          name: 'grid',
          origin: vm.Vector3(double.nan, 1.5, -2.0),
          columns: 5000,
          columnSpacing: double.nan,
          rowSpacing: double.infinity,
          children: [b0, b1],
        );
        expect(grid.columns, 256);
        expect(b0.origin.x.isFinite, isTrue);
        expect(b1.origin.x.isFinite, isTrue);

        final r0 = btn('r0');
        final r1 = btn('r1');
        VrRow3D(
          name: 'row',
          origin: vm.Vector3(0, double.nan, -2.0),
          spacing: double.nan,
          children: [r0, r1],
        );
        expect(r0.origin.x.isFinite, isTrue);
        expect(r1.origin.y.isFinite, isTrue);

        final c0 = btn('c0');
        final c1 = btn('c1');
        VrColumn3D(
          name: 'col',
          origin: vm.Vector3(0, 1.5, double.infinity),
          spacing: double.negativeInfinity,
          children: [c0, c1],
        );
        expect(c0.origin.y.isFinite, isTrue);
        expect(c1.origin.z.isFinite, isTrue);
      },
    );
  });
}
