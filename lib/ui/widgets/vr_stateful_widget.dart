import 'vr_widget_base.dart';
import 'vr_widget_state.dart';

/// The 3D counterpart of Flutter's `StatefulWidget`: immutable config +
/// a [VrWidgetState] object holding mutable state.
abstract class VrStatefulWidget extends VrWidget {
  VrStatefulWidget({required super.name});

  VrWidgetState createState();
}
