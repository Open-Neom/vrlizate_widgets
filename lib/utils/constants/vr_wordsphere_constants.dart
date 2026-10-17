/// Constants for 3D world-plane projection and Head + Joystick Wordsphere
/// text entry sessions in the VRlizate SDK.
abstract final class VrWordsphereConstants {
  static const double defaultBoardSizeMeters = 1.65;
  static const double defaultBoardDistanceMeters = 1.8;
  static const double defaultBaseSizeTexels = 512.0;
  static const double maxHitRadiusNormalized = 0.48;
  static const double maxCursorRadiusNormalized = 0.465;
  static const double defaultStickSpeed = 230.0;
  static const double defaultStickDeadzone = 0.08;
  static const double defaultCursorLiftMeters = 0.012;
  static const double defaultCursorRadiusMeters = 0.009;
  static const double rayParallelEpsilon = -1e-7;

  static const String boardNodeName = 'wordsphere_world_keyboard';
  static const String cursorNodeName = 'wordsphere_world_cursor';

  static const String hudAimHint =
      'Stick derecho: apuntar · X: comenzar';
  static const String hudTraceHint =
      'Stick derecho: trazar · X: confirmar · B: cancelar';
}
