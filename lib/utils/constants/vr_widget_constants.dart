import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Centralized constants for `vrlizate_widgets`: node suffixes, default labels,
/// spatial dimensions, material factors, and animation parameters.
class VrWidgetConstants {
  const VrWidgetConstants._();

  // ─── Node suffixes & prefixes ───────────────────────────────────
  static const String panelMovePrefix = 'mv_';
  static const String dropdownOptionSegment = '_opt_';
  static const String sliderSegment = '_seg_';
  static const String segmentedControlSegment = '_segment_';
  static const String stepperDecrementSuffix = '_decrement';
  static const String stepperIncrementSuffix = '_increment';
  static const String worldPanelRootSuffix = '_world_panel_root';
  static const String worldPanelPlateSuffix = '_world_panel_plate';
  static const String worldPanelTitleSuffix = '_title';
  static const String worldPanelSubtitleSuffix = '_subtitle';
  static const String worldPanelDescriptionSuffix = '_description';
  static const String worldPanelActionSegment = '_action_';

  static const String cardBevelSuffix = '_bevel';
  static const String cardAccentSuffix = '_accent';
  static const String switchThumbSuffix = '_thumb';
  static const String chipIndicatorSuffix = '_indicator';
  static const String iconEmblemSuffix = '_emblem';
  static const String dialogHeaderSuffix = '_header';
  static const String dialogConfirmSuffix = '_confirm';
  static const String dialogCancelSuffix = '_cancel';
  static const String listTileLeadingSuffix = '_leading';
  static const String listTileTrailingSuffix = '_trailing';

  // ─── Default labels & HUD strings ───────────────────────────────
  static const String dropdownOpenSuffix = '(abierto)';
  static const String panelGrabbedSuffix = '(muévelo con la mirada)';
  static const String stepperMinusSymbol = '−';
  static const String stepperPlusSymbol = '+';
  static const String stepperEqualsSymbol = '=';
  static const String stateOnLabel = 'ON';
  static const String stateOffLabel = 'OFF';
  static const String chipSelectedSuffix = '(seleccionado)';
  static const String dialogDefaultConfirmLabel = 'Confirmar';
  static const String dialogDefaultCancelLabel = 'Cancelar';
  static const String textEllipsis = '…';

  // ─── Spatial & placement defaults ───────────────────────────────
  static const double defaultScale = 1.0;
  static const double minScale = 0.25;
  static const double maxScale = 4.0;
  static const double defaultFollowDistance = 1.8;
  static const double defaultFollowSmoothing = 8.0;
  static const double defaultFloatAmplitude = 0.035;
  static const double defaultFloatFrequencyHz = 0.65;
  static const double defaultGrabDistance = 2.5;
  static const double minDragDistance = 0.8;
  static const double maxDragDistance = 8.0;
  static const double defaultDragDistance = 2.0;
  static const double directionEpsilon = 1e-10;

  // ─── Flash & material defaults ──────────────────────────────────
  static const double flashDecayPerSecond = 4.0;
  static const double defaultMetallicFactor = 0.3;
  static const double defaultRoughnessFactor = 0.4;

  // ─── Button defaults ────────────────────────────────────────────
  static const double buttonDefaultWidth = 0.34;
  static const double buttonDefaultHeight = 0.14;
  static const double buttonDefaultDepth = 0.06;

  // ─── Toggle defaults ────────────────────────────────────────────
  static const double toggleDefaultSize = 0.16;
  static const double toggleDefaultDepth = 0.05;

  // ─── Dropdown defaults ──────────────────────────────────────────
  static const double dropdownDefaultWidth = 0.4;
  static const double dropdownDefaultOptionHeight = 0.12;

  // ─── Slider defaults ────────────────────────────────────────────
  static const int sliderDefaultDivisions = 5;
  static const double sliderDefaultInitialValue = 0.5;
  static const double sliderDefaultWidth = 0.42;

  // ─── Panel defaults ─────────────────────────────────────────────
  static const double panelDefaultWidth = 0.72;
  static const double panelDefaultSpacing = 0.22;

  // ─── Segmented / Progress / Stepper defaults ────────────────────
  static const double segmentedDefaultWidth = 0.72;
  static const double segmentedDefaultHeight = 0.14;
  static const int progressDefaultSegments = 10;
  static const double progressDefaultWidth = 0.66;
  static const double stepperDefaultMin = 0.0;
  static const double stepperDefaultMax = 10.0;
  static const double stepperDefaultStep = 1.0;
  static const double stepperDefaultWidth = 0.58;

  // ─── Card 3D defaults ───────────────────────────────────────────
  static const double cardDefaultWidth = 0.68;
  static const double cardDefaultHeight = 0.42;
  static const double cardDefaultDepth = 0.035;
  static const double cardBevelDepth = 0.02;
  static const double cardBevelPadding = 0.03;
  static const double cardAccentHeight = 0.055;
  static const double cardAccentDepth = 0.015;
  static const double cardDefaultElevation = 0.025;

  // ─── Switch 3D defaults ─────────────────────────────────────────
  static const double switchDefaultWidth = 0.28;
  static const double switchDefaultHeight = 0.13;
  static const double switchTrackDepth = 0.04;
  static const double switchThumbRadiusFactor = 0.42;
  static const double switchThumbTravelFactor = 0.26;
  static const double switchThumbZOffset = 0.032;

  // ─── Chip 3D defaults ───────────────────────────────────────────
  static const double chipDefaultWidth = 0.32;
  static const double chipDefaultHeight = 0.11;
  static const double chipDefaultDepth = 0.04;
  static const double chipIndicatorRadius = 0.022;
  static const double chipIndicatorZOffset = 0.026;

  // ─── IconButton 3D defaults ─────────────────────────────────────
  static const double iconButtonDefaultSize = 0.16;
  static const double iconButtonDepth = 0.06;
  static const double iconButtonEmblemFactor = 0.38;
  static const double iconButtonEmblemZOffset = 0.042;

  // ─── Dialog 3D defaults ─────────────────────────────────────────
  static const double dialogDefaultWidth = 0.92;
  static const double dialogDefaultHeight = 0.56;
  static const double dialogBackdropDepth = 0.035;
  static const double dialogHeaderHeight = 0.09;
  static const double dialogButtonWidth = 0.34;
  static const double dialogButtonHeight = 0.12;
  static const double dialogButtonDepth = 0.05;
  static const double dialogButtonZOffset = 0.035;

  // ─── ListTile 3D defaults ───────────────────────────────────────
  static const double listTileDefaultWidth = 0.76;
  static const double listTileDefaultHeight = 0.15;
  static const double listTilePlateDepth = 0.035;
  static const double listTileLeadingSize = 0.075;
  static const double listTileTrailingSize = 0.085;
  static const double listTileAccessoryZOffset = 0.028;

  // ─── Layout 3D defaults ─────────────────────────────────────────
  static const double rowDefaultSpacing = 0.42;
  static const double columnDefaultSpacing = 0.22;
  static const int gridDefaultColumns = 2;
  static const double gridDefaultColumnSpacing = 0.44;
  static const double gridDefaultRowSpacing = 0.24;

  // ─── Surface & Text defaults ────────────────────────────────────
  static const double surfaceDefaultAvailableWidth = 1.5;
  static const double surfaceDefaultMaxHeight = 0.9;
  static const double surfaceMaxPixelRatio = 1.5;
  static const double surfaceMaxTextureDimension = 1536.0;
  static const int surfaceUpdateIntervalMs = 250;

  static const double textDefaultFontSize = 72.0;
  static const double textLabelDefaultFontSize = 96.0;
  static const double textLabelDefaultHeight = 0.08;
  static const double textDefaultMaxWidthPx = 1024.0;
  static const int textDefaultMaxLines = 2;
  static const int textDefaultPaddingPx = 10;
  static const Color textDefaultColor = Color(0xFFFFFFFF);

  // ─── Default PBR Color factories (Vector4 clones) ───────────────
  static vm.Vector4 get defaultButtonColor =>
      vm.Vector4(0.15, 0.50, 0.65, 1.0);
  static vm.Vector4 get defaultCardColor =>
      vm.Vector4(0.09, 0.11, 0.17, 1.0);
  static vm.Vector4 get defaultCardBevelColor =>
      vm.Vector4(0.04, 0.05, 0.08, 1.0);
  static vm.Vector4 get defaultCardAccentColor =>
      vm.Vector4(0.18, 0.72, 0.92, 1.0);
  static vm.Vector4 get defaultSwitchActiveColor =>
      vm.Vector4(0.16, 0.85, 0.56, 1.0);
  static vm.Vector4 get defaultSwitchInactiveColor =>
      vm.Vector4(0.24, 0.27, 0.35, 1.0);
  static vm.Vector4 get defaultSwitchThumbColor =>
      vm.Vector4(0.92, 0.96, 1.0, 1.0);
  static vm.Vector4 get defaultChipSelectedColor =>
      vm.Vector4(0.20, 0.68, 0.90, 1.0);
  static vm.Vector4 get defaultChipUnselectedColor =>
      vm.Vector4(0.14, 0.18, 0.26, 1.0);
  static vm.Vector4 get defaultIconButtonColor =>
      vm.Vector4(0.22, 0.52, 0.88, 1.0);
  static vm.Vector4 get defaultIconEmblemColor =>
      vm.Vector4(0.92, 0.96, 1.0, 1.0);
  static vm.Vector4 get defaultDialogBackdropColor =>
      vm.Vector4(0.06, 0.08, 0.13, 1.0);
  static vm.Vector4 get defaultDialogHeaderColor =>
      vm.Vector4(0.16, 0.22, 0.36, 1.0);
  static vm.Vector4 get defaultDialogConfirmColor =>
      vm.Vector4(0.16, 0.78, 0.52, 1.0);
  static vm.Vector4 get defaultDialogCancelColor =>
      vm.Vector4(0.72, 0.24, 0.30, 1.0);
  static vm.Vector4 get defaultListTileColor =>
      vm.Vector4(0.10, 0.13, 0.20, 1.0);
  static vm.Vector4 get defaultListTileLeadingColor =>
      vm.Vector4(0.20, 0.74, 0.92, 1.0);
  static vm.Vector4 get defaultListTileTrailingColor =>
      vm.Vector4(0.32, 0.40, 0.58, 1.0);
}
