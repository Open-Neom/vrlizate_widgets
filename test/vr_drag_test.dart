import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  final eye = vm.Vector3(0, 1.6, 0);
  final forward = vm.Vector3(0, 0, -1);

  group('VrDragController', () {
    test('idle: update and end return null', () {
      final drag = VrDragController();
      expect(drag.isDragging, isFalse);
      expect(drag.update(eye, forward), isNull);
      expect(drag.end(eye, forward), isNull);
    });

    test(
      'begin captures the distance on first update and follows the gaze',
      () {
        final drag = VrDragController();
        final start = vm.Vector3(0, 1.6, -3); // 3 m ahead of the eye
        drag.begin('card_1', start);
        expect(drag.isDragging, isTrue);
        expect(drag.grabbedName, 'card_1');

        final pos = drag.update(eye, forward)!;
        expect((pos - eye).length, closeTo(3.0, 1e-6));

        // Look right: the node follows the new direction at the same distance.
        final right = vm.Vector3(1, 0, 0);
        final pos2 = drag.update(eye, right)!;
        expect(pos2.x, closeTo(3.0, 1e-6));
        expect((pos2 - eye).length, closeTo(3.0, 1e-6));
      },
    );

    test('distance is clamped to min/max', () {
      final drag = VrDragController()
        ..minDistance = 0.8
        ..maxDistance = 8.0;
      drag.begin('near', vm.Vector3(0, 1.6, -0.2)); // 0.2 m away
      final pos = drag.update(eye, forward)!;
      expect((pos - eye).length, closeTo(0.8, 1e-6));
      drag.cancel();

      drag.begin('far', vm.Vector3(0, 1.6, -30)); // 30 m away
      final pos2 = drag.update(eye, forward)!;
      expect((pos2 - eye).length, closeTo(8.0, 1e-6));
    });

    test('end returns the final drop position and clears the drag', () {
      final drag = VrDragController();
      drag.begin('card_1', vm.Vector3(1, 1.6, -2));
      drag.update(eye, forward);
      final drop = drag.end(eye, forward)!;
      expect(drop, isNotNull);
      expect(drag.isDragging, isFalse);
      expect(drag.update(eye, forward), isNull);
    });

    test('cancel clears without reporting a drop', () {
      final drag = VrDragController();
      drag.begin('card_1', vm.Vector3(0, 1.6, -2));
      drag.update(eye, forward);
      drag.cancel();
      expect(drag.isDragging, isFalse);
      expect(drag.end(eye, forward), isNull);
    });

    test('requireButtonB blocks drag unless Button B is held for holdDurationSeconds', () {
      final drag = VrDragController();
      final candidatePos = vm.Vector3(0, 1.6, -2.2);

      // Without Button B: does not start even after gazing for 2 seconds.
      expect(
        drag.updateDragCandidate(
          hoveredName: 'card_1',
          candidatePosition: candidatePos,
          buttonBHeld: false,
          dt: 2.0,
        ),
        isFalse,
      );
      expect(drag.isDragging, isFalse);
      expect(drag.holdProgress, 0.0);

      // With Button B held briefly (< 0.85s): builds progress but does not start yet.
      expect(
        drag.updateDragCandidate(
          hoveredName: 'card_1',
          candidatePosition: candidatePos,
          buttonBHeld: true,
          dt: 0.4,
        ),
        isFalse,
      );
      expect(drag.isDragging, isFalse);
      expect(drag.holdProgress, greaterThan(0.0));
      expect(drag.holdProgress, lessThan(1.0));

      // Continuing to hold Button B past 0.85s starts the drag.
      expect(
        drag.updateDragCandidate(
          hoveredName: 'card_1',
          candidatePosition: candidatePos,
          buttonBHeld: true,
          dt: 0.5,
        ),
        isTrue,
      );
      expect(drag.isDragging, isTrue);
      expect(drag.grabbedName, 'card_1');

      // Releasing Button B automatically releases the drag.
      expect(
        drag.updateDragCandidate(
          hoveredName: 'card_1',
          candidatePosition: candidatePos,
          buttonBHeld: false,
          dt: 0.016,
        ),
        isFalse,
      );
      expect(drag.isDragging, isFalse);
    });
  });
}
