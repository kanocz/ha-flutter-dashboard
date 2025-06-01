import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A utility class for logging WebSocket debug information
class DebugLogger {
  static const String _logFileName = 'widget_debug.log';
  static File? _logFile;
  static IOSink? _logSink;
  static bool _initialized = false;

  /// Initialize the logger
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      if (!kIsWeb) {
        final directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/$_logFileName');
        
        // Clear previous logs
        await _logFile!.writeAsString('Debug Log Started: ${DateTime.now()}\n');
        
        // Open a sink for appending
        _logSink = _logFile!.openWrite(mode: FileMode.append);
        
        debugPrint('Debug log initialized at: ${_logFile!.path}');
        _initialized = true;
      }
    } catch (e) {
      debugPrint('Failed to initialize debug logger: $e');
    }
  }

  /// Log a message to both console and file
  static void log(String message) {
    final timestamp = DateTime.now().toString();
    final formattedMessage = '[$timestamp] $message';
    
    // Always print to console
    debugPrint(formattedMessage);
    
    // Write to file if initialized
    if (_initialized && _logSink != null) {
      _logSink!.writeln(formattedMessage);
    }
  }

  /// Close the logger when done
  static Future<void> dispose() async {
    if (_logSink != null) {
      await _logSink!.flush();
      await _logSink!.close();
      _logSink = null;
    }
    _initialized = false;
  }
}
