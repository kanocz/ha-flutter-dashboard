import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class BlindWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService apiService;

  const BlindWidgetCard({
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

        final position = currentState.attributes['current_position'] as int? ?? 0;
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;

        // Define the state for visual representation
        final stateText = currentState.state.toUpperCase();
        final isOpen = currentState.state.toLowerCase() == 'open';
        final isClosed = currentState.state.toLowerCase() == 'closed';
        final isMoving = !isOpen && !isClosed;

        final stateColor = isOpen
            ? Colors.green
            : isClosed
                ? Colors.grey
                : colorScheme.primary;
        
        // Simplified UI for simplified view or small widgets
        if (useSimplifiedView || isSmallWidget) {
          return Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isMoving 
                    ? colorScheme.primaryContainer.withOpacity(0.3)
                    : Colors.transparent,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show blind icon representing current state
                  Icon(
                    isOpen 
                        ? Icons.vertical_align_top
                        : isClosed
                            ? Icons.vertical_align_bottom
                            : Icons.swap_vert,
                    size: 28,
                    color: stateColor,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // State text
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      stateText,
                      style: themeData.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: stateColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  // Position indicator
                  if (currentState.attributes.containsKey('current_position')) ...[
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.grey[300],
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: position / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: stateColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  // Minimal controls if there's space
                  if (!isSmallWidget) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(2),
                          iconSize: 18,
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: (isEditing || !isInteractive) ? null : () async {
                            await apiService.openBlind(widget.entityId);
                          },
                          tooltip: 'Open',
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(2),
                          iconSize: 18,
                          icon: const Icon(Icons.stop),
                          onPressed: (isEditing || !isInteractive) ? null : () async {
                            await apiService.stopBlind(widget.entityId);
                          },
                          tooltip: 'Stop',
                        ),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(2),
                          iconSize: 18,
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: (isEditing || !isInteractive) ? null : () async {
                            await apiService.closeBlind(widget.entityId);
                          },
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        
        // Standard layout for normal sized widgets
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              currentState.state,
              style: themeData.textTheme.bodyLarge?.copyWith(
                color: stateColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: (isEditing || !isInteractive)
                      ? null
                      : () async {
                          await apiService.openBlind(widget.entityId);
                        },
                  tooltip: 'Open',
                ),
                IconButton(
                  icon: const Icon(Icons.stop),
                  onPressed: (isEditing || !isInteractive)
                      ? null
                      : () async {
                          await apiService.stopBlind(widget.entityId);
                        },
                  tooltip: 'Stop',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: (isEditing || !isInteractive)
                      ? null
                      : () async {
                          await apiService.closeBlind(widget.entityId);
                        },
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (currentState.attributes.containsKey('current_position')) ...[
              Slider(
                value: position.toDouble(),
                min: 0,
                max: 100,
                divisions: 10,
                label: '$position%',
                onChanged: (isEditing || !isInteractive)
                    ? null
                    : (value) {
                        apiService.setBlindPosition(widget.entityId, value.round());
                      },
              ),
              Text('Position: $position%'),
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

        final position = currentState.attributes['current_position'] as int? ?? 0;
        final themeData = Theme.of(context);
        final colorScheme = themeData.colorScheme;

        // Define the state for visual representation
        final stateText = currentState.state;
        final isOpen = currentState.state.toLowerCase() == 'open';
        final isClosed = currentState.state.toLowerCase() == 'closed';
        final isMoving = !isOpen && !isClosed;

        final stateColor = isOpen
            ? Colors.green
            : isClosed
                ? Colors.grey
                : colorScheme.primary;
        
        // Create a visual representation of the blind position
        Widget buildBlindVisual() {
          return Container(
            height: 150,
            width: 100,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                // Background (window)
                Container(
                  color: Colors.blue[50],
                ),
                // Blind slats animation
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: (100 - position) / 100 * 150,
                  child: Container(
                    color: Colors.grey[300],
                    child: Column(
                      children: List.generate(
                        20,
                        (index) => Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[400]!,
                                  width: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isMoving 
                    ? colorScheme.primaryContainer
                    : isOpen
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Status: ',
                    style: themeData.textTheme.titleMedium,
                  ),
                  Text(
                    stateText,
                    style: themeData.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: stateColor,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Visual and position controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visual representation
                buildBlindVisual(),
                
                // Controls
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('Open'),
                      onPressed: !isInteractive ? null : () async {
                        await apiService.openBlind(widget.entityId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      onPressed: !isInteractive ? null : () async {
                        await apiService.stopBlind(widget.entityId);
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('Close'),
                      onPressed: !isInteractive ? null : () async {
                        await apiService.closeBlind(widget.entityId);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Position slider
            if (currentState.attributes.containsKey('current_position')) ...[
              Text(
                'Position: $position%',
                style: themeData.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Closed', style: themeData.textTheme.bodySmall),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: stateColor,
                        inactiveTrackColor: Colors.grey[300],
                        thumbColor: stateColor,
                      ),
                      child: Slider(
                        value: position.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '$position%',
                        onChanged: !isInteractive ? null : (value) {
                          apiService.setBlindPosition(widget.entityId, value.round());
                        },
                      ),
                    ),
                  ),
                  Text('Open', style: themeData.textTheme.bodySmall),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Preset positions if the device supports it
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: !isInteractive ? null : () {
                    apiService.setBlindPosition(widget.entityId, 0);
                  },
                  child: const Text('0%'),
                ),
                ElevatedButton(
                  onPressed: !isInteractive ? null : () {
                    apiService.setBlindPosition(widget.entityId, 25);
                  },
                  child: const Text('25%'),
                ),
                ElevatedButton(
                  onPressed: !isInteractive ? null : () {
                    apiService.setBlindPosition(widget.entityId, 50);
                  },
                  child: const Text('50%'),
                ),
                ElevatedButton(
                  onPressed: !isInteractive ? null : () {
                    apiService.setBlindPosition(widget.entityId, 75);
                  },
                  child: const Text('75%'),
                ),
                ElevatedButton(
                  onPressed: !isInteractive ? null : () {
                    apiService.setBlindPosition(widget.entityId, 100);
                  },
                  child: const Text('100%'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
