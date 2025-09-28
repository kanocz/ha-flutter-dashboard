import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';

class DashboardConfig {
  final String version;
  final DateTime exportedAt;
  final String appName;
  final List<DashboardWidget> widgets;
  final Map<String, dynamic> metadata;

  DashboardConfig({
    required this.version,
    required this.exportedAt,
    required this.appName,
    required this.widgets,
    this.metadata = const {},
  });

  factory DashboardConfig.fromJson(Map<String, dynamic> json) {
    return DashboardConfig(
      version: json['version'] ?? '1.0.0',
      exportedAt: json['exportedAt'] != null 
          ? DateTime.parse(json['exportedAt']) 
          : DateTime.now(),
      appName: json['appName'] ?? 'Home Assistant Dashboard',
      widgets: (json['widgets'] as List<dynamic>?)
          ?.map((widget) => DashboardWidget.fromJson(widget as Map<String, dynamic>))
          .toList() ?? [],
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'appName': appName,
      'widgets': widgets.map((widget) => widget.toJson()).toList(),
      'metadata': metadata,
    };
  }

  DashboardConfig copyWith({
    String? version,
    DateTime? exportedAt,
    String? appName,
    List<DashboardWidget>? widgets,
    Map<String, dynamic>? metadata,
  }) {
    return DashboardConfig(
      version: version ?? this.version,
      exportedAt: exportedAt ?? this.exportedAt,
      appName: appName ?? this.appName,
      widgets: widgets ?? this.widgets,
      metadata: metadata ?? this.metadata,
    );
  }
}