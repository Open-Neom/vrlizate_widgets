# vrlizate_widgets

Controles 3D reutilizables, widgets espaciales y contenedores de layout para escenas Flutter GPU (`flutter_scene`), diseñados para mirada, puntero láser, mando y gamepad.

> Versión actual: **1.0.0**. Consulta [CHANGELOG.md](CHANGELOG.md) para el historial de cambios.

## Componentes incluidos

- **Controles interactivos clásicos:** `VrButton3D`, `VrToggle3D`, `VrDropdown3D`, `VrSlider3D`, `VrSegmentedControl3D`, `VrStepper3D`, `VrProgressBar3D`.
- **Contrapartes 3D de widgets Flutter (`lib/ui/widgets/`):**
  - `VrCard3D`: tarjeta 3D biselada con elevación configurable y franja de acento.
  - `VrSwitch3D`: interruptor 3D tipo píldora con pulgar deslizante.
  - `VrChip3D`: chip 3D seleccionable con indicador luminoso.
  - `VrIconButton3D`: botón de acción flotante circular o cúbico con emblema en relieve.
  - `VrDialog3D`: diálogo modal espacial con placa de fondo, encabezado y botones de confirmar/cancelar.
  - `VrListTile3D`: fila 3D con indicador izquierdo, placa central y acción secundaria derecha.
- **Layouts espaciales 3D (`lib/ui/layouts/`):** `VrRow3D`, `VrColumn3D`, `VrGrid3D`.
- **Posicionamiento estático y dinámico en 3D:** `VrPlacementMode` (`staticWorld`, `dynamicBillboard`, `headLockedHud`, `dynamicFloating`) y `VrSpatialPose`.
- **Paneles, arrastre y texto:** `VrPanel3D`, `VrDragController`, `VrTextLabel`, `VrTextRaster`, `VrTextBitmap`.
- **Panel de acciones fijo en el mundo:** `VrWorldActionPanel3D`, `VrWorldAction`, `VrWorldPose`.
- **Proyección de widgets Flutter en 3D:** `VrWidgetSurface3D` (conserva proporción, comparte textura entre ambos ojos y limita la captura a 250 ms / máx. 1536 px).

## Instalación

Requiere Dart `>=3.10.0`, Flutter `>=3.47.0` y un backend compatible con Flutter GPU / Impeller.

```yaml
dependencies:
  vrlizate_widgets: ^1.0.0
```

## Uso básico

### Registro de controles y layouts 3D con posicionamiento dinámico

```dart
final controls = VrControlRegistry();
final row = VrRow3D(
  name: 'quick_actions',
  origin: Vector3(0, 1.5, -2.0),
  spacing: 0.42,
  placementMode: VrPlacementMode.dynamicBillboard,
  children: [
    VrSwitch3D(
      name: 'audio_switch',
      label: 'Audio espacial',
      center: Vector3.zero(),
      initialValue: true,
      onChanged: (enabled) => setSpatialAudio(enabled),
    ),
    VrChip3D(
      name: 'hd_chip',
      label: 'Modo HD',
      center: Vector3.zero(),
      onSelected: (selected) => setHdMode(selected),
    ),
  ],
);

row.registerAll(controls);
for (final node in row.nodes) {
  scene.add(node);
}

StereoSceneView(
  scene: scene,
  onGazeHoverChanged: controls.handleHover,
  onGazeSelect: controls.handleSelect,
  onTick: (elapsed, dt) {
    controls.update(dt);
    row.updateSpatialPlacement(
      viewerPosition: rig.eyeCenter,
      viewerForward: rig.forward,
      elapsedSeconds: elapsed,
      dt: dt,
    );
  },
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

## Verificación

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

## Licencia

Apache License 2.0 — consulta [LICENSE](LICENSE).
