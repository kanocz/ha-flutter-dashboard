import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/utils/format_helper.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class ClimateWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService apiService;

  const ClimateWidgetCard({
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
        
        if (currentState == null) {
          return const Center(
            child: Text('No data'),
          );
        }

        final isOn = currentState.state.toLowerCase() != 'off';
        final currentTemp = currentState.attributes['current_temperature'] as double? ?? 0.0;
        final targetTemp = currentState.attributes['temperature'] as double? ?? currentTemp;
        final minTemp = currentState.attributes['min_temp'] as double? ?? 15.0;
        final maxTemp = currentState.attributes['max_temp'] as double? ?? 30.0;
        final step = currentState.attributes['target_temp_step'] as double? ?? 0.5;
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;

        // Function to toggle the climate device
        Future<void> toggleClimate() async {
          if (isEditing || !isInteractive) return;
          
          if (isOn) {
            await apiService.turnOffClimate(widget.entityId);
          } else {
            await apiService.turnOnClimate(widget.entityId);
          }
        }

        // Get active color based on theme
        final activeColor = colorScheme.primary;
        final activeBackgroundColor = isOn 
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : Colors.grey.withOpacity(0.1);
            
        // For simplified view, just show the current temperature and status
        if (useSimplifiedView || isSmallWidget) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isInteractive ? toggleClimate : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: activeBackgroundColor,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        FormatHelper.formatTemperature(currentTemp),
                        style: themeData.textTheme.titleLarge?.copyWith(
                          color: isOn ? activeColor : null,
                          fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOn ? 'ON' : 'OFF',
                      style: themeData.textTheme.bodySmall?.copyWith(
                        color: isOn ? activeColor : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Regular layout for normal sized widgets
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: isInteractive ? toggleClimate : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: activeBackgroundColor,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOn ? Icons.power_rounded : Icons.power_off_rounded,
                      size: 20,
                      color: isOn ? activeColor : null,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOn ? 'ON' : 'OFF',
                      style: themeData.textTheme.bodyMedium?.copyWith(
                        color: isOn ? activeColor : null,
                        fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      'Current',
                      style: themeData.textTheme.bodySmall,
                    ),
                    Text(
                      FormatHelper.formatTemperature(currentTemp),
                      style: themeData.textTheme.titleMedium,
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Target',
                      style: themeData.textTheme.bodySmall,
                    ),
                    Text(
                      FormatHelper.formatTemperature(targetTemp),
                      style: themeData.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isOn) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: (isEditing || !isInteractive)
                        ? null
                        : () {
                            if (targetTemp > minTemp) {
                              apiService.setClimateTemperature(
                                  widget.entityId, targetTemp - step);
                            }
                          },
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbColor: activeColor,
                        activeTrackColor: activeColor.withOpacity(0.8),
                        inactiveTrackColor: activeColor.withOpacity(0.2),
                      ),
                      child: Slider(
                        value: targetTemp,
                        min: minTemp,
                        max: maxTemp,
                        divisions: ((maxTemp - minTemp) / step).round(),
                        label: FormatHelper.formatTemperature(targetTemp),
                        onChanged: (isEditing || !isInteractive)
                            ? null
                            : (value) {
                                apiService.setClimateTemperature(
                                    widget.entityId, value);
                              },
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: (isEditing || !isInteractive)
                        ? null
                        : () {
                            if (targetTemp < maxTemp) {
                              apiService.setClimateTemperature(
                                  widget.entityId, targetTemp + step);
                            }
                          },
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
  
  @override
  Widget buildDetailPopupContent(BuildContext context) {
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

        final isOn = currentState.state.toLowerCase() != 'off';
        final currentTemp = currentState.attributes['current_temperature'] as double? ?? 0.0;
        final targetTemp = currentState.attributes['temperature'] as double? ?? currentTemp;
        final minTemp = currentState.attributes['min_temp'] as double? ?? 15.0;
        final maxTemp = currentState.attributes['max_temp'] as double? ?? 30.0;
        final step = currentState.attributes['target_temp_step'] as double? ?? 0.5;
        final hvacMode = currentState.attributes['hvac_mode']?.toString() ?? (isOn ? 'heat' : 'off');
        final hvacModes = currentState.attributes['hvac_modes'] as List<dynamic>? ?? ['heat', 'cool', 'off'];
        
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;
        final activeColor = colorScheme.primary;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current temperature display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOn ? colorScheme.primaryContainer : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Temperature',
                            style: themeData.textTheme.titleSmall?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            FormatHelper.formatTemperature(currentTemp),
                            style: themeData.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: isOn,
                        onChanged: isInteractive ? (value) async {
                          if (value) {
                            await apiService.turnOnClimate(widget.entityId);
                          } else {
                            await apiService.turnOffClimate(widget.entityId);
                          }
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Target temperature controls
            Text(
              'Target Temperature',
              style: themeData.textTheme.titleMedium,
            ),
            Text(
              FormatHelper.formatTemperature(targetTemp),
              style: themeData.textTheme.headlineMedium?.copyWith(
                color: isOn ? activeColor : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbColor: isOn ? activeColor : Colors.grey,
                activeTrackColor: isOn ? activeColor.withOpacity(0.8) : Colors.grey.withOpacity(0.4),
                inactiveTrackColor: isOn ? activeColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              ),
              child: Slider(
                value: targetTemp,
                min: minTemp,
                max: maxTemp,
                divisions: ((maxTemp - minTemp) / step).round(),
                label: FormatHelper.formatTemperature(targetTemp),
                onChanged: (isOn && isInteractive) 
                  ? (value) {
                      apiService.setClimateTemperature(widget.entityId, value);
                    }
                  : null,
              ),
            ),
            
            // Show min/max temperature range
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Min: ${FormatHelper.formatTemperature(minTemp)}',
                    style: themeData.textTheme.bodyMedium,
                  ),
                  Text(
                    'Max: ${FormatHelper.formatTemperature(maxTemp)}',
                    style: themeData.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Mode controls
            if (hvacModes.isNotEmpty && hvacModes.length > 1) ...[
              Text(
                'Mode',
                style: themeData.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: hvacModes.map<Widget>((mode) {
                  final isActive = mode.toString() == hvacMode;
                  
                  // Skip 'off' as we handle that with the switch
                  if (mode.toString() == 'off') {
                    return const SizedBox.shrink();
                  }
                  
                  String modeName;
                  IconData modeIcon;
                  
                  switch (mode.toString()) {
                    case 'heat':
                      modeName = 'Heat';
                      modeIcon = Icons.whatshot;
                      break;
                    case 'cool':
                      modeName = 'Cool';
                      modeIcon = Icons.ac_unit;
                      break;
                    case 'heat_cool':
                      modeName = 'Auto';
                      modeIcon = Icons.autorenew;
                      break;
                    case 'dry':
                      modeName = 'Dry';
                      modeIcon = Icons.water_drop;
                      break;
                    case 'fan_only':
                      modeName = 'Fan';
                      modeIcon = Icons.cyclone;
                      break;
                    default:
                      modeName = mode.toString().replaceFirst(mode.toString()[0], mode.toString()[0].toUpperCase());
                      modeIcon = Icons.settings;
                      break;
                  }
                  
                  return ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          modeIcon,
                          size: 18,
                          color: isActive ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(modeName),
                      ],
                    ),
                    selected: isActive,
                    onSelected: isInteractive ? (selected) {
                      if (selected && isOn) {
                        // Call service to set mode
                        apiService.callService(
                          'climate',
                          'set_hvac_mode',
                          {
                            'entity_id': widget.entityId,
                            'hvac_mode': mode,
                          },
                        );
                      } else if (selected && !isOn) {
                        // Turn on first, then set mode
                        apiService.turnOnClimate(widget.entityId).then((_) {
                          apiService.callService(
                            'climate',
                            'set_hvac_mode',
                            {
                              'entity_id': widget.entityId,
                              'hvac_mode': mode,
                            },
                          );
                        });
                      }
                    } : null,
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
