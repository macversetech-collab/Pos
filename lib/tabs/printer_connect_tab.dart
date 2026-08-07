import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models.dart';
import '../bluetooth_printer_service.dart';
import '../widgets/app_version_widget.dart';

class PrinterConnectTab extends StatefulWidget {
  final PrinterSettings settings;
  final VoidCallback onSaveSettings;
  final bool isNested;

  const PrinterConnectTab({
    super.key,
    required this.settings,
    required this.onSaveSettings,
    this.isNested = false,
  });

  @override
  State<PrinterConnectTab> createState() => _PrinterConnectTabState();
}

class _PrinterConnectTabState extends State<PrinterConnectTab> {
  List<BluetoothInfo> _devices = [];
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectingMac;
  String? _connectedDeviceName;

  @override
  void initState() {
    super.initState();
    BluetoothPrinterService.connectionStatusNotifier
        .addListener(_onConnectionStatusChanged);
    _checkCurrentConnection();
    _scanDevices();
  }

  @override
  void dispose() {
    BluetoothPrinterService.connectionStatusNotifier
        .removeListener(_onConnectionStatusChanged);
    super.dispose();
  }

  void _onConnectionStatusChanged() {
    if (!mounted) return;
    final bool status = BluetoothPrinterService.connectionStatusNotifier.value;
    setState(() {
      _isConnected = status;
      if (status && widget.settings.bluetoothMac.isNotEmpty) {
        final match = _devices
            .where((d) => d.macAdress == widget.settings.bluetoothMac)
            .firstOrNull;
        _connectedDeviceName = match?.name ?? "Saved Printer";
      } else if (!status) {
        _connectedDeviceName = null;
      }
    });
  }

  Future<void> _checkCurrentConnection() async {
    if (kIsWeb) return;
    final bool connected = await BluetoothPrinterService.getConnectionStatus();
    setState(() {
      _isConnected = connected;
      if (connected && widget.settings.bluetoothMac.isNotEmpty) {
        _connectedDeviceName = "Saved Printer";
      } else {
        _connectedDeviceName = null;
      }
    });
  }

  Future<void> _scanDevices() async {
    if (kIsWeb) return;
    setState(() {
      _isScanning = true;
    });

    try {
      final List<BluetoothInfo> list =
          await BluetoothPrinterService.getPairedDevices();
      setState(() {
        _devices = list;
        // If we find our saved device in the scan results, we can label it
        if (_isConnected && widget.settings.bluetoothMac.isNotEmpty) {
          final savedDevice = list.firstWhere(
            (d) => d.macAdress == widget.settings.bluetoothMac,
            orElse: () => BluetoothInfo(
              name: "Saved Printer",
              macAdress: widget.settings.bluetoothMac,
            ),
          );
          _connectedDeviceName = savedDevice.name;
        }
      });
    } catch (e) {
      debugPrint('Error scanning devices: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _connectDevice(BluetoothInfo device) async {
    setState(() {
      _connectingMac = device.macAdress;
    });

    final bool success = await BluetoothPrinterService.connectToDevice(
      device.macAdress,
    );

    setState(() {
      _connectingMac = null;
      _isConnected = success;
      if (success) {
        _connectedDeviceName = device.name;
        widget.settings.bluetoothMac = device.macAdress;
        widget.settings.connectionInterface = 'bluetooth';
        widget.onSaveSettings(); // Save global config
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Connected to ${device.name} successfully!'
                : 'Failed to connect to ${device.name}.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disconnectDevice() async {
    await BluetoothPrinterService.disconnect();
    setState(() {
      _isConnected = false;
      _connectedDeviceName = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer disconnected.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  Future<void> _printTestPage(String macAddress) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sending test print command...')),
    );

    final result = await BluetoothPrinterService.printTestReceipt(
      macAddress: macAddress,
      settings: widget.settings,
    );

    if (mounted) {
      final success = result == "SUCCESS";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Test page printed!' : 'Test print failed: $result',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      _checkCurrentConnection(); // Refresh connection status
    }
  }

  Widget _buildWebContent() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'Bluetooth Printing Unavailable',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Bluetooth thermal printing is only supported on Android mobile or tablet devices.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (widget.isNested) {
        return _buildWebContent();
      }
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildWebContent(),
          ),
        ),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        if (!widget.isNested) ...[
          const Text(
            'BLUETOOTH PRINTER CENTER',
            style: TextStyle(
              color: Color(0xFF004D40), // Dark Teal
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan, pair, and configure your POS thermal receipt printing hardware',
            style: TextStyle(color: Color(0xFF8C7E6A), fontSize: 11),
          ),
          const SizedBox(height: 16),
        ],

        // 1. Connection Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAE7E2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isConnected
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isConnected
                      ? Icons.print_rounded
                      : Icons.print_disabled_rounded,
                  color: _isConnected
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isConnected
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isConnected
                          ? '${_connectedDeviceName ?? "Device"} (${widget.settings.bluetoothMac})'
                          : 'No printer currently selected or active.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isConnected)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  onPressed: _disconnectDevice,
                  icon: const Icon(
                    Icons.power_settings_new_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Disconnect',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Discover Devices List Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAE7E2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Paired Printers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004D40),
                    ),
                  ),
                  _isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF6D00),
                          ),
                        )
                      : TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6D00),
                          ),
                          onPressed: _scanDevices,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text(
                            'Scan Devices',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
              const Divider(height: 20),

              if (_devices.isEmpty && !_isScanning)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No paired Bluetooth devices found.\nPlease pair the printer in your Android settings first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  final bool isConnecting =
                      _connectingMac == device.macAdress;
                  final bool isThisDeviceSaved =
                      widget.settings.bluetoothMac == device.macAdress;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isThisDeviceSaved
                          ? const Color(0xFFE0F2F1)
                          : const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isThisDeviceSaved
                            ? const Color(0xFF004D40).withValues(alpha: 0.2)
                            : const Color(0xFFEAE7E2),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Icon(
                        Icons.bluetooth,
                        color: isThisDeviceSaved
                            ? const Color(0xFF004D40)
                            : Colors.grey,
                      ),
                      title: Text(
                        device.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        device.macAdress,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Test Print Button
                          IconButton(
                            icon: const Icon(
                              Icons.assignment_turned_in_rounded,
                            ),
                            color: const Color(0xFFFF6D00),
                            iconSize: 20,
                            tooltip: 'Print Test Page',
                            onPressed: () =>
                                _printTestPage(device.macAdress),
                          ),
                          const SizedBox(width: 4),

                          if (isConnecting)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF6D00),
                              ),
                            )
                          else if (isThisDeviceSaved && _isConnected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                            )
                          else
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF004D40),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _connectDevice(device),
                              child: const Text(
                                'Connect',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Printer Settings Configuration (Paper Width Config)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAE7E2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hardware Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF004D40),
                ),
              ),
              const Divider(height: 20),

              // Advanced Settings Trigger Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Advanced Print Settings',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: Color(0xFF004D40),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdvancedSettingsPage(
                            settings: widget.settings,
                            onSave: widget.onSaveSettings,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.isNested) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
        child: content,
      ),
    );
  }
}

class AdvancedSettingsPage extends StatefulWidget {
  final PrinterSettings settings;
  final VoidCallback onSave;

  const AdvancedSettingsPage({
    super.key,
    required this.settings,
    required this.onSave,
  });

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  late String _printMode;
  late String _printWidth;
  late String _printResolution;

  late TextEditingController _initialController;
  late TextEditingController _cutterController;
  late TextEditingController _drawerController;

  @override
  void initState() {
    super.initState();
    _printMode = widget.settings.printMode;
    _printWidth = widget.settings.printWidth;
    _printResolution = widget.settings.printResolution;

    _initialController = TextEditingController(
      text: widget.settings.initialCommands,
    );
    _cutterController = TextEditingController(
      text: widget.settings.cutterCommands,
    );
    _drawerController = TextEditingController(
      text: widget.settings.drawerCommands,
    );
  }

  @override
  void dispose() {
    _initialController.dispose();
    _cutterController.dispose();
    _drawerController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    widget.settings.printMode = _printMode;
    widget.settings.printWidth = _printWidth;
    widget.settings.printResolution = _printResolution;
    widget.settings.initialCommands = _initialController.text;
    widget.settings.cutterCommands = _cutterController.text;
    widget.settings.drawerCommands = _drawerController.text;

    widget.onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced settings'),
        backgroundColor: const Color(
          0xFF4CAF50,
        ), // Vibrant Green matching the screenshot!
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saveAndPop,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Print Mode Dropdown
                _buildLabel('Print mode'),
                DropdownButton<String>(
                  value: _printMode,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Graphic', child: Text('Graphic')),
                    DropdownMenuItem(value: 'Text', child: Text('Text')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _printMode = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Print Width Dropdown
                _buildLabel('Print width'),
                DropdownButton<String>(
                  value: _printWidth,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '48 mm', child: Text('48 mm')),
                    DropdownMenuItem(value: '72 mm', child: Text('72 mm')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _printWidth = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Print Resolution Dropdown
                _buildLabel('Print resolution'),
                DropdownButton<String>(
                  value: _printResolution,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: '203 dpi (8 dots/mm)',
                      child: Text('203 dpi (8 dots/mm)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _printResolution = val);
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Initial ESC/POS Commands
                _buildLabel('Initial ESC/POS commands'),
                TextField(
                  controller: _initialController,
                  decoration: const InputDecoration(hintText: 'e.g. 1B,40'),
                ),
                const SizedBox(height: 20),

                // Cutter ESC/POS Commands
                _buildLabel('Cutter ESC/POS commands'),
                TextField(
                  controller: _cutterController,
                  decoration: const InputDecoration(hintText: '0A,0A,56,42,00'),
                ),
                const SizedBox(height: 20),

                // Drawer ESC/POS Commands
                _buildLabel('Drawer ESC/POS commands'),
                TextField(
                  controller: _drawerController,
                  decoration: const InputDecoration(hintText: '1B,70,00,19,FA'),
                ),
                const SizedBox(height: 30),

                // Save button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onPressed: _saveAndPop,
                  child: const Text(
                    'SAVE SETTINGS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: AppVersionWidget(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
        ),
      ),
    );
  }
}
