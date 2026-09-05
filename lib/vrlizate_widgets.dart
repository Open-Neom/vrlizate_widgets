/// vrlizate_widgets — reusable gaze-interactive 3D widgets for Flutter GPU.
///
/// The VR counterpart of basic Flutter widgets: buttons, toggles, dropdowns
/// and movable panels implemented as native flutter_scene scene-graph nodes
/// (stereo + gaze via vrlizate_scene's StereoSceneView raycast), with
/// Flutter-style semantics:
///
/// - **Stateless / stateful**: [VrStatelessWidget] builds from config;
///   [VrStatefulWidget] holds a [VrWidgetState] whose `setState` mutates
///   materials/visibility and notifies the host HUD.
/// - **Live resize**: [VrSpatial.scaleTo] makes any widget big or small
///   without rebuilding nodes.
/// - **Movable**: [VrPanel3D] grabs with a gaze-dwell on its handle bar and
///   follows the gaze until dropped.
/// - **Drag-and-drop**: [VrDragController] drags any node with the gaze
///   (grab → follows the gaze ray → drop), host decides snap/delete rules.
/// - **Sliders**: [VrSlider3D] is a segmented slider (gaze reports node
///   names, not hit points): dwell a pad and the thumb glides there.
/// - **Advanced controls**: [VrSegmentedControl3D], [VrProgressBar3D] and
///   [VrStepper3D] cover tabs/filters, progress and bounded numeric input.
/// - **3D text**: [VrTextLabel] renders text to a texture
///   (canvas-to-texture sprite) — unlit, alpha-blended, optional billboard.
/// - **World-locked actions**: [VrWorldActionPanel3D] presents information and
///   buttons at a stable spatial pose, with gaze, laser and joystick routing.
///
/// Requires Flutter master channel (Flutter GPU) and
/// `flutter config --enable-dart-data-assets`.
library;

export 'src/vr_controls.dart';
export 'src/vr_advanced_controls.dart';
export 'src/vr_widget.dart';
export 'src/vr_panel.dart';
export 'src/vr_drag.dart';
export 'src/vr_slider.dart';
export 'src/vr_text.dart';
export 'src/vr_world_action_panel.dart';
