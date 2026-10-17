import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';

import '../../utils/constants/vr_widget_constants.dart';

/// A Flutter presentation projected into the world at its original aspect ratio.
///
/// One capture is shared by both eyes. Input stays with the surrounding spatial
/// controls, so embedded 2D buttons cannot open routes behind the viewer.
class VrWidgetSurface3D {
  factory VrWidgetSurface3D({
    required String name,
    required Widget child,
    required Size logicalSize,
    double availableWidth = VrWidgetConstants.surfaceDefaultAvailableWidth,
    double maxHeight = VrWidgetConstants.surfaceDefaultMaxHeight,
  }) {
    if (!logicalSize.width.isFinite ||
        !logicalSize.height.isFinite ||
        logicalSize.width <= 0 ||
        logicalSize.height <= 0 ||
        !availableWidth.isFinite ||
        availableWidth <= 0 ||
        !maxHeight.isFinite ||
        maxHeight <= 0) {
      throw ArgumentError('Surface dimensions must be finite and positive.');
    }
    final aspect = logicalSize.aspectRatio;
    final width = math.min(availableWidth, maxHeight * aspect);
    final height = width / aspect;
    final ratio = math.min(
      VrWidgetConstants.surfaceMaxPixelRatio,
      VrWidgetConstants.surfaceMaxTextureDimension /
          math.max(logicalSize.width, logicalSize.height),
    );
    final component = WidgetComponent(
      child: MediaQuery(
        data: MediaQueryData(
          size: logicalSize,
          devicePixelRatio: ratio,
          textScaler: TextScaler.noScaling,
        ),
        child: ExcludeFocus(child: IgnorePointer(child: child)),
      ),
      size: logicalSize,
      pixelRatio: ratio,
      worldHeight: height,
      update: const WidgetUpdatePolicy.interval(
        Duration(milliseconds: VrWidgetConstants.surfaceUpdateIntervalMs),
      ),
      input: WidgetInput.manual,
      occlusionHiding: true,
    );
    return VrWidgetSurface3D._(
      Node(name: name)
        ..raycastable = false
        ..addComponent(component),
      component,
      width,
      height,
    );
  }

  VrWidgetSurface3D._(
    this.node,
    this.component,
    this.worldWidth,
    this.worldHeight,
  );

  final Node node;
  final WidgetComponent component;
  final double worldWidth;
  final double worldHeight;
}
