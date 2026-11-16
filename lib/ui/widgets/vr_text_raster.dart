import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../domain/models/vr_text_bitmap.dart';
import '../../utils/constants/vr_widget_constants.dart';

/// Rasterizes text with Flutter's 2D text stack — no GPU involved, so this
/// is fully testable headless.
class VrTextRaster {
  /// Renders [text] into a tightly sized bitmap.
  ///
  /// [fontSize] is the raster size in pixels: it controls crispness, not
  /// world size (the label quad scales to the world height you choose).
  static Future<VrTextBitmap> rasterize(
    String text, {
    double fontSize = VrWidgetConstants.textDefaultFontSize,
    Color color = VrWidgetConstants.textDefaultColor,
    FontWeight fontWeight = FontWeight.w600,
    double maxWidthPx = VrWidgetConstants.textDefaultMaxWidthPx,
    int maxLines = VrWidgetConstants.textDefaultMaxLines,
    int paddingPx = VrWidgetConstants.textDefaultPaddingPx,
  }) async {
    final painter = TextPainter(
      text: TextSpan(
        text: text.isEmpty ? ' ' : text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: VrWidgetConstants.textEllipsis,
    )..layout(maxWidth: maxWidthPx);

    final w = (painter.width + paddingPx * 2).ceil().clamp(2, 4096);
    final h = (painter.height + paddingPx * 2).ceil().clamp(2, 4096);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    painter.paint(canvas, Offset(paddingPx.toDouble(), paddingPx.toDouble()));
    final picture = recorder.endRecording();

    final image = await picture.toImage(w, h);
    try {
      final bytes = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (bytes == null) {
        throw StateError('VrTextRaster: could not read RGBA pixels');
      }
      final raw = Uint8List.fromList(bytes.buffer.asUint8List());
      // Bleed ink RGB into zero-alpha texels so GPU bilinear + mipmap filtering
      // with AlphaMode.blend never interpolates toward black (0, 0, 0) halos.
      final rBleed = (color.r * 255).round().clamp(0, 255);
      final gBleed = (color.g * 255).round().clamp(0, 255);
      final bBleed = (color.b * 255).round().clamp(0, 255);
      for (var i = 0; i < raw.length; i += 4) {
        if (raw[i + 3] == 0) {
          raw[i] = rBleed;
          raw[i + 1] = gBleed;
          raw[i + 2] = bBleed;
        }
      }
      return VrTextBitmap(raw, w, h);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
