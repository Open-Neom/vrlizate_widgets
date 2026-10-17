import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  Mesh fakeMesh() => Mesh.primitives(primitives: const []);
  final center = vm.Vector3(0, 1.5, -2.2);

  group('VrCard3D', () {
    test('builds bevel, plate, and accent strip and handles press and elevation', () {
      var pressed = 0;
      final card = VrCard3D(
        name: 'info_card',
        label: 'Sesión VR',
        subtitle: 'Activa',
        center: center,
        meshBuilder: fakeMesh,
        onPressed: () => pressed++,
      );

      expect(card.nodes.length, 3);
      expect(card.label, 'Sesión VR — Activa');

      final registry = VrControlRegistry()..register(card);
      registry.handleHover(Node(name: 'info_card'));
      expect(registry.hoveredLabel, 'Sesión VR — Activa');
      expect(registry.handleSelect(Node(name: card.accentNodeName)), isTrue);
      expect(pressed, 1);

      card.setElevation(0.08);
      expect(
        card.nodes[1].localTransform.getTranslation().z,
        closeTo(center.z + 0.08, 1e-6),
      );
    });
  });

  group('VrSwitch3D', () {
    test('toggles value, slides thumb node, and supports programmatic setValue', () {
      bool? lastValue;
      final sw = VrSwitch3D(
        name: 'audio_sw',
        label: 'Audio',
        center: center,
        meshBuilder: fakeMesh,
        onChanged: (v) => lastValue = v,
      );

      expect(sw.value, isFalse);
      expect(sw.label, 'Audio: OFF');
      final offThumbX = sw.nodes[1].localTransform.getTranslation().x;
      expect(offThumbX, lessThan(center.x));

      final registry = VrControlRegistry()..register(sw);
      expect(registry.handleSelect(Node(name: sw.thumbNodeName)), isTrue);
      expect(sw.value, isTrue);
      expect(lastValue, isTrue);
      expect(sw.label, 'Audio: ON');
      final onThumbX = sw.nodes[1].localTransform.getTranslation().x;
      expect(onThumbX, greaterThan(center.x));

      // Programmatic setValue does not trigger callback.
      lastValue = null;
      sw.setValue(false);
      expect(sw.value, isFalse);
      expect(lastValue, isNull);
      expect(sw.nodes[1].localTransform.getTranslation().x, closeTo(offThumbX, 1e-6));
    });
  });

  group('VrChip3D', () {
    test('toggles selection and indicator visibility', () {
      bool? selectedState;
      final chip = VrChip3D(
        name: 'filter_chip',
        label: 'Espacial',
        center: center,
        meshBuilder: fakeMesh,
        onSelected: (v) => selectedState = v,
      );

      expect(chip.selected, isFalse);
      expect(chip.nodes[1].visible, isFalse);

      final registry = VrControlRegistry()..register(chip);
      expect(registry.handleSelect(Node(name: 'filter_chip')), isTrue);
      expect(chip.selected, isTrue);
      expect(chip.nodes[1].visible, isTrue);
      expect(selectedState, isTrue);
      expect(chip.label, contains(VrWidgetConstants.chipSelectedSuffix));

      chip.setSelected(false);
      expect(chip.selected, isFalse);
      expect(chip.nodes[1].visible, isFalse);
    });
  });

  group('VrIconButton3D', () {
    test('fires onPressed on base or emblem selection and supports disabled state', () {
      var taps = 0;
      final fab = VrIconButton3D(
        name: 'recenter_fab',
        label: 'Recentrar',
        center: center,
        meshBuilder: fakeMesh,
        onPressed: () => taps++,
      );

      final registry = VrControlRegistry()..register(fab);
      expect(registry.handleSelect(Node(name: fab.emblemNodeName)), isTrue);
      expect(taps, 1);

      fab.enabled = false;
      expect(registry.handleSelect(Node(name: 'recenter_fab')), isFalse);
      expect(taps, 1);
    });
  });

  group('VrDialog3D', () {
    test('routes confirm and cancel actions and toggles visibility via show/dismiss', () {
      var confirmed = 0;
      var cancelled = 0;
      final dialog = VrDialog3D(
        name: 'exit_dialog',
        label: 'Salir de la escena',
        center: center,
        meshBuilder: fakeMesh,
        onConfirm: () => confirmed++,
        onCancel: () => cancelled++,
      );

      final registry = VrControlRegistry()..register(dialog);
      registry.handleHover(Node(name: dialog.confirmNodeName));
      expect(registry.hoveredLabel, 'Salir de la escena: Confirmar');
      expect(registry.handleSelect(Node(name: dialog.confirmNodeName)), isTrue);
      expect(confirmed, 1);

      registry.handleHover(Node(name: dialog.cancelNodeName));
      expect(registry.hoveredLabel, 'Salir de la escena: Cancelar');
      expect(registry.handleSelect(Node(name: dialog.cancelNodeName)), isTrue);
      expect(cancelled, 1);

      dialog.dismiss();
      expect(dialog.isOpen, isFalse);
      for (final node in dialog.nodes) {
        expect(node.visible, isFalse);
      }

      dialog.show();
      expect(dialog.isOpen, isTrue);
      for (final node in dialog.nodes) {
        expect(node.visible, isTrue);
      }
    });
  });

  group('VrListTile3D', () {
    test('separates main plate tap from trailing action tap', () {
      var mainTaps = 0;
      var trailingTaps = 0;
      final tile = VrListTile3D(
        name: 'room_tile',
        label: 'Sala Principal',
        subtitle: '12 usuarios',
        center: center,
        meshBuilder: fakeMesh,
        onTap: () => mainTaps++,
        onTrailingTap: () => trailingTaps++,
      );

      expect(tile.label, 'Sala Principal: 12 usuarios');

      final registry = VrControlRegistry()..register(tile);
      expect(registry.handleSelect(Node(name: 'room_tile')), isTrue);
      expect(mainTaps, 1);
      expect(trailingTaps, 0);

      expect(registry.handleSelect(Node(name: tile.trailingNodeName)), isTrue);
      expect(mainTaps, 1);
      expect(trailingTaps, 1);
    });
  });
}
