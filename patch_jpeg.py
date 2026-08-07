import re

with open("lib/widgets/digital_voucher_dialog.dart", "r") as f:
    content = f.read()

import_statement = "import 'package:image_gallery_saver/image_gallery_saver.dart';\n"
if "package:image_gallery_saver" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:image_gallery_saver/image_gallery_saver.dart';")

save_method = """
  Future<void> _handleSaveAsJpeg() async {
    setState(() => _isCapturing = true);
    try {
      const double logicalWidth = 384.0;
      final thermalWidget = ThermalReceiptWidget(
        order: widget.order,
        activeItems: widget.items,
        width: logicalWidth,
        type: ReceiptType.customer, // ensure it uses customer layout
      );

      final screenshotController = ScreenshotController();
      final Uint8List pngBytes = await screenshotController.captureFromWidget(
        thermalWidget,
        pixelRatio: 1.5,
        delay: const Duration(milliseconds: 150),
        targetSize: const Size(logicalWidth, 4000.0),
      );

      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "Customer_Voucher_${widget.order.orderNumber}",
      );

      if (mounted) {
        if (result != null && result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voucher saved to gallery successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save voucher: $result')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving voucher: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving voucher: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _handleConfirmPrint() async {"""

if "_handleSaveAsJpeg" not in content:
    content = content.replace("  Future<void> _handleConfirmPrint() async {", save_method)


# We need to add a button for this in the UI.
# Search for:
button_search = """                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D241E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isCapturing ? null : _handleConfirmPrint,
                      icon: _isCapturing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.print_outlined, size: 20),
                      label: Text(
                        _isCapturing ? 'Capturing...' : 'Confirm & Print',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),"""

new_buttons = """                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D241E),
                            side: const BorderSide(color: Color(0xFF2D241E)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isCapturing ? null : _handleSaveAsJpeg,
                          icon: const Icon(Icons.image_outlined, size: 20),
                          label: const Text('Save as JPEG', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D241E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isCapturing ? null : _handleConfirmPrint,
                          icon: _isCapturing 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.print_outlined, size: 20),
                          label: Text(
                            _isCapturing ? 'Capturing...' : 'Confirm & Print',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),"""

if button_search in content:
    content = content.replace(button_search, new_buttons)
else:
    print("Could not find button search text")

with open("lib/widgets/digital_voucher_dialog.dart", "w") as f:
    f.write(content)
print("Digital voucher patched.")
