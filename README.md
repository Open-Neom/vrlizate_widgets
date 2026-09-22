# vrlizate_widgets

Controles 3D reutilizables para escenas Flutter GPU, diseñados para mirada,
puntero láser, gamepad y teléfonos de gama baja.

Reusable 3D controls for Flutter GPU scenes, designed for gaze, laser pointer,
gamepad and budget phones.

## Widgets

- `VrButton3D`, `VrToggle3D`, `VrDropdown3D`
- `VrSlider3D`, `VrSegmentedControl3D`, `VrStepper3D`
- `VrProgressBar3D`
- `VrPanel3D`, `VrDragController`
- `VrTextLabel`
- `VrWorldActionPanel3D`, `VrWorldAction`, `VrWorldPose`

Los controles compuestos usan primitivas pequeñas y cambian materiales o
visibilidad durante la interacción. No reconstruyen ni vuelven a subir meshes
por frame. El registro reutiliza su lista de controles durante `update`;
esto evita un `Set` nuevo por frame, pero no garantiza Zero-GC de toda la app.

Compound controls use small primitives and update materials or visibility
during interaction. They do not rebuild or re-upload meshes per frame. The
registry reuses its control list during `update`, avoiding a new `Set` each
frame; this does not make the entire application allocation-free.

## Instalación / Installation

```yaml
dependencies:
  vrlizate_widgets: ^0.3.0
```

Para distribuir versiones release en Windows o Linux se requiere Flutter
3.47.1+ y activar Flutter GPU en el runner de la plataforma, según las
[instrucciones de flutter_scene](https://pub.dev/packages/flutter_scene).

Shipping Windows or Linux releases requires Flutter 3.47.1+ and Flutter GPU
enabled in the platform runner; follow the
[flutter_scene setup instructions](https://pub.dev/packages/flutter_scene).

## Integración local / Local integration

El paquete requiere Dart 3.10+, Flutter 3.47+ y un runtime compatible con
Flutter GPU/Impeller y la versión de `flutter_scene` de [pubspec.yaml](pubspec.yaml).
Desde un workspace con ambos paquetes en directorios hermanos:

The package requires Dart 3.10+, Flutter 3.47+, and a runtime compatible with
Flutter GPU/Impeller and the `flutter_scene` dependency in [pubspec.yaml](pubspec.yaml).
For sibling packages in a local workspace:

```yaml
dependencies:
  vrlizate_widgets:
    path: ../vrlizate_widgets
```

## Uso / Usage

```dart
final controls = VrControlRegistry();
final tabs = VrSegmentedControl3D(
  name: 'period',
  label: 'Periodo',
  center: Vector3(0, 1.5, -2),
  options: const ['Día', 'Semana', 'Mes'],
  onChanged: (index, value) => loadPeriod(value),
);

controls.register(tabs);
for (final node in tabs.nodes) {
  scene.add(node);
}

StereoSceneView(
  scene: scene,
  onGazeHoverChanged: controls.handleHover,
  onGazeSelect: controls.handleSelect,
  onTick: (_, dt) => controls.update(dt),
);
```

Para interfaces dinámicas, llama `controls.unregister(control)` antes de
retirar sus nodos. `setValue` y `setSelectedIndex` restauran estado persistido
sin disparar callbacks de usuario.

For dynamic interfaces, call `controls.unregister(control)` before removing
its nodes. `setValue` and `setSelectedIndex` restore persisted state without
firing user callbacks.

## Panel fijo en el mundo / World-anchored panel

`VrPanel3D` permite agarrar y mover un panel. `VrWorldActionPanel3D` conserva
su pose al mover la cabeza: sólo `reanchor` cambia su posición. Es apropiado
para confirmaciones y menús que se seleccionan con el centro de la mirada.

`VrPanel3D` supports grabbing and moving a panel. `VrWorldActionPanel3D` keeps
its pose when the head moves; only `reanchor` relocates it. Use it for
confirmations and menus selected by a gaze reticle.

```dart
final panel = await VrWorldActionPanel3D.create(
  name: 'demo_confirmation',
  pose: VrWorldPose.fromViewer(
    eye: rig.eyeCenter,
    forward: rig.forward,
    distance: 1.8,
  ),
  title: 'Kanban VR',
  description: 'Organiza tus tareas en el espacio.',
  actions: [
    VrWorldAction(id: 'enter', label: 'Entrar', onPressed: enterDemo),
    VrWorldAction(id: 'back', label: 'Volver', onPressed: closePanel),
  ],
  columns: 2,
);
panel.addTo(scene);

// Route the active pointer only (gaze or laser).
// For modal picking: scene.raycast(ray, where: panel.ownsInteractiveNode).
panel.handleHover(hitNode);
panel.moveGridFocus(horizontal: 1); // Right on screen; vertical: 1 is down.
panel.activateFocused();           // A / trigger on the focused action.
// Each frame: panel.update(dt). When closed: panel.removeFrom(scene).
```

El host conecta los drivers y decide si mirada o láser controla el foco antes
de reenviar eventos. Los widgets no se conectan al hardware automáticamente.
Los objetivos se reconocen por identidad; una etiqueta renombrada sigue
seleccionando su botón, y un nodo ajeno con el mismo nombre no lo activa.

The host connects hardware drivers and arbitrates gaze versus laser before
forwarding events. Widgets do not connect to devices themselves. Targets are
recognized by identity: renamed labels still select their own button, while
unrelated nodes sharing a name cannot activate it.

La navegación de grid conserva la fila/columna y omite opciones deshabilitadas
o huecos de la última fila. `moveFocus` mantiene navegación lineal; `setFocus`
permite elegir explícitamente una opción. Una mirada inmóvil no recupera el
foco que acaba de mover el joystick; debe cambiar de objetivo.

Grid navigation preserves the row/column and skips disabled or absent cells.
`moveFocus` provides linear navigation; `setFocus` explicitly chooses an
action. A stationary pointer does not reclaim focus after joystick navigation;
its target must change.

## Verificación / Verification

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

La suite contiene 66 pruebas. Las pruebas headless inyectan meshes vacíos para
validar lógica y scene graph sin Impeller; el orden visual se comprueba con
la proyección de cámara real de `flutter_scene`. No verifican legibilidad a
través de lentes, confort binocular, renderizado físico ni FPS sostenidos:
eso requiere pruebas en dispositivos y builds profile/release.

The suite contains 66 tests. Headless tests inject empty meshes to validate
logic and the scene graph without Impeller; visual ordering is checked using
the actual `flutter_scene` camera projection. Lens readability, binocular
comfort, physical rendering, and sustained FPS require device testing in
profile/release builds.

## Licencia / License

Apache License 2.0, la misma licencia del núcleo `vrlizate`.
See [LICENSE](LICENSE) for the full terms.
