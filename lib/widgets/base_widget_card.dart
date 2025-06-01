import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/utils/icon_helper.dart';

abstract class BaseWidgetCard extends StatelessWidget {
  final DashboardWidget widget;
  final EntityState? entityState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isEditing;
  final bool isInteractive;
  
  const BaseWidgetCard({
    Key? key,
    required this.widget,
    this.entityState,
    this.onTap,
    this.onLongPress,
    this.isEditing = false,
    this.isInteractive = true,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Determine if this is a small widget (1x1)
    final isSmallWidget = widget.width == 1 && widget.height == 1;
    
    // Special case for clock widget - hide title and icon for more space
    final bool isClockWidget = widget.type == 'time';
    
    // Determine if we should use simplified view
    final bool useSimplifiedView = widget.useSimplifiedView;
    
    // Determine if header should be shown
    final bool showHeader = !isClockWidget && 
        (!isSmallWidget || (widget.caption.isNotEmpty && !useSimplifiedView));
    
    // Get the widget type to determine if we should support popup details
    final String widgetType = widget.type;
    final bool supportsDetailPopup = widgetType == 'light' || 
                                     widgetType == 'blind' || 
                                     widgetType == 'climate';
    
    return Card(
      child: InkWell(
        // Only respond to taps if widget is interactive (not protected or dashboard not locked)
        onTap: isInteractive ? onTap : null,
        onLongPress: supportsDetailPopup && !isEditing ?
          () => _showDetailPopup(context) : onLongPress,
        child: Container(
          padding: isSmallWidget || useSimplifiedView ? 
            const EdgeInsets.all(6) : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isEditing ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader)
                Row(
                  children: [
                    Icon(
                      IconHelper.getIconData(widget.icon),
                      size: isSmallWidget || useSimplifiedView ? 14 : 24,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.caption,
                        style: (isSmallWidget || useSimplifiedView)
                            ? Theme.of(context).textTheme.bodySmall
                            : Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (showHeader)
                SizedBox(height: isSmallWidget || useSimplifiedView ? 2 : 8),
              Expanded(
                child: buildWidgetContent(
                  context, 
                  isSmallWidget: isSmallWidget,
                  useSimplifiedView: useSimplifiedView,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show a popup with the detailed widget controls
  void _showDetailPopup(BuildContext context) {
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(
            minWidth: 300,
            maxWidth: 400,
            minHeight: 200,
            maxHeight: 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and icon
              Row(
                children: [
                  Icon(
                    IconHelper.getIconData(widget.icon),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.caption,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              // Widget content with full controls
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: buildDetailPopupContent(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Must be implemented by subclasses to build the widget content
  // isSmallWidget parameter indicates if the widget is a small 1x1 size
  // useSimplifiedView parameter indicates if the widget should use simplified controls
  Widget buildWidgetContent(
    BuildContext context, {
    bool isSmallWidget = false,
    bool useSimplifiedView = false,
  });
  
  // Can be overridden by subclasses to build detailed popup content
  Widget buildDetailPopupContent(BuildContext context) {
    // By default, use the regular widget content but with full size
    return buildWidgetContent(context, isSmallWidget: false, useSimplifiedView: false);
  }
}
