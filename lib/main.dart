import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'widgets/fade_indexed_stack.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_theme.dart';
import 'models.dart';
import 'services/order_repository.dart';
import 'services/catalog_repository.dart';
import 'services/print_queue_manager.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/order_form_tab.dart';
import 'tabs/settings_tab.dart';
import 'tabs/printer_connect_tab.dart';
import 'tabs/counter_showline_tab.dart';
import 'widgets/digital_voucher_dialog.dart';
import 'widgets/thermal_receipt_widget.dart';
import 'bluetooth_printer_service.dart';
import 'package:screenshot/screenshot.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/auth_service.dart';
import 'services/voucher_repository.dart';
import 'services/closure_repository.dart';
import 'screens/login_screen.dart';
import 'widgets/app_version_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://vvuinevpbvzvdrzwwcgm.supabase.co',
    publishableKey: 'sb_publishable_K_Siqrx9gXE9T22kpUOdHQ_ZI66dB45',
  );
  await OrderRepository().init();
  await CatalogRepository().init();
  await VoucherRepository().init();
  await PrintQueueManager().init();
  await AuthService().init();
  await ClosureRepository().init();
  runApp(const SweetBloomApp());
}

class SweetBloomApp extends StatelessWidget {
  const SweetBloomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASH Bakery POS',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE0F7FA), // Fallback light cyan
        primaryColor: const Color(0xFF00796B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B),
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFFFFB74D), // Soft pastel orange
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF004D40),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF004D40),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF004D40)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00796B),
            foregroundColor: Colors.white,
            elevation: 2,
            shadowColor: const Color(0x3300796B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.tealMain.withValues(alpha: 0.04), // Tinted glass surface
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: AppColors.tealMain.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: AppColors.tealMain.withValues(alpha: 0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: BorderSide(color: AppColors.tealMain.withValues(alpha: 0.8), width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: const BorderSide(color: Color(0x11FFFFFF)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.tealDark, fontWeight: FontWeight.w600),
          hintStyle: TextStyle(color: AppColors.tealMain.withValues(alpha: 0.4)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQueryData.copyWith(
            textScaler: WebResponsiveTextScaler(
              delegate: mediaQueryData.textScaler,
              screenWidth: mediaQueryData.size.width,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkedAuth = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final role = await AuthService().checkCurrentRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _checkedAuth = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00796B)),
        ),
      );
    }

    if (_userRole == null) {
      return LoginScreen(
        onLoginSuccess: () {
          _checkAuth();
        },
      );
    }

    return const MainNavigationScreen();
  }
}

/// A custom [TextScaler] that dynamically scales up "big fonts" (fontSize >= 13)
/// on the web platform when the window/screen width exceeds 800 pixels.
class WebResponsiveTextScaler extends TextScaler {
  final TextScaler delegate;
  final double screenWidth;

  const WebResponsiveTextScaler({
    required this.delegate,
    required this.screenWidth,
  });

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => delegate.textScaleFactor;

  @override
  double scale(double fontSize) {
    final double originalScaled = delegate.scale(fontSize);

    // Only apply dynamic window-width scaling on Web for font sizes >= 8
    if (kIsWeb && screenWidth > 800 && fontSize >= 8) {
      // Scale factor ranges from 1.0 (at width 800) to 1.6 (at width 2000+)
      double factor = 1.0 + (screenWidth - 800) * 0.0005;
      if (factor > 1.6) factor = 1.6;
      return originalScaled * factor;
    }

    return originalScaled;
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentTabIndex = 0;

  List<CakeSize> _sizes = [];
  List<CakeItem> _items = [];

  final List<Order> _orders = [];
  final PrinterSettings _printerSettings = PrinterSettings();
  Order? _editingOrder;
  final Set<String> _submittedOrderIds = {};
  int _orderFormResetCounter = 0;

  @override
  void initState() {
    super.initState();
    _seedInitialMockOrders();
    _loadCachedCatalogData();
    unawaited(_fetchCatalogData());
    _initConnectivityListener();
    _loadPrinterSettings();
  }

  Future<void> _loadPrinterSettings() async {
    try {
      final box = await Hive.openBox('settings');
      final savedMac = box.get('bluetoothMac') as String?;
      if (savedMac != null && savedMac.isNotEmpty) {
        setState(() {
          _printerSettings.bluetoothMac = savedMac;
        });
        BluetoothPrinterService.setTargetMac(savedMac);
      }
    } catch (e) {
      debugPrint('Error loading printer settings: $e');
    }
  }

  Future<void> _savePrinterSettings() async {
    try {
      final box = await Hive.openBox('settings');
      await box.put('bluetoothMac', _printerSettings.bluetoothMac);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  void _initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (!results.contains(ConnectivityResult.none)) {
        OrderRepository().syncPendingOrders();
      }
    });
  }

  Future<void> _fetchCatalogData() async {
    final refreshed = await CatalogRepository().refreshFromRemote();
    if (refreshed == null || !mounted) return;
    _applyCatalog(refreshed);
  }

  void _loadCachedCatalogData() {
    final cached = CatalogRepository().getCachedCatalog();
    if (cached.sizes.isEmpty || cached.items.isEmpty) return;
    _applyCatalog(cached);
  }

  void _applyCatalog(CatalogSnapshot catalog) {
    if (!mounted) return;
    setState(() {
      _sizes = catalog.sizes;
      _items = catalog.items;
    });
  }

  void _seedInitialMockOrders() {
    _orders.addAll([
      Order(
        id: 'ord-1',
        orderNumber: 'KB-20260628-01',
        deliveryDate: '2026-06-28',
        deliveryTime: '08:30',
        itemId: 'item-1',
        size: '6"',
        variant: 'Classic',
        designCode: 'ASH-001',
        customName: 'Mya Mya',
        customLettering: 'Happy 24th Birthday Mya Mya!',
        customerPhone: '09-450123456',
        paymentStatus: 'fully_paid',
        depositPaid: 35000,
        remainingBalance: 0,
        isKpay: true,
        totalAmount: 35000,
        deliveryCost: 2000,
        orderFrom: 'Page',
        createdAt: DateTime.parse('2026-06-26T10:30:00'),
        printCount: 2,
      ),
      Order(
        id: 'ord-2',
        orderNumber: 'KB-20260629-01',
        deliveryDate: '2026-06-29',
        deliveryTime: '11:30',
        itemId: 'item-2',
        size: '6"',
        variant: 'Classic',
        designCode: 'BD-156',
        customName: 'Ko Kyaw',
        customLettering: 'HBD Ko Kyaw!',
        customerPhone: '09-971234567',
        paymentStatus: 'deposit',
        depositPaid: 11000,
        remainingBalance: 11500,
        isKpay: false,
        totalAmount: 22500,
        deliveryCost: 0,
        orderFrom: 'Walk-In',
        createdAt: DateTime.parse('2026-06-27T14:15:00'),
        printCount: 1,
      ),
      Order(
        id: 'ord-3',
        orderNumber: 'KB-20260630-01',
        deliveryDate: '2026-06-30',
        deliveryTime: '16:00',
        itemId: 'item-3',
        size: '8"',
        variant: 'Special',
        designCode: 'ASH-008',
        customName: 'Thidar',
        customLettering: 'Congratulations Thidar!',
        customerPhone: '09-250987654',
        paymentStatus: 'deposit',
        depositPaid: 15000,
        remainingBalance: 30000,
        isKpay: true,
        totalAmount: 45000,
        deliveryCost: 3000,
        orderFrom: 'Viber',
        createdAt: DateTime.parse('2026-06-28T09:00:00'),
        printCount: 0,
      ),
    ]);
  }

  Future<bool> _printReceiptImage(Uint8List imageBytes) async {
    if (kIsWeb) return false;
    if (_printerSettings.bluetoothMac.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No Bluetooth printer configured. Please connect a printer first in the Printer tab.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Generate unique job ID to support distinct copies while deduplicating exact overlaps
    final String jobId = "${DateTime.now().millisecondsSinceEpoch}_${imageBytes.hashCode}";
    final completer = Completer<bool>();

    final job = PrintJob(
      id: jobId,
      imageBytes: imageBytes,
      macAddress: _printerSettings.bluetoothMac,
      settings: _printerSettings,
      completer: completer,
    );

    PrintQueueManager().addJob(job);

    final bool success = await completer.future;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Receipt printed successfully!'
                : 'Failed to print. Job was dropped or failed.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
    return success;
  }

  Future<Uint8List> _captureReceiptWidget(Order order, ReceiptType type) async {
    const double logicalWidth = 384.0;
    final thermalWidget = ThermalReceiptWidget(
      order: order,
      activeItems: _items,
      width: logicalWidth,
      type: type,
    );
    final screenshotController = ScreenshotController();
    return await screenshotController.captureFromWidget(
      thermalWidget,
      pixelRatio: 1.5,
      delay: const Duration(milliseconds: 150),
    );
  }

  void _saveOrderToMemoryAndClearDraft(Order submitted, bool isEdit) {
    setState(() {
      final existingIndex = _orders.indexWhere(
        (o) => o.id == submitted.id,
      );
      final updatedOrder = Order(
        id: submitted.id,
        orderNumber: submitted.orderNumber,
        deliveryDate: submitted.deliveryDate,
        deliveryTime: submitted.deliveryTime,
        itemId: submitted.itemId,
        size: submitted.size,
        variant: submitted.variant,
        designCode: submitted.designCode,
        customName: submitted.customName,
        customAge: submitted.customAge,
        customDate: submitted.customDate,
        customLettering: submitted.customLettering,
        specialInstructions: submitted.specialInstructions,
        customerPhone: submitted.customerPhone,
        paymentStatus: submitted.paymentStatus,
        depositPaid: submitted.depositPaid,
        remainingBalance: submitted.remainingBalance,
        isKpay: submitted.isKpay,
        totalAmount: submitted.totalAmount,
        toysCost: submitted.toysCost,
        moneyPullingCost: submitted.moneyPullingCost,
        moneyPullingNote: submitted.moneyPullingNote,
        deliveryCost: submitted.deliveryCost,
        orderFrom: submitted.orderFrom,
        createdAt: submitted.createdAt,
        printCount: submitted.printCount,
        printStatus: isEdit ? submitted.printStatus : 'pending',
        isPrepOnly: submitted.isPrepOnly,
      );
      if (existingIndex != -1) {
        _orders[existingIndex] = updatedOrder;
      } else {
        _orders.add(updatedOrder);
      }
      _editingOrder = null;
      _orderFormResetCounter++;
    });

    if (!isEdit) {
      OrderRepository().clearDraft();
    }
  }

  void _navigateToCalendarTab() {
    if (!mounted) return;
    final bool compact = MediaQuery.of(context).size.width < 800 && !kIsWeb;
    final String userRole = AuthService().getCachedRole() ?? 'staff';
    final bool isAdmin = userRole == 'admin';
    final bool isSale = userRole == 'sale';
    final List<bool> visibilities = [
      isAdmin || isSale,
      isAdmin && !compact,
      true, // Calendar
      isAdmin && !compact,
      isAdmin || isSale,
      isAdmin && !compact,
    ];
    int calendarIndex = 0;
    for (int i = 0; i < 2; i++) {
      if (visibilities[i]) {
        calendarIndex++;
      }
    }
    setState(() {
      _currentTabIndex = calendarIndex;
    });
  }

  void _showPrintingProgressDialog(BuildContext context, String title, String subtitle) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF00796B)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF2D241E)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPrintRetryOptionsDialog(
    Order order,
    Uint8List customerBytes, {
    String? failedReason,
    bool isPartialFail = false,
  }) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext retryContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPartialFail ? 'Kitchen Copy Failed' : 'Receipt Printing Failed',
                  style: TextStyle(
                    color: const Color(0xFF2D241E),
                    fontWeight: FontWeight.bold,
                    fontSize: retryContext.responsiveFont(15, min: 13, max: 18),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                failedReason ??
                    'Printer experienced an error (e.g. paper out, Bluetooth disconnect, or timeout).\n\nYour order is safely saved! Select a retry option:',
                style: const TextStyle(fontSize: 12.5, color: Colors.black87),
              ),
              if (order.customerPrinted || order.kitchenPrinted) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F2EC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEAE7E2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Customer: ${order.customerPrinted ? "✅ Printed" : "❌ Not Printed"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: order.customerPrinted ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Kitchen: ${order.kitchenPrinted ? "✅ Printed" : "❌ Not Printed"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: order.kitchenPrinted ? Colors.green[800] : Colors.red[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Smart highlight: If Customer printed but Kitchen failed -> Recommend Kitchen Only
                if (order.customerPrinted && !order.kitchenPrinted) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: false, singleType: ReceiptType.kitchen);
                    },
                    icon: const Icon(Icons.kitchen, size: 16),
                    label: const Text('Reprint: Kitchen Only (Recommended)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D241E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: true);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reprint Both (Customer + Kitchen)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ] else if (order.kitchenPrinted && !order.customerPrinted) ...[
                  // Smart highlight: If Kitchen printed but Customer failed -> Recommend Customer Only
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: false, singleType: ReceiptType.customer);
                    },
                    icon: const Icon(Icons.person_rounded, size: 16),
                    label: const Text('Reprint: Customer Only (Recommended)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D241E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: true);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reprint Both (Customer + Kitchen)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ] else ...[
                  // Standard options
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004D40),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: true);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry: Customer + Kitchen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D241E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: false, singleType: ReceiptType.customer);
                    },
                    icon: const Icon(Icons.person_rounded, size: 16),
                    label: const Text('Retry: Customer Only', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D241E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      Navigator.of(retryContext).pop();
                      await _executePrintWorkflow(order, customerBytes, printBoth: false, singleType: ReceiptType.kitchen);
                    },
                    icon: const Icon(Icons.kitchen, size: 16),
                    label: const Text('Retry: Kitchen Only', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
                const SizedBox(height: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8C7E6A),
                    side: const BorderSide(color: Color(0xFFEAE7E2), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.of(retryContext).pop();
                    _navigateToCalendarTab();
                  },
                  child: const Text('Cancel / Skip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _executePrintWorkflow(
    Order order,
    Uint8List customerBytes, {
    required bool printBoth,
    ReceiptType? singleType,
  }) async {
    bool isProgressDialogOpen = false;

    // 0. Ensure Voucher exists before printing (Idempotent Decoupled Step)
    await VoucherRepository().ensureVoucher(
      orderId: order.id,
      orderNumber: order.orderNumber,
      voucherType: 'customer',
    );

    if (printBoth || singleType == ReceiptType.kitchen) {
      await VoucherRepository().ensureVoucher(
        orderId: order.id,
        orderNumber: order.orderNumber,
        voucherType: 'kitchen',
      );
    }

    // 1. Set status to 'printing'
    await OrderRepository().updatePrintStatus(order.id, 'printing');
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == order.id);
      if (idx != -1) _orders[idx].printStatus = 'printing';
    });

    try {
      if (printBoth) {
        // Step A: Print Customer Copy
        if (!mounted) return;
        _showPrintingProgressDialog(context, 'Printing Customer Copy...', 'Sending rasterized graphics to printer');
        isProgressDialogOpen = true;

        final bool cSuccess = await _printReceiptImage(customerBytes);
        if (mounted && isProgressDialogOpen) {
          Navigator.of(context).pop(); // dismiss progress dialog
          isProgressDialogOpen = false;
        }

        if (!cSuccess) {
          const errMsg = 'Customer copy print failed (paper out or disconnected).';
          await OrderRepository().updatePrintStatus(
            order.id,
            'failed',
            customerPrinted: false,
            kitchenPrinted: false,
            lastPrintError: errMsg,
          );
          setState(() {
            final idx = _orders.indexWhere((o) => o.id == order.id);
            if (idx != -1) {
              _orders[idx].printStatus = 'failed';
              _orders[idx].customerPrinted = false;
              _orders[idx].kitchenPrinted = false;
              _orders[idx].lastPrintError = errMsg;
            }
          });
          await _showPrintRetryOptionsDialog(order, customerBytes, failedReason: errMsg);
          return;
        }

        // Customer copy succeeded!
        await VoucherRepository().updateVoucherStatus(order.id, 'customer', 'printed');
        await OrderRepository().updatePrintStatus(
          order.id,
          'printing',
          customerPrinted: true,
        );
        setState(() {
          final idx = _orders.indexWhere((o) => o.id == order.id);
          if (idx != -1) {
            _orders[idx].customerPrinted = true;
          }
        });

        // Step B: Customer copy succeeded! Delay 6s then print Kitchen Copy
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer copy printed. Waiting 6s to print kitchen copy...'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        await Future.delayed(const Duration(seconds: 6));

        if (!mounted) return;
        _showPrintingProgressDialog(context, 'Printing Kitchen Copy...', 'Sending kitchen layout to printer');
        isProgressDialogOpen = true;

        final kitchenBytes = await _captureReceiptWidget(order, ReceiptType.kitchen);
        final bool kSuccess = await _printReceiptImage(kitchenBytes);
        if (mounted && isProgressDialogOpen) {
          Navigator.of(context).pop(); // dismiss progress dialog
          isProgressDialogOpen = false;
        }

        if (!kSuccess) {
          const errMsg = 'Customer copy printed, but Kitchen copy failed.';
          await OrderRepository().updatePrintStatus(
            order.id,
            'partial_failed',
            printCount: order.printCount + 1,
            customerPrinted: true,
            kitchenPrinted: false,
            lastPrintError: errMsg,
          );
          setState(() {
            final idx = _orders.indexWhere((o) => o.id == order.id);
            if (idx != -1) {
              _orders[idx].printStatus = 'partial_failed';
              _orders[idx].printCount++;
              _orders[idx].customerPrinted = true;
              _orders[idx].kitchenPrinted = false;
              _orders[idx].lastPrintError = errMsg;
            }
          });
          await _showPrintRetryOptionsDialog(order, customerBytes, isPartialFail: true, failedReason: errMsg);
          return;
        }

        // Both succeeded!
        await VoucherRepository().updateVoucherStatus(order.id, 'kitchen', 'printed');
        await OrderRepository().updatePrintStatus(
          order.id,
          'completed',
          printCount: order.printCount + 2,
          customerPrinted: true,
          kitchenPrinted: true,
          lastPrintError: null,
        );
        setState(() {
          final idx = _orders.indexWhere((o) => o.id == order.id);
          if (idx != -1) {
            _orders[idx].printStatus = 'completed';
            _orders[idx].printCount += 2;
            _orders[idx].customerPrinted = true;
            _orders[idx].kitchenPrinted = true;
            _orders[idx].lastPrintError = null;
          }
        });
        _navigateToCalendarTab();

      } else {
        // Single Copy Print Mode
        final ReceiptType type = singleType ?? ReceiptType.customer;
        final String label = type == ReceiptType.customer ? 'Customer Receipt' : 'Kitchen Voucher';
        if (!mounted) return;
        _showPrintingProgressDialog(context, 'Printing $label...', 'Sending rasterized graphics to printer');
        isProgressDialogOpen = true;

        final Uint8List targetBytes = type == ReceiptType.customer
            ? customerBytes
            : await _captureReceiptWidget(order, ReceiptType.kitchen);

        final bool success = await _printReceiptImage(targetBytes);
        if (mounted && isProgressDialogOpen) {
          Navigator.of(context).pop(); // dismiss progress dialog
          isProgressDialogOpen = false;
        }

        if (success) {
          final bool isCustomer = type == ReceiptType.customer;
          final bool newCustomerPrinted = isCustomer ? true : order.customerPrinted;
          final bool newKitchenPrinted = !isCustomer ? true : order.kitchenPrinted;
          final bool isBothDone = newCustomerPrinted && newKitchenPrinted;
          final String newStatus = isBothDone ? 'completed' : 'partial_failed';

          await OrderRepository().updatePrintStatus(
            order.id,
            newStatus,
            printCount: order.printCount + 1,
            customerPrinted: newCustomerPrinted,
            kitchenPrinted: newKitchenPrinted,
            lastPrintError: null,
          );
          setState(() {
            final idx = _orders.indexWhere((o) => o.id == order.id);
            if (idx != -1) {
              _orders[idx].printStatus = newStatus;
              _orders[idx].printCount++;
              _orders[idx].customerPrinted = newCustomerPrinted;
              _orders[idx].kitchenPrinted = newKitchenPrinted;
              _orders[idx].lastPrintError = null;
            }
          });
          _navigateToCalendarTab();
        } else {
          final String errMsg = '$label printing failed.';
          await OrderRepository().updatePrintStatus(
            order.id,
            order.customerPrinted || order.kitchenPrinted ? 'partial_failed' : 'failed',
            customerPrinted: order.customerPrinted,
            kitchenPrinted: order.kitchenPrinted,
            lastPrintError: errMsg,
          );
          setState(() {
            final idx = _orders.indexWhere((o) => o.id == order.id);
            if (idx != -1) {
              _orders[idx].printStatus = order.customerPrinted || order.kitchenPrinted ? 'partial_failed' : 'failed';
              _orders[idx].lastPrintError = errMsg;
            }
          });
          await _showPrintRetryOptionsDialog(order, customerBytes, failedReason: errMsg);
        }
      }
    } catch (e) {
      debugPrint('Unhandled error or timeout during print workflow: $e');
      if (mounted && isProgressDialogOpen) {
        Navigator.of(context).pop(); // ensure progress dialog is closed
        isProgressDialogOpen = false;
      }
      final String errMsg = 'Printer communication error or timeout ($e).';
      await OrderRepository().updatePrintStatus(
        order.id,
        order.customerPrinted || order.kitchenPrinted ? 'partial_failed' : 'failed',
        lastPrintError: errMsg,
      );
      setState(() {
        final idx = _orders.indexWhere((o) => o.id == order.id);
        if (idx != -1) {
          _orders[idx].printStatus = order.customerPrinted || order.kitchenPrinted ? 'partial_failed' : 'failed';
          _orders[idx].lastPrintError = errMsg;
        }
      });
      if (mounted) {
        await _showPrintRetryOptionsDialog(
          order,
          customerBytes,
          failedReason: errMsg,
        );
      }
    }
  }

  void _showReprintOptionsDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Print Mode'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Color(0xFF8C7E6A)),
                title: const Text('Customer Receipt Only', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.of(context).pop();
                  final bytes = await _captureReceiptWidget(order, ReceiptType.customer);
                  await _executePrintWorkflow(order, bytes, printBoth: false, singleType: ReceiptType.customer);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.kitchen, color: Color(0xFF8C7E6A)),
                title: const Text('Kitchen Voucher Only', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.of(context).pop();
                  final bytes = await _captureReceiptWidget(order, ReceiptType.customer);
                  await _executePrintWorkflow(order, bytes, printBoth: false, singleType: ReceiptType.kitchen);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.print, color: Color(0xFF8C7E6A)),
                title: const Text('Both', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.of(context).pop();
                  final bytes = await _captureReceiptWidget(order, ReceiptType.customer);
                  await _executePrintWorkflow(order, bytes, printBoth: true);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8C7E6A))),
            ),
          ],
        );
      },
    );
  }

  void _showDigitalVoucherDialog(
    BuildContext context,
    Order order, {
    void Function(Uint8List imageBytes)? onConfirmPrint,
    VoidCallback? onEdit,
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DigitalVoucherDialog(
          order: order,
          bakeryName: _printerSettings.bakeryName,
          footerNotes: _printerSettings.footerNotes,
          items: _items,
          onConfirmPrint:
              onConfirmPrint ??
              (imageBytes) async {
                setState(() {
                  final index = _orders.indexWhere((o) => o.id == order.id);
                  if (index != -1) {
                    _orders[index].printCount++;
                  }
                });
                Navigator.of(context).pop();
                await _printReceiptImage(imageBytes);
              },
          onEdit:
              onEdit ??
              () {
                setState(() {
                  _editingOrder = order;
                  _currentTabIndex = 0;
                });
                Navigator.of(context).pop();
              },
          onCancel:
              onCancel ??
              () {
                Navigator.of(context).pop();
              },
        );
      },
    );
  }

  void _showPrintOptionsAfterSave(
    BuildContext context,
    Order submitted,
    Uint8List imageBytes,
    bool isEdit,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              const Icon(Icons.print_rounded, color: Color(0xFFD4A373)),
              const SizedBox(width: 8),
              Text(
                'Print Receipt Options',
                style: TextStyle(
                  color: const Color(0xFF2D241E),
                  fontWeight: FontWeight.bold,
                  fontSize: context.responsiveFont(
                    16,
                    min: 14,
                    max: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Choose receipt configuration to print:',
            style: TextStyle(
              fontSize: context.responsiveFont(13, min: 11, max: 16),
              color: Colors.black87,
            ),
          ),
          actionsPadding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16,
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D241E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _executePrintWorkflow(submitted, imageBytes, printBoth: false, singleType: ReceiptType.customer);
                  },
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: const Text(
                    'Customer Receipt',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D241E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _executePrintWorkflow(submitted, imageBytes, printBoth: true);
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text(
                    'Customer + Kitchen',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8C7E6A),
                    side: const BorderSide(
                      color: Color(0xFFEAE7E2),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _navigateToCalendarTab();
                  },
                  child: const Text(
                    'No Print',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Persists a confirmed order to Hive + Supabase, creates the voucher record,
  /// and updates in-memory state. Called only when the user actually confirms
  /// (Print or No Print) — never during preview or cancel.
  Future<bool> _persistConfirmedOrder(Order submitted, Map<String, dynamic> orderMap, bool isEdit) async {
    // Idempotency: once persisted, block duplicate calls for the same order
    if (!isEdit && _submittedOrderIds.contains(submitted.id)) {
      debugPrint('DUPLICATE PERSIST BLOCKED: ${submitted.id}');
      return true; // already saved — treat as success
    }

    try {
      final bool saveSuccess = await OrderRepository().saveOrder(orderMap);

      await VoucherRepository().ensureVoucher(
        orderId: submitted.id,
        orderNumber: submitted.orderNumber,
        voucherType: 'customer',
      );

      if (!mounted) return false;

      if (!saveSuccess) {
        debugPrint('PERSIST FAILED: saveSuccess was false for ${submitted.id}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save order locally.'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }

      // Mark as persisted for idempotency
      if (!isEdit) _submittedOrderIds.add(submitted.id);

      _saveOrderToMemoryAndClearDraft(submitted, isEdit);

      debugPrint('PERSIST SUCCESS: ${submitted.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Order updated successfully!' : 'Order saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return true;
    } catch (e) {
      debugPrint('PERSIST FAILED: Exception for ${submitted.id} - $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _handleOrderSubmit(Order submitted) async {
    final bool isEdit = _editingOrder != null;

    if (!isEdit) {
      debugPrint('CREATE ORDER START (preview): ${submitted.id}');
    } else {
      debugPrint('EDIT ORDER START (preview): ${submitted.id}');
    }

    debugPrint('DEBUG main->DB _handleOrderSubmit: size="${submitted.size}", phone="${submitted.customerPhone}", lettering="${submitted.customLettering}", instructions="${submitted.specialInstructions}"');

    // Build order payload once — shared by all confirmation paths
    final orderMap = {
      'id': submitted.id,
      'order_number': submitted.orderNumber,
      'delivery_date': submitted.deliveryDate,
      'delivery_time': submitted.deliveryTime,
      'item_id': submitted.itemId,
      'size': submitted.size,
      'variant': submitted.variant,
      'design_code': submitted.designCode,
      'custom_name': submitted.customName,
      'custom_age': submitted.customAge,
      'custom_date': submitted.customDate,
      'custom_lettering': submitted.customLettering,
      'special_instructions': submitted.specialInstructions,
      'customer_phone': submitted.customerPhone,
      'payment_status': submitted.paymentStatus,
      'deposit_paid': submitted.depositPaid,
      'remaining_balance': submitted.remainingBalance,
      'is_kpay': submitted.isKpay,
      'total_amount': submitted.totalAmount,
      'toys_cost': submitted.toysCost,
      'money_pulling_cost': submitted.moneyPullingCost,
      'money_pulling_note': submitted.moneyPullingNote,
      'delivery_cost': submitted.deliveryCost,
      'order_from': submitted.orderFrom,
      'created_at': submitted.createdAt.toUtc().toIso8601String(),
      'print_count': submitted.printCount,
      'print_status': isEdit ? submitted.printStatus : 'pending',
      'is_prep_only': submitted.isPrepOnly,
    };

    if (!mounted) return;

    // Open Voucher Preview — NO persistence yet.
    // Order is only saved when the user explicitly confirms (Print or No Print).
    _showDigitalVoucherDialog(
      context,
      submitted,
      onConfirmPrint: (imageBytes) async {
        // Close DigitalVoucherDialog first
        Navigator.of(context).pop();

        // NOW persist the order (first time save)
        final saved = await _persistConfirmedOrder(submitted, orderMap, isEdit);
        if (!saved || !mounted) return;

        // Show the Print copies confirmation dialog
        _showPrintOptionsAfterSave(context, submitted, imageBytes, isEdit);
      },
      onEdit: () {
        // Return to Order Entry with the current data — no persistence
        setState(() {
          _editingOrder = submitted;
          _currentTabIndex = 0;
        });
        Navigator.of(context).pop();
      },
      onCancel: () {
        // Close preview, return to Order Entry — no persistence, draft preserved
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildNavIcon(IconData activeIcon, IconData inactiveIcon, bool isActive) {
    return AnimatedScale(
      scale: isActive ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00796B).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? const Color(0xFF00796B) : const Color(0xFF78909C).withValues(alpha: 0.7),
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isCompactScreen = screenWidth < 800 && !kIsWeb;
    final String userRole = AuthService().getCachedRole() ?? 'staff';
    final bool isAdmin = userRole == 'admin';
    final bool isSale = userRole == 'sale';
    final bool isStaff = userRole == 'staff';

    final List<Map<String, dynamic>> navConfigs = [
      {
        'activeIcon': Icons.shopping_cart_rounded,
        'inactiveIcon': Icons.shopping_cart_outlined,
        'label': 'Order',
        'visible': isAdmin || isSale,
      },
      {
        'activeIcon': Icons.bar_chart_rounded,
        'inactiveIcon': Icons.bar_chart_outlined,
        'label': 'Sales',
        'visible': isAdmin && !isCompactScreen,
      },
      {
        'activeIcon': Icons.calendar_month_rounded,
        'inactiveIcon': Icons.calendar_month_outlined,
        'label': 'Calendar',
        'visible': true,
      },
      {
        'activeIcon': Icons.storefront_rounded,
        'inactiveIcon': Icons.storefront_outlined,
        'label': 'Counter & Showline',
        'visible': isAdmin && !isCompactScreen,
      },
      {
        'activeIcon': Icons.print_rounded,
        'inactiveIcon': Icons.print_outlined,
        'label': 'Printer',
        'visible': isAdmin || isSale,
      },
      {
        'activeIcon': Icons.settings_rounded,
        'inactiveIcon': Icons.settings_outlined,
        'label': 'Configurator',
        'visible': isAdmin && !isCompactScreen,
      },
    ];

    final List<Map<String, dynamic>> visibleNavs = navConfigs.where((n) => n['visible'] as bool).toList();
    final tabs = [
      if (isAdmin || isSale)
        OrderEntryFormTab(
          key: ValueKey('${_orderFormResetCounter}_${_editingOrder?.id ?? "new"}'),
          items: _items,
          sizes: _sizes,
          initialOrder: _editingOrder,
          onSubmit: _handleOrderSubmit,
          onCancel: () {
            setState(() {
              _editingOrder = null;
              final calendarIndex = visibleNavs.indexWhere((nav) => nav['label'] == 'Calendar');
              _currentTabIndex = calendarIndex != -1 ? calendarIndex : 0;
            });
          },
          onReset: () {
            setState(() {
              _orderFormResetCounter++;
            });
          },
        ),
      if (isAdmin && !isCompactScreen)
        SalesDashboardTab(
          items: _items,
          sizes: _sizes,
          onSelectOrder: (order) => _showDigitalVoucherDialog(context, order),
          setActiveTab: (index) => setState(() => _currentTabIndex = index),
          isActive: _currentTabIndex == visibleNavs.indexWhere((nav) => nav['label'] == 'Sales'),
        ),
      CalendarTab(
        orders: _orders,
        items: _items,
        sizes: _sizes,
        settings: _printerSettings,
        isAdmin: isAdmin || isSale,
        onReprint: (order) => _showReprintOptionsDialog(context, order),
        onEdit: (order) {
          debugPrint('DEBUG Calendar->main onEdit: size="${order.size}", phone="${order.customerPhone}", lettering="${order.customLettering}", instructions="${order.specialInstructions}"');
          setState(() {
            _editingOrder = order;
            _currentTabIndex = 0;
          });
        },
        onDelete: (orderId) {
          setState(() {
            _orders.removeWhere((o) => o.id == orderId);
          });
        },
      ),
      if (isAdmin && !isCompactScreen)
        CounterShowlineDashboard(
          isActive: _currentTabIndex == visibleNavs.indexWhere((nav) => nav['label'] == 'Counter & Showline'),
          items: _items,
          sizes: _sizes,
        ),
      if (isAdmin || isSale)
        PrinterConnectTab(
          settings: _printerSettings,
          onSaveSettings: () {
            _savePrinterSettings();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Printer settings saved successfully!'),
              ),
            );
          },
        ),
      if (isAdmin && !isCompactScreen)
        SettingsTab(
          sizes: _sizes,
          items: _items,
          settings: _printerSettings,
          onSaveSettings: () {
            _savePrinterSettings();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings updated successfully!')),
            );
          },
          onAddSize: (size) async {
            setState(() => _sizes.add(size));
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Supabase.instance.client.from('cake_sizes').insert({
                'id': size.id,
                'name': size.name,
                'base_price': size.basePrice,
              });
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(content: Text('Size added successfully!')),
              );
            } catch (e) {
              debugPrint('Error adding size: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error adding size: $e')),
              );
            }
          },
          onEditSize: (id, name, price) async {
            setState(() {
              final idx = _sizes.indexWhere((s) => s.id == id);
              if (idx != -1) {
                _sizes[idx] = CakeSize(id: id, name: name, basePrice: price);
              }
            });
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Supabase.instance.client
                  .from('cake_sizes')
                  .update({'name': name, 'base_price': price})
                  .eq('id', id);
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(content: Text('Size updated successfully!')),
              );
            } catch (e) {
              debugPrint('Error editing size: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error updating size: $e')),
              );
            }
          },
          onDeleteSize: (id) async {
            setState(() => _sizes.removeWhere((s) => s.id == id));
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Supabase.instance.client
                  .from('cake_sizes')
                  .delete()
                  .eq('id', id);
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(content: Text('Size deleted successfully!')),
              );
            } catch (e) {
              debugPrint('Error deleting size: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error deleting size: $e')),
              );
            }
          },
          onAddItem: (item) async {
            setState(() => _items.add(item));
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Supabase.instance.client.from('cake_items').insert({
                'id': item.id,
                'name': item.name,
                'sizes': item.sizes,
                'variants': item.variants,
                'pricing': item.pricing,
              });
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(content: Text('Cake Item added successfully!')),
              );
            } catch (e) {
              debugPrint('Error adding item: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error adding item: $e')),
              );
            }
          },
          onDeleteItem: (id) async {
            setState(() => _items.removeWhere((i) => i.id == id));
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Supabase.instance.client
                  .from('cake_items')
                  .delete()
                  .eq('id', id);
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Cake Item deleted successfully!'),
                ),
              );
            } catch (e) {
              debugPrint('Error deleting item: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error deleting item: $e')),
              );
            }
          },
          onEditItemName: (id, newName) async {
            setState(() {
              final idx = _items.indexWhere((i) => i.id == id);
              if (idx != -1) {
                _items[idx].name = newName;
              }
            });
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Supabase.instance.client
                  .from('cake_items')
                  .update({'name': newName})
                  .eq('id', id);
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Item name updated successfully!'),
                ),
              );
            } catch (e) {
              debugPrint('Error editing item name: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error updating item name: $e')),
              );
            }
          },
          onSavePricing: (itemId, size, variant, price) async {
            setState(() {
              final idx = _items.indexWhere((i) => i.id == itemId);
              if (idx != -1) {
                final item = _items[idx];
                if (!item.sizes.contains(size)) item.sizes.add(size);
                if (!item.variants.contains(variant)) {
                  item.variants.add(variant);
                }
                item.pricing['$size:$variant'] = price;
              }
            });
            final messenger = ScaffoldMessenger.of(context);
            try {
              final item = _items.firstWhere((i) => i.id == itemId);
              await Supabase.instance.client
                  .from('cake_items')
                  .update({
                    'sizes': item.sizes,
                    'variants': item.variants,
                    'pricing': item.pricing,
                  })
                  .eq('id', itemId);
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Pricing combination saved successfully!'),
                ),
              );
            } catch (e) {
              debugPrint('Error saving pricing: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error saving pricing: $e')),
              );
            }
          },
          onDeletePricing: (itemId, size, variant) async {
            setState(() {
              final idx = _items.indexWhere((i) => i.id == itemId);
              if (idx != -1) {
                final item = _items[idx];
                item.pricing.remove('$size:$variant');
                // Clean up unused size/variant listings
                item.sizes.clear();
                item.variants.clear();
                for (var key in item.pricing.keys) {
                  final parts = key.split(':');
                  if (parts.length == 2) {
                    final s = parts[0];
                    final v = parts[1];
                    if (!item.sizes.contains(s)) item.sizes.add(s);
                    if (!item.variants.contains(v)) item.variants.add(v);
                  }
                }
              }
            });
            final messenger = ScaffoldMessenger.of(context);
            try {
              final item = _items.firstWhere((i) => i.id == itemId);
              await Supabase.instance.client
                  .from('cake_items')
                  .update({
                    'sizes': item.sizes,
                    'variants': item.variants,
                    'pricing': item.pricing,
                  })
                  .eq('id', itemId);
              _fetchCatalogData();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Pricing combination deleted successfully!'),
                ),
              );
            } catch (e) {
              debugPrint('Error deleting pricing: $e');
              messenger.showSnackBar(
                SnackBar(content: Text('Error deleting pricing: $e')),
              );
            }
          },
        ),
    ];

    final activeIndex = (_currentTabIndex < tabs.length) ? _currentTabIndex : 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0F7FA), // Light Cyan
            Color(0xFFB2DFDB), // Soft Teal
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Show gradient backdrop
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              const Icon(
                Icons.cake_rounded,
                color: Color(0xFF00796B),
                size: 28,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _printerSettings.bakeryName,
                    style: const TextStyle(
                      color: Color(0xFF004D40),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'Baking Prep & Printing Management System',
                    style: TextStyle(
                      color: Color(0xFF00796B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF004D40)),
              tooltip: 'About App',
              onPressed: () => showAboutAppDialog(context),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Color(0xFF004D40)),
              tooltip: 'Sign Out',
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                    (route) => false,
                  );
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: FadeIndexedStack(index: activeIndex, children: tabs),
        ),
        bottomNavigationBar: isStaff
            ? null
            : SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: BottomNavigationBar(
                    currentIndex: activeIndex,
                    selectedItemColor: const Color(0xFF00796B),
                    unselectedItemColor: const Color(0xFF78909C).withValues(alpha: 0.8),
                    selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    backgroundColor: Colors.transparent,
                    showUnselectedLabels: true,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    onTap: (index) {
                      setState(() {
                        _currentTabIndex = index;
                        if (visibleNavs[index]['label'] != 'Order') {
                          _editingOrder = null;
                        }
                      });
                    },
                    items: visibleNavs.map((nav) {
                      final int index = visibleNavs.indexOf(nav);
                      return BottomNavigationBarItem(
                        icon: _buildNavIcon(
                          nav['activeIcon'] as IconData,
                          nav['inactiveIcon'] as IconData,
                          activeIndex == index,
                        ),
                        label: nav['label'] as String,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
