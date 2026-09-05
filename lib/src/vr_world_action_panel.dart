import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'vr_controls.dart';
import 'vr_text.dart';

/// An immutable world-space basis for spatial UI.
///
/// Local +X is basis-right, local +Y is panel-up, and local +Z points out of
/// the panel toward its viewer. This is a right-handed geometric basis;
/// flutter_scene's left-handed camera projects +X toward screen-left for a
/// default viewer-facing pose. Panels compensate in their visual layout.
/// The vectors supplied to the factories are
/// copied and every public vector getter returns a copy, so callers cannot
/// move an already placed panel by mutating a [vm.Vector3].
class VrWorldPose {
  VrWorldPose._({
    required vm.Vector3 center,
    required vm.Vector3 right,
    required vm.Vector3 up,
    required vm.Vector3 towardViewer,
  }) : _center = center.clone(),
       _right = right.clone(),
       _up = up.clone(),
       _towardViewer = towardViewer.clone(),
       _transform = _basisTransform(center, right, up, towardViewer);

  /// Creates a pose from an explicit orthonormal basis.
  ///
  /// [right] is projected onto the plane perpendicular to [towardViewer], and
  /// [up] chooses the resulting basis' vertical sign. This defensive
  /// orthonormalization prevents sensor drift from shearing panel geometry.
  factory VrWorldPose.basis({
    required vm.Vector3 center,
    required vm.Vector3 right,
    required vm.Vector3 up,
    required vm.Vector3 towardViewer,
  }) {
    _requireFinite(center, 'center');
    _requireDirection(right, 'right');
    _requireDirection(up, 'up');
    _requireDirection(towardViewer, 'towardViewer');

    final front = towardViewer.normalized();
    var panelRight = right - front * right.dot(front);
    if (panelRight.length2 < _epsilon) {
      panelRight = up.cross(front);
    }
    if (panelRight.length2 < _epsilon) {
      panelRight = _fallbackUp(front).cross(front);
    }
    panelRight.normalize();

    var panelUp = front.cross(panelRight)..normalize();
    if (panelUp.dot(up) < 0) {
      panelRight = -panelRight;
      panelUp = -panelUp;
    }
    return VrWorldPose._(
      center: center,
      right: panelRight,
      up: panelUp,
      towardViewer: front,
    );
  }

  /// Places a panel [distance] metres along the viewer's gaze direction.
  ///
  /// Supplying the viewer's [right] and [up] preserves headset roll. When
  /// omitted, an upright world-space basis is derived instead.
  factory VrWorldPose.fromViewer({
    required vm.Vector3 eye,
    required vm.Vector3 forward,
    vm.Vector3? right,
    vm.Vector3? up,
    double distance = 1.8,
  }) {
    _requireFinite(eye, 'eye');
    _requireDirection(forward, 'forward');
    if (!distance.isFinite || distance <= 0) {
      throw ArgumentError.value(
        distance,
        'distance',
        'Must be finite and greater than zero.',
      );
    }

    final gaze = forward.normalized();
    final center = eye + gaze * distance;
    final front = -gaze;
    final preferredUp = up?.clone() ?? _fallbackUp(front);
    var preferredRight = right?.clone() ?? preferredUp.cross(front);
    if (preferredRight.length2 < _epsilon) {
      preferredRight = _fallbackUp(front).cross(front);
    }
    return VrWorldPose.basis(
      center: center,
      right: preferredRight,
      up: preferredUp,
      towardViewer: front,
    );
  }

  /// Creates an upright pose at [center] facing [eye].
  ///
  /// [worldUp] is projected onto the panel plane. A stable fallback is used
  /// when the viewer is directly above or below the panel.
  factory VrWorldPose.facingEye({
    required vm.Vector3 center,
    required vm.Vector3 eye,
    vm.Vector3? worldUp,
  }) {
    _requireFinite(center, 'center');
    _requireFinite(eye, 'eye');
    final towardViewer = eye - center;
    _requireDirection(towardViewer, 'eye - center');
    final front = towardViewer.normalized();
    var preferredUp = worldUp?.clone() ?? vm.Vector3(0, 1, 0);
    _requireDirection(preferredUp, 'worldUp');
    if (preferredUp.cross(front).length2 < _epsilon) {
      preferredUp = _fallbackUp(front);
    }
    return VrWorldPose.basis(
      center: center,
      right: preferredUp.cross(front),
      up: preferredUp,
      towardViewer: front,
    );
  }

  static const double _epsilon = 1e-10;

  final vm.Vector3 _center;
  final vm.Vector3 _right;
  final vm.Vector3 _up;
  final vm.Vector3 _towardViewer;
  final vm.Matrix4 _transform;

  vm.Vector3 get center => _center.clone();
  vm.Vector3 get right => _right.clone();
  vm.Vector3 get up => _up.clone();
  vm.Vector3 get towardViewer => _towardViewer.clone();

  /// A copy of the local-to-world transform represented by this pose.
  vm.Matrix4 get transform => _transform.clone();

  /// Converts a panel-local point into world space.
  vm.Vector3 localToWorld(vm.Vector3 local) =>
      _center + _right * local.x + _up * local.y + _towardViewer * local.z;

  /// Returns a local-to-world transform translated by [localOffset].
  vm.Matrix4 transformAt(vm.Vector3 localOffset) {
    final result = _transform.clone();
    result.setTranslation(localToWorld(localOffset));
    return result;
  }

  static vm.Matrix4 _basisTransform(
    vm.Vector3 center,
    vm.Vector3 right,
    vm.Vector3 up,
    vm.Vector3 towardViewer,
  ) {
    final result = vm.Matrix4.identity();
    result.setColumn(0, vm.Vector4(right.x, right.y, right.z, 0));
    result.setColumn(1, vm.Vector4(up.x, up.y, up.z, 0));
    result.setColumn(
      2,
      vm.Vector4(towardViewer.x, towardViewer.y, towardViewer.z, 0),
    );
    result.setColumn(3, vm.Vector4(center.x, center.y, center.z, 1));
    return result;
  }

  static vm.Vector3 _fallbackUp(vm.Vector3 front) {
    final worldUp = vm.Vector3(0, 1, 0);
    if (front.dot(worldUp).abs() < 0.95) return worldUp;
    return vm.Vector3(0, 0, 1);
  }

  static void _requireDirection(vm.Vector3 value, String name) {
    _requireFinite(value, name);
    if (value.length2 < _epsilon) {
      throw ArgumentError.value(value, name, 'Must not be a zero vector.');
    }
  }

  static void _requireFinite(vm.Vector3 value, String name) {
    if (!value.x.isFinite || !value.y.isFinite || !value.z.isFinite) {
      throw ArgumentError.value(value, name, 'Must contain finite values.');
    }
  }
}

/// One button in a [VrWorldActionPanel3D].
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

/// Description passed to a custom [VrWorldTextNodeBuilder].
///
/// The default builder creates a [VrTextLabel]. A custom builder is useful for
/// another text backend and for headless tests where Flutter GPU is absent.
class VrWorldTextSpec {
  VrWorldTextSpec({
    required this.text,
    required vm.Vector3 localCenter,
    required this.height,
    required this.fontSize,
    required this.color,
    required this.fontWeight,
    required this.maxWidthPx,
    required this.maxLines,
    required this.nodeName,
    required this.interactive,
  }) : _localCenter = localCenter.clone();

  final String text;
  final vm.Vector3 _localCenter;
  final double height;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double maxWidthPx;
  final int maxLines;
  final String nodeName;
  final bool interactive;

  vm.Vector3 get localCenter => _localCenter.clone();
}

typedef VrWorldTextNodeBuilder = Future<Node> Function(VrWorldTextSpec spec);

/// A fixed, world-space information card with gaze/laser/joystick actions.
///
/// This is intentionally separate from [VrPanel3D]: it has no grab state and
/// never follows the head. [update] only advances button feedback. Its pose
/// changes exclusively through an explicit [reanchor] call.
///
/// Hosts should use [ownsNode] as their modal raycast predicate so geometry
/// behind the non-raycastable plate cannot steal input.
class VrWorldActionPanel3D {
  VrWorldActionPanel3D._({
    required this.name,
    required this.columns,
    required VrWorldPose pose,
    required List<VrWorldAction> actions,
    required Node rootNode,
    required Node plateNode,
    required List<VrButton3D> buttons,
    required List<Node> textNodes,
    required List<Node> actionTextNodes,
  }) : _pose = pose,
       actions = List.unmodifiable(actions),
       rootNode = rootNode,
       plateNode = plateNode,
       _buttons = buttons,
       _actionTextNodes = actionTextNodes,
       _ownedNodes = HashSet<Node>.identity(),
       _interactiveNodes = HashSet<Node>.identity(),
       _actionIndexByNode = HashMap<Node, int>.identity() {
    _ownedNodes.add(rootNode);
    _ownedNodes.add(plateNode);
    _ownedNodes.addAll(textNodes);
    for (var i = 0; i < _buttons.length; i++) {
      final button = _buttons[i];
      _registry.register(button);
      for (final node in button.nodes) {
        _ownedNodes.add(node);
        _interactiveNodes.add(node);
        _actionIndexByNode[node] = i;
      }
      final textNode = _actionTextNodes[i];
      _interactiveNodes.add(textNode);
      _actionIndexByNode[textNode] = i;
    }
    final firstEnabled = actions.indexWhere((action) => action.enabled);
    setFocus(firstEnabled < 0 ? 0 : firstEnabled);
  }

  final String name;
  final int columns;
  final List<VrWorldAction> actions;
  final Node rootNode;
  final Node plateNode;
  final List<VrButton3D> _buttons;
  final List<Node> _actionTextNodes;
  final Set<Node> _ownedNodes;
  final Set<Node> _interactiveNodes;
  final Map<Node, int> _actionIndexByNode;
  final VrControlRegistry _registry = VrControlRegistry();

  VrWorldPose _pose;
  Scene? _scene;
  int _focusedIndex = 0;
  int? _lastHoveredActionIndex;

  VrWorldPose get pose => _pose;
  int get focusedIndex => _focusedIndex;
  VrWorldAction get focusedAction => actions[_focusedIndex];
  bool get isMounted => _scene != null;

  /// Every node owned by this panel, including its root and decorative nodes.
  Iterable<Node> get nodes => UnmodifiableSetView(_ownedNodes);

  /// Creates a panel. Text is rasterized and uploaded asynchronously.
  static Future<VrWorldActionPanel3D> create({
    required String name,
    required VrWorldPose pose,
    required String title,
    required List<VrWorldAction> actions,
    String subtitle = '',
    String description = '',
    Color accentColor = const Color(0xFF00E5FF),
    Color plateColor = const Color(0xFF080816),
    double width = 1.62,
    double buttonHeight = 0.18,
    double actionSpacing = 0.06,
    int columns = 1,
    double columnSpacing = 0.08,
    VrControlMeshBuilder? meshBuilder,
    VrWorldTextNodeBuilder? textNodeBuilder,
  }) async {
    // Callers may mutate their list while asynchronous text uploads finish.
    // Freeze it before creating geometry so actions and hit targets stay 1:1.
    actions = List<VrWorldAction>.unmodifiable(actions);
    _validate(
      name: name,
      title: title,
      actions: actions,
      width: width,
      buttonHeight: buttonHeight,
      actionSpacing: actionSpacing,
      columns: columns,
      columnSpacing: columnSpacing,
    );

    final actionStride = buttonHeight + actionSpacing;
    final rows = (actions.length + columns - 1) ~/ columns;
    final panelHeight = 0.60 + rows * actionStride;
    final top = panelHeight / 2;
    final gridWidth = width - 0.28;
    final buttonWidth = (gridWidth - columnSpacing * (columns - 1)) / columns;
    final firstActionY = top - 0.52 - buttonHeight / 2;

    final root = Node(name: '${name}_world_panel_root')
      ..raycastable = false
      ..localTransform = pose.transform;

    final plateMaterial = PhysicallyBasedMaterial()
      ..baseColorFactor = _vectorColor(plateColor)
      ..metallicFactor = 0.48
      ..roughnessFactor = 0.24
      ..emissiveFactor = vm.Vector4(
        accentColor.r * 0.06,
        accentColor.g * 0.06,
        accentColor.b * 0.06,
        0,
      );
    final plate = Node(
      name: '${name}_world_panel_plate',
      mesh:
          meshBuilder?.call() ??
          Mesh(
            CuboidGeometry(vm.Vector3(width, panelHeight, 0.055)),
            plateMaterial,
          ),
    )..raycastable = false;
    root.add(plate);

    final buttons = <VrButton3D>[];
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final row = i ~/ columns;
      final column = i % columns;
      // flutter_scene's camera uses up.cross(forward) as screen-right.
      // Our viewer-facing right-handed basis therefore projects +X to the
      // left: descend local X so the grid reads left-to-right on screen.
      final x =
          gridWidth / 2 -
          buttonWidth / 2 -
          column * (buttonWidth + columnSpacing);
      final button = VrButton3D(
        name: _nodeName(name, action.id),
        label: action.label,
        center: vm.Vector3(x, firstActionY - actionStride * row, 0.055),
        color: _vectorColor(action.color ?? accentColor),
        width: buttonWidth,
        height: buttonHeight,
        meshBuilder: meshBuilder,
        onPressed: action.onPressed,
      )..enabled = action.enabled;
      buttons.add(button);
      for (final node in button.nodes) {
        root.add(node);
      }
    }

    final specs = <VrWorldTextSpec>[
      VrWorldTextSpec(
        text: title.toUpperCase(),
        localCenter: vm.Vector3(0, top - 0.14, 0.09),
        height: 0.115,
        fontSize: 84,
        color: accentColor,
        fontWeight: FontWeight.w800,
        maxWidthPx: 1350,
        maxLines: 1,
        nodeName: '${name}_title',
        interactive: false,
      ),
      if (subtitle.trim().isNotEmpty)
        VrWorldTextSpec(
          text: subtitle,
          localCenter: vm.Vector3(0, top - 0.28, 0.09),
          height: 0.066,
          fontSize: 76,
          color: const Color(0xFFCBD5E1),
          fontWeight: FontWeight.w600,
          maxWidthPx: 1350,
          maxLines: 1,
          nodeName: '${name}_subtitle',
          interactive: false,
        ),
      if (description.trim().isNotEmpty)
        VrWorldTextSpec(
          text: description,
          localCenter: vm.Vector3(0, top - 0.41, 0.09),
          height: 0.11,
          fontSize: 72,
          color: const Color(0xFFE2E8F0),
          fontWeight: FontWeight.w500,
          maxWidthPx: 1450,
          maxLines: 2,
          nodeName: '${name}_description',
          interactive: false,
        ),
      for (var i = 0; i < actions.length; i++)
        VrWorldTextSpec(
          text: actions[i].label.toUpperCase(),
          localCenter: vm.Vector3(
            gridWidth / 2 -
                buttonWidth / 2 -
                (i % columns) * (buttonWidth + columnSpacing),
            firstActionY - actionStride * (i ~/ columns),
            0.091,
          ),
          height: math.min(0.075, buttonHeight * 0.42),
          fontSize: 82,
          color: Colors.white,
          fontWeight: FontWeight.w800,
          maxWidthPx: 1350,
          maxLines: 1,
          nodeName: _nodeName(name, actions[i].id),
          interactive: true,
        ),
    ];

    final builder = textNodeBuilder ?? _buildTextNode;
    final textNodes = await Future.wait(specs.map(builder));
    final actionTextNodes = <Node>[];
    for (var i = 0; i < textNodes.length; i++) {
      final node = textNodes[i];
      final spec = specs[i];
      node
        ..name = spec.nodeName
        ..raycastable = spec.interactive
        ..localTransform = _textTransform(spec.localCenter);
      root.add(node);
      if (spec.interactive) actionTextNodes.add(node);
    }

    return VrWorldActionPanel3D._(
      name: name,
      columns: columns,
      pose: pose,
      actions: actions,
      rootNode: root,
      plateNode: plate,
      buttons: buttons,
      textNodes: textNodes,
      actionTextNodes: actionTextNodes,
    );
  }

  /// Returns true only for node identities belonging to this panel.
  bool ownsNode(Node? node) => node != null && _ownedNodes.contains(node);

  /// Returns true only for an enabled button or button-label node.
  bool ownsInteractiveNode(Node? node) =>
      node != null &&
      _interactiveNodes.contains(node) &&
      actions[_actionIndexByNode[node]!].enabled;

  /// Routes pointer hover, changing focus only when its action target changes.
  ///
  /// A stationary pointer must not undo a later joystick focus change. A miss
  /// clears pointer history, but preserves the visible keyboard/joystick focus.
  /// Hosts must arbitrate gaze and laser before forwarding one pointer stream.
  void handleHover(Node? node) {
    if (!ownsInteractiveNode(node)) {
      _lastHoveredActionIndex = null;
      return;
    }
    final index = _actionIndexByNode[node]!;
    if (index == _lastHoveredActionIndex) return;
    _lastHoveredActionIndex = index;
    setFocus(index);
  }

  /// Selects [node] only when it is one of this panel's owned actions.
  bool handleSelect(Node? node) {
    if (!ownsInteractiveNode(node)) return false;
    final index = _actionIndexByNode[node]!;
    setFocus(index);
    return _registry.handleSelect(_buttons[index].nodes.first);
  }

  /// Moves linear focus by [delta], wrapping and skipping disabled actions.
  /// Use [moveGridFocus] for spatial horizontal/vertical navigation.
  int moveFocus(int delta) {
    if (delta == 0) return _focusedIndex;
    final count = actions.length;
    var next = (_focusedIndex + delta) % count;
    for (var attempt = 0; attempt < count; attempt++) {
      if (actions[next].enabled) {
        setFocus(next);
        break;
      }
      next = (next + delta.sign) % count;
    }
    return _focusedIndex;
  }

  /// Moves one grid cell in screen coordinates: +horizontal is right and
  /// +vertical is down. Wraps within the same row/column, skipping disabled or
  /// absent cells in an incomplete final row, without jumping diagonally.
  /// Supply only one nonzero axis per call.
  int moveGridFocus({int horizontal = 0, int vertical = 0}) {
    if (horizontal != 0 && vertical != 0) {
      throw ArgumentError('Supply only one grid navigation axis.');
    }
    if (horizontal == 0 && vertical == 0) return _focusedIndex;
    final row = _focusedIndex ~/ columns;
    final column = _focusedIndex % columns;
    final rows = (actions.length + columns - 1) ~/ columns;
    final limit = horizontal != 0 ? columns : rows;
    final step = horizontal != 0 ? horizontal.sign : vertical.sign;
    for (var offset = 1; offset <= limit; offset++) {
      final nextRow = vertical != 0 ? (row + offset * step) % rows : row;
      final nextColumn = horizontal != 0
          ? (column + offset * step) % columns
          : column;
      final next = nextRow * columns + nextColumn;
      if (next < actions.length && actions[next].enabled) {
        setFocus(next);
        break;
      }
    }
    return _focusedIndex;
  }

  /// Focuses an action by index and applies the normal hover visual.
  void setFocus(int index) {
    if (index < 0 || index >= actions.length) {
      throw RangeError.index(index, actions, 'index');
    }
    _focusedIndex = index;
    _registry.handleHover(_buttons[index].nodes.first);
  }

  /// Activates the focused action, returning false when it is disabled.
  bool activateFocused() =>
      _registry.handleSelect(_buttons[_focusedIndex].nodes.first);

  /// Explicitly relocates the panel. No frame method calls this implicitly.
  void reanchor(VrWorldPose pose) {
    _pose = pose;
    rootNode.localTransform = pose.transform;
  }

  /// Adds the complete panel subtree to [scene].
  void addTo(Scene scene) {
    if (_scene != null) {
      if (identical(_scene, scene)) return;
      throw StateError('VrWorldActionPanel3D is already mounted in a scene.');
    }
    scene.add(rootNode);
    _scene = scene;
  }

  /// Removes the panel subtree from [scene]. The panel may be added again.
  void removeFrom(Scene scene) {
    if (_scene == null) return;
    if (!identical(_scene, scene)) {
      throw ArgumentError(
        'The panel is mounted in a different Scene.',
        'scene',
      );
    }
    _registry.handleHover(null);
    _lastHoveredActionIndex = null;
    if (rootNode.parent != null) scene.remove(rootNode);
    _scene = null;
  }

  /// Advances button press feedback without changing the world pose.
  void update(double dt) => _registry.update(dt);

  static Future<Node> _buildTextNode(VrWorldTextSpec spec) async {
    final label = await VrTextLabel.create(
      spec.text,
      center: spec.localCenter,
      height: spec.height,
      fontSize: spec.fontSize,
      color: spec.color,
      fontWeight: spec.fontWeight,
      maxWidthPx: spec.maxWidthPx,
      maxLines: spec.maxLines,
      name: spec.nodeName,
    );
    return label.node;
  }

  static vm.Matrix4 _textTransform(vm.Vector3 localCenter) =>
      vm.Matrix4.translation(localCenter)
        ..rotateX(math.pi / 2)
        ..scaleByVector3(vm.Vector3(-1, 1, 1));

  static vm.Vector4 _vectorColor(Color color) =>
      vm.Vector4(color.r, color.g, color.b, color.a);

  static String _nodeName(String panelName, String actionId) =>
      '${panelName}_action_$actionId';

  static void _validate({
    required String name,
    required String title,
    required List<VrWorldAction> actions,
    required double width,
    required double buttonHeight,
    required double actionSpacing,
    required int columns,
    required double columnSpacing,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Must not be empty.');
    }
    if (actions.isEmpty) {
      throw ArgumentError.value(actions, 'actions', 'Must not be empty.');
    }
    if (!width.isFinite || width <= 0.4) {
      throw ArgumentError.value(
        width,
        'width',
        'Must be finite and greater than 0.4.',
      );
    }
    if (!buttonHeight.isFinite || buttonHeight <= 0) {
      throw ArgumentError.value(
        buttonHeight,
        'buttonHeight',
        'Must be finite and greater than zero.',
      );
    }
    if (!actionSpacing.isFinite || actionSpacing < 0) {
      throw ArgumentError.value(
        actionSpacing,
        'actionSpacing',
        'Must be finite and non-negative.',
      );
    }
    if (columns < 1 || columns > actions.length) {
      throw ArgumentError.value(
        columns,
        'columns',
        'Must be between 1 and the number of actions.',
      );
    }
    if (!columnSpacing.isFinite || columnSpacing < 0) {
      throw ArgumentError.value(
        columnSpacing,
        'columnSpacing',
        'Must be finite and non-negative.',
      );
    }
    final availableButtonWidth =
        (width - 0.28 - columnSpacing * (columns - 1)) / columns;
    if (availableButtonWidth <= 0) {
      throw ArgumentError.value(
        columnSpacing,
        'columnSpacing',
        'Leaves no horizontal space for action buttons.',
      );
    }
    final ids = <String>{};
    for (final action in actions) {
      if (action.id.trim().isEmpty) {
        throw ArgumentError.value(action.id, 'action.id', 'Must not be empty.');
      }
      if (!ids.add(action.id)) {
        throw ArgumentError.value(
          action.id,
          'action.id',
          'Must be unique within a panel.',
        );
      }
      if (action.label.trim().isEmpty) {
        throw ArgumentError.value(
          action.label,
          'action.label',
          'Must not be empty.',
        );
      }
    }
  }
}
