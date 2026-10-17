import 'package:flutter/painting.dart';

/// One button in a `VrWorldActionPanel3D`.
class VrWorldAction {
  const VrWorldAction({
    required this.id,
    required this.label,
    required this.onPressed,
    this.color,
    this.enabled = true,
  });

  final String id;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final bool enabled;
}
