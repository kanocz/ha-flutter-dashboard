import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/blind_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/climate_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/light_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/lock_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/static_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/switch_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/time_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/separator_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/label_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/rtsp_video_widget_card.dart';
import 'package:ha_flutter_dashboard/widgets/group_widget_card.dart';

class WidgetCardFactory {
  static Widget createWidgetCard({
    required DashboardWidget widget,
    required HomeAssistantApiService apiService,
    EntityState? entityState,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isEditing = false,
    bool isInteractive = true,
    bool? isDashboardLocked,
  }) {
    switch (widget.type) {
      case AppConstants.widgetTypeTime:
        return TimeWidgetCard(
          widget: widget,
          apiService: apiService,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeLight:
        return LightWidgetCard(
          widget: widget,
          apiService: apiService,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeSwitch:
        return SwitchWidgetCard(
          widget: widget,
          apiService: apiService,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeBlind:
        return BlindWidgetCard(
          widget: widget,
          apiService: apiService,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeLock:
        return LockWidgetCard(
          widget: widget,
          apiService: apiService,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeClimate:
        return ClimateWidgetCard(
          widget: widget,
          apiService: apiService,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeStatic:
        return StaticWidgetCard(
          widget: widget,
          apiService: apiService,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeSeparator:
        return SeparatorWidgetCard(
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeLabel:
        return LabelWidgetCard(
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeRtspVideo:
        return RtspVideoWidgetCard(
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );
      case AppConstants.widgetTypeGroup:
        return GroupWidgetCard(
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
          isDashboardLocked: isDashboardLocked ?? false,
        );
      default:
        return Container(
          child: Center(
            child: Text('Unknown widget type: ${widget.type}'),
          ),
        );
    }
  }
  
  /// Get a list of supported widget types
  static List<Map<String, dynamic>> getSupportedWidgetTypes() {
    return [
      {
        'type': AppConstants.widgetTypeSeparator,
        'name': 'Separator',
        'description': 'Add a horizontal separator or space',
        'icon': Icons.horizontal_rule,
        'needsEntity': false,
      },
      {
        'type': AppConstants.widgetTypeLabel,
        'name': 'Label',
        'description': 'Display text with configurable formatting',
        'icon': Icons.text_fields,
        'needsEntity': false,
      },
      {
        'type': AppConstants.widgetTypeTime,
        'name': 'Time',
        'description': 'Display current time',
        'icon': Icons.access_time,
        'needsEntity': false,
      },
      {
        'type': AppConstants.widgetTypeLight,
        'name': 'Light',
        'description': 'Control a light (on/off, brightness)',
        'icon': Icons.lightbulb,
        'needsEntity': true,
        'entityDomain': 'light',
      },
      {
        'type': AppConstants.widgetTypeSwitch,
        'name': 'Switch',
        'description': 'Control a switch (on/off)',
        'icon': Icons.toggle_on,
        'needsEntity': true,
        'entityDomain': 'switch',
      },
      {
        'type': AppConstants.widgetTypeBlind,
        'name': 'Blind',
        'description': 'Control a blind/cover (open/close/position)',
        'icon': Icons.blinds,
        'needsEntity': true,
        'entityDomain': 'cover',
      },
      {
        'type': AppConstants.widgetTypeLock,
        'name': 'Lock',
        'description': 'Control a lock (lock/unlock)',
        'icon': Icons.lock,
        'needsEntity': true,
        'entityDomain': 'lock',
      },
      {
        'type': AppConstants.widgetTypeClimate,
        'name': 'Climate',
        'description': 'Control climate (on/off, temperature)',
        'icon': Icons.thermostat,
        'needsEntity': true,
        'entityDomain': 'climate',
      },
      {
        'type': AppConstants.widgetTypeStatic,
        'name': 'Static',
        'description': 'Display entity state',
        'icon': Icons.info,
        'needsEntity': true,
        'entityDomain': null, // Any entity is allowed
      },
      {
        'type': AppConstants.widgetTypeRtspVideo,
        'name': 'RTSP Video',
        'description': 'Display RTSP video stream (video only)',
        'icon': Icons.videocam,
        'needsEntity': false,
      },
      {
        'type': AppConstants.widgetTypeGroup,
        'name': 'Group',
        'description': 'A group of widgets (icon + label, opens popup)',
        'icon': Icons.folder,
        'needsEntity': false,
      },
    ];
  }
}
