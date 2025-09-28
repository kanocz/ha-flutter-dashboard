import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/dashboard_bloc.dart';
import 'package:ha_flutter_dashboard/models/dashboard_config.dart';
import 'package:ha_flutter_dashboard/models/dashboard_widget.dart';
import 'package:ha_flutter_dashboard/services/import_export_service.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({Key? key}) : super(key: key);

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ImportExportService _importExportService;
  
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;
  DashboardConfig? _previewConfig;
  Map<String, dynamic>? _previewData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _importExportService = ImportExportService(
      context.read<StorageService>(),
    );
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final storageService = context.read<StorageService>();
    final savedUrl = storageService.getImportExportUrl();
    if (savedUrl.isNotEmpty) {
      _urlController.text = savedUrl;
    }
  }

  Future<void> _saveUrl() async {
    final storageService = context.read<StorageService>();
    await storageService.setImportExportUrl(_urlController.text.trim());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _setLoading(bool loading, [String? message]) {
    setState(() {
      _isLoading = loading;
      _statusMessage = message;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<DashboardWidget> _getCurrentWidgets() {
    final dashboardState = context.read<DashboardBloc>().state;
    if (dashboardState is DashboardLoaded) {
      return dashboardState.widgets;
    }
    return [];
  }

  // EXPORT
  Future<void> _exportToFile() async {
    try {
      _setLoading(true, 'Exporting to file...');
      final widgets = _getCurrentWidgets();
      if (widgets.isEmpty) {
        _showError('No widgets to export');
        return;
      }
      
      await _importExportService.exportToFile(widgets);
      _showSuccess('Configuration exported to file');
    } catch (e) {
      _showError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _exportToServer() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter server URL');
      return;
    }

    if (!_importExportService.isValidUrl(url)) {
      _showError('Invalid URL');
      return;
    }

    try {
      _setLoading(true, 'Sending to server...');
      final widgets = _getCurrentWidgets();
      if (widgets.isEmpty) {
        _showError('No widgets to export');
        return;
      }
      
      await _importExportService.exportToServer(url, widgets);
      _showSuccess('Configuration sent to server');
    } catch (e) {
      _showError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // IMPORT
  Future<void> _importFromFile() async {
    try {
      _setLoading(true, 'Importing from file...');
      final config = await _importExportService.importFromFile();
      await _showImportPreview(config);
    } catch (e) {
      _showError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _importFromServer() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showError('Please enter server URL');
      return;
    }

    if (!_importExportService.isValidUrl(url)) {
      _showError('Invalid URL');
      return;
    }

    try {
      _setLoading(true, 'Loading from server...');
      final config = await _importExportService.importFromServer(url);
      await _showImportPreview(config);
    } catch (e) {
      _showError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _showImportPreview(DashboardConfig config) async {
    _previewConfig = config;
    _previewData = await _importExportService.getConfigPreview(config);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _buildPreviewDialog(),
    );

    if (result == true && _previewConfig != null) {
      await _applyImport(_previewConfig!, replaceAll: true);
    }
  }

  Future<void> _applyImport(DashboardConfig config, {bool replaceAll = false}) async {
    try {
      _setLoading(true, 'Applying configuration...');
      await _importExportService.applyImportedConfig(config, replaceAll: replaceAll);
      
      // Update Dashboard
      if (context.mounted) {
        context.read<DashboardBloc>().add(LoadDashboardWidgets());
      }
      
      _showSuccess('Configuration applied (${config.widgets.length} widgets)');
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Widget _buildPreviewDialog() {
    return AlertDialog(
      title: const Text('Preview'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_previewData != null) ...[
              Text('Application: ${_previewData!['appName']}'),
              Text('Version: ${_previewData!['version']}'),
              Text('Exported: ${_previewData!['exportedAt']}'),
              Text('Widget count: ${_previewData!['widgetCount']}'),
              const SizedBox(height: 16),
              const Text('Widget types:'),
              ...(_previewData!['widgetTypes'] as List<String>)
                  .map((type) => Text('• $type')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import/Export'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Export', icon: Icon(Icons.upload)),
            Tab(text: 'Import', icon: Icon(Icons.download)),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildExportTab(),
              _buildImportTab(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Export widget configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Export to file
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Local file',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Save configuration to device file'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportToFile,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Export to file'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Export to server
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Remote server',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Send configuration to server via POST request'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://example.com/api/config',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (value) => _saveUrl(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _exportToServer,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('POST - Send to server'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Import widget configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Import will replace ALL existing widgets!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Import from file
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Local file',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Load configuration from file'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importFromFile,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Import from file'),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Import from server
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Remote server',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('Load configuration from server via GET request'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://example.com/api/config',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (value) => _saveUrl(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _importFromServer,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('GET - Load from server'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}