import 'vr_widget_base.dart';

/// The 3D counterpart of Flutter's `StatelessWidget`: appearance and
/// behavior derive only from constructor configuration; the widget builds
/// its nodes once and never rebuilds (mutations go through `VrSpatial`).
abstract class VrStatelessWidget extends VrWidget {
  VrStatelessWidget({required super.name});
}
