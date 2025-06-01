import 'package:flutter/material.dart';
import 'package:ha_flutter_dashboard/services/storage_service.dart';

class SetPinDialog extends StatefulWidget {
  final StorageService storageService;
  final bool isPinRequired;

  const SetPinDialog({
    Key? key,
    required this.storageService,
    required this.isPinRequired,
  }) : super(key: key);

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  final List<TextEditingController> _pinControllers = 
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _pinFocusNodes = 
      List.generate(4, (_) => FocusNode());
  
  final List<TextEditingController> _confirmPinControllers = 
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _confirmPinFocusNodes = 
      List.generate(4, (_) => FocusNode());
  
  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    for (var controller in _confirmPinControllers) {
      controller.dispose();
    }
    for (var node in _confirmPinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter a 4-digit PIN to protect dashboard editing and settings.'),
          const SizedBox(height: 16),
          const Text('Enter PIN:'),
          const SizedBox(height: 8),
          _buildPinRow(_pinControllers, _pinFocusNodes),
          const SizedBox(height: 16),
          const Text('Confirm PIN:'),
          const SizedBox(height: 8),
          _buildPinRow(_confirmPinControllers, _confirmPinFocusNodes),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // If PIN is required but user canceled, disable protection
            if (widget.isPinRequired) {
              widget.storageService.setPasswordProtectionEnabled(false);
            }
          },
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => _savePin(context),
          child: const Text('SAVE'),
        ),
      ],
    );
  }
  
  Widget _buildPinRow(List<TextEditingController> controllers, List<FocusNode> focusNodes) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (index) => Container(
          width: 50,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          child: TextField(
            controller: controllers[index],
            focusNode: focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            obscureText: true,
            decoration: const InputDecoration(
              counterText: '',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 3) {
                focusNodes[index + 1].requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }
  
  void _savePin(BuildContext context) {
    // Get PIN from controllers
    final pin = _pinControllers.map((c) => c.text).join();
    final confirmPin = _confirmPinControllers.map((c) => c.text).join();
    
    // Validate PIN
    if (pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit PIN')),
      );
      return;
    }
    
    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }
    
    // Save the PIN
    widget.storageService.setPin(pin);
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN set successfully')),
    );
  }
}
