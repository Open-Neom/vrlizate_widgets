import 'dart:math';
import 'dart:typed_data';

/// A rasterized text bitmap (straight-alpha RGBA, row-major).
class VrTextBitmap {
  const VrTextBitmap(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;

  /// width / height (≥ tiny epsilon; never zero).
  double get aspect => width / max(height, 1);

  /// Whether any pixel is visible (alpha > 0).
  bool get hasInk => pixels.any((p) => p != 0);
}
