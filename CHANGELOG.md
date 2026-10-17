## 1.0.0 - 2026-10-17

- Added `VrPlacementMode` (`staticWorld`, `dynamicBillboard`, `headLockedHud`, `dynamicFloating`) and `VrSpatialPose` so every 3D widget and layout can be placed statically or dynamically in the 3D scene.
- Enhanced `VrSpatial` and `VrControlRegistry.updateSpatial` with `configurePlacement` and `updateSpatialPlacement`.
- Added 3D counterparts for common Flutter Material widgets:
  - `VrCard3D`: beveled 3D card with configurable elevation, header accent strip, and press callback.
  - `VrSwitch3D`: pill track toggle switch with animated sliding thumb node.
  - `VrChip3D`: selectable 3D filter/choice chip pill with indicator node.
  - `VrIconButton3D`: circular or cubic 3D floating action button with raised center emblem.
  - `VrDialog3D`: spatial 3D modal dialog with backdrop, header, confirm, and cancel actions.
  - `VrListTile3D`: 3D list item row with leading indicator, main plate, and trailing action node.
- Added 3D spatial layout containers: `VrRow3D`, `VrColumn3D`, and `VrGrid3D` for automatic X/Y alignment and group spatial transforms.
- Added `VrWidgetSurface3D` for bounded aspect-preserving 3D projection of Flutter widgets with throttled texture capture (250 ms, max 1536 px) and optional `content` slot in `VrWorldActionPanel3D.create`.
- Refactored codebase to follow Open Neom modular architecture (`lib/utils/constants/`, `lib/utils/enums/`, `lib/domain/models/`, `lib/ui/widgets/`, `lib/ui/layouts/`) with one public class/enum per file and centralized constants in `VrWidgetConstants`.

## 0.3.1 - 2026-09-22

- Require Flutter 3.47.0 or newer, matching the flutter_scene dependency's
  minimum supported SDK.

## 0.3.0

- Prepared the first pub.dev distribution with the ecosystem's Apache-2.0
  license and explicit exclusions for generated build/test caches.

- Added `VrWorldActionPanel3D`, `VrWorldAction`, and immutable `VrWorldPose`
  for information cards and confirmations anchored in the 3D world.
- Added gaze/laser selection by node identity and persistent controller focus.
  A stationary pointer or pointer miss no longer overrides joystick focus.
- Added row/column grid navigation with wrapping, disabled-action skipping,
  and safe handling of incomplete rows or an entirely disabled panel.
- Corrected visual column ordering against the actual `flutter_scene` camera
  projection; screen-right navigation now follows the displayed layout.
- Snapshotted action lists before asynchronous text creation to keep geometry,
  labels, callbacks, and selection targets consistent.
- Removed per-frame registry `Set` creation by caching registered controls;
  fixed hover cleanup when clearing or replacing a registration.
- Added regression coverage for projection, identity, focus, asynchronous
  creation, and registry lifecycle. The headless suite contains 66 tests.

## 0.2.0

- Added `VrSegmentedControl3D` for tabs, filters and exclusive choices.
- Added `VrProgressBar3D` with low-cost segmented material updates.
- Added `VrStepper3D` with bounded increment/decrement controls.
- Added `VrControlRegistry.unregister` for dynamic scene lifecycle safety.
- Disabled controls now refresh and dim their emissive state immediately.
- Added bilingual usage documentation and headless coverage for the new API.

## 0.1.0

- Initial 3D controls, panels, drag-and-drop, slider and text labels.
