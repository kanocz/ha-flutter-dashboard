import 'package:flutter/material.dart';

/// Helper class for dealing with group widget persistence
class GroupWidgetHelper {
  
  /// Makes sure the group widget data structure is consistent and properly formed
  static List<Map<String, dynamic>> sanitizeGroupWidgets(dynamic groupWidgetsInput) {
    final List<Map<String, dynamic>> cleanList = [];
    
    // If null or wrong type, return empty list
    if (groupWidgetsInput == null) {
      debugPrint('GroupWidgetHelper: Input was null');
      return cleanList;
    }
    
    // Handle different input types (better robustness)
    List<dynamic> inputList;
    
    if (groupWidgetsInput is List) {
      inputList = groupWidgetsInput;
    } else if (groupWidgetsInput is Map && groupWidgetsInput.containsKey('groupWidgets') && groupWidgetsInput['groupWidgets'] is List) {
      // Sometimes we get the entire config map instead of just the groupWidgets list
      inputList = groupWidgetsInput['groupWidgets'] as List;
    } else {
      debugPrint('GroupWidgetHelper: Input was not a List or properly formatted Map: ${groupWidgetsInput.runtimeType}');
      return cleanList;
    }
    
    // Debug the input
    debugPrint('GroupWidgetHelper: Processing ${inputList.length} widgets from input');
    
    // Convert each item ensuring it has all required fields
    for (final dynamic item in inputList) {
      if (item is Map) {
        try {
          // Ensure all required fields exist with defaults
          // Create a cleaned and properly typed widget map
          final Map<String, dynamic> cleanWidget = {
            'id': item['id']?.toString() ?? '',
            'type': item['type']?.toString() ?? '',
            'entityId': item['entityId']?.toString() ?? '',
            'caption': item['caption']?.toString() ?? '',
            'icon': item['icon']?.toString() ?? '',
            'config': item['config'] != null 
                ? Map<String, dynamic>.from(item['config']) 
                : <String, dynamic>{},
            'positionX': _ensureDouble(item['positionX'], 0.0),
            'positionY': _ensureDouble(item['positionY'], 0.0),
            'widthPx': _ensureDouble(item['widthPx'], 100.0), 
            'heightPx': _ensureDouble(item['heightPx'], 100.0),
          };
          
          // Only add if we have at least id and type
          if (cleanWidget['id'].toString().isNotEmpty && 
              cleanWidget['type'].toString().isNotEmpty) {
            cleanList.add(cleanWidget);
          } else {
            debugPrint('GroupWidgetHelper: Skipping widget with empty id or type');
          }
        } catch (e) {
          debugPrint('GroupWidgetHelper: Error sanitizing widget: $e');
        }
      }
    }
    
    debugPrint('GroupWidgetHelper: Sanitized ${cleanList.length} widgets');
    return cleanList;
  }
  
  /// Ensures the value is a double, with a default fallback
  static double _ensureDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}
