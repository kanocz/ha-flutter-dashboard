import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';

/// Helper class for fetching and caching entity states for widgets in popups
class PopupGridHelper {
  /// Fetch entity states for widgets that aren't found in the current entityStates map
  static Future<void> fetchMissingEntityStates({
    required List<Map<String, dynamic>> widgets,
    required HomeAssistantApiService apiService,
    required Map<String, EntityState> entityStates,
    required Function(String entityId, EntityState state) onEntityStateLoaded,
  }) async {
    // Go through all widgets in the group
    for (int i = 0; i < widgets.length; i++) {
      final String? entityId = widgets[i]['entityId']?.toString();
      if (entityId != null && entityId.isNotEmpty) {
        // Check if it's already in the entityStates map
        if (!entityStates.containsKey(entityId)) {
          debugPrint('PopupGridHelper: Fetching state for $entityId');
          
          try {
            // Fetch state from Home Assistant
            final entityState = await apiService.getState(entityId);
            
            // Call the callback with the fetched state
            onEntityStateLoaded(entityId, entityState);
            debugPrint('PopupGridHelper: Successfully fetched state for $entityId: ${entityState.state}');
          } catch (e) {
            debugPrint('PopupGridHelper: Error fetching state for $entityId: $e');
          }
        }
      }
    }
  }
}
