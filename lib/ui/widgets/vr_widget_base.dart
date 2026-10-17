import 'package:flutter_scene/scene.dart';

import 'vr_spatial.dart';

/// Base contract of every `vrlizate_widgets` 3D widget.
abstract class VrWidget with VrSpatial {
  VrWidget({required this.name});

  /// Unique widget id (scene node names derive from it).
  final String name;

  /// Human label for HUD hover feedback.
  String get label;

  /// All scene nodes of this widget.
  List<Node> get nodes;

  @override
  List<Node> get spatialNodes => nodes;
}
