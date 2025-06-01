import 'package:ha_flutter_dashboard/config/constants.dart';

class DashboardWidget {
  final String id;
  final String type;
  final String entityId;
  final String caption;
  final String icon;
  final Map<String, dynamic> config;
  final int row;
  final int column;
  final double widthPx;
  final double heightPx;
  final double positionX;
  final double positionY;
  
  // Helper getters for config values
  bool get useSimplifiedView => config[AppConstants.configUseSimplifiedView] ?? false;
  bool get isProtected => config[AppConstants.configProtected] ?? false;

  // For backward compatibility with old code, provide width/height as grid cell count (rounded from px)
  int get width => (widthPx / 100).round();
  int get height => (heightPx / 100).round();

  DashboardWidget({
    required this.id,
    required this.type,
    required this.entityId,
    required this.caption,
    required this.icon,
    required this.config,
    required this.row,
    required this.column,
    double? widthPx,
    double? heightPx,
    this.positionX = 0.0,
    this.positionY = 0.0,
    int? width,
    int? height,
  })  : widthPx = widthPx ?? ((width ?? 1) * 100.0),
        heightPx = heightPx ?? ((height ?? 1) * 100.0);

  factory DashboardWidget.fromJson(Map<String, dynamic> json) {
    return DashboardWidget(
      id: json['id'],
      type: json['type'],
      entityId: json['entityId'] ?? '',
      caption: json['caption'],
      icon: json['icon'],
      config: json['config'] ?? {},
      row: json['row'] ?? 0,
      column: json['column'] ?? 0,
      widthPx: (json['widthPx'] ?? ((json['width'] ?? 1) * 100.0)).toDouble(),
      heightPx: (json['heightPx'] ?? ((json['height'] ?? 1) * 100.0)).toDouble(),
      positionX: (json['positionX'] ?? 0.0).toDouble(),
      positionY: (json['positionY'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'entityId': entityId,
      'caption': caption,
      'icon': icon,
      'config': config,
      'row': row,
      'column': column,
      'widthPx': widthPx,
      'heightPx': heightPx,
      'positionX': positionX,
      'positionY': positionY,
    };
  }

  DashboardWidget copyWith({
    String? id,
    String? type,
    String? entityId,
    String? caption,
    String? icon,
    Map<String, dynamic>? config,
    int? row,
    int? column,
    double? widthPx,
    double? heightPx,
    double? positionX,
    double? positionY,
  }) {
    return DashboardWidget(
      id: id ?? this.id,
      type: type ?? this.type,
      entityId: entityId ?? this.entityId,
      caption: caption ?? this.caption,
      icon: icon ?? this.icon,
      config: config ?? this.config,
      row: row ?? this.row,
      column: column ?? this.column,
      widthPx: widthPx ?? this.widthPx,
      heightPx: heightPx ?? this.heightPx,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
    );
  }
}
