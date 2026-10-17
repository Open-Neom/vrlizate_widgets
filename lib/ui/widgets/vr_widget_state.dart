import 'package:flutter/foundation.dart';

import 'vr_stateful_widget.dart';

/// Mutable state of a [VrStatefulWidget].
///
/// `setState` runs the mutation and then notifies the host via [onChanged]
/// (HUDs repaint; scene nodes update synchronously inside the mutation —
/// 3D widgets mutate materials/visibility directly, no rebuild pass).
abstract class VrWidgetState {
  VrStatefulWidget? _widget;
  VrStatefulWidget get widget => _widget!;

  /// Called after every [setState] — hosts refresh their HUD here.
  VoidCallback? onChanged;

  @mustCallSuper
  void mount(covariant VrStatefulWidget widget) {
    _widget = widget;
  }

  void setState(VoidCallback fn) {
    fn();
    onChanged?.call();
  }
}
