import 'package:flutter/material.dart';

class NumpadPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final int pinLength;
  final Function(String) onPinEntered;
  final bool obscurePin;

  const NumpadPinDialog({
    Key? key,
    required this.title,
    required this.subtitle,
    this.pinLength = 4,
    required this.onPinEntered,
    this.obscurePin = true,
  }) : super(key: key);

  @override
  State<NumpadPinDialog> createState() => _NumpadPinDialogState();
}

class _NumpadPinDialogState extends State<NumpadPinDialog> {
  late String _enteredPin;
  
  @override
  void initState() {
    super.initState();
    _enteredPin = '';
  }

  void _addDigit(String digit) {
    if (_enteredPin.length < widget.pinLength) {
      setState(() {
        _enteredPin += digit;
      });
      
      // If pin is complete, trigger callback
      if (_enteredPin.length == widget.pinLength) {
        Future.delayed(const Duration(milliseconds: 300), () {
          widget.onPinEntered(_enteredPin);
        });
      }
    }
  }

  void _removeLastDigit() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // PIN display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.pinLength, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  width: 45,
                  height: 45,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isFilled 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isFilled 
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                      : null,
                  ),
                  child: Center(
                    child: isFilled
                      ? widget.obscurePin
                        ? const Icon(Icons.circle, size: 16)
                        : Text(
                            _enteredPin[index],
                            style: Theme.of(context).textTheme.headlineSmall,
                          )
                      : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            
            // Numpad
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumButton('1'),
                    _buildNumButton('2'),
                    _buildNumButton('3'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumButton('4'),
                    _buildNumButton('5'),
                    _buildNumButton('6'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumButton('7'),
                    _buildNumButton('8'),
                    _buildNumButton('9'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    _buildNumButton('0'),
                    _buildActionButton(
                      onPressed: _removeLastDigit,
                      child: const Icon(Icons.backspace_outlined),
                      backgroundColor: Theme.of(context).colorScheme.errorContainer,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumButton(String number) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: () => _addDigit(number),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(35),
          ),
          padding: const EdgeInsets.all(8),
        ),
        child: Text(
          number,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required Widget child,
    required Color backgroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 70,
      height: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(35),
          ),
          padding: const EdgeInsets.all(8),
        ),
        child: child,
      ),
    );
  }
}
