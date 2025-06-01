import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class LockWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService apiService;

  const LockWidgetCard({
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
        
        final isLocked = currentState.state.toLowerCase() == 'locked';
        final themeData = Theme.of(context);
        final lockedColor = Colors.red.shade700;
        final unlockedColor = Colors.green.shade600;
        
        if (isSmallWidget) {
          // Simplified layout for small widgets
          return Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isLocked 
                    ? lockedColor.withOpacity(0.2) 
                    : unlockedColor.withOpacity(0.2),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLocked ? Icons.lock : Icons.lock_open,
                    size: 20,
                    color: isLocked ? lockedColor : unlockedColor,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isLocked ? 'LOCKED' : 'UNLOCKED',
                      style: themeData.textTheme.bodySmall?.copyWith(
                        color: isLocked ? lockedColor : unlockedColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Mini toggle for small widget
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isLocked,
                      onChanged: isEditing || !isInteractive ? null : (value) async {
                        if (value) {
                          await apiService.lockLock(widget.entityId);
                        } else {
                          await apiService.unlockLock(widget.entityId);
                        }
                      },
                      activeColor: lockedColor,
                      inactiveThumbColor: unlockedColor,
                      inactiveTrackColor: unlockedColor.withOpacity(0.3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Normal sized widget with more details and controls
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocked ? Icons.lock : Icons.lock_open,
              size: 40,
              color: isLocked ? lockedColor : unlockedColor,
            ),
            const SizedBox(height: 8),
            Text(
              isLocked ? 'LOCKED' : 'UNLOCKED',
              style: themeData.textTheme.titleMedium?.copyWith(
                color: isLocked ? lockedColor : unlockedColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Toggle switch for lock/unlock
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Unlock',
                  style: themeData.textTheme.bodyMedium?.copyWith(
                    color: !isLocked ? unlockedColor : Colors.grey,
                    fontWeight: !isLocked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: isLocked,
                  onChanged: isEditing || !isInteractive ? null : (value) async {
                    if (value) {
                      await apiService.lockLock(widget.entityId);
                    } else {
                      await apiService.unlockLock(widget.entityId);
                    }
                  },
                  activeColor: lockedColor,
                  inactiveThumbColor: unlockedColor,
                  inactiveTrackColor: unlockedColor.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  'Lock',
                  style: themeData.textTheme.bodyMedium?.copyWith(
                    color: isLocked ? lockedColor : Colors.grey,
                    fontWeight: isLocked ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Open button
            ElevatedButton.icon(
              onPressed: isEditing || !isInteractive ? null : () async {
                await apiService.openLock(widget.entityId);
              },
              icon: const Icon(Icons.door_front_door),
              label: const Text('Open'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        );
      },
    );
  }
}
