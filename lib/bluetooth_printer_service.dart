import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/thermal_receipt_widget.dart';

class BluetoothPrinterService {
  // Prevent instantiation
  BluetoothPrinterService._();

  /// Requests Android Bluetooth permissions if not already granted.
  static Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    try {
      final bool isGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return isGranted;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Discovers paired Bluetooth devices on the system.
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    if (kIsWeb) return [];
    try {
      final bool isGranted = await requestPermissions();
      if (!isGranted) return [];
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      debugPrint('Error fetching paired Bluetooth devices: $e');
      return [];
    }
  }

  static String? _targetMac;
  static bool _isConnecting = false;
  static bool _isPrinting = false;

  /// Single source of truth for Bluetooth connection status across the app.
  static final ValueNotifier<bool> connectionStatusNotifier =
      ValueNotifier<bool>(false);

  /// Getter for configured target printer MAC address.
  static String? get targetMac => _targetMac;

  /// Configures the target printer MAC address without holding a persistent socket connection.
  static void setTargetMac(String macAddress) {
    _targetMac = macAddress;
  }

  /// Connects to a specific Bluetooth thermal printer by MAC address.
  static Future<bool> connectToDevice(String macAddress) async {
    if (kIsWeb) return false;

    _targetMac = macAddress;

    // Timeout safety for spin lock
    int spinAttempts = 0;
    while (_isConnecting && spinAttempts < 30) {
      await Future.delayed(const Duration(milliseconds: 100));
      spinAttempts++;
    }

    _isConnecting = true;

    try {
      await _internalDisconnect(); // Clear stale connection state before reconnecting
      await Future.delayed(
        const Duration(milliseconds: 200),
      ); // Allow Android OS to release socket

      final bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Bluetooth connection attempt timed out (5s)');
          return false;
        },
      );
      connectionStatusNotifier.value = connected;
      return connected;
    } catch (e) {
      debugPrint('Error connecting to Bluetooth printer: $e');
      connectionStatusNotifier.value = false;
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Disconnects from the current printer.
  static Future<bool> disconnect() async {
    _targetMac = null;
    final bool result = await _internalDisconnect();
    connectionStatusNotifier.value = false;
    return result;
  }

  static Future<bool> _internalDisconnect() async {
    if (kIsWeb) return false;
    try {
      final bool res = await PrintBluetoothThermal.disconnect.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      return res;
    } catch (e) {
      debugPrint('Error disconnecting Bluetooth printer: $e');
      return false;
    }
  }

  /// Checks whether a printer is currently connected and updates the single notifier source.
  static Future<bool> getConnectionStatus() async {
    if (kIsWeb) {
      connectionStatusNotifier.value = false;
      return false;
    }
    try {
      final bool status = await PrintBluetoothThermal.connectionStatus.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      connectionStatusNotifier.value = status;
      return status;
    } catch (e) {
      debugPrint('Error checking connection status: $e');
      connectionStatusNotifier.value = false;
      return false;
    }
  }

  static List<int> _parseHexCommands(String commandStr) {
    if (commandStr.trim().isEmpty) return [];
    try {
      return commandStr
          .split(',')
          .map((s) => int.parse(s.trim(), radix: 16))
          .toList();
    } catch (e) {
      debugPrint('Error parsing hex commands: $e');
      return [];
    }
  }

  /// Formats and prints a test page to verify connection and paper width.
  static Future<String> printTestReceipt({
    required String macAddress,
    required PrinterSettings settings,
  }) async {
    if (kIsWeb) return "Platform Web Not Supported";
    if (_isPrinting) {
      debugPrint('Printer is busy. Skipping test print job.');
      return "PRINTING_IN_PROGRESS";
    }
    _isPrinting = true;
    bool writeAttempted = false;

    try {
      const paperSize = PaperSize.mm80;
      const double width = 576.0;

      const double scale = 1.5;
      final double fontSizeTitle = 24.0 * scale;
      final double fontSizeBody = 16.0 * scale;

      final testWidget = Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
        color: Colors.white,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cake, size: 28, color: Colors.black),
                    const SizedBox(width: 8.0),
                    Text(
                      'ASH Bakery',
                      style: GoogleFonts.dancingScript(
                        fontSize: fontSizeTitle,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Text(
                  'Connection Successful',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeBody,
                    color: Colors.black,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Paper size: ${paperSize == PaperSize.mm58 ? "58mm" : "80mm"}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: fontSizeBody, color: Colors.black),
                ),
                const SizedBox(height: 8.0),
                Text(
                  DateTime.now().toLocal().toString().substring(0, 19),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSizeBody,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final screenshotController = ScreenshotController();
      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        testWidget,
        pixelRatio: 1.0,
        delay: const Duration(milliseconds: 10),
      );

      final img.Image? originalImage = img.decodeImage(imageBytes);
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      if (settings.initialCommands.isNotEmpty) {
        bytes += _parseHexCommands(settings.initialCommands);
      }

      if (originalImage == null) {
        bytes += generator.text('*** ASH BAKERY TEST ***');
        bytes += generator.text('ERROR: DECODE_IMAGE_FAILED');
        bytes += generator.feed(2);
      } else {
        final img.Image grayscaleImage = img.grayscale(originalImage);
        bytes += generator.imageRaster(grayscaleImage, align: PosAlign.left);
        bytes += generator.feed(1); // Minimal feed to cutter
      }

      String cutterCmd = settings.cutterCommands;
      if (cutterCmd == '0A,0A,56,42,00' || cutterCmd.contains('56,42')) {
        cutterCmd = '1D,56,42,00';
      }

      if (cutterCmd.isNotEmpty) {
        bytes += _parseHexCommands(cutterCmd);
      } else {
        bytes += generator.cut();
      }
      bytes += generator.reset();

      bool isConnected = await getConnectionStatus();
      if (!isConnected) {
        isConnected = await connectToDevice(macAddress);
      }
      if (!isConnected) return "CONNECTION_FAILED";
      
      // Delay before sending to prevent partial buffer send
      await Future.delayed(const Duration(milliseconds: 100));

      writeAttempted = true;
      bool success = await PrintBluetoothThermal.writeBytes(bytes).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Bluetooth writeBytes attempt timed out (5s)');
          return false;
        },
      );

      if (!success) {
        debugPrint('Test print failed, retrying after 300ms...');
        await Future.delayed(const Duration(milliseconds: 300));
        success = await PrintBluetoothThermal.writeBytes(bytes).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Bluetooth retry writeBytes attempt timed out (5s)');
            return false;
          },
        );
      }
      
      return success ? "SUCCESS" : "WRITE_BYTES_FAILED";
    } catch (e) {
      debugPrint('Error printing test receipt: $e');
      return "ERROR: $e";
    } finally {
      if (writeAttempted) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _internalDisconnect();
      connectionStatusNotifier.value = false;
      _isPrinting = false;
    }
  }

  /// Formats and prints a receipt for a given Order matching the uploaded layout reference.
  static Future<String> printOrderReceipt({
    required String macAddress,
    required Order order,
    required String cakeName,
    required PrinterSettings settings,
  }) async {
    if (kIsWeb) return "Platform Web Not Supported";

    try {
      // Retrieve items from database to supply to UnifiedReceiptWidget
      List<CakeItem> activeItems = [];
      try {
        final res = await Supabase.instance.client.from('cake_items').select();
        activeItems = (res as List).map((r) {
          final pricingMap = Map<String, int>.from(r['pricing'] ?? {});
          return CakeItem(
            id: r['id'] as String,
            name: r['name'] as String,
            sizes: List<String>.from(r['sizes'] ?? []),
            variants: List<String>.from(r['variants'] ?? []),
            pricing: pricingMap,
          );
        }).toList();
      } catch (e) {
        debugPrint("Failed to fetch items from Supabase for printing: $e");
      }

      // 384 logical × 1.5 pixelRatio = 576 physical pixels = 80mm @ 203dpi
      const double logicalWidth = 384.0;
      const double pixelRatio = 1.5;

      // Use dedicated thermal widget — compact black-only layout for 80mm paper
      final receiptWidget = ThermalReceiptWidget(
        order: order,
        activeItems: activeItems,
        width: logicalWidth,
      );

      // Capture at 1.5× to get 576px physical output matching 80mm paper exactly
      final screenshotController = ScreenshotController();
      final Uint8List imageBytes = await screenshotController.captureFromWidget(
        receiptWidget,
        pixelRatio: pixelRatio,
        delay: const Duration(milliseconds: 80),
      );

      return await printRasterizedReceiptImage(
        macAddress: macAddress,
        imageBytes: imageBytes,
        settings: settings,
      );
    } catch (e) {
      debugPrint('Error printing legacy receipt: $e');
      return "ERROR: $e";
    }
  }

  /// Prints a pre-rasterized receipt PNG byte array directly to the printer.
  static Future<String> printRasterizedReceiptImage({
    required String macAddress,
    required Uint8List imageBytes,
    required PrinterSettings settings,
  }) async {
    if (kIsWeb) return "Platform Web Not Supported";
    if (_isPrinting) {
      debugPrint('Printer is busy. Skipping print job.');
      return "PRINTING_IN_PROGRESS";
    }
    _isPrinting = true;
    bool writeAttempted = false;

    try {
      const paperSize = PaperSize.mm80;

      final img.Image? originalImage = img.decodeImage(imageBytes);
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      String initCmd = settings.initialCommands.replaceAll('0A,0A,56,42,00', '').replaceAll('56,42', '');
      if (initCmd.isNotEmpty) {
        bytes += _parseHexCommands(initCmd);
      }
      String drawCmd = settings.drawerCommands.replaceAll('0A,0A,56,42,00', '').replaceAll('56,42', '');
      if (drawCmd.isNotEmpty) {
        bytes += _parseHexCommands(drawCmd);
      }

      if (originalImage == null) {
        bytes += generator.text('*** ASH BAKERY ***');
        bytes += generator.text('ERROR: DECODE_IMAGE_FAILED');
        bytes += generator.text('Please retry printing the voucher.');
        bytes += generator.feed(2);
      } else {
        // Convert to grayscale
        final img.Image grayscaleImage = img.grayscale(originalImage);
        bytes += generator.imageRaster(grayscaleImage, align: PosAlign.left);
        bytes += generator.feed(1); // Minimal feed; cutter command advances paper to blade
      }

      String cutterCmd = settings.cutterCommands;
      if (cutterCmd == '0A,0A,56,42,00' || cutterCmd.contains('56,42')) {
        cutterCmd = '1D,56,42,00';
      }

      if (cutterCmd.isNotEmpty) {
        bytes += _parseHexCommands(cutterCmd);
      } else {
        bytes += generator.cut();
      }
      
      bytes += generator.reset();

      // Connect only after the complete printable byte buffer is ready.
      bool isConnected = await getConnectionStatus();
      if (!isConnected) {
        isConnected = await connectToDevice(macAddress);
      }
      if (!isConnected) {
        debugPrint('Could not connect to printer at $macAddress');
        connectionStatusNotifier.value = false;
        return "CONNECTION_FAILED";
      }

      // Delay before sending to prevent partial buffer send
      await Future.delayed(const Duration(milliseconds: 100));

      // Write raw bytes to printer
      writeAttempted = true;
      bool success = await PrintBluetoothThermal.writeBytes(bytes).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Bluetooth writeBytes attempt timed out (5s)');
          return false;
        },
      );

      if (!success) {
        debugPrint('Print failed, retrying after 300ms...');
        await Future.delayed(const Duration(milliseconds: 300));
        success = await PrintBluetoothThermal.writeBytes(bytes).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Bluetooth retry writeBytes attempt timed out (5s)');
            return false;
          },
        );
      }

      return success ? "SUCCESS" : "WRITE_BYTES_FAILED";
    } catch (e) {
      debugPrint('Error printing rasterized receipt: $e');
      return "ERROR: $e";
    } finally {
      if (writeAttempted) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      await _internalDisconnect();
      connectionStatusNotifier.value = false;
      _isPrinting = false;
    }
  }
}
