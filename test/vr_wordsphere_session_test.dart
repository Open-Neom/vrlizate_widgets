import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/vrlizate_widgets.dart';

void main() {
  test('VrWordspherePlane projects and intersects rays accurately', () {
    final eye = vm.Vector3(0, 1.6, 0);
    final forward = vm.Vector3(0, 0, -1);
    final right = vm.Vector3(1, 0, 0);
    final up = vm.Vector3(0, 1, 0);

    final plane = VrWordspherePlane.inFrontOfViewer(
      eyeCenter: eye,
      forward: forward,
      screenRight: right,
      up: up,
    );

    const target = Offset(320, 210);
    final worldPt = plane.worldPoint(target);
    final ray = vm.Ray.originDirection(eye, (worldPt - eye).normalized());
    final hit = plane.intersect(ray)!;

    expect(hit.dx, closeTo(target.dx, 1e-3));
    expect(hit.dy, closeTo(target.dy, 1e-3));
  });

  test('VrWordsphereSessionController combines Head Gaze and Joystick', () {
    final eye = vm.Vector3(0, 1.6, 0);
    final plane = VrWordspherePlane.inFrontOfViewer(
      eyeCenter: eye,
      forward: vm.Vector3(0, 0, -1),
      screenRight: vm.Vector3(1, 0, 0),
      up: vm.Vector3(0, 1, 0),
    );
    final session = VrWordsphereSessionController(plane: plane);

    final centerRay = vm.Ray.originDirection(eye, vm.Vector3(0, 0, -1));
    final gazePos = session.updateCursor(ray: centerRay, dt: 0.016)!;
    expect(gazePos.dx, closeTo(256, 1e-3));
    expect(gazePos.dy, closeTo(256, 1e-3));

    final stickPos = session.updateCursor(
      ray: centerRay,
      stickX: 0.8,
      stickY: 0.4,
      dt: 0.05,
    )!;
    expect(session.stickAim, isTrue);
    expect(stickPos.dx, greaterThan(256));
    expect(stickPos.dy, lessThan(256));

    expect(session.toggleTracing(), isTrue);
    var deleted = 0;
    expect(session.handleCancelOrDelete(onDeleteWord: () => deleted++), isTrue);
    expect(session.isTracing, isFalse);
    expect(deleted, 0);

    expect(
      session.handleCancelOrDelete(onDeleteWord: () => deleted++),
      isFalse,
    );
    expect(deleted, 1);

    // Non-finite stick inputs must never poison stickPoint with NaN.
    final safePos = session.updateCursor(
      ray: centerRay,
      stickX: double.infinity,
      stickY: double.nan,
      dt: 0.05,
    )!;
    expect(safePos.dx.isFinite, isTrue);
    expect(safePos.dy.isFinite, isTrue);
  });
}
