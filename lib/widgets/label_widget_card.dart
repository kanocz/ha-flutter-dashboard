import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/utils/icon_helper.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class LabelWidgetCard extends BaseWidgetCard {
  const LabelWidgetCard({
    Key? key,
    required DashboardWidget widget,
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
  Widget build(BuildContext context) {
    // Override the build method to hide the header and only show the content
    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isEditing ? Border.all(color: Colors.blue, width: 2) : null,
          ),
          child: buildWidgetContent(context),
        ),
      ),
    );
  }

  @override
  Widget buildWidgetContent(
    BuildContext context, {
    bool isSmallWidget = false,
    bool useSimplifiedView = false,
  }) {
    // Get label configuration from widget config
    final labelSize = widget.config[AppConstants.configLabelSize] as String? ?? 'medium';
    final labelAlign = widget.config[AppConstants.configLabelAlign] as String? ?? 'center';
    final labelBold = widget.config[AppConstants.configLabelBold] as bool? ?? false;
    final labelItalic = widget.config[AppConstants.configLabelItalic] as bool? ?? false;
    
    // Get the text style based on size
    TextStyle getTextStyle() {
      final themeData = Theme.of(context);
      TextStyle style;
      
      switch (labelSize) {
        case 'small':
          style = themeData.textTheme.bodySmall ?? const TextStyle(fontSize: 12);
          break;
        case 'large':
          style = themeData.textTheme.headlineSmall ?? const TextStyle(fontSize: 20);
          break;
        case 'xlarge':
          style = themeData.textTheme.headlineMedium ?? const TextStyle(fontSize: 24);
          break;
        case 'medium':
        default:
          style = themeData.textTheme.bodyLarge ?? const TextStyle(fontSize: 16);
          break;
      }
      
      // Apply font weight and style
      style = style.copyWith(
        fontWeight: labelBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: labelItalic ? FontStyle.italic : FontStyle.normal,
      );
      
      return style;
    }
    
    // Get alignment based on config
    Alignment getAlignment() {
      switch (labelAlign) {
        case 'left':
          return Alignment.centerLeft;
        case 'right':
          return Alignment.centerRight;
        case 'center':
        default:
          return Alignment.center;
      }
    }
    
    // Check if icon should be shown
    final bool showIcon = widget.icon.isNotEmpty && widget.icon != 'none';
    
    return Container(
      alignment: getAlignment(),
      padding: const EdgeInsets.all(8),
      child: showIcon
        ? Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: _getMainAxisAlignment(labelAlign),
            children: [
              Icon(
                IconHelper.getIconData(widget.icon),
                size: _getIconSize(labelSize),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.caption,
                  style: getTextStyle(),
                  textAlign: _getTextAlignment(labelAlign),
                ),
              ),
            ],
          )
        : Text(
            widget.caption,
            style: getTextStyle(),
            textAlign: _getTextAlignment(labelAlign),
          ),
    );
  }
  
  // Helper method to get icon size based on label size
  double _getIconSize(String labelSize) {
    switch (labelSize) {
      case 'small':
        return 16;
      case 'large':
        return 28;
      case 'xlarge':
        return 32;
      case 'medium':
      default:
        return 24;
    }
  }
  
  // Helper method to get text alignment based on label alignment
  TextAlign _getTextAlignment(String labelAlign) {
    switch (labelAlign) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }
  
  // Helper method to get row alignment based on label alignment
  MainAxisAlignment _getMainAxisAlignment(String labelAlign) {
    switch (labelAlign) {
      case 'left':
        return MainAxisAlignment.start;
      case 'right':
        return MainAxisAlignment.end;
      case 'center':
      default:
        return MainAxisAlignment.center;
    }
  }
}
