import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/home_assistant_bloc.dart';
import 'package:ha_flutter_dashboard/blocs/launcher_bloc.dart';
import 'package:ha_flutter_dashboard/models/home_assistant_instance.dart';
import 'package:ha_flutter_dashboard/screens/dashboard_screen.dart';
import 'package:ha_flutter_dashboard/widgets/qr_scanner_widget.dart';
import 'package:uuid/uuid.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _tokenController = TextEditingController();
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isDiscovering = false;
  bool _isManualEntry = false;
  bool _isLauncherMode = false;

  @override
  void initState() {
    super.initState();
    // Start discovering Home Assistant instances
    _startDiscovery();
    
    // Get the current launcher mode setting
    final launcherState = context.read<LauncherBloc>().state;
    _isLauncherMode = launcherState.isLauncher;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _startDiscovery() {
    setState(() {
      _isDiscovering = true;
    });
    
    context.read<HomeAssistantBloc>().add(DiscoverInstances());
    
    // Set a timeout for discovery
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    });
  }

  void _addManualInstance() {
    if (_urlController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
        ),
      );
      return;
    }

    // Validate URL format
    String url = _urlController.text;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    
    // Remove trailing slash if present
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Create the instance
    final instance = HomeAssistantInstance(
      id: const Uuid().v4(),
      name: _nameController.text,
      url: url,
      isManuallyAdded: true,
    );

    // Add it to the bloc
    context.read<HomeAssistantBloc>().add(AddManualInstance(instance));
    
    // Select it
    context.read<HomeAssistantBloc>().add(SelectInstance(instance.id));

    // Reset form
    setState(() {
      _isManualEntry = false;
      _urlController.clear();
      _nameController.clear();
    });
  }

  void _openQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRScannerWidget(
          onQRCodeScanned: (String scannedData) {
            setState(() {
              _tokenController.text = scannedData;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Token scanned successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  void _selectInstance(String id) {
    context.read<HomeAssistantBloc>().add(SelectInstance(id));
  }

  void _saveToken() {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid token'),
        ),
      );
      return;
    }

    // Save the token
    context.read<HomeAssistantBloc>().add(SetLongTermToken(_tokenController.text));
    
    // Save launcher mode setting
    context.read<LauncherBloc>().add(ToggleLauncherMode(_isLauncherMode));

    // Navigate to dashboard
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeAssistantBloc, HomeAssistantState>(
      builder: (context, state) {
        if (state is HomeAssistantInitial) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is HomeAssistantLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Setup Home Assistant Dashboard'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step 1: Select HA Instance
                    _buildStepHeader('Step 1: Select Home Assistant Instance'),
                    if (_isManualEntry)
                      _buildManualEntryForm()
                    else
                      _buildInstancesList(state),
                      
                    // Step 2: Enter Long-term Token
                    if (state.selectedInstanceId != null) ...[
                      const SizedBox(height: 24),
                      _buildStepHeader('Step 2: Enter Long-term Access Token'),
                      const SizedBox(height: 8),
                      const Text(
                        'You can generate a long-term access token in Home Assistant under your Profile > Long-lived Access Tokens.',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tokenController,
                        decoration: InputDecoration(
                          labelText: 'Long-term Access Token',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _openQRScanner,
                            tooltip: 'Scan QR Code',
                          ),
                        ),
                        obscureText: true,
                      ),
                      
                      // Step 3: Launcher Mode
                      const SizedBox(height: 24),
                      _buildStepHeader('Step 3: Configure Launcher Mode'),
                      SwitchListTile(
                        title: const Text('Use as Android Launcher'),
                        subtitle: const Text(
                          'App will start on device boot and prevent switching to other apps',
                        ),
                        value: _isLauncherMode,
                        onChanged: (value) {
                          setState(() {
                            _isLauncherMode = value;
                          });
                        },
                      ),
                      
                      // Submit Button
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveToken,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                        child: const Text('Finish Setup'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // Error state
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Error loading Home Assistant setup'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _startDiscovery,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  Widget _buildInstancesList(HomeAssistantLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Discovered Instances:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_isDiscovering)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // List of discovered instances
        if (state.instances.isEmpty && !_isDiscovering)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No instances found'),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.instances.length,
            itemBuilder: (context, index) {
              final instance = state.instances[index];
              final isSelected = instance.id == state.selectedInstanceId;
              
              return Card(
                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                child: ListTile(
                  title: Text(instance.name),
                  subtitle: Text(instance.url),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () => _selectInstance(instance.id),
                ),
              );
            },
          ),
          
        // Buttons for manual entry or refresh
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: _isDiscovering ? null : _startDiscovery,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isManualEntry = true;
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Manually'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualEntryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Instance Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            labelText: 'URL (e.g., http://homeassistant.local:8123)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isManualEntry = false;
                  _urlController.clear();
                  _nameController.clear();
                });
              },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _addManualInstance,
              child: const Text('Add'),
            ),
          ],
        ),
      ],
    );
  }
}
