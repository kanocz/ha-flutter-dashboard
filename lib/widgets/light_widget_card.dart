import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class LightWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService apiService;

  const LightWidgetCard({
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

        final isOn = currentState.state.toLowerCase() == 'on';
        final brightness = currentState.attributes['brightness'] as int? ?? 0;
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;
        
        // Function to toggle the light
        Future<void> toggleLight() async {
          if (isEditing || !isInteractive) return;
          
          if (isOn) {
            await apiService.turnOffLight(widget.entityId);
          } else {
            // If brightness is 0, set to 255 (100%) when turning on
            if (brightness == 0) {
              await apiService.turnOnLight(widget.entityId, brightness: 255);
            } else {
              await apiService.turnOnLight(widget.entityId);
            }
          }
        }

        // Get active color based on theme
        final activeColor = colorScheme.primary;
        final activeBackgroundColor = isOn 
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : Colors.grey.withOpacity(0.1);
            
        // For simplified view, show minimal controls
        if (useSimplifiedView || isSmallWidget) {
          return Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: activeBackgroundColor,
              ),
              child: Column(
                children: [
                  // Clickable area for toggle (top part)
                  Expanded(
                    child: InkWell(
                      onTap: toggleLight,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                              color: isOn ? activeColor : null,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                !isOn ? 'OFF' : brightness == 255 ? 'ON' : '${(brightness / 255 * 100).round()}%',
                                style: themeData.textTheme.bodyMedium?.copyWith(
                                  color: isOn ? activeColor : null,
                                  fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Slider area (always available)
                  _BrightnessSlider(
                    brightness: brightness,
                    activeColor: activeColor,
                    apiService: apiService,
                    entityId: widget.entityId,
                    isInteractive: isInteractive && !isEditing,
                  ),
                ],
              ),
            ),
          );
        }

        // Regular sized widget with controls
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: (isEditing || !isInteractive) ? null : toggleLight,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: activeBackgroundColor,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                      color: isOn ? activeColor : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      !isOn ? 'OFF' : brightness == 255 ? 'ON' : '${(brightness / 255 * 100).round()}%',
                      style: themeData.textTheme.titleMedium?.copyWith(
                        color: isOn ? activeColor : null,
                        fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Always show the brightness slider
            const SizedBox(height: 8),
            _BrightnessSlider(
              brightness: brightness,
              activeColor: isOn ? activeColor : Colors.grey,
              apiService: apiService,
              entityId: widget.entityId,
              isInteractive: isInteractive && !isEditing,
            ),
            StreamBuilder<EntityState>(
              initialData: entityState,
              stream: apiService.stateUpdateStream?.where(
                (state) => state.entityId == widget.entityId,
              ),
              builder: (context, snapshot) {
                final currentBrightness = snapshot.data?.attributes['brightness'] as int? ?? brightness;
                final currentIsOn = (snapshot.data?.state ?? (isOn ? 'on' : 'off')).toLowerCase() == 'on';
                return Text(
                  !currentIsOn ? 'OFF' : currentBrightness == 255 ? 'ON' : '${(currentBrightness / 255 * 100).round()}%',
                  style: themeData.textTheme.bodyMedium?.copyWith(
                    color: currentIsOn ? activeColor : Colors.grey,
                  ),
                );
              },
            ),
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

        final isOn = currentState.state.toLowerCase() == 'on';
        final brightness = currentState.attributes['brightness'] as int? ?? 0;
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;
        final activeColor = colorScheme.primary;
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Large ON/OFF toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOn ? colorScheme.primaryContainer : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: 48,
                    color: isOn ? activeColor : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    !isOn ? 'OFF' : brightness == 255 ? 'ON' : '${(brightness / 255 * 100).round()}%',
                    style: themeData.textTheme.titleLarge?.copyWith(
                      color: isOn ? activeColor : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: !isInteractive ? null : () async {
                      if (isOn) {
                        await apiService.turnOffLight(widget.entityId);
                      } else {
                        // If brightness is 0, set to 255 (100%) when turning on
                        if (brightness == 0) {
                          await apiService.turnOnLight(widget.entityId, brightness: 255);
                        } else {
                          await apiService.turnOnLight(widget.entityId);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOn ? Colors.red.shade700 : Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(isOn ? 'Turn Off' : 'Turn On'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Brightness controls
            Text(
              !isOn ? 'Brightness: OFF' : brightness == 255 ? 'Brightness: ON' : 'Brightness: ${(brightness / 255 * 100).round()}%',
              style: themeData.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.brightness_low, color: Colors.grey),
                Expanded(
                  child: _BrightnessSlider(
                    brightness: brightness,
                    activeColor: isOn ? activeColor : Colors.grey,
                    apiService: apiService,
                    entityId: widget.entityId,
                    isInteractive: isInteractive,
                  ),
                ),
                Icon(Icons.brightness_high, color: Colors.grey),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BrightnessSlider extends StatefulWidget {
  final int brightness;
  final Color activeColor;
  final HomeAssistantApiService apiService;
  final String entityId;
  final bool isInteractive;

  const _BrightnessSlider({
    required this.brightness,
    required this.activeColor,
    required this.apiService,
    required this.entityId,
    required this.isInteractive,
  });

  @override
  State<_BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<_BrightnessSlider> {
  late double _currentBrightness;
  bool _isDragging = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _currentBrightness = widget.brightness.toDouble();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_BrightnessSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update the slider value if we're not currently dragging
    if (!_isDragging && oldWidget.brightness != widget.brightness) {
      _currentBrightness = widget.brightness.toDouble();
    }
  }

  void _onSliderChanged(double value) {
    setState(() {
      _currentBrightness = value;
      _isDragging = true;
    });
    
    // Always allow slider interaction when the widget itself is interactive
    if (!widget.isInteractive) {
      return;
    }
    
    // Debounce the API calls during dragging to avoid too many requests
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (_isDragging) {
        // Always call turnOnLight with brightness - this will turn on the light if it's off
        widget.apiService.turnOnLight(widget.entityId, brightness: value);
      }
    });
  }

  void _onSliderChangeEnd(double value) {
    setState(() {
      _isDragging = false;
    });
    
    // Only proceed if the widget is interactive
    if (!widget.isInteractive) {
      return;
    }
    
    // Cancel any pending debounced call and send the final value immediately
    _debounceTimer?.cancel();
    
    if (value == 0) {
      // If brightness is 0, turn off the light
      widget.apiService.turnOffLight(widget.entityId);
    } else {
      // Otherwise, turn on the light with the specified brightness
      widget.apiService.turnOnLight(widget.entityId, brightness: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          thumbColor: widget.activeColor,
          activeTrackColor: widget.activeColor.withOpacity(0.8),
          inactiveTrackColor: widget.activeColor.withOpacity(0.2),
          trackHeight: 4,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
          valueIndicatorColor: widget.activeColor,
          showValueIndicator: ShowValueIndicator.onlyForDiscrete,
        ),
        child: Slider(
          value: _currentBrightness,
          min: 0,
          max: 255,
          divisions: null, // Remove divisions for smooth dragging
          onChanged: widget.isInteractive ? _onSliderChanged : null,
          onChangeEnd: widget.isInteractive ? _onSliderChangeEnd : null,
        ),
      ),
    );
  }
}
