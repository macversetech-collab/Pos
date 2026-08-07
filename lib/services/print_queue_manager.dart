import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../bluetooth_printer_service.dart';
import '../models.dart';

class PrintJob {
  final String id;
  final Uint8List imageBytes;
  final String macAddress;
  final PrinterSettings settings;
  final Completer<bool>? completer;
  int retryCount;

  PrintJob({
    required this.id,
    required this.imageBytes,
    required this.macAddress,
    required this.settings,
    this.completer,
    this.retryCount = 0,
  });
}

class PrintQueueManager {
  static const String _boxName = 'print_queue_box';
  static final PrintQueueManager _instance = PrintQueueManager._internal();
  factory PrintQueueManager() => _instance;
  PrintQueueManager._internal();

  final Queue<PrintJob> _queue = Queue();
  final Set<String> _printedJobs = {};
  bool _isProcessing = false;
  Box? _box;
  bool _initialized = false;

  /// Initializes the Hive Box for offline persistent printing, reloads any
  /// pending print jobs, and starts processing the queue.
  Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox(_boxName);
      _loadQueue();
      _initialized = true;
      debugPrint('[PrintQueueManager] Persistent print queue initialized.');
      _processQueue();
    } catch (e) {
      debugPrint('[PrintQueueManager] Error initializing box: $e');
    }
  }

  /// Adds a new job to the printing queue.
  /// Deduplicates jobs using a unique job ID to avoid double-printing.
  void addJob(PrintJob job) {
    if (_printedJobs.contains(job.id)) {
      debugPrint('DUPLICATE PRINT JOB SKIPPED: ${job.id}');
      job.completer?.complete(true);
      return;
    }

    debugPrint("QUEUE ADD: ${job.id}");
    _queue.add(job);
    _saveQueue();
    _processQueue();
  }

  /// Internal queue worker loop that processes print jobs sequentially.
  /// Automatically handles offline waiting and auto-reconnects lost sockets.
  Future<void> _processQueue() async {
    if (!_initialized) {
      await init();
    }
    if (_isProcessing) return;
    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final job = _queue.first;

      // 3. OFFLINE PRINT SUPPORT
      bool isConnected = await BluetoothPrinterService.getConnectionStatus();
      if (!isConnected) {
        debugPrint("[PrintQueueManager] Offline. Attempting auto reconnect to ${job.macAddress}...");
        // 4. AUTO RECONNECT
        isConnected = await BluetoothPrinterService.connectToDevice(job.macAddress);
      }

      if (!isConnected) {
        debugPrint("[PrintQueueManager] Still offline. Waiting 2 seconds before retry...");
        await Future.delayed(const Duration(seconds: 2));
        continue; // Keep looping until printer reconnects
      }

      debugPrint("PRINTING: ${job.id}");

      try {
        final result = await BluetoothPrinterService.printRasterizedReceiptImage(
          macAddress: job.macAddress,
          imageBytes: job.imageBytes,
          settings: job.settings,
        );

        if (result == "SUCCESS") {
          debugPrint("SUCCESS: ${job.id}");
          _printedJobs.add(job.id);
          job.completer?.complete(true);
          _queue.removeFirst();
          _saveQueue();
        } else {
          throw Exception(result);
        }
      } catch (e) {
        job.retryCount++;
        debugPrint("RETRY: ${job.id}");
        debugPrint("[PrintQueueManager] Print job failed: $e. Retry count: ${job.retryCount}/3");

        if (job.retryCount <= 3) {
          _saveQueue();
          await Future.delayed(const Duration(seconds: 2));
        } else {
          debugPrint("[PrintQueueManager] Job ${job.id} failed after 3 retries. Dropping.");
          job.completer?.complete(false);
          _queue.removeFirst();
          _saveQueue();
        }
      }

      await Future.delayed(const Duration(milliseconds: 300)); // Spacing between jobs
    }

    _isProcessing = false;
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  void _saveQueue() {
    final box = _box;
    if (box == null) return;
    try {
      final List<Map<String, dynamic>> serialized = _queue.map((job) => _jobToMap(job)).toList();
      box.put('pending_jobs', serialized);
    } catch (e) {
      debugPrint('[PrintQueueManager] Error saving queue to box: $e');
    }
  }

  void _loadQueue() {
    final box = _box;
    if (box == null) return;
    try {
      final stored = box.get('pending_jobs');
      if (stored is List) {
        for (var item in stored) {
          if (item is Map) {
            _queue.add(_jobFromMap(item, null));
          }
        }
        debugPrint('[PrintQueueManager] Loaded ${_queue.length} pending jobs from storage.');
      }
    } catch (e) {
      debugPrint('[PrintQueueManager] Error loading queue from box: $e');
    }
  }

  Map<String, dynamic> _jobToMap(PrintJob job) {
    return {
      'id': job.id,
      'imageBytes': job.imageBytes,
      'macAddress': job.macAddress,
      'settings': _settingsToMap(job.settings),
      'retryCount': job.retryCount,
    };
  }

  PrintJob _jobFromMap(Map<dynamic, dynamic> map, Completer<bool>? completer) {
    return PrintJob(
      id: map['id']?.toString() ?? '',
      imageBytes: map['imageBytes'] as Uint8List,
      macAddress: map['macAddress']?.toString() ?? '',
      settings: _settingsFromMap(map['settings'] as Map),
      completer: completer,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _settingsToMap(PrinterSettings s) {
    return {
      'connectionInterface': s.connectionInterface,
      'paperWidth': s.paperWidth,
      'bluetoothMac': s.bluetoothMac,
      'ethernetIp': s.ethernetIp,
      'ethernetPort': s.ethernetPort,
      'openCashDrawer': s.openCashDrawer,
      'autoPaperCut': s.autoPaperCut,
      'bakeryName': s.bakeryName,
      'footerNotes': s.footerNotes,
      'printMode': s.printMode,
      'printWidth': s.printWidth,
      'printResolution': s.printResolution,
      'initialCommands': s.initialCommands,
      'cutterCommands': s.cutterCommands,
      'drawerCommands': s.drawerCommands,
    };
  }

  PrinterSettings _settingsFromMap(Map<dynamic, dynamic> map) {
    return PrinterSettings(
      connectionInterface: map['connectionInterface']?.toString() ?? 'bluetooth',
      paperWidth: map['paperWidth']?.toString() ?? '80mm',
      bluetoothMac: map['bluetoothMac']?.toString() ?? '00:11:22:33:FF:EE',
      ethernetIp: map['ethernetIp']?.toString() ?? '192.168.1.100',
      ethernetPort: (map['ethernetPort'] as num?)?.toInt() ?? 9100,
      openCashDrawer: map['openCashDrawer'] == true,
      autoPaperCut: map['autoPaperCut'] == true,
      bakeryName: map['bakeryName']?.toString() ?? 'ASH Bakery',
      footerNotes: map['footerNotes']?.toString() ?? '',
      printMode: map['printMode']?.toString() ?? 'Graphic',
      printWidth: map['printWidth']?.toString() ?? '72 mm',
      printResolution: map['printResolution']?.toString() ?? '203 dpi (8 dots/mm)',
      initialCommands: map['initialCommands']?.toString() ?? '',
      cutterCommands: map['cutterCommands']?.toString() ?? '1D,56,42,00',
      drawerCommands: map['drawerCommands']?.toString() ?? '1B,70,00,19,FA',
    );
  }
}
