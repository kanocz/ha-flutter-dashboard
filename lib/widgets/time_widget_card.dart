import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/services/home_assistant_api_service.dart';
import 'package:ha_flutter_dashboard/utils/format_helper.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';
import 'package:intl/intl.dart';

class TimeWidgetCard extends BaseWidgetCard {
  final HomeAssistantApiService? apiService; // Optional as time widget doesn't require API integration

  const TimeWidgetCard({
    Key? key,
    required DashboardWidget widget,
    this.apiService,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    bool isEditing = false,
    bool isInteractive = true,
  }) : super(
          key: key,
          widget: widget,
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
    return _TimeWidgetContent(
      showSeconds: widget.config['showSeconds'] ?? false,
      isSmallWidget: isSmallWidget,
    );
  }
}

class _TimeWidgetContent extends StatefulWidget {
  final bool showSeconds;
  final bool isSmallWidget;

  const _TimeWidgetContent({
    required this.showSeconds,
    this.isSmallWidget = false,
  });

  @override
  State<_TimeWidgetContent> createState() => _TimeWidgetContentState();
}

class _TimeWidgetContentState extends State<_TimeWidgetContent> {
  late DateTime _currentTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    // Update every second or minute based on if we're showing seconds
    final updateInterval = widget.showSeconds ? const Duration(seconds: 1) : const Duration(minutes: 1);
    
    _timer = Timer.periodic(updateInterval, (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = widget.showSeconds ? 'HH:mm:ss' : 'HH:mm';
    final formatter = DateFormat(timeFormat);
    
    if (widget.isSmallWidget) {
      // Small 1x1 widget layout - show only time and optimize space
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              formatter.format(_currentTime),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    
    // Regular widget layout - maximize space since we hide icon and title
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatter.format(_currentTime),
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              DateFormat('E, MMM d, yyyy').format(_currentTime),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
