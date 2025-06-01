import 'dart:convert';

import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/home_assistant_instance.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class StorageService {
  late SharedPreferences _prefs;
  late Box _widgetsBox;
  
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await Hive.initFlutter();
    _widgetsBox = await Hive.openBox('widgets');
  }
  
  // Theme Mode
  ThemeMode getThemeMode() {
    final value = _prefs.getString(AppConstants.keyThemeMode);
    
    if (value == ThemeMode.dark.toString()) {
      return ThemeMode.dark;
    } else if (value == ThemeMode.light.toString()) {
      return ThemeMode.light;
    } else {
      return ThemeMode.system;
    }
  }
  
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode.toString());
  }
  
  // Password Protection
  bool isPasswordProtectionEnabled() {
    return _prefs.getBool(AppConstants.keyEditPasswordEnabled) ?? false;
  }
  
  Future<void> setPasswordProtectionEnabled(bool value) async {
    await _prefs.setBool(AppConstants.keyEditPasswordEnabled, value);
  }
  
  bool isPasswordSet() {
    return _prefs.getString(AppConstants.keyEditPassword)?.isNotEmpty ?? false;
  }
  
  String? getStoredPasswordHash() {
    return _prefs.getString(AppConstants.keyEditPassword);
  }
  
  Future<void> setPassword(String password) async {
    String passwordHash = _hashPassword(password);
    await _prefs.setString(AppConstants.keyEditPassword, passwordHash);
  }
  
  bool verifyPassword(String password) {
    String? storedHash = getStoredPasswordHash();
    if (storedHash == null) return true; // No password set
    
    String inputHash = _hashPassword(password);
    return storedHash == inputHash;
  }
  
  String _hashPassword(String password) {
    // Simple SHA-256 hashing for password
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // PIN Management
  bool verifyPin(String pin) {
    // Reuse the existing password verification mechanism for simplicity
    return verifyPassword(pin);
  }
  
  Future<void> setPin(String pin) async {
    // Reuse the existing password setting mechanism
    await setPassword(pin);
  }
  
  // Dashboard Locking
  bool isDashboardLocked() {
    return _prefs.getBool(AppConstants.keyDashboardLocked) ?? true;
  }
  
  Future<void> setDashboardLocked(bool value) async {
    await _prefs.setBool(AppConstants.keyDashboardLocked, value);
  }
  
  bool isAutoLockEnabled() {
    return _prefs.getBool(AppConstants.keyAutoLockEnabled) ?? true;
  }
  
  Future<void> setAutoLockEnabled(bool value) async {
    await _prefs.setBool(AppConstants.keyAutoLockEnabled, value);
  }

  // Screensaver Settings
  int getScreensaverTimeout() {
    return _prefs.getInt(AppConstants.keyScreensaverTimeout) ?? AppConstants.screensaverDisabled;
  }

  Future<void> setScreensaverTimeout(int timeoutMs) async {
    await _prefs.setInt(AppConstants.keyScreensaverTimeout, timeoutMs);
  }

  bool isScreensaverEnabled() {
    return getScreensaverTimeout() > 0;
  }
  
  // Grid Dimensions
  Map<String, int> getGridDimensions() {
    final String? jsonData = _prefs.getString(AppConstants.keyGridDimensions);
    
    if (jsonData == null) {
      return {
        'portraitColumns': AppConstants.defaultGridWidthPortrait,
        'portraitRows': AppConstants.defaultGridHeightPortrait,
        'landscapeColumns': AppConstants.defaultGridWidthLandscape,
        'landscapeRows': AppConstants.defaultGridHeightLandscape,
      };
    }
    
    try {
      final Map<String, dynamic> data = jsonDecode(jsonData);
      return {
        'portraitColumns': data['portraitColumns'] as int? ?? AppConstants.defaultGridWidthPortrait,
        'portraitRows': data['portraitRows'] as int? ?? AppConstants.defaultGridHeightPortrait,
        'landscapeColumns': data['landscapeColumns'] as int? ?? AppConstants.defaultGridWidthLandscape,
        'landscapeRows': data['landscapeRows'] as int? ?? AppConstants.defaultGridHeightLandscape,
      };
    } catch (e) {
      return {
        'portraitColumns': AppConstants.defaultGridWidthPortrait,
        'portraitRows': AppConstants.defaultGridHeightPortrait,
        'landscapeColumns': AppConstants.defaultGridWidthLandscape,
        'landscapeRows': AppConstants.defaultGridHeightLandscape,
      };
    }
  }
  
  Future<void> setGridDimensions({
    required int portraitColumns,
    required int portraitRows,
    required int landscapeColumns,
    required int landscapeRows,
  }) async {
    final Map<String, dynamic> data = {
      'portraitColumns': portraitColumns,
      'portraitRows': portraitRows,
      'landscapeColumns': landscapeColumns,
      'landscapeRows': landscapeRows,
    };
    
    await _prefs.setString(AppConstants.keyGridDimensions, jsonEncode(data));
  }
  
  // Orientation lock
  static const String keyOrientationLock = "orientation_lock"; // "portrait", "landscape", or "system"

  String getOrientationLock() {
    return _prefs.getString(keyOrientationLock) ?? "landscape";
  }

  Future<void> setOrientationLock(String value) async {
    await _prefs.setString(keyOrientationLock, value);
  }

  // Fullscreen Mode
  static const String keyFullscreenMode = "fullscreen_mode";

  bool isFullscreenModeEnabled() {
    return _prefs.getBool(keyFullscreenMode) ?? false;
  }

  Future<void> setFullscreenModeEnabled(bool value) async {
    await _prefs.setBool(keyFullscreenMode, value);
  }
  
  // WebSocket message timeout
  int getWebsocketMessageTimeout() {
    return _prefs.getInt(AppConstants.keyWebsocketMessageTimeout) ?? AppConstants.defaultWebsocketMessageTimeoutMs;
  }
  
  Future<void> setWebsocketMessageTimeout(int milliseconds) async {
    await _prefs.setInt(AppConstants.keyWebsocketMessageTimeout, milliseconds);
  }

  // Home Assistant Instances
  List<HomeAssistantInstance> getHomeAssistantInstances() {
    final String? jsonList = _prefs.getString(AppConstants.keyHaInstances);
    
    if (jsonList == null) return [];
    
    final List<dynamic> decoded = jsonDecode(jsonList);
    return decoded.map((item) => HomeAssistantInstance.fromJson(item)).toList();
  }
  
  Future<void> saveHomeAssistantInstances(List<HomeAssistantInstance> instances) async {
    final String jsonList = jsonEncode(instances.map((i) => i.toJson()).toList());
    await _prefs.setString(AppConstants.keyHaInstances, jsonList);
  }
  
  // Selected Home Assistant Instance
  String? getSelectedHomeAssistantInstanceId() {
    return _prefs.getString(AppConstants.keySelectedHaInstance);
  }
  
  Future<void> setSelectedHomeAssistantInstanceId(String id) async {
    await _prefs.setString(AppConstants.keySelectedHaInstance, id);
  }
  
  // Long Term Token
  String? getLongTermToken() {
    return _prefs.getString(AppConstants.keyLongTermToken);
  }
  
  Future<void> setLongTermToken(String token) async {
    await _prefs.setString(AppConstants.keyLongTermToken, token);
  }
  
  // Is Launcher
  bool isLauncher() {
    return _prefs.getBool(AppConstants.keyIsLauncher) ?? false;
  }
  
  Future<void> setIsLauncher(bool value) async {
    await _prefs.setBool(AppConstants.keyIsLauncher, value);
  }
  
  // Dashboard Widgets
  List<DashboardWidget> getDashboardWidgets() {
    final Map<dynamic, dynamic> widgets = _widgetsBox.toMap();
    
    final List<DashboardWidget> widgetList = widgets.values
        .map((item) {
          if (item is DashboardWidget) return item;
          
          try {
            // Convert the Map<dynamic, dynamic> to Map<String, dynamic>
            final Map<String, dynamic> convertedMap = {};
            
            if (item is Map) {
              item.forEach((key, value) {
                String keyStr = key.toString();
                
                // Handle nested maps (e.g., config)
                if (value is Map) {
                  Map<String, dynamic> nestedMap = {};
                  value.forEach((nestedKey, nestedValue) {
                    nestedMap[nestedKey.toString()] = nestedValue;
                  });
                  convertedMap[keyStr] = nestedMap;
                } else {
                  convertedMap[keyStr] = value;
                }
              });
              
              return DashboardWidget.fromJson(convertedMap);
            }
          } catch (e, st) {
            debugPrint('StorageService: Error converting widget data: $e');
            debugPrint(st.toString());
          }
          
          throw Exception('Invalid widget data type: ${item.runtimeType}');
        })
        .toList();
    
    // Sort widgets by row position
    widgetList.sort((a, b) => a.row.compareTo(b.row));
    
    return widgetList;
  }
  
  Future<void> saveDashboardWidget(DashboardWidget widget) async {
    await _widgetsBox.put(widget.id, widget.toJson());
  }
  
  Future<void> deleteDashboardWidget(String id) async {
    await _widgetsBox.delete(id);
  }
  
  Future<void> clearAllDashboardWidgets() async {
    await _widgetsBox.clear();
  }
}
