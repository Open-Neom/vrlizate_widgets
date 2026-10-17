import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

typedef VrWorldTextNodeBuilder = Future<Node> Function(VrWorldTextSpec spec);

/// Description passed to a custom [VrWorldTextNodeBuilder].
///
/// The default builder creates a `VrTextLabel`. A custom builder is useful for
/// another text backend and for headless tests where Flutter GPU is absent.
class VrWorldTextSpec {
  VrWorldTextSpec({
    required this.text,
    required vm.Vector3 localCenter,
    required this.height,
    required this.fontSize,
    required this.color,
    required this.fontWeight,
    required this.maxWidthPx,
    required this.maxLines,
    required this.nodeName,
    required this.interactive,
  }) : _localCenter = localCenter.clone();

  final String text;
  final vm.Vector3 _localCenter;
  final double height;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double maxWidthPx;
  final int maxLines;
  final String nodeName;
  final bool interactive;

  vm.Vector3 get localCenter => _localCenter.clone();
}
