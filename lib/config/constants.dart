class AppConstants {
  // Home Assistant API
  static const String haApiVersion = "8";
  static const String haDiscoveryUrl = "_home-assistant._tcp.local";
  static const int haDiscoveryPort = 5353;
  
  // Local Storage Keys
  static const String keyHaInstances = "ha_instances";
  static const String keySelectedHaInstance = "selected_ha_instance";
  static const String keyLongTermToken = "ha_long_term_token";
  static const String keyThemeMode = "theme_mode";
  static const String keyWidgets = "dashboard_widgets";
  static const String keyIsLauncher = "is_launcher";
  static const String keyGridDimensions = "grid_dimensions";
  static const String keyEditPassword = "edit_password";
  static const String keyEditPasswordEnabled = "edit_password_enabled";
  static const String keyDashboardLocked = "dashboard_locked";
  static const String keyAutoLockEnabled = "auto_lock_enabled";
  static const String keyWebsocketMessageTimeout = "websocket_message_timeout";
  static const String keyScreensaverTimeout = "screensaver_timeout";
  
  // Widget Types
  static const String widgetTypeTime = "time";
  static const String widgetTypeLight = "light";
  static const String widgetTypeSwitch = "switch";
  static const String widgetTypeBlind = "blind";
  static const String widgetTypeLock = "lock";
  static const String widgetTypeClimate = "climate";
  static const String widgetTypeStatic = "static";
  static const String widgetTypeSeparator = "separator";
  static const String widgetTypeLabel = "label";
  static const String widgetTypeRtspVideo = "rtsp_video";
  static const String widgetTypeGroup = "group"; // Group widget type
  
  // Widget Config Keys
  static const String configUseSimplifiedView = "useSimplifiedView";
  static const String configShowSeconds = "showSeconds";
  static const String configSeparatorStyle = "separatorStyle";
  static const String configSeparatorColor = "separatorColor";
  static const String configLabelSize = "labelSize";
  static const String configLabelAlign = "labelAlign";
  static const String configLabelBold = "labelBold";
  static const String configLabelItalic = "labelItalic";
  static const String configProtected = "protected";
  
  // Default Grid Dimensions
  static const int defaultGridWidthPortrait = 4;
  static const int defaultGridHeightPortrait = 6;
  static const int defaultGridWidthLandscape = 6;
  static const int defaultGridHeightLandscape = 4;
  
  // Auto-lock timeout in milliseconds (3 minutes)
  static const int autoLockTimeoutMs = 3 * 60 * 1000; 
  
  // Screensaver timeout options in milliseconds
  static const int screensaverDisabled = 0;
  static const int screensaver1Minute = 60 * 1000;
  static const int screensaver2Minutes = 2 * 60 * 1000;
  static const int screensaver5Minutes = 5 * 60 * 1000;
  static const int screensaver10Minutes = 10 * 60 * 1000;
  
  // Websocket default settings
  static const int defaultWebsocketReconnectDelayMs = 10000; // 10 seconds
  static const int defaultWebsocketMessageTimeoutMs = 15000; // 15 seconds
}
