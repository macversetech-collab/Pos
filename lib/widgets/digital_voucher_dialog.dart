import 'package:flutter/foundation.dart';
import '../utils/download_helper.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:screenshot/screenshot.dart';
import '../models.dart';
import 'unified_receipt_widget.dart';
import 'thermal_receipt_widget.dart';
import '../services/voucher_repository.dart';

class DigitalVoucherDialog extends StatefulWidget {
  final Order order;
  final String bakeryName;
  final String footerNotes;
  final List<CakeItem> items;
  final void Function(Uint8List imageBytes)? onConfirmPrint;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final bool isViewOnly;

  const DigitalVoucherDialog({
    super.key,
    required this.order,
    required this.bakeryName,
    required this.footerNotes,
    required this.items,
    this.onConfirmPrint,
    this.onEdit,
    this.onCancel,
    this.isViewOnly = false,
  });

  @override
  State<DigitalVoucherDialog> createState() => _DigitalVoucherDialogState();
}

class _DigitalVoucherDialogState extends State<DigitalVoucherDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _isCapturing = false;


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
        
      );

      if (kIsWeb) {
        await downloadImageWeb(pngBytes, "Customer_Voucher_${widget.order.orderNumber}");
      } else {
        await Gal.putImageBytes(
          pngBytes,
          name: "Customer_Voucher_${widget.order.orderNumber}",
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher saved to gallery successfully!')),
        );
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

  Future<void> _handleConfirmPrint() async {
    if (widget.onConfirmPrint == null) return;
    setState(() => _isCapturing = true);

    try {
      // Ensure voucher exists idempotently before printing
      await VoucherRepository().ensureVoucher(
        orderId: widget.order.id,
        orderNumber: widget.order.orderNumber,
        voucherType: 'customer',
      );

      // Render ThermalReceiptWidget offscreen — do NOT screenshot the preview UI.
      // 384 logical × 1.5 pixelRatio = 576 physical px = 80mm @ 203dpi
      const double logicalWidth = 384.0;

      final thermalWidget = ThermalReceiptWidget(
        order: widget.order,
        activeItems: widget.items,
        width: logicalWidth,
      );

      final screenshotController = ScreenshotController();
      final Uint8List pngBytes = await screenshotController.captureFromWidget(
        thermalWidget,
        pixelRatio: 1.5,
        delay: const Duration(milliseconds: 150),
         // tall enough for any receipt + footer
      );

      widget.onConfirmPrint!(pngBytes);
    } catch (e) {
      debugPrint('Error generating thermal receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating thermal receipt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 24.0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF004D40), // ASH Deep Teal
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (widget.onCancel != null) {
                        widget.onCancel!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'VOUCHER PREVIEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00897B), // Secondary Teal
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CUSTOMER VOUCHER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.order.orderNumber,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.isViewOnly) ...[
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      onPressed: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(
                        Icons.edit,
                        size: 13,
                        color: Color(0xFFFF6D00), // Orange Accent
                      ),
                      label: const Text(
                        'EDIT SPECS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Voucher receipt area with light warm contrast background
            Flexible(
              child: Container(
                color: const Color(0xFFF0EFEA), // desk gray backdrop
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Subheading inside preview area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: Color(0xFF00897B),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'DIGITAL THERMAL VOUCHER PREVIEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00897B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF004D40), // Deep Teal
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                            child: Text(
                              'EST. VALUE: ${widget.order.totalAmount.toLocaleString()} MMK',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Shared Unified Widget wrapped with RepaintBoundary
                      RepaintBoundary(
                        key: _boundaryKey,
                        child: UnifiedReceiptWidget(
                          order: widget.order,
                          activeItems: widget.items,
                          bakeryName: widget.bakeryName,
                          footerNotes: widget.footerNotes,
                          width: 380,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Handling Setup Section (UI only, not printed)
                      _buildPaymentHandlingSetup(widget.order),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog bottom action control bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF9F6),
                border: Border(
                  top: BorderSide(color: Color(0xFFEAE7E2), width: 1.5),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF8C7E6A),
                        side: const BorderSide(
                          color: Color(0xFFEAE7E2),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        if (widget.onCancel != null) {
                          widget.onCancel!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        widget.isViewOnly ? 'Close' : 'Cancel',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (!widget.isViewOnly) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00897B), // Teal outline
                          side: const BorderSide(
                            color: Color(0xFF00897B),
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
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6D00), // Orange outline
                          side: const BorderSide(color: Color(0xFFFF6D00), width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isCapturing ? null : _handleSaveAsJpeg,
                        icon: const Icon(Icons.image_outlined, size: 18),
                        label: const Text(
                          'JPEG',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40), // Solid Deep Teal
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
                          _isCapturing ? 'Capturing...' : 'Print',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentHandlingSetup(Order order) {
    final bool isDeposit = order.paymentStatus == 'deposit';
    final bool isFullyPaid = order.paymentStatus == 'fully_paid';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFEAE7E2), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wallet, color: Color(0xFF00897B), size: 16),
              const SizedBox(width: 6),
              const Text(
                'PAYMENT SETTLEMENT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF00897B),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isDeposit ? const Color(0xFFFFF3E0) : Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isDeposit
                          ? const Color(0xFFFF6D00)
                          : const Color(0xFFEAE7E2),
                      width: isDeposit ? 2.0 : 1.0,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'DEPOSIT (စရံပေး)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF2D241E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Partial Breakdown',
                        style: TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isFullyPaid ? const Color(0xFFE8F5E9) : Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isFullyPaid
                          ? const Color(0xFF00897B)
                          : const Color(0xFFEAE7E2),
                      width: isFullyPaid ? 2.0 : 1.0,
                    ),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'FULLY PAID (ရှင်းပြီး)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF2D241E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Balance = 0',
                        style: TextStyle(
                          fontSize: 8,
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
