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
        type: ReceiptType.customer,
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


# replace the Row containing the buttons
old_buttons = """                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00796B),
                        side: const BorderSide(
                          color: Color(0xFF00796B),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D241E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isCapturing ? null : _handleConfirmPrint,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(
                        _isCapturing ? 'Capturing...' : 'Confirm & Print',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],"""

new_buttons = """                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00796B),
                      side: const BorderSide(
                        color: Color(0xFF00796B),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    ),
                    onPressed: () {
                      if (widget.onEdit != null) {
                        widget.onEdit!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Icon(Icons.edit_note_rounded, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D241E),
                        side: const BorderSide(
                          color: Color(0xFF2D241E),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isCapturing ? null : _handleSaveAsJpeg,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text(
                        'JPEG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D241E),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isCapturing ? null : _handleConfirmPrint,
                      icon: _isCapturing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_rounded, size: 18),
                      label: Text(
                        _isCapturing ? 'Wait...' : 'Print',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],"""

if old_buttons in content:
    content = content.replace(old_buttons, new_buttons)
else:
    print("Could not find button layout block!")

with open("lib/widgets/digital_voucher_dialog.dart", "w") as f:
    f.write(content)
print("Digital voucher JPEG logic patched.")
