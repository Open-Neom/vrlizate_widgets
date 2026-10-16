# vrlizate_widgets

Controles 3D reutilizables y paneles anclados al mundo para escenas Flutter GPU (`flutter_scene`), diseñados para mirada, puntero láser, mando y gamepad.

> Versión actual: **0.3.1**. Consulta [CHANGELOG.md](CHANGELOG.md) para el historial de cambios.

## Componentes incluidos

- **Controles interactivos:** `VrButton3D`, `VrToggle3D`, `VrDropdown3D`, `VrSlider3D`, `VrSegmentedControl3D`, `VrStepper3D`, `VrProgressBar3D`.
- **Paneles y texto:** `VrPanel3D`, `VrDragController`, `VrTextLabel`.
- **Panel de acciones fijo en el mundo:** `VrWorldActionPanel3D`, `VrWorldAction`, `VrWorldPose`.
- **Proyección de widgets Flutter en 3D:** `VrWidgetSurface3D` (conserva proporción, comparte textura entre ambos ojos y limita la captura a 250 ms / máx. 1536 px).

Los controles actualizan materiales o visibilidad sin reconstruir ni resubir geometría en cada frame, y `VrControlRegistry` reutiliza su colección interna durante `update`.

## Instalación

Requiere Dart `>=3.10.0`, Flutter `>=3.47.0` y un backend compatible con Flutter GPU / Impeller.

```yaml
dependencies:
  vrlizate_widgets: ^0.3.1
```

## Uso básico

### Registro de controles 3D

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

### Panel de confirmación anclado al mundo (`VrWorldActionPanel3D`)

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
```

Soporta selección por identidad de nodo (mirada/láser) y navegación por cuadrícula con joystick (`moveGridFocus`, `activateFocused`) sin que un puntero inmóvil robe el foco.

## Verificación

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

## Licencia

Apache License 2.0 — consulta [LICENSE](LICENSE).
