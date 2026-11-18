import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/domain/models/vr_wordsphere_plane.dart';
import 'package:vrlizate_widgets/domain/services/vr_wordsphere_session_controller.dart';

void main() {
  test('VrWordsphereSessionController survives non-finite stick deflection and non-finite dt without NaN cursor', () {
    final plane = VrWordspherePlane.inFrontOfViewer(
      eyeCenter: vm.Vector3(0, 1.6, 0),
      forward: vm.Vector3(0, 0, -1),
      screenRight: vm.Vector3(1, 0, 0),
      up: vm.Vector3(0, 1, 0),
    );
    final controller = VrWordsphereSessionController(plane: plane);
    final ray = vm.Ray.originDirection(
      vm.Vector3(0, 1.6, 0),
      vm.Vector3(0, 0, -1),
    );

    final cursor = controller.updateCursor(
      ray: ray,
      stickX: double.infinity,
      stickY: double.negativeInfinity,
      dt: double.nan,
    );
    expect(cursor, isNotNull);
    expect(cursor!.dx.isFinite, isTrue);
    expect(cursor.dy.isFinite, isTrue);

    final cursor2 = controller.updateCursor(
      ray: ray,
      stickX: double.infinity,
      stickY: double.infinity,
      dt: 0.05,
    );
    expect(cursor2, isNotNull);
    expect(cursor2!.dx.isFinite, isTrue);
    expect(cursor2.dy.isFinite, isTrue);
  });
}
