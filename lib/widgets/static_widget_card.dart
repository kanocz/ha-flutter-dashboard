import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/utils/format_helper.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class StaticWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService apiService;

  const StaticWidgetCard({
    Key? key,
    required DashboardWidget widget,
    required this.apiService,
    EntityState? entityState,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isEditing = false,
    bool isInteractive = true,
  }) : super(
          key: key,
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
          isInteractive: isInteractive,
        );

  @override
  Widget buildWidgetContent(
    BuildContext context, {
    bool isSmallWidget = false,
    bool useSimplifiedView = false,
  }) {
    return StreamBuilder<EntityState>(
      initialData: entityState,
      stream: apiService.stateUpdateStream?.where(
        (state) => state.entityId == widget.entityId,
      ),
      builder: (context, snapshot) {
        final currentState = snapshot.data ?? entityState;
        if (currentState == null) {
          return const Center(child: Text('No data'));
        }
        
        // Format the state value based on its content
        String displayValue = currentState.state;
        if (double.tryParse(displayValue) != null) {
          final doubleValue = double.parse(displayValue);
          if (currentState.attributes.containsKey('unit_of_measurement')) {
            final unit = currentState.attributes['unit_of_measurement'] as String? ?? '';
            if (unit == '°C' || unit == '°F') {
              displayValue = FormatHelper.formatTemperature(doubleValue);
            } else {
              displayValue = '${doubleValue.toStringAsFixed(1)} $unit';
            }
          }
        }
        
        final textColor = FormatHelper.getColorForState(currentState.state);
        final themeData = Theme.of(context);
        
        // For small widgets, simplify the display
        if (isSmallWidget) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                displayValue,
                style: themeData.textTheme.titleLarge?.copyWith(
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        // Regular sized widget with more details
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayValue,
                style: themeData.textTheme.headlineMedium?.copyWith(
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              if (currentState.attributes.containsKey('friendly_name') &&
                  currentState.attributes['friendly_name'] != widget.caption) ...[
                const SizedBox(height: 8),
                Text(
                  currentState.attributes['friendly_name'] as String? ?? '',
                  style: themeData.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
