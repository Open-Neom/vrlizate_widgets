import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  final center = vm.Vector3(0, 1.4, -2.5);

  /// flutter_scene geometry constructors upload to Flutter GPU eagerly —
  /// unavailable headless. Empty-primitive meshes keep the scene-graph logic
  /// (names, visibility, transforms) fully testable.
  Mesh fakeMesh() => Mesh.primitives(primitives: const []);

  Node namedNode(String name) => Node(name: name);

  group('VrControlRegistry', () {
    test('routes hover and select by node name', () {
      final registry = VrControlRegistry();
      var pressed = 0;
      registry.register(
        VrButton3D(
          name: 'btn_a',
          label: 'Botón A',
          center: center,
          meshBuilder: fakeMesh,
          onPressed: () => pressed++,
        ),
      );

      registry.handleHover(namedNode('btn_a'));
      expect(registry.hoveredName, 'btn_a');
      expect(registry.hoveredLabel, 'Botón A');

      expect(registry.handleSelect(namedNode('btn_a')), isTrue);
      expect(pressed, 1);

      // Unknown node: not consumed.
      expect(registry.handleSelect(namedNode('floor_0_0')), isFalse);

      registry.handleHover(null);
      expect(registry.hoveredName, isNull);
      expect(registry.hoveredLabel, isNull);
    });

    test('disabled controls ignore selection', () {
      final registry = VrControlRegistry();
      var pressed = 0;
      final button = VrButton3D(
        name: 'btn_b',
        label: 'Botón B',
        center: center,
        meshBuilder: fakeMesh,
        onPressed: () => pressed++,
      );
      registry.register(button);

      button.enabled = false;
      expect(registry.handleSelect(namedNode('btn_b')), isFalse);
      expect(pressed, 0);
    });

    test('unregister removes only the matching control and clears hover', () {
      final registry = VrControlRegistry();
      final original = VrButton3D(
        name: 'shared',
        label: 'Original',
        center: center,
        meshBuilder: fakeMesh,
      );
      final replacement = VrButton3D(
        name: 'shared',
        label: 'Replacement',
        center: center,
        meshBuilder: fakeMesh,
      );

      registry.register(original);
      registry.register(replacement);
      registry.unregister(original);
      registry.handleHover(namedNode('shared'));
      expect(registry.hoveredLabel, 'Replacement');

      registry.unregister(replacement);
      expect(registry.hoveredName, isNull);
      expect(registry.handleSelect(namedNode('shared')), isFalse);
    });

    test(
      'cached update list deduplicates multi-node controls and stays current',
      () {
        final registry = VrControlRegistry();
        final original = CountingControl('shared', ['a', 'b']);
        final replacement = CountingControl('replacement', ['b']);
        final view = registry.controls;
        registry.register(original);
        registry.register(original);
        registry.register(replacement);

        expect(registry.controls, same(view));
        expect(view, [original, replacement]);
        for (var frame = 0; frame < 120; frame++) {
          registry.update(1 / 120);
        }
        expect(original.updates, 120);
        expect(replacement.updates, 120);

        registry.unregister(original);
        expect(view, [replacement]);
        registry.update(1 / 60);
        expect(original.updates, 120);
        expect(replacement.updates, 121);
        registry.clear();
        expect(view, isEmpty);
        registry.update(1 / 60);
        expect(replacement.updates, 121);
      },
    );

    test('clearing/replacing hovered controls resets their visual state', () {
      final registry = VrControlRegistry();
      final original = CountingControl('original', ['a']);
      final replacement = CountingControl('replacement', ['a']);
      registry.register(original);
      registry.handleHover(namedNode('a'));
      expect(original.hovered, isTrue);
      registry.register(replacement);
      expect(original.hovered, isFalse);
      registry.handleHover(namedNode('a'));
      expect(replacement.hovered, isTrue);
      registry.clear();
      expect(replacement.hovered, isFalse);
      expect(registry.hoveredName, isNull);
    });
  });

  group('VrButton3D', () {
    test('hover brightens emissive and flash decays on update', () {
      final button = VrButton3D(
        name: 'b',
        label: 'B',
        center: center,
        meshBuilder: fakeMesh,
      );
      final mat = button.debugMaterial;

      expect(mat.emissiveFactor.x, closeTo(0, 1e-9)); // idle until applied
      button.applyEmissive();
      final idle = mat.emissiveFactor.x;
      button.onHoverEnter('b');
      final hovered = mat.emissiveFactor.x;
      expect(hovered, greaterThan(idle));

      button.onSelect('b');
      final flashing = mat.emissiveFactor.x;
      expect(flashing, greaterThan(hovered));

      button.update(0.25); // flash decays at 4/s → gone after 0.25s
      expect(mat.emissiveFactor.x, closeTo(hovered, 1e-6));
    });
  });

  group('VrToggle3D', () {
    test('select toggles value, visibility and callback', () {
      bool? reported;
      final toggle = VrToggle3D(
        name: 't',
        label: 'T',
        center: center,
        meshBuilder: fakeMesh,
        onChanged: (v) => reported = v,
      );
      expect(toggle.value, isFalse);
      expect(toggle.nodes[1].visible, isFalse); // check sphere hidden

      toggle.onSelect('t');
      expect(toggle.value, isTrue);
      expect(toggle.nodes[1].visible, isTrue);
      expect(reported, isTrue);

      toggle.onSelect('t');
      expect(toggle.value, isFalse);
      expect(toggle.nodes[1].visible, isFalse);
    });

    test('setValue syncs value and check visibility without onChanged', () {
      var fired = false;
      final toggle = VrToggle3D(
        name: 't',
        label: 'T',
        center: center,
        meshBuilder: fakeMesh,
        onChanged: (_) => fired = true,
      );
      toggle.setValue(true);
      expect(toggle.value, isTrue);
      expect(toggle.nodes[1].visible, isTrue);
      expect(fired, isFalse);
      toggle.setValue(false);
      expect(toggle.value, isFalse);
      expect(toggle.nodes[1].visible, isFalse);
    });
  });

  group('VrDropdown3D', () {
    test('header opens options, option selects and closes', () {
      int? pickedIndex;
      String? pickedOption;
      final dropdown = VrDropdown3D(
        name: 'dd',
        label: 'Bioma',
        center: center,
        meshBuilder: fakeMesh,
        options: const ['Bosque', 'Desierto', 'Tundra'],
        onChanged: (i, o) {
          pickedIndex = i;
          pickedOption = o;
        },
      );

      // Closed: options hidden.
      expect(dropdown.isOpen, isFalse);
      for (final n in dropdown.nodes.skip(1)) {
        expect(n.visible, isFalse);
      }

      // Header opens.
      dropdown.onSelect('dd');
      expect(dropdown.isOpen, isTrue);
      for (final n in dropdown.nodes.skip(1)) {
        expect(n.visible, isTrue);
      }

      // Hover option 2 → HUD label shows it.
      dropdown.onHoverEnter('dd_opt_2');
      expect(dropdown.label, contains('Tundra'));

      // Select option 2.
      dropdown.onSelect('dd_opt_2');
      expect(dropdown.selectedIndex, 2);
      expect(dropdown.selectedOption, 'Tundra');
      expect(dropdown.isOpen, isFalse);
      expect(pickedIndex, 2);
      expect(pickedOption, 'Tundra');
      expect(dropdown.label, contains('Tundra'));
      for (final n in dropdown.nodes.skip(1)) {
        expect(n.visible, isFalse);
      }
    });

    test('registry integration: full open-pick flow by node names', () {
      final registry = VrControlRegistry();
      String? picked;
      registry.register(
        VrDropdown3D(
          name: 'travel',
          label: 'Viajar',
          center: center,
          meshBuilder: fakeMesh,
          options: const ['A', 'B'],
          onChanged: (_, o) => picked = o,
        ),
      );

      registry.handleSelect(namedNode('travel')); // open
      registry.handleHover(namedNode('travel_opt_1'));
      expect(registry.hoveredLabel, contains('B'));
      registry.handleSelect(namedNode('travel_opt_1'));
      expect(picked, 'B');
    });
  });
}

class CountingControl extends VrControl {
  CountingControl(String name, this.nodeNames) : super(name: name, label: name);

  @override
  final List<String> nodeNames;
  int updates = 0;
  bool hovered = false;

  @override
  List<Node> get nodes => const [];
  @override
  void update(double dt) => updates++;
  @override
  void onHoverEnter(String nodeName) => hovered = true;
  @override
  void onHoverExit(String nodeName) => hovered = false;
  @override
  void onSelect(String nodeName) {}
  @override
  void applyEmissive() {}
}
