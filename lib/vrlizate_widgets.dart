/// vrlizate_widgets — reusable gaze-interactive 3D widgets and spatial layouts
/// for Flutter GPU.
///
/// The VR counterpart of core Flutter widgets and layout containers: buttons,
/// toggles, switches, chips, cards, icon buttons, list tiles, dialogs,
/// dropdowns, sliders, movable panels, and spatial layout containers (`VrRow3D`,
/// `VrColumn3D`, `VrGrid3D`) implemented as native `flutter_scene` scene-graph
/// nodes, with static and dynamic 3D placement modes (`VrPlacementMode`).
library;

export 'domain/models/vr_spatial_pose.dart';
export 'domain/models/vr_text_bitmap.dart';
export 'domain/models/vr_world_action.dart';
export 'domain/models/vr_world_pose.dart';
export 'domain/models/vr_world_text_spec.dart';

export 'src/vr_advanced_controls.dart';
export 'src/vr_controls.dart';
export 'src/vr_drag.dart';
export 'src/vr_panel.dart';
export 'src/vr_slider.dart';
export 'src/vr_text.dart';
export 'src/vr_widget.dart';
export 'src/vr_widget_surface.dart';
export 'src/vr_world_action_panel.dart';

export 'ui/layouts/vr_column_3d.dart';
export 'ui/layouts/vr_grid_3d.dart';
export 'ui/layouts/vr_row_3d.dart';

export 'ui/widgets/vr_card_3d.dart';
export 'ui/widgets/vr_chip_3d.dart';
export 'ui/widgets/vr_dialog_3d.dart';
export 'ui/widgets/vr_icon_button_3d.dart';
export 'ui/widgets/vr_list_tile_3d.dart';
export 'ui/widgets/vr_switch_3d.dart';

export 'utils/constants/vr_widget_constants.dart';
export 'utils/enums/vr_placement_mode.dart';
