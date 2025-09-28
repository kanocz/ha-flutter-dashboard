import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ha_flutter_dashboard/models/dashboard_config.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';

class ImportExportService {
  final StorageService _storageService;

  ImportExportService(this._storageService);

  /// Экспорт конфигурации в JSON строку
  String exportConfigToJson(List<DashboardWidget> widgets) {
    final config = DashboardConfig(
      version: '1.0.0',
      exportedAt: DateTime.now(),
      appName: 'Home Assistant Dashboard',
      widgets: widgets,
      metadata: {
        'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        'exportSource': 'mobile_app',
      },
    );

    final jsonMap = config.toJson();
    return const JsonEncoder.withIndent('  ').convert(jsonMap);
  }

  /// Импорт конфигурации из JSON строки
  DashboardConfig importConfigFromJson(String jsonString) {
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return DashboardConfig.fromJson(jsonMap);
    } catch (e) {
      throw Exception('Error parsing JSON: $e');
    }
  }

  /// Экспорт в локальный файл
  Future<void> exportToFile(List<DashboardWidget> widgets) async {
    try {
      final jsonString = exportConfigToJson(widgets);
      
      if (kIsWeb) {
        // Для веб-платформы используем file_picker для сохранения
        await FilePicker.platform.saveFile(
          dialogTitle: 'Save Dashboard Configuration',
          fileName: 'dashboard_config_${DateTime.now().millisecondsSinceEpoch}.json',
          bytes: utf8.encode(jsonString),
          type: FileType.custom,
          allowedExtensions: ['json'],
        );
      } else {
        // Для мобильных платформ
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw Exception('No permission to write files');
        }

        Directory? directory;
        if (Platform.isAndroid) {
          directory = await getExternalStorageDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory != null) {
          final fileName = 'dashboard_config_${DateTime.now().millisecondsSinceEpoch}.json';
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(jsonString);
          debugPrint('Configuration exported to: ${file.path}');
        }
      }
    } catch (e) {
      throw Exception('Error exporting to file: $e');
    }
  }

  /// Импорт из локального файла
  Future<DashboardConfig> importFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        String jsonString;

        if (kIsWeb) {
          if (file.bytes != null) {
            jsonString = utf8.decode(file.bytes!);
          } else {
            throw Exception('Failed to read file');
          }
        } else {
          if (file.path != null) {
            final fileObj = File(file.path!);
            jsonString = await fileObj.readAsString();
          } else {
            throw Exception('Failed to get file path');
          }
        }

        return importConfigFromJson(jsonString);
      } else {
        throw Exception('No file selected');
      }
    } catch (e) {
      throw Exception('Error importing from file: $e');
    }
  }

  /// Экспорт на сервер через POST запрос
  Future<void> exportToServer(String url, List<DashboardWidget> widgets) async {
    try {
      final jsonString = exportConfigToJson(widgets);
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'User-Agent': 'HA-Flutter-Dashboard/1.0.0',
        },
        body: utf8.encode(jsonString),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('Configuration successfully sent to server');
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Error sending to server: $e');
      }
    }
  }

  /// Импорт с сервера через GET запрос
  Future<DashboardConfig> importFromServer(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json; charset=utf-8',
          'User-Agent': 'HA-Flutter-Dashboard/1.0.0',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Explicitly decode as UTF-8
        final jsonString = utf8.decode(response.bodyBytes);
        return importConfigFromJson(jsonString);
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('Connection error: $e');
      } else {
        throw Exception('Error loading from server: $e');
      }
    }
  }

  /// Применить импортированную конфигурацию
  Future<void> applyImportedConfig(DashboardConfig config, {bool replaceAll = false}) async {
    try {
      if (replaceAll) {
        // Удаляем все существующие виджеты
        await _storageService.clearAllDashboardWidgets();
      }

      // Сохраняем новые виджеты
      for (final widget in config.widgets) {
        await _storageService.saveDashboardWidget(widget);
      }

      debugPrint('Imported ${config.widgets.length} widgets');
    } catch (e) {
      throw Exception('Error applying configuration: $e');
    }
  }

  /// Валидация URL
  bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Получить конфигурацию для предварительного просмотра
  Future<Map<String, dynamic>> getConfigPreview(DashboardConfig config) async {
    return {
      'version': config.version,
      'exportedAt': config.exportedAt.toIso8601String(),
      'appName': config.appName,
      'widgetCount': config.widgets.length,
      'widgetTypes': config.widgets
          .map((w) => w.type)
          .toSet()
          .toList(),
      'metadata': config.metadata,
    };
  }
}