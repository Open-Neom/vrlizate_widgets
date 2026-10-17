import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../../domain/models/vr_text_bitmap.dart';
import '../../utils/constants/vr_widget_constants.dart';
import 'vr_text_raster.dart';

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

  /// The scene node (add it to your scene). Unnamed unless `name` was given
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
    double height = VrWidgetConstants.textLabelDefaultHeight,
    double fontSize = VrWidgetConstants.textLabelDefaultFontSize,
    Color color = VrWidgetConstants.textDefaultColor,
    FontWeight fontWeight = FontWeight.w600,
    double maxWidthPx = VrWidgetConstants.textDefaultMaxWidthPx,
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
    double height = VrWidgetConstants.textLabelDefaultHeight,
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
    final node = Node(
      name: name ?? '',
      mesh: Mesh(PlaneGeometry(width: worldWidth, depth: height), material),
    );
    node.localTransform = vm.Matrix4.translation(center)
      ..multiply(vm.Matrix4.rotationX(pi / 2))
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
