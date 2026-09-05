/// 3D text via canvas-to-texture sprites.
///
/// flutter_scene has no text renderer (no SDF glyphs, no font pipeline), so
/// text is rasterized with Flutter's 2D stack ([TextPainter] → `ui.Image` →
/// RGBA pixels), uploaded as a [Texture2D] and shown on an [UnlitMaterial]
/// quad ([AlphaMode.blend]) — always readable, transparent background.
///
/// Split in two layers so the expensive part stays testable headless:
///
/// - [VrTextRaster] — pure rasterization (no GPU): safe in `flutter test`.
/// - [VrTextLabel] — the scene node (GPU upload): runtime only.
///
/// ```dart
/// final label = await VrTextLabel.create('POR HACER',
///     center: Vector3(-1.35, 2.7, -2.6), height: 0.12);
/// scene.add(label.node);
/// // Optional upright billboard per frame:
/// label.faceCamera(rig.eyeCenter);
/// ```
library;

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

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

/// Rasterizes text with Flutter's 2D text stack — no GPU involved, so this
/// is fully testable headless.
class VrTextRaster {
  /// Renders [text] into a tightly sized bitmap.
  ///
  /// [fontSize] is the raster size in pixels: it controls crispness, not
  /// world size (the label quad scales to the world height you choose).
  static Future<VrTextBitmap> rasterize(
    String text, {
    double fontSize = 72,
    Color color = const Color(0xFFFFFFFF),
    FontWeight fontWeight = FontWeight.w600,
    double maxWidthPx = 1024,
    int maxLines = 2,
    int paddingPx = 10,
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
      ellipsis: '…',
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
      return VrTextBitmap(bytes.buffer.asUint8List(), w, h);
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

/// A 3D text label: an unlit quad with the rasterized text as its texture.
///
/// Creation uploads to Flutter GPU — **runtime only** (headless tests should
/// cover [VrTextRaster]; the node step needs Impeller).
class VrTextLabel {
  VrTextLabel._({
    required this.node,
    required this.text,
    required this.worldWidth,
    required this.worldHeight,
  });

  /// The scene node (add it to your scene). Unnamed unless [name] was given
  /// — labels are decorative, not gaze-interactive, by default.
  final Node node;
  final String text;
  final double worldWidth;
  final double worldHeight;

  /// Creates a label of [text] centered at [center], [height] meters tall,
  /// initially facing +Z (use [faceCamera] for billboard behavior).
  static Future<VrTextLabel> create(
    String text, {
    required vm.Vector3 center,
    double height = 0.08,
    double fontSize = 96,
    Color color = const Color(0xFFFFFFFF),
    FontWeight fontWeight = FontWeight.w600,
    double maxWidthPx = 1024,
    int maxLines = 1,
    String? name,
  }) async {
    final bitmap = await VrTextRaster.rasterize(
      text,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      maxWidthPx: maxWidthPx,
      maxLines: maxLines,
    );
    return fromBitmap(bitmap, text, center: center, height: height, name: name);
  }

  /// Builds the label node from an already-rasterized [bitmap] (the GPU
  /// step — separated so hosts can share/rasterize in advance).
  static VrTextLabel fromBitmap(
    VrTextBitmap bitmap,
    String text, {
    required vm.Vector3 center,
    double height = 0.08,
    String? name,
  }) {
    final texture = Texture2D.fromPixels(
      bitmap.pixels,
      bitmap.width,
      bitmap.height,
    );
    final material = UnlitMaterial(colorTexture: texture)
      ..alphaMode = AlphaMode.blend
      ..vertexColorWeight = 0.0;
    final worldWidth = height * bitmap.aspect;
    // PlaneGeometry lies in XZ (normal +Y, v=0 at z=-depth/2). Rotating
    // +90° on X makes it vertical facing +Z with v=0 at the TOP — the text
    // reads upright and left-to-right for a viewer at +Z.
    final node = Node(
      name: name ?? '',
      mesh: Mesh(PlaneGeometry(width: worldWidth, depth: height), material),
    );
    node.localTransform = vm.Matrix4.translation(center)
      ..multiply(vm.Matrix4.rotationX(pi / 2))
      // Flutter's canvas texture and PlaneGeometry use opposite horizontal
      // conventions. Mirror the local X axis once so text reads normally in
      // world space; flutter_scene accounts for the flipped winding.
      ..scaleByVector3(vm.Vector3(-1, 1, 1));
    return VrTextLabel._(
      node: node,
      text: text,
      worldWidth: worldWidth,
      worldHeight: height,
    );
  }

  /// Upright billboard: yaws the label so it faces [eye] horizontally while
  /// keeping the text upright (no pitch — pitching text hurts readability).
  void faceCamera(vm.Vector3 eye) {
    final pos = node.localTransform.getTranslation();
    final d = eye - pos;
    final yaw = atan2(d.x, d.z);
    node.localTransform = vm.Matrix4.translation(pos)
      ..multiply(vm.Matrix4.rotationY(yaw))
      ..multiply(vm.Matrix4.rotationX(pi / 2))
      ..scaleByVector3(vm.Vector3(-1, 1, 1));
  }
}
