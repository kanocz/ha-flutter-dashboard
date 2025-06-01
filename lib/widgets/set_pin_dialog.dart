import 'package:flutter/material.dart';

// A specialized dialog for setting a PIN with confirmation
class SetPinDialog extends StatefulWidget {
  final Function(String) onPinConfirmed;
  
  const SetPinDialog({
    Key? key, 
    required this.onPinConfirmed,
  }) : super(key: key);

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _errorMessage = '';
  
  void _addDigit(String digit) {
    setState(() {
      if (!_isConfirming) {
        if (_enteredPin.length < 4) {
          _enteredPin += digit;
          
          // If first PIN is complete, move to confirmation
          if (_enteredPin.length == 4) {
            Future.delayed(const Duration(milliseconds: 500), () {
              setState(() {
                _isConfirming = true;
                _errorMessage = '';
              });
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          
          // If confirmation PIN is complete, check match
          if (_confirmPin.length == 4) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _checkPinsMatch();
            });
          }
        }
      }
    });
  }
  
  void _removeLastDigit() {
    setState(() {
      if (!_isConfirming) {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // If confirmation is empty, go back to entering first PIN
          _isConfirming = false;
        }
      }
      _errorMessage = '';
    });
  }
  
  void _checkPinsMatch() {
    if (_enteredPin == _confirmPin) {
      // PINs match, call the callback and close dialog
      widget.onPinConfirmed(_enteredPin);
      Navigator.of(context).pop();
    } else {
      // PINs don't match, reset confirmation
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
    }
  }
  
  void _cancel() {
    Navigator.of(context).pop();
  }
  
  void _reset() {
    setState(() {
      _enteredPin = '';
      _confirmPin = '';
      _isConfirming = false;
      _errorMessage = '';
    });
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
              _isConfirming ? 'Confirm PIN' : 'Set PIN',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirming 
                ? 'Re-enter the same PIN to confirm'
                : 'Enter a 4-digit PIN to protect your dashboard',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            
            // PIN display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final String currentPin = _isConfirming ? _confirmPin : _enteredPin;
                final bool isFilled = index < currentPin.length;
                
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
                      ? const Icon(Icons.circle, size: 16)
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
                      onPressed: _cancel,
                      child: const Text('Cancel'),
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    _buildNumButton('0'),
                    _buildActionButton(
                      onPressed: _isConfirming ? _reset : _removeLastDigit,
                      child: _isConfirming 
                        ? const Icon(Icons.refresh)
                        : const Icon(Icons.backspace_outlined),
                      backgroundColor: _isConfirming
                        ? Colors.orange.withOpacity(0.2)
                        : Theme.of(context).colorScheme.errorContainer,
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
