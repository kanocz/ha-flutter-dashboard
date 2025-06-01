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
          if (isEditing || !isInteractive) return;
          DebugLogger.log('SwitchWidget: Switch tapped, toggling state');
          final entityId = widget.entityId;
          final domain = entityId.split('.').first;
          String serviceDomain = domain;
          String serviceName = 'toggle';
          // Only call toggle for supported domains
          if (domain == 'switch' || domain == 'input_boolean' || domain == 'light' || domain == 'fan') {
            // ok
          } else {
            // fallback: try switch.toggle
            serviceDomain = 'switch';
          }
          try {
            await apiService.callService(serviceDomain, serviceName, {'entity_id': entityId});
          } catch (e) {
            DebugLogger.log('SwitchWidget: Error toggling $serviceDomain: $e');
          }
        }

        // Get active color based on theme
        final activeColor = colorScheme.primary;
        final activeBackgroundColor = isOn 
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.grey.withOpacity(0.1);
            
        if (isSmallWidget) {
          // Compact layout for small widgets
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: toggleSwitch,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: activeBackgroundColor,
                ),
                alignment: Alignment.center,
                child: Text(
                  isOn ? 'ON' : 'OFF',
                  style: themeData.textTheme.titleMedium?.copyWith(
                    color: isOn ? activeColor : null,
                    fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }

        // Regular layout for normal sized widgets
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: toggleSwitch,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: activeBackgroundColor,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Display a status icon based on the state
                  Icon(
                    isOn ? Icons.power_rounded : Icons.power_off_rounded,
                    size: 36,
                    color: isOn ? activeColor : colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  // Status text
                  Text(
                    isOn ? 'ON' : 'OFF',
                    style: themeData.textTheme.headlineSmall?.copyWith(
                      color: isOn ? activeColor : null,
                      fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
