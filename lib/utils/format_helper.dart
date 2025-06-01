import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FormatHelper {
  static String formatDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(dateTime);
  }
  
  static String formatTime(DateTime time, {bool showSeconds = false}) {
    final DateFormat formatter = DateFormat(showSeconds ? 'HH:mm:ss' : 'HH:mm');
    return formatter.format(time);
  }
  
  static String formatDate(DateTime date) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    return formatter.format(date);
  }
  
  static String formatTemperature(double temp, {bool showUnit = true}) {
    return '${temp.toStringAsFixed(1)}${showUnit ? '°C' : ''}';
  }
  
  static String formatPercentage(double value) {
    return '${(value * 100).round()}%';
  }
  
  static Color getColorForState(String state) {
    switch (state.toLowerCase()) {
      case 'on':
      case 'open':
      case 'unlocked':
        return Colors.green;
      case 'off':
      case 'closed':
      case 'locked':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
