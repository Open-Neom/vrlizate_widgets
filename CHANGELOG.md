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
