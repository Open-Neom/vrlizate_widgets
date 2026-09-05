import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  Mesh emptyMesh() => Mesh.primitives(primitives: const []);
  Node namedNode(String name) => Node(name: name);
  final center = vm.Vector3(0, 1.4, -2.2);

  group('VrSegmentedControl3D', () {
    test('exposes stable nodes and selects through the registry', () {
      int? changedIndex;
      String? changedOption;
      final control = VrSegmentedControl3D(
        name: 'view',
        label: 'Vista',
        center: center,
        options: const ['Día', 'Semana', 'Mes'],
        meshBuilder: emptyMesh,
        onChanged: (index, option) {
          changedIndex = index;
          changedOption = option;
        },
      );
      final registry = VrControlRegistry()..register(control);

      expect(control.nodeNames, [
        'view_segment_0',
        'view_segment_1',
        'view_segment_2',
      ]);
      expect(registry.handleSelect(namedNode('view_segment_2')), isTrue);
      expect(control.selectedIndex, 2);
      expect(control.selectedOption, 'Mes');
      expect(changedIndex, 2);
      expect(changedOption, 'Mes');
    });

    test('hover previews an option and selected material stays brighter', () {
      final control = VrSegmentedControl3D(
        name: 'mode',
        label: 'Modo',
        center: center,
        options: const ['Leer', 'Editar'],
        selectedIndex: 0,
        meshBuilder: emptyMesh,
      );

      expect(control.label, 'Modo: Leer');
      control.onHoverEnter('mode_segment_1');
      expect(control.label, 'Modo: Editar');
      expect(
        control.debugSegmentMaterials[0].emissiveFactor.length,
        greaterThan(control.debugSegmentMaterials[1].emissiveFactor.length),
      );
      control.onSelect('mode_segment_1');
      expect(
        control.debugSegmentMaterials[1].emissiveFactor.length,
        greaterThan(control.debugSegmentMaterials[0].emissiveFactor.length),
      );
    });

    test(
      'programmatic selection does not fire callback and validates index',
      () {
        var callbacks = 0;
        final control = VrSegmentedControl3D(
          name: 'answer',
          label: 'Respuesta',
          center: center,
          options: const ['A', 'B'],
          meshBuilder: emptyMesh,
          onChanged: (_, __) => callbacks++,
        );

        control.setSelectedIndex(1);
        expect(control.selectedOption, 'B');
        expect(callbacks, 0);
        expect(() => control.setSelectedIndex(2), throwsRangeError);
      },
    );
  });

  group('VrProgressBar3D', () {
    test('clamps value and updates inexpensive material segments', () {
      final progress = VrProgressBar3D(
        name: 'lesson',
        label: 'Lección',
        center: center,
        initialValue: 0.45,
        segments: 10,
        meshBuilder: emptyMesh,
      );

      expect(progress.filledSegments, 5);
      expect(progress.label, 'Lección: 45%');
      expect(progress.nodes, hasLength(11));
      progress.setValue(2);
      expect(progress.value, 1);
      expect(progress.filledSegments, 10);
      progress.setValue(-1);
      expect(progress.value, 0);
      expect(progress.filledSegments, 0);
    });

    test('supports custom formatting, gaze inspection and optional action', () {
      var pressed = 0;
      final progress = VrProgressBar3D(
        name: 'course',
        label: 'Curso',
        center: center,
        initialValue: 0.5,
        valueFormat: (value) => '${(value * 8).round()} de 8',
        meshBuilder: emptyMesh,
        onPressed: () => pressed++,
      );
      final registry = VrControlRegistry()..register(progress);

      registry.handleHover(namedNode('course'));
      expect(registry.hoveredLabel, 'Curso: 4 de 8');
      expect(registry.handleSelect(namedNode('course')), isTrue);
      expect(pressed, 1);
    });

    test('disabled state removes emissive feedback immediately', () {
      final progress = VrProgressBar3D(
        name: 'download',
        label: 'Descarga',
        center: center,
        initialValue: 0.8,
        meshBuilder: emptyMesh,
      );

      expect(
        progress.debugSegmentMaterials.first.emissiveFactor.length,
        greaterThan(0),
      );
      progress.enabled = false;
      expect(
        progress.debugSegmentMaterials.every(
          (material) => material.emissiveFactor.length == 0,
        ),
        isTrue,
      );
    });
  });

  group('VrStepper3D', () {
    test('increments, decrements and reports changes through stable nodes', () {
      final changes = <double>[];
      final stepper = VrStepper3D(
        name: 'quantity',
        label: 'Cantidad',
        center: center,
        initialValue: 2,
        min: 1,
        max: 3,
        meshBuilder: emptyMesh,
        onChanged: changes.add,
      );
      final registry = VrControlRegistry()..register(stepper);

      expect(stepper.nodeNames, [
        'quantity',
        'quantity_decrement',
        'quantity_increment',
      ]);
      registry.handleSelect(namedNode('quantity_increment'));
      registry.handleSelect(namedNode('quantity_increment')); // at max
      registry.handleSelect(namedNode('quantity_decrement'));
      expect(stepper.value, 2);
      expect(changes, [3, 2]);
    });

    test(
      'setValue clamps without callback and formatter reaches HUD label',
      () {
        var callbacks = 0;
        final stepper = VrStepper3D(
          name: 'duration',
          label: 'Duración',
          center: center,
          min: 5,
          max: 30,
          step: 5,
          meshBuilder: emptyMesh,
          valueFormat: (value) => '${value.toInt()} min',
          onChanged: (_) => callbacks++,
        );

        stepper.setValue(99);
        expect(stepper.value, 30);
        expect(stepper.label, 'Duración = 30 min');
        expect(callbacks, 0);
        stepper.onHoverEnter('duration_decrement');
        expect(stepper.label, 'Duración − 30 min');
      },
    );

    test('raised plus/minus geometry remains part of the gaze targets', () {
      final stepper = VrStepper3D(
        name: 'level',
        label: 'Nivel',
        center: center,
        meshBuilder: emptyMesh,
      );

      expect(stepper.nodes, hasLength(6));
      expect(
        stepper.nodes.where((node) => node.name == 'level_increment'),
        hasLength(3),
      );
      expect(
        stepper.nodes.where((node) => node.name == 'level_decrement'),
        hasLength(2),
      );
    });
  });
}
