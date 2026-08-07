import 'package:flutter/foundation.dart';

// ==========================================
// DATA MODELS
// ==========================================

class CakeSize {
  String id;
  String name;
  int basePrice;
  CakeSize({required this.id, required this.name, required this.basePrice});
}

class CakeItem {
  String id;
  String name;
  List<String> sizes;
  List<String> variants;
  Map<String, int> pricing; // size:variant -> price

  CakeItem({
    required this.id,
    required this.name,
    required this.sizes,
    required this.variants,
    required this.pricing,
  });
}

class Order {
  String id;
  String orderNumber;
  String deliveryDate; // YYYY-MM-DD
  String deliveryTime; // HH:MM (24-hour)
  String itemId;
  String size;
  String variant;
  String designCode;
  String customName;
  String customAge;
  String customDate;
  String customLettering;
  String specialInstructions;
  String customerPhone;
  String paymentStatus; // 'fully_paid' or 'deposit'
  int depositPaid;
  int remainingBalance;
  bool isKpay;
  int totalAmount;
  int toysCost;
  int moneyPullingCost;
  String moneyPullingNote;
  int deliveryCost;
  String orderFrom;
  DateTime createdAt;
  int printCount;

  // Tracking properties
  String
  printStatus; // 'pending', 'printing', 'completed', 'partial_failed', 'failed'
  bool isSynced;

  // Granular print tracking fields
  bool customerPrinted;
  bool kitchenPrinted;
  String? lastPrintError;

  String get syncStatus => isSynced ? 'synced' : 'pending_sync';

  // Virtual property to differentiate actual deliveries vs prep items in lists
  bool isPrepOnly;

  Order({
    required this.id,
    required this.orderNumber,
    required this.deliveryDate,
    required this.deliveryTime,
    required this.itemId,
    required this.size,
    required this.variant,
    required this.designCode,
    required this.customName,
    this.customAge = '',
    this.customDate = '',
    required this.customLettering,
    this.specialInstructions = '',
    required this.customerPhone,
    required this.paymentStatus,
    this.depositPaid = 0,
    this.remainingBalance = 0,
    this.isKpay = false,
    required this.totalAmount,
    this.toysCost = 0,
    this.moneyPullingCost = 0,
    this.moneyPullingNote = '',
    this.deliveryCost = 0,
    this.orderFrom = 'Page',
    required this.createdAt,
    this.printCount = 0,
    this.printStatus = 'pending',
    this.isSynced = true,
    this.isPrepOnly = false,
    this.customerPrinted = false,
    this.kitchenPrinted = false,
    this.lastPrintError,
  });

  Order copyWith({
    bool? isPrepOnly,
    String? printStatus,
    int? printCount,
    bool? isSynced,
    bool? customerPrinted,
    bool? kitchenPrinted,
    String? lastPrintError,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      deliveryDate: deliveryDate,
      deliveryTime: deliveryTime,
      itemId: itemId,
      size: size,
      variant: variant,
      designCode: designCode,
      customName: customName,
      customAge: customAge,
      customDate: customDate,
      customLettering: customLettering,
      specialInstructions: specialInstructions,
      customerPhone: customerPhone,
      paymentStatus: paymentStatus,
      depositPaid: depositPaid,
      remainingBalance: remainingBalance,
      isKpay: isKpay,
      totalAmount: totalAmount,
      toysCost: toysCost,
      moneyPullingCost: moneyPullingCost,
      moneyPullingNote: moneyPullingNote,
      deliveryCost: deliveryCost,
      orderFrom: orderFrom,
      createdAt: createdAt,
      printCount: printCount ?? this.printCount,
      printStatus: printStatus ?? this.printStatus,
      isSynced: isSynced ?? this.isSynced,
      isPrepOnly: isPrepOnly ?? this.isPrepOnly,
      customerPrinted: customerPrinted ?? this.customerPrinted,
      kitchenPrinted: kitchenPrinted ?? this.kitchenPrinted,
      lastPrintError: lastPrintError ?? this.lastPrintError,
    );
  }
}

class PrinterSettings {
  String connectionInterface; // 'bluetooth' or 'ethernet'
  String paperWidth; // '58mm' or '80mm'
  String bluetoothMac;
  String ethernetIp;
  int ethernetPort;
  bool openCashDrawer;
  bool autoPaperCut;
  String bakeryName;
  String footerNotes;

  // Advanced settings from screenshot
  String printMode; // 'Graphic' or 'Text'
  String printWidth; // '48 mm' or '72 mm'
  String printResolution; // '203 dpi (8 dots/mm)'
  String initialCommands; // ESC/POS hex commands
  String cutterCommands; // ESC/POS hex commands, default: '1D,56,42,00'
  String drawerCommands; // ESC/POS hex commands, default: '1B,70,00,19,FA'

  PrinterSettings({
    this.connectionInterface = 'bluetooth',
    this.paperWidth = '80mm',
    this.bluetoothMac = '00:11:22:33:FF:EE',
    this.ethernetIp = '192.168.1.100',
    this.ethernetPort = 9100,
    this.openCashDrawer = false,
    this.autoPaperCut = false,
    this.bakeryName = 'ASH Bakery',
    this.footerNotes =
        'Thank you for supporting ASH Bakery! Keep refrigerated.',
    this.printMode = 'Graphic',
    this.printWidth = '72 mm',
    this.printResolution = '203 dpi (8 dots/mm)',
    this.initialCommands = '',
    this.cutterCommands = '1D,56,42,00',
    this.drawerCommands = '1B,70,00,19,FA',
  });
}

// ==========================================
// UTILITY FUNCTIONS & FORMATTING
// ==========================================

// Formats YYYY-MM-DD to DD.MM.YYYY
String formatDateToDDMMYY(String dateStr) {
  if (dateStr.isEmpty) return '';
  List<String> parts = dateStr.split('-');
  if (parts.length == 3) {
    String year = parts[0];
    String month = parts[1];
    String day = parts[2];
    return "$day.$month.$year";
  }
  return dateStr;
}

// Formats HH:MM to 12-Hour AM/PM
String formatTimeTo12Hour(String timeStr) {
  if (timeStr.isEmpty) return '12:00 PM';
  try {
    final trimmed = timeStr.trim();
    if (trimmed.contains('T')) {
      final dt = DateTime.parse(trimmed).toLocal();
      int hour12 = dt.hour % 12;
      if (hour12 == 0) hour12 = 12;
      String period = dt.hour >= 12 ? 'PM' : 'AM';
      String hourStr = hour12 < 10 ? '0$hour12' : '$hour12';
      String minuteStr = dt.minute < 10 ? '0${dt.minute}' : '${dt.minute}';
      return '$hourStr:$minuteStr $period';
    }

    if (trimmed.toUpperCase().contains('AM') ||
        trimmed.toUpperCase().contains('PM')) {
      return trimmed;
    }

    List<String> parts = trimmed.split(':');
    if (parts.length >= 2) {
      int hour = int.tryParse(parts[0]) ?? 12;
      int minute = int.tryParse(parts[1]) ?? 0;
      String period = hour >= 12 ? 'PM' : 'AM';
      int hour12 = hour % 12;
      if (hour12 == 0) hour12 = 12;
      String hourStr = hour12 < 10 ? '0$hour12' : '$hour12';
      String minuteStr = minute < 10 ? '0$minute' : '$minute';
      return '$hourStr:$minuteStr $period';
    }
  } catch (e) {
    debugPrint('Error formatting time: $e');
  }
  return timeStr;
}

bool isBefore9AM(String timeStr) {
  if (timeStr.isEmpty) return false;
  try {
    final trimmed = timeStr.trim();
    if (trimmed.contains('T')) {
      final dt = DateTime.parse(trimmed).toLocal();
      return dt.hour < 9;
    }

    String clean = trimmed.toUpperCase();
    bool isPM = clean.contains('PM');
    bool isAM = clean.contains('AM');
    clean = clean.replaceAll('AM', '').replaceAll('PM', '').trim();

    List<String> parts = clean.split(':');
    if (parts.isNotEmpty) {
      int hour = int.tryParse(parts[0]) ?? 12;
      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;
      return hour < 9;
    }
  } catch (e) {
    debugPrint('Error parsing time in isBefore9AM: $e');
  }
  return false;
}

String getDayBefore(String dateStr) {
  try {
    DateTime dt = DateTime.parse(dateStr);
    DateTime dayBefore = dt.subtract(const Duration(days: 1));
    return "${dayBefore.year}-${dayBefore.month.toString().padLeft(2, '0')}-${dayBefore.day.toString().padLeft(2, '0')}";
  } catch (e) {
    return dateStr;
  }
}

// Custom regex check to prevent Burmese Characters in required strings
bool hasBurmeseCharacters(String value) {
  final RegExp burmeseRegex = RegExp(r'[\u1000-\u109F]');
  return burmeseRegex.hasMatch(value);
}

// Integer localization/formatting helper
extension IntFormatting on int {
  String toLocaleString() {
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return toString().replaceAllMapped(reg, (Match match) => '${match[1]},');
  }
}

// ==========================================
// VOUCHER MODEL (Idempotent tracking)
// ==========================================
class Voucher {
  final String id;
  final String orderId;
  final String code;
  final String voucherType; // 'customer' or 'kitchen'
  final String status; // 'pending', 'printed'
  final DateTime createdAt;
  final DateTime updatedAt;

  Voucher({
    required this.id,
    required this.orderId,
    required this.code,
    this.voucherType = 'customer',
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'code': code,
      'voucher_type': voucherType,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory Voucher.fromMap(Map<String, dynamic> map) {
    return Voucher(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      code: map['code'] as String,
      voucherType: map['voucher_type'] as String? ?? 'customer',
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Voucher copyWith({
    String? status,
    DateTime? updatedAt,
  }) {
    return Voucher(
      id: id,
      orderId: orderId,
      code: code,
      voucherType: voucherType,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
