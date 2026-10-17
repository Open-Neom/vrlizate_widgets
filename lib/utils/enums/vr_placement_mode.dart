/// Defines how a 3D widget or layout container is anchored and updated in space.
enum VrPlacementMode {
  /// Fixed position and rotation in 3D world space.
  staticWorld,

  /// Fixed world position; automatically rotates yaw towards the viewer camera.
  dynamicBillboard,

  /// Smoothly follows the viewer camera position + forward vector at a
  /// configurable distance and offset.
  headLockedHud,

  /// Continuous subtle 3D levitation/bobbing in space around its anchor
  /// while remaining draggable to new anchors.
  dynamicFloating,
}
