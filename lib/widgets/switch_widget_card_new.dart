import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/utils/debug_logger.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class SwitchWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService apiService;

  const SwitchWidgetCard({
    Key? key,
    required DashboardWidget widget,
    required this.apiService,
    EntityState? entityState,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isEditing = false,
  }) : super(
          key: key,
          widget: widget,
          entityState: entityState,
          onTap: onTap,
          onLongPress: onLongPress,
          isEditing: isEditing,
        );

  @override
  Widget buildWidgetContent(BuildContext context, {bool isSmallWidget = false}) {
    // Use a StreamBuilder to directly listen for real-time updates from the API service
    return StreamBuilder<EntityState>(
      // Initial data is the current entity state
      initialData: entityState,
      // Listen to state updates from the API service, filtering to only this entity
      stream: apiService.stateUpdateStream?.where(
        (state) => state.entityId == widget.entityId,
      ),
      builder: (context, snapshot) {
        // Get the latest state from the snapshot or use the initial entityState
        final currentState = snapshot.data ?? entityState;
            
        DebugLogger.log('SwitchWidget: Building with entityState: ${currentState?.state}');

        if (currentState == null) {
          return const Center(
            child: Text('No data'),
          );
        }

        final isOn = currentState.state.toLowerCase() == 'on';
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;
        
        // Debug current state
        DebugLogger.log('SwitchWidget: Entity ${widget.entityId} state: ${currentState.state}, isOn: $isOn');

        // Function to toggle the switch
        Future<void> toggleSwitch() async {
          if (isEditing) return;
          
          DebugLogger.log('SwitchWidget: Switch tapped, toggling state');
          try {
            // Use toggleSwitch from the API service
            await apiService.toggleSwitch(widget.entityId);
          } catch (e) {
            DebugLogger.log('SwitchWidget: Error toggling switch: $e');
            // Fallback to callService if toggleSwitch doesn't work
            try {
              await apiService.callService('switch', 'toggle', {'entity_id': widget.entityId});
            } catch (e2) {
              DebugLogger.log('SwitchWidget: Error with fallback method: $e2');
            }
          }
        }

        // For small widgets, use a more compact layout
        if (isSmallWidget) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: toggleSwitch,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isOn ? colorScheme.primaryContainer.withOpacity(0.5) : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isOn ? Icons.power_rounded : Icons.power_off_rounded,
                      size: 24,
                      color: isOn ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOn ? 'ON' : 'OFF',
                      style: themeData.textTheme.bodyMedium?.copyWith(
                        color: isOn ? colorScheme.primary : null,
                        fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Standard layout for regular sized widgets
        return InkWell(
          onTap: toggleSwitch,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isOn ? colorScheme.primaryContainer.withOpacity(0.3) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Display a status icon based on the state
                Icon(
                  isOn ? Icons.power_rounded : Icons.power_off_rounded,
                  size: 32,
                  color: isOn ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(height: 8),
                // Status text
                Text(
                  isOn ? 'ON' : 'OFF',
                  style: themeData.textTheme.bodyLarge?.copyWith(
                    color: isOn ? colorScheme.primary : null,
                    fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
