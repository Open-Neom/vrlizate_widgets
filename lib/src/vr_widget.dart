/// Framework layer of vrlizate_widgets: Flutter-style widget semantics for
/// native 3D scene-graph controls.
///
/// - [VrSpatial] gives every 3D widget **live resize** (`scaleTo`) and
///   **movement** (`moveTo`) without rebuilding — node transforms are
///   recomputed from stored offsets around the widget origin.
/// - [VrStatelessWidget]: appearance derives only from constructor config.
/// - [VrStatefulWidget] + [VrWidgetState]: mutable state; `setState`
///   recomputes the widget's materials/visibility and notifies the host
///   (HUD refresh) via [VrWidgetState.onChanged].
///
/// Widgets stay plain scene-graph objects (named nodes), so they work with
/// any gaze/raycast router — e.g. `VrControlRegistry` from this package —
/// and with any current or future render backend behind flutter_scene.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

// ─── Spatial behavior (resize + move) ─────────────────────────────

/// Live resize and move for 3D widgets, without rebuilding nodes.
///
/// Call [initSpatial] once after the widget's nodes exist (widget
/// constructors do this). Offsets are captured per node relative to
/// [origin] at scale 1.0; [scaleTo] and [moveTo] recompute transforms.
mixin VrSpatial {
  /// World anchor of the widget (nodes are placed relative to it).
  vm.Vector3 origin = vm.Vector3.zero();

  /// Current scale (1.0 = design size). Big/small at runtime.
  double scale = 1.0;

  final Map<Node, vm.Vector3> _baseOffsets = {};

  /// Nodes managed by this mixin (provided by the widget).
  List<Node> get spatialNodes;

  /// Captures current node positions as offsets from [origin].
  /// Called by the widget constructor after placing its nodes.
  void initSpatial(vm.Vector3 origin) {
    this.origin = origin.clone();
    _baseOffsets.clear();
    for (final n in spatialNodes) {
      _baseOffsets[n] = n.localTransform.getTranslation() - origin;
    }
  }

  /// Moves the whole widget to [position] (its origin).
  void moveTo(vm.Vector3 position) {
    origin = position.clone();
    _applySpatial();
  }

  /// Translates the whole widget by [delta].
  void moveBy(vm.Vector3 delta) => moveTo(origin + delta);

  /// Resizes the whole widget (offsets scale out from the origin and
  /// geometry scales uniformly).
  void scaleTo(double s) {
    scale = s.clamp(0.25, 4.0);
    _applySpatial();
  }

  void _applySpatial() {
    for (final entry in _baseOffsets.entries) {
      final transform = vm.Matrix4.translation(origin + entry.value * scale)
        ..multiply(vm.Matrix4.diagonal3Values(scale, scale, scale));
      entry.key.localTransform = transform;
    }
  }
}

// ─── Widget base ──────────────────────────────────────────────────

/// Base contract of every vrlizate_widgets 3D widget.
abstract class VrWidget with VrSpatial {
  VrWidget({required this.name});

  /// Unique widget id (scene node names derive from it).
  final String name;

  /// Human label for HUD hover feedback (no 3D text in flutter_scene yet).
  String get label;

  /// All scene nodes of this widget.
  List<Node> get nodes;

  @override
  List<Node> get spatialNodes => nodes;
}

// ─── Stateless ────────────────────────────────────────────────────

/// The 3D counterpart of Flutter's `StatelessWidget`: appearance and
/// behavior derive only from constructor configuration; the widget builds
/// its nodes once and never rebuilds (mutations go through [VrSpatial]).
abstract class VrStatelessWidget extends VrWidget {
  VrStatelessWidget({required super.name});
}

// ─── Stateful ─────────────────────────────────────────────────────

/// The 3D counterpart of Flutter's `StatefulWidget`: immutable config +
/// a [VrWidgetState] object holding mutable state.
abstract class VrStatefulWidget extends VrWidget {
  VrStatefulWidget({required super.name});

  VrWidgetState createState();
}

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
