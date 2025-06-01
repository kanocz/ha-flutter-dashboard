import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/models/entity_state.dart';
import 'package:ha_flutter_dashboard/widgets/base_widget_card.dart';

class SeparatorWidgetCard extends BaseWidgetCard {
  const SeparatorWidgetCard({
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
    // Override the build method completely to create a separator that spans the entire row
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        border: isEditing ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: buildWidgetContent(context),
    );
  }

  @override
  Widget buildWidgetContent(
    BuildContext context, {
    bool isSmallWidget = false,
    bool useSimplifiedView = false,
  }) {
    // Get separator style from config
    final separatorStyle = widget.config[AppConstants.configSeparatorStyle] as String? ?? 'line';
    final separatorColor = _getColorFromString(
      widget.config[AppConstants.configSeparatorColor] as String? ?? 'grey',
    );
    
    // Style the separator based on the configuration
    switch (separatorStyle) {
      case 'empty':
        return const SizedBox(height: 16);
        
      case 'thick':
        return Divider(
          color: separatorColor,
          thickness: 4,
          height: 24,
        );
        
      case 'dashed':
        return _DashedDivider(
          color: separatorColor,
          height: 24,
        );
        
      case 'dotted':
        return _DottedDivider(
          color: separatorColor,
          height: 24,
        );
        
      case 'line':
      default:
        return Divider(
          color: separatorColor,
          thickness: 1,
          height: 24,
        );
    }
  }
  
  // Helper method to parse color from string
  Color _getColorFromString(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'red': return Colors.red;
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'yellow': return Colors.yellow;
      case 'orange': return Colors.orange;
      case 'purple': return Colors.purple;
      case 'pink': return Colors.pink;
      case 'brown': return Colors.brown;
      case 'black': return Colors.black;
      case 'white': return Colors.white;
      case 'grey':
      default: return Colors.grey;
    }
  }
}

// Custom painter for dotted divider
class _DottedDivider extends StatelessWidget {
  final Color color;
  final double height;
  
  const _DottedDivider({
    required this.color,
    this.height = 24,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      child: Center(
        child: CustomPaint(
          painter: _DottedLinePainter(color: color),
          size: Size.fromHeight(1),
        ),
      ),
    );
  }
}

// Custom painter for dashed divider
class _DashedDivider extends StatelessWidget {
  final Color color;
  final double height;
  
  const _DashedDivider({
    required this.color,
    this.height = 24,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      child: Center(
        child: CustomPaint(
          painter: _DashedLinePainter(color: color),
          size: Size.fromHeight(1),
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  
  _DottedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
      
    const spacing = 4.0;
    double start = 0;
    
    while (start < size.width) {
      canvas.drawPoints(
        PointMode.points, 
        [Offset(start, 0)], 
        paint
      );
      start += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  
  _DashedLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
      
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double start = 0;
    
    while (start < size.width) {
      canvas.drawLine(
        Offset(start, 0),
        Offset(start + dashWidth, 0),
        paint,
      );
      start += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
