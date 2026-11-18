import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:vrlizate_widgets/domain/models/vr_spatial_pose.dart';
import 'package:vrlizate_widgets/utils/enums/vr_placement_mode.dart';

void main() {
  group('Lote 87 vrlizate_widgets Web-Safe Hardening', () {
    test(
      'VrSpatialPose sanitizes non-finite constructor fields, setBasePosition, and per-frame update across all modes',
      () {
        for (final mode in VrPlacementMode.values) {
          final pose = VrSpatialPose(
            placementMode: mode,
            position: vm.Vector3(double.nan, 1.5, -2.0),
            rotation: vm.Quaternion(double.infinity, 0, 0, 1),
            scale: double.nan,
            followDistance: double.infinity,
            followSmoothing: -5.0,
            floatAmplitude: double.nan,
            floatFrequencyHz: double.infinity,
          );
          expect(pose.position.x.isFinite, isTrue);
          expect(pose.position.y.isFinite, isTrue);
          expect(pose.position.z.isFinite, isTrue);
          expect(pose.rotation.storage.every((v) => v.isFinite), isTrue);
          expect(pose.scale.isFinite && pose.scale > 0, isTrue);

          pose.setBasePosition(vm.Vector3(1.0, double.infinity, -2.0));
          expect(pose.basePosition.y.isFinite, isTrue);

          pose.update(
            viewerPosition: vm.Vector3(double.nan, 1.6, 0),
            viewerForward: vm.Vector3(0, 0, double.negativeInfinity),
            elapsedSeconds: double.infinity,
            dt: double.nan,
          );
          expect(pose.position.x.isFinite, isTrue);
          expect(pose.position.y.isFinite, isTrue);
          expect(pose.position.z.isFinite, isTrue);
          expect(pose.rotation.storage.every((v) => v.isFinite), isTrue);

          // Valid update afterwards still works cleanly
          pose.update(
            viewerPosition: vm.Vector3(0, 1.6, 0),
            viewerForward: vm.Vector3(0, 0, -1),
            elapsedSeconds: 1000000.5,
            dt: 0.016,
          );
          expect(pose.position.x.isFinite, isTrue);
          expect(pose.position.y.isFinite, isTrue);
          expect(pose.position.z.isFinite, isTrue);
          expect(pose.rotation.storage.every((v) => v.isFinite), isTrue);
        }
      },
    );
  });
}
