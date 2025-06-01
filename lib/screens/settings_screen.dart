import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:ha_flutter_dashboard/blocs/home_assistant_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/launcher_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/theme_bloc.dart';
import 'package:ha_flutter_dashboard/config/constants.dart';
import 'package:ha_flutter_dashboard/screens/setup_screen.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';
import 'package:ha_flutter_dashboard/widgets/numpad_pin_dialog.dart';
import 'package:ha_flutter_dashboard/widgets/set_pin_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late StorageService _storageService;
  bool _isPasswordProtectionEnabled = false;
  bool _isAutoLockEnabled = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeStorageService();
  }
  
  Future<void> _initializeStorageService() async {
    _storageService = StorageService();
    await _storageService.init();
    if (mounted) {
      setState(() {
        _isPasswordProtectionEnabled = _storageService.isPasswordProtectionEnabled();
        _isAutoLockEnabled = _storageService.isAutoLockEnabled();
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: !_isInitialized 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading settings...'),
                ],
              ),
            )
          : ListView(
        children: [
          const _SectionHeader(title: 'Security'),
          SwitchListTile(
            title: const Text('PIN Protected Editing'),
            subtitle: const Text('Require a 4-digit PIN to edit dashboard and settings'),
            value: _isPasswordProtectionEnabled,
            onChanged: (value) {
              setState(() {
                _isPasswordProtectionEnabled = value;
                _storageService.setPasswordProtectionEnabled(value);

                if (value && !_storageService.isPasswordSet()) {
                  // If enabling protection but no PIN set, show dialog to set PIN
                  _showSetPasswordDialog();
                }
              });
            },
          ),
          ListTile(
            title: const Text('Change PIN'),
            subtitle: const Text('Set or change 4-digit PIN for editing'),
            leading: const Icon(Icons.pin),
            enabled: _isPasswordProtectionEnabled,
            onTap: _showSetPasswordDialog,
          ),
          SwitchListTile(
            title: const Text('Auto-Lock Dashboard'),
            subtitle: const Text('Automatically lock the dashboard after 3 minutes of inactivity'),
            value: _isAutoLockEnabled,
            onChanged: _isPasswordProtectionEnabled 
              ? (value) {
                  setState(() {
                    _isAutoLockEnabled = value;
                    _storageService.setAutoLockEnabled(value);
                    
                    // Lock the dashboard immediately upon enabling auto-lock
                    if (value) {
                      _storageService.setDashboardLocked(true);
                    }
                  });
                } 
              : null,
          ),
          ListTile(
            title: const Text('Screensaver'),
            subtitle: Text(_getScreensaverTimeoutLabel(_storageService.getScreensaverTimeout())),
            leading: const Icon(Icons.display_settings),
            onTap: () => _showScreensaverTimeoutDialog(context),
          ),
          const Divider(),
          const _SectionHeader(title: 'Appearance'),
          // Fullscreen mode toggle
          SwitchListTile(
            title: const Text('Fullscreen Mode'),
            subtitle: const Text('Hide system UI for immersive experience'),
            value: _storageService.isFullscreenModeEnabled(),
            onChanged: (value) async {
              await _storageService.setFullscreenModeEnabled(value);
              if (value) {
                // Enter fullscreen
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
              } else {
                // Exit fullscreen
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              }
              setState(() {});
            },
          ),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              String themeModeName;
              if (state.themeMode == ThemeMode.light) {
                themeModeName = 'Light';
              } else if (state.themeMode == ThemeMode.dark) {
                themeModeName = 'Dark';
              } else {
                themeModeName = 'System';
              }

              return ListTile(
                title: const Text('Theme Mode'),
                subtitle: Text(themeModeName),
                trailing: const Icon(Icons.brightness_6),
                onTap: () => _showThemeModeDialog(context, state.themeMode),
              );
            },
          ),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return ListTile(
                title: const Text('Grid Dimensions'),
                subtitle: Text(
                  'Portrait: ${state.gridPortraitColumns}×${state.gridPortraitRows}, '
                  'Landscape: ${state.gridLandscapeColumns}×${state.gridLandscapeRows}',
                ),
                trailing: const Icon(Icons.grid_view),
                onTap: () => _showGridDimensionsDialog(
                  context,
                  state.gridPortraitColumns,
                  state.gridPortraitRows,
                  state.gridLandscapeColumns,
                  state.gridLandscapeRows,
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Screen Orientation'),
            subtitle: Text(_getOrientationLockLabel(context.read<StorageService>().getOrientationLock())),
            trailing: const Icon(Icons.screen_rotation),
            onTap: () => _showOrientationDialog(context),
          ),
          const Divider(),
          const _SectionHeader(title: 'Launcher'),
          BlocBuilder<LauncherBloc, LauncherState>(
            builder: (context, state) {
              return SwitchListTile(
                title: const Text('Use as Android Launcher'),
                subtitle: const Text(
                  'App will start on device boot and prevent switching to other apps',
                ),
                value: state.isLauncher,
                onChanged: (value) {
                  context.read<LauncherBloc>().add(ToggleLauncherMode(value));
                },
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Home Assistant Connection'),
          BlocBuilder<HomeAssistantBloc, HomeAssistantState>(
            builder: (context, state) {
              if (state is HomeAssistantLoaded && state.selectedInstance != null) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('Connected Instance'),
                      subtitle: Text(state.selectedInstance!.name),
                      trailing: const Icon(Icons.home),
                    ),
                    ListTile(
                      title: const Text('Server URL'),
                      subtitle: Text(state.selectedInstance!.url),
                      trailing: const Icon(Icons.link),
                    ),
                    ListTile(
                      title: const Text('Long-term Access Token'),
                      subtitle: const Text('●●●●●●●●●●●●●●●●'),
                      trailing: const Icon(Icons.vpn_key),
                      onTap: () => _showTokenDialog(context),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _changeHomeAssistantInstance(context),
                      icon: const Icon(Icons.edit),
                      label: const Text('Change Home Assistant Instance'),
                    ),
                  ],
                );
              } else {
                return const ListTile(
                  title: Text('Not connected'),
                  subtitle: Text('Tap to connect to Home Assistant'),
                  trailing: Icon(Icons.error_outline),
                );
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'Connection'),
          ListTile(
            title: const Text('WebSocket Message Timeout'),
            subtitle: Text(
              _isInitialized
                  ? '${_storageService.getWebsocketMessageTimeout() ~/ 1000} seconds'
                  : '',
            ),
            trailing: const Icon(Icons.timer),
            onTap: _isInitialized ? () => _showWebsocketTimeoutDialog(context) : null,
          ),
          const Divider(),
          const _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
            trailing: Icon(Icons.info_outline),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () => _resetApp(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset App'),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme Mode'),
        children: [
          _ThemeModeOption(
            title: 'Light',
            icon: Icons.brightness_7,
            isSelected: currentMode == ThemeMode.light,
            onTap: () {
              context.read<ThemeBloc>().add(ToggleThemeMode(ThemeMode.light));
              Navigator.pop(context);
            },
          ),
          _ThemeModeOption(
            title: 'Dark',
            icon: Icons.brightness_3,
            isSelected: currentMode == ThemeMode.dark,
            onTap: () {
              context.read<ThemeBloc>().add(ToggleThemeMode(ThemeMode.dark));
              Navigator.pop(context);
            },
          ),
          _ThemeModeOption(
            title: 'System',
            icon: Icons.brightness_auto,
            isSelected: currentMode == ThemeMode.system,
            onTap: () {
              context.read<ThemeBloc>().add(ToggleThemeMode(ThemeMode.system));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showGridDimensionsDialog(
    BuildContext context,
    int portraitColumns,
    int portraitRows,
    int landscapeColumns,
    int landscapeRows,
  ) {
    final portraitColumnsController = TextEditingController(text: portraitColumns.toString());
    final portraitRowsController = TextEditingController(text: portraitRows.toString());
    final landscapeColumnsController = TextEditingController(text: landscapeColumns.toString());
    final landscapeRowsController = TextEditingController(text: landscapeRows.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grid Dimensions'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configure the number of columns and rows for the dashboard grid in different orientations.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Portrait Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: portraitColumnsController,
                      decoration: const InputDecoration(
                        labelText: 'Columns',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: portraitRowsController,
                      decoration: const InputDecoration(
                        labelText: 'Rows',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Landscape Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: landscapeColumnsController,
                      decoration: const InputDecoration(
                        labelText: 'Columns',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: landscapeRowsController,
                      decoration: const InputDecoration(
                        labelText: 'Rows',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final newPortraitColumns = int.tryParse(portraitColumnsController.text) ?? portraitColumns;
              final newPortraitRows = int.tryParse(portraitRowsController.text) ?? portraitRows;
              final newLandscapeColumns = int.tryParse(landscapeColumnsController.text) ?? landscapeColumns;
              final newLandscapeRows = int.tryParse(landscapeRowsController.text) ?? landscapeRows;

              context.read<ThemeBloc>().add(
                UpdateGridDimensions(
                  portraitColumns: newPortraitColumns,
                  portraitRows: newPortraitRows,
                  landscapeColumns: newLandscapeColumns,
                  landscapeRows: newLandscapeRows,
                ),
              );

              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showTokenDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Access Token'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Access Token',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<HomeAssistantBloc>().add(
                  SetLongTermToken(controller.text),
                );
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _changeHomeAssistantInstance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SetupScreen(),
      ),
    );
  }

  void _resetApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will clear all settings and data. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
                (route) => false,
              );
            },
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  void _showSetPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SetPinDialog(
        onPinConfirmed: (pin) {
          // Set the PIN
          _storageService.setPin(pin);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN has been set')),
          );
          
          // If setting a PIN for the first time, ensure PIN protection stays enabled
          if (_isPasswordProtectionEnabled && !_storageService.isPasswordSet()) {
            _storageService.setPasswordProtectionEnabled(true);
          }
        },
      ),
    );
  }

  String _getScreensaverTimeoutLabel(int timeoutMs) {
    switch (timeoutMs) {
      case 0:
        return "Disabled";
      case 60000: // 1 minute
        return "1 minute";
      case 120000: // 2 minutes
        return "2 minutes";
      case 300000: // 5 minutes
        return "5 minutes";
      case 600000: // 10 minutes
        return "10 minutes";
      default:
        return "Disabled";
    }
  }

  void _showScreensaverTimeoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Screensaver Timeout'),
        children: [
          SimpleDialogOption(
            child: const Text('Disabled'),
            onPressed: () {
              _storageService.setScreensaverTimeout(0);
              setState(() {});
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text('1 minute'),
            onPressed: () {
              _storageService.setScreensaverTimeout(60000);
              setState(() {});
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text('2 minutes'),
            onPressed: () {
              _storageService.setScreensaverTimeout(120000);
              setState(() {});
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text('5 minutes'),
            onPressed: () {
              _storageService.setScreensaverTimeout(300000);
              setState(() {});
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text('10 minutes'),
            onPressed: () {
              _storageService.setScreensaverTimeout(600000);
              setState(() {});
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  String _getOrientationLockLabel(String value) {
    switch (value) {
      case "portrait":
        return "Portrait";
      case "landscape":
        return "Landscape";
      default:
        return "System Default";
    }
  }

  void _showOrientationDialog(BuildContext context) {
    final storage = context.read<StorageService>();
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Screen Orientation'),
        children: [
          SimpleDialogOption(
            child: const Text('Landscape'),
            onPressed: () {
              storage.setOrientationLock("landscape");
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text('Portrait'),
            onPressed: () {
              storage.setOrientationLock("portrait");
              Navigator.pop(context);
            },
          ),
          SimpleDialogOption(
            child: const Text('System Default'),
            onPressed: () {
              storage.setOrientationLock("system");
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showWebsocketTimeoutDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: (_storageService.getWebsocketMessageTimeout() ~/ 1000).toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WebSocket Message Timeout'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Timeout (seconds)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final int? seconds = int.tryParse(controller.text);
              if (seconds != null && seconds > 0) {
                await _storageService.setWebsocketMessageTimeout(seconds * 1000);
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    Key? key,
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Icon(
              Icons.check,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
