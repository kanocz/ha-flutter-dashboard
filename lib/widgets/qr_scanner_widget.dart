import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:qr_code_tools/qr_code_tools.dart';
import 'dart:io';

class QRScannerWidget extends StatefulWidget {
  final Function(String) onQRCodeScanned;
  
  const QRScannerWidget({
    Key? key,
    required this.onQRCodeScanned,
  }) : super(key: key);

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _tokenController = TextEditingController();
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
    ]
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _barcodeScanner.close();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    if (_isProcessing) return;
    
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      _showErrorDialog('Error accessing camera: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _processImage(image);
      }
    } catch (e) {
      _showErrorDialog('Error accessing gallery: $e');
    }
  }

  Future<void> _processImage(XFile imageFile) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final File file = File(imageFile.path);
      String? qrText;
      
      // Попробуем сначала Google ML Kit
      try {
        final inputImage = InputImage.fromFilePath(imageFile.path);
        print('Processing image with ML Kit: ${imageFile.path}');
        
        final barcodes = await _barcodeScanner.processImage(inputImage);
        print('ML Kit found ${barcodes.length} barcodes');
        
        for (final barcode in barcodes) {
          print('Barcode type: ${barcode.type}');
          print('Barcode format: ${barcode.format}');
          print('Barcode value: ${barcode.rawValue}');
          
          if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
            qrText = barcode.rawValue;
            break;
          }
        }
      } catch (e) {
        print('ML Kit failed: $e');
      }
      
      // Если ML Kit не нашел, попробуем qr_code_tools
      if (qrText == null || qrText.isEmpty) {
        try {
          print('Trying qr_code_tools...');
          final result = await QrCodeToolsPlugin.decodeFrom(file.path);
          print('qr_code_tools result: $result');
          qrText = result;
        } catch (e) {
          print('qr_code_tools failed: $e');
        }
      }
      
      // Если нашли QR-код
      if (qrText != null && qrText.isNotEmpty) {
        print('Successfully found QR code: $qrText');
        widget.onQRCodeScanned(qrText);
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code scanned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
      
      // QR-код не найден, предлагаем ручной ввод
      _showManualEntry('No QR code found in the image. Please enter the token manually:');
      
    } catch (e) {
      _showErrorDialog('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showManualEntry(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Home Assistant Token',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_tokenController.text.trim().isNotEmpty) {
                widget.onQRCodeScanned(_tokenController.text.trim());
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Use Token'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code / Token'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose an option to add your Home Assistant token:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            Card(
              child: ListTile(
                leading: _isProcessing 
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(),
                    )
                  : const Icon(Icons.camera_alt, size: 32),
                title: const Text('Take Photo of QR Code'),
                subtitle: _isProcessing 
                  ? const Text('Processing image...')
                  : const Text('Use camera to capture QR code'),
                onTap: _isProcessing ? null : _pickFromCamera,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: ListTile(
                leading: _isProcessing 
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(),
                    )
                  : const Icon(Icons.photo_library, size: 32),
                title: const Text('Select QR Code from Gallery'),
                subtitle: _isProcessing 
                  ? const Text('Processing image...')
                  : const Text('Choose QR code image from gallery'),
                onTap: _isProcessing ? null : _pickFromGallery,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit, size: 32),
                title: const Text('Enter Token Manually'),
                subtitle: const Text('Type the token directly'),
                onTap: () => _showManualEntry('Enter your Home Assistant token:'),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              _isProcessing 
                ? 'Processing QR code... Please wait.'
                : 'Note: QR codes will be automatically recognized. For best results, ensure codes are clear and well-lit.',
              style: TextStyle(
                fontSize: 12, 
                color: _isProcessing ? Colors.orange : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}