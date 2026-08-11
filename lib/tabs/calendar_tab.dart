import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/realtime/realtime_manager.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/order_repository.dart';
import '../services/closure_repository.dart';
import '../widgets/anchored_dropdown.dart';
import '../widgets/scale_button.dart';
import '../widgets/digital_voucher_dialog.dart';

class CalendarTab extends StatefulWidget {
  final List<Order> orders;
  final List<CakeItem> items;
  final List<CakeSize> sizes;
  final PrinterSettings? settings;
  final void Function(Order) onReprint;
  final void Function(Order) onEdit;
  final void Function(String)? onDelete;
  final bool isAdmin;

  const CalendarTab({
    super.key,
    required this.orders,
    required this.items,
    required this.sizes,
    this.settings,
    required this.onReprint,
    required this.onEdit,
    this.onDelete,
    this.isAdmin = true,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  late int _currentYear;
  late int _currentMonth;
  late String _selectedDate;
  Order? _selectedOrder;
  String? _lastCelebratedDate;

  // Track which aggregated baking size requirements are checked off
  final Map<String, bool> _bakedSizes = {};

  // Removed temporary _completedOrders Map

  // --- Stateful orders data (replaced StreamBuilder) ---
  List<Map<String, dynamic>> _ordersData = [];
  bool _isLoading = true;
  final Set<String> _deletedOrderIds = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
    _selectedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    _fetchOrders();
    _subscribeRealtime();
  }

  /// Subscribes to realtime order changes via the centralized [RealtimeManager].
  /// On any INSERT/UPDATE/DELETE, triggers a full refetch to stay in sync.
  void _subscribeRealtime() {
    RealtimeManager().subscribe(
      key: 'calendar',
      table: 'orders',
      onChange: (payload) {
        debugPrint('CalendarTab: Realtime change (${payload.eventType}) → refreshing…');
        _fetchOrders();
      },
    );
  }

  /// Fetches orders from Supabase for the current month range.
  /// Uses REST query (not realtime stream) for reliable, complete data.
  Future<void> _fetchOrders() async {
    final int prevM = _currentMonth == 1 ? 12 : _currentMonth - 1;
    final int prevY = _currentMonth == 1 ? _currentYear - 1 : _currentYear;
    final String startFilterStr =
        "$prevY-${prevM.toString().padLeft(2, '0')}-01";

    debugPrint('CalendarTab: Fetching orders (filter ≥ $startFilterStr)');

    try {
      final List<dynamic> result = await Supabase.instance.client
          .from('orders')
          .select()
          .gte('delivery_date', startFilterStr);

      if (!mounted) return;
      setState(() {
        _ordersData = List<Map<String, dynamic>>.from(result);
        _isLoading = false;
      });
      debugPrint('CalendarTab: Fetched ${_ordersData.length} orders.');
    } catch (e) {
      debugPrint('CalendarTab: Fetch error (silent): $e');
      // Keep existing data on error — never blank the screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String cleanDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final trimmed = dateStr.trim();
      if (trimmed.contains('T')) {
        DateTime dt = DateTime.parse(trimmed).toLocal();
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      }
      if (trimmed.length >= 10) {
        final sub = trimmed.substring(0, 10);
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(sub)) {
          return sub;
        }
      }
      DateTime dt = DateTime.parse(trimmed).toLocal();
      return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateStr;
    }
  }

  String getDayNext(String dateStr) {
    try {
      final clean = cleanDate(dateStr);
      DateTime dt = DateTime.parse(clean);
      DateTime next = dt.add(const Duration(days: 1));
      return "${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateStr;
    }
  }

  final List<String> _monthsList = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final List<String> _daysOfWeek = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  List<_CakeOrderItem> _parseOrderItems(Order o) {
    List<_CakeOrderItem> result = [];

    final mainCake = widget.items.firstWhere(
      (item) => item.id == o.itemId,
      orElse: () => CakeItem(
        id: '',
        name: 'Special Cake',
        sizes: [],
        variants: [],
        pricing: {},
      ),
    );

    int firstQty = 1;
    String cleanInstructions = o.specialInstructions;
    if (cleanInstructions.contains('[Qty: ')) {
      final startIdx = cleanInstructions.indexOf('[Qty: ') + '[Qty: '.length;
      final endIdx = cleanInstructions.indexOf(']', startIdx);
      if (endIdx != -1) {
        firstQty =
            int.tryParse(cleanInstructions.substring(startIdx, endIdx)) ?? 1;
        cleanInstructions = cleanInstructions
            .replaceRange(cleanInstructions.indexOf('[Qty: '), endIdx + 1, '')
            .trim();
      }
    }

    result.add(
      _CakeOrderItem(
        name: mainCake.name,
        size: o.size,
        variant: o.variant,
        quantity: firstQty,
      ),
    );

    if (cleanInstructions.contains('[Additional Items: ')) {
      final startIdx =
          cleanInstructions.indexOf('[Additional Items: ') +
          '[Additional Items: '.length;
      int bracketCount = 1;
      int endIdx = -1;
      for (int i = startIdx; i < cleanInstructions.length; i++) {
        if (cleanInstructions[i] == '[') {
          bracketCount++;
        } else if (cleanInstructions[i] == ']') {
          bracketCount--;
        }

        if (bracketCount == 0) {
          endIdx = i;
          break;
        }
      }
      if (endIdx != -1) {
        final itemsPart = cleanInstructions.substring(startIdx, endIdx);
        final itemStrings = <String>[];
        int lastSplit = 0;
        int inBrackets = 0;
        for (int i = 0; i < itemsPart.length; i++) {
          if (itemsPart[i] == '[') {
            inBrackets++;
          } else if (itemsPart[i] == ']') {
            inBrackets--;
          } else if (itemsPart.startsWith(', ', i) && inBrackets == 0) {
            itemStrings.add(itemsPart.substring(lastSplit, i));
            lastSplit = i + 2;
            i++;
          }
        }
        if (lastSplit < itemsPart.length) {
          itemStrings.add(itemsPart.substring(lastSplit));
        }
        for (var itemStr in itemStrings) {
          final nameEnd = itemStr.indexOf(' (');
          if (nameEnd != -1) {
            final name = itemStr.substring(0, nameEnd).trim();
            final specsStart = nameEnd + 2;
            final specsEnd = itemStr.indexOf(') x', specsStart);
            if (specsEnd != -1) {
              final specs = itemStr.substring(specsStart, specsEnd);
              final qtyStart = specsEnd + 3;
              final qtyPart = itemStr.substring(qtyStart);
              int qty = 1;
              if (qtyPart.contains(' [')) {
                final qtyStr = qtyPart.substring(0, qtyPart.indexOf(' ['));
                qty = int.tryParse(qtyStr) ?? 1;
              } else {
                qty = int.tryParse(qtyPart) ?? 1;
              }
              final specParts = specs.split(' - ');
              final size = specParts[0];
              final variant = specParts.length > 1 ? specParts[1] : '';
              result.add(
                _CakeOrderItem(
                  name: name,
                  size: size,
                  variant: variant,
                  quantity: qty,
                ),
              );
            }
          }
        }
      }
    }
    return result;
  }

  int _getTotalCakesCount(List<Order> orders) {
    int total = 0;
    for (var o in orders) {
      final parsed = _parseOrderItems(o);
      for (var item in parsed) {
        total += item.quantity;
      }
    }
    return total;
  }

  // Helper to dynamically calculate orders due on a day (including tomorrow's morning prep items)
  List<Order> _getOrdersForDate(String targetDate, List<Order> allOrders) {
    final String cleanTarget = cleanDate(targetDate);
    List<Order> result = [];
    for (var o in allOrders) {
      final String cleanDeliv = cleanDate(o.deliveryDate);
      if (cleanDeliv == cleanTarget) {
        // Direct match
        result.add(o);
      } else if (isBefore9AM(o.deliveryTime) &&
          cleanDate(getDayBefore(o.deliveryDate)) == cleanTarget) {
        // Advance prep match: Only orders due tomorrow BEFORE 9:00 AM appear on previous day
        result.add(o);
      }
    }

    // Sort today's actual orders first, then tomorrow's prep.
    // Within each category, sort by delivery time.
    final todayActual =
        result.where((o) => cleanDate(o.deliveryDate) == cleanTarget).toList()
          ..sort(
            (a, b) => a.deliveryTime.compareTo(
              b.deliveryTime.isEmpty ? '12:00' : b.deliveryTime,
            ),
          );

    final tomorrowPrep =
        result.where((o) => cleanDate(o.deliveryDate) != cleanTarget).toList()
          ..sort(
            (a, b) => a.deliveryTime.compareTo(
              b.deliveryTime.isEmpty ? '12:00' : b.deliveryTime,
            ),
          );

    return [...todayActual, ...tomorrowPrep];
  }

  Future<void> _toggleOrderCompletion(
    Order ord,
    bool newVal, [
    List<Order>? currentOrders,
  ]) async {
    setState(() {
      ord.isPrepOnly = newVal;
    });

    if (currentOrders != null && currentOrders.isNotEmpty) {
      final finishedCount =
          currentOrders.where((o) => o.isPrepOnly == true).length;
      final remainingCount = currentOrders.length - finishedCount;
      if (remainingCount == 0) {
        if (_lastCelebratedDate != _selectedDate) {
          _lastCelebratedDate = _selectedDate;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _showCelebrationDialog(context, currentOrders.length);
            }
          });
        }
      } else if (remainingCount > 0) {
        if (_lastCelebratedDate == _selectedDate) {
          _lastCelebratedDate = null;
        }
      }
    }

    try {
      await OrderRepository().updateOrderStatus(ord.id, newVal);
    } catch (e) {
      debugPrint('Error updating order completion: $e');
    }
  }

  Future<void> _confirmDelete(BuildContext context, Order order) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Cancel & Delete Order?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to permanently remove this cake order from the database?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Go Back'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
              child: const Text('Delete permanently'),
            ),
          ],
        );
      },
    );

    if (confirm == true && context.mounted) {
      try {
        final bool success = await OrderRepository().deleteOrder(order.id);

        if (context.mounted) {
          if (success) {
            widget.onDelete?.call(order.id);
            setState(() {
              _deletedOrderIds.add(order.id);
              if (_selectedOrder?.id == order.id) {
                _selectedOrder = null;
              }
            });
            _fetchOrders();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order successfully removed'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete order from database.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteMonth(BuildContext context) async {
    final DateTime now = DateTime.now();

    int tempSelectedMonth = now.month;
    int tempSelectedYear = now.year;

    // 1. Show dynamic month selection dialog (Calendar Style Dropdowns)
    final Map<String, int>? selectedChoice = await showDialog<Map<String, int>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Clear Month Data',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the exact month and year to clear permanently:',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AnchoredDropdown<int>(
                          initialValue: tempSelectedMonth,
                          decoration: AppDecorations.input(labelText: 'Month'),
                          items: List.generate(12, (index) {
                            return DropdownMenuItem(
                              value: index + 1,
                              child: Text(_monthsList[index]),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => tempSelectedMonth = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnchoredDropdown<int>(
                          initialValue: tempSelectedYear,
                          decoration: AppDecorations.input(labelText: 'Year'),
                          items: List.generate(10, (index) {
                            int year = 2024 + index;
                            return DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            );
                          }),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => tempSelectedYear = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop({'month': tempSelectedMonth, 'year': tempSelectedYear}),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D241E),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Next'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedChoice == null) return;
    if (!context.mounted) return;

    final int targetMonth = selectedChoice['month']!;
    final int targetYear = selectedChoice['year']!;
    final String targetMonthName = _monthsList[targetMonth - 1];
    final String expectedConfirmationText = "$targetMonthName $targetYear"
        .toUpperCase();

    // 2. Show double-confirmation dialog
    final String? confirmationTyped = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final controller = TextEditingController();
        bool isValid = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Confirm Deletion',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'You are about to permanently delete all Orders/Vouchers for ',
                        ),
                        TextSpan(
                          text: '$targetMonthName $targetYear',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '. This action is irreversible and cannot be undone.\n\nTo confirm, type ',
                        ),
                        TextSpan(
                          text: '"$expectedConfirmationText"',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'JetBrains Mono',
                          ),
                        ),
                        const TextSpan(text: ':'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Confirmation Text',
                    ),
                    autofocus: true,
                    onChanged: (value) {
                      setDialogState(() {
                        isValid =
                            controller.text.trim().toUpperCase() ==
                            expectedConfirmationText;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () => Navigator.of(context).pop(controller.text)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('PERMANENTLY DELETE'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmationTyped?.trim().toUpperCase() == expectedConfirmationText &&
        context.mounted) {
      final String monthStr = targetMonth.toString().padLeft(2, '0');
      final String startMonthStr = "$targetYear-$monthStr-01";
      final int lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
      final String endMonthStr =
          "$targetYear-$monthStr-${lastDay.toString().padLeft(2, '0')}";

      final DateTime startLocal = DateTime(targetYear, targetMonth, 1, 0, 0, 0);
      final DateTime endLocal = DateTime(
        targetYear,
        targetMonth,
        lastDay,
        23,
        59,
        59,
      );
      final String startTimestampUtc = startLocal.toUtc().toIso8601String();
      final String endTimestampUtc = endLocal.toUtc().toIso8601String();

      try {
        // 1. Primary order deletion from Hive & Supabase
        await OrderRepository().deleteOrdersForMonth(targetYear, targetMonth);

        // 2. Auxiliary table: counter_cake_revenue_entries (Isolated try-catch)
        try {
          await Supabase.instance.client
              .from('counter_cake_revenue_entries')
              .delete()
              .gte('created_at', startTimestampUtc)
              .lte('created_at', endTimestampUtc);
        } catch (e) {
          debugPrint(
            'Error deleting counter_cake_revenue_entries for $targetMonthName: $e',
          );
        }

        // 3. Auxiliary table: showline_entries (Isolated try-catch)
        try {
          await Supabase.instance.client
              .from('showline_entries')
              .delete()
              .gte('date', startMonthStr)
              .lte('date', endMonthStr);
        } catch (e) {
          debugPrint(
            'Error deleting showline_entries for $targetMonthName: $e',
          );
        }

        if (context.mounted) {
          setState(() {
            _deletedOrderIds.clear();
            _selectedOrder = null;
          });
          _fetchOrders();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'All data for $targetMonthName successfully removed',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting month data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildStatusBadges(Order ord) {
    Widget syncBadge;
    if (ord.isSynced) {
      syncBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          border: Border.all(color: const Color(0xFFA5D6A7)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done, size: 10, color: Color(0xFF2E7D32)),
            SizedBox(width: 3),
            Text(
              'SYNCED',
              style: TextStyle(
                fontSize: 8.5,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      syncBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          border: Border.all(color: const Color(0xFFFFCC80)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 10, color: Color(0xFFE65100)),
            SizedBox(width: 3),
            Text(
              'PENDING SYNC',
              style: TextStyle(
                fontSize: 8.5,
                color: Color(0xFFE65100),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    Widget printBadge;
    switch (ord.printStatus) {
      case 'completed':
        printBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            border: Border.all(color: const Color(0xFFA5D6A7)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.print_outlined,
                size: 10,
                color: Color(0xFF2E7D32),
              ),
              const SizedBox(width: 3),
              Text(
                'PRINTED (${ord.printCount})',
                style: const TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
      case 'printing':
        printBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            border: Border.all(color: const Color(0xFF90CAF9)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 8,
                height: 8,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFF1565C0),
                ),
              ),
              SizedBox(width: 4),
              Text(
                'PRINTING...',
                style: TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
      case 'partial_failed':
        printBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            border: Border.all(color: const Color(0xFFFFB74D)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.print_disabled, size: 10, color: Color(0xFFEF6C00)),
              SizedBox(width: 3),
              Text(
                'PARTIAL FAIL',
                style: TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFFEF6C00),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
      case 'failed':
        printBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            border: Border.all(color: const Color(0xFFEF9A9A)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 10, color: Color(0xFFC62828)),
              SizedBox(width: 3),
              Text(
                'PRINT FAILED',
                style: TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
      case 'pending':
      default:
        printBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            border: Border.all(color: const Color(0xFFCFD8DC)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty, size: 10, color: Color(0xFF546E7A)),
              SizedBox(width: 3),
              Text(
                'PRINT PENDING',
                style: TextStyle(
                  fontSize: 8.5,
                  color: Color(0xFF546E7A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
        break;
    }

    Widget copyStatusBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        border: Border.all(color: const Color(0xFFEAE7E2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cust ${ord.customerPrinted ? "✅" : "❌"}',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: ord.customerPrinted ? Colors.green[800] : Colors.red[800],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Kitch ${ord.kitchenPrinted ? "✅" : "❌"}',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: ord.kitchenPrinted ? Colors.green[800] : Colors.red[800],
            ),
          ),
        ],
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [printBadge, copyStatusBadge, syncBadge],
    );
  }

  void _handlePrevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
      _selectedOrder = null;
      _isLoading = true;
    });
    _fetchOrders();
  }

  void _handleNextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
      _selectedOrder = null;
      _isLoading = true;
    });
    _fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime firstDayOfCurrentMonth = DateTime(
      _currentYear,
      _currentMonth,
      1,
    );
    final DateTime startRangeDate = firstDayOfCurrentMonth.subtract(
      const Duration(days: 7),
    );
    final DateTime lastDayOfCurrentMonth = DateTime(
      _currentYear,
      _currentMonth + 1,
      0,
    );
    final DateTime endRangeDate = lastDayOfCurrentMonth.add(
      const Duration(days: 14),
    );

    final String startRangeStr =
        "${startRangeDate.year}-${startRangeDate.month.toString().padLeft(2, '0')}-${startRangeDate.day.toString().padLeft(2, '0')}";
    final String endRangeStr =
        "${endRangeDate.year}-${endRangeDate.month.toString().padLeft(2, '0')}-${endRangeDate.day.toString().padLeft(2, '0')}";

    // --- Loading state ---
    if (_isLoading && _ordersData.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    {
        // Use stateful data (fetched via REST + realtime notifications)
        final List<Map<String, dynamic>> rawRows =
            List<Map<String, dynamic>>.from(_ordersData);
        final Set<String> persistentDeletedIds = OrderRepository()
            .getDeletedOrderIds();
        final Set<String> allDeletedIds = {
          ..._deletedOrderIds,
          ...persistentDeletedIds,
        };

        rawRows.removeWhere((row) => allDeletedIds.contains(row['id']));
        final List<Map<String, dynamic>> unsyncedRows = OrderRepository()
            .getUnsyncedOrders();
        unsyncedRows.removeWhere((row) => allDeletedIds.contains(row['id']));

        final Map<String, Map<String, dynamic>> mergedMap = {};
        for (var r in rawRows) {
          final String id = r['id'] as String;
          final map = Map<String, dynamic>.from(r);
          map['isSynced'] = true;
          mergedMap[id] = map;
        }
        for (var u in unsyncedRows) {
          final String id = u['id'] as String;
          if (!mergedMap.containsKey(id)) {
            mergedMap[id] = u;
          }
        }
        debugPrint('DEBUG Calendar merged IDs: ${mergedMap.keys.toList()}');

        final List<Order> allOrders = [];
        for (var row in mergedMap.values) {
          try {
            final order = Order(
              id: row['id']?.toString() ?? '',
              orderNumber: row['order_number']?.toString() ?? '',
              deliveryDate: row['delivery_date']?.toString() ?? '',
              deliveryTime: row['delivery_time']?.toString() ?? '',
              itemId: row['item_id']?.toString() ?? '',
              size: row['size']?.toString() ?? '',
              variant: row['variant']?.toString() ?? '',
              designCode: row['design_code']?.toString() ?? '',
              customName: row['custom_name']?.toString() ?? '',
              customAge: row['custom_age']?.toString() ?? '',
              customDate: row['custom_date']?.toString() ?? '',
              customLettering: row['custom_lettering']?.toString() ?? '',
              specialInstructions:
                  row['special_instructions']?.toString() ?? '',
              customerPhone: row['customer_phone']?.toString() ?? '',
              paymentStatus: row['payment_status']?.toString() ?? 'deposit',
              depositPaid: (row['deposit_paid'] as num?)?.toInt() ?? 0,
              remainingBalance:
                  (row['remaining_balance'] as num?)?.toInt() ?? 0,
              isKpay: row['is_kpay'] == true || row['is_kpay'] == 1,
              totalAmount: (row['total_amount'] as num?)?.toInt() ?? 0,
              toysCost: (row['toys_cost'] as num?)?.toInt() ?? 0,
              moneyPullingCost:
                  (row['money_pulling_cost'] as num?)?.toInt() ?? 0,
              moneyPullingNote: row['money_pulling_note']?.toString() ?? '',
              deliveryCost: (row['delivery_cost'] as num?)?.toInt() ?? 0,
              orderFrom: row['order_from']?.toString() ?? 'Page',
              createdAt: row['created_at'] != null
                  ? (DateTime.tryParse(row['created_at'].toString()) ??
                        DateTime.now())
                  : DateTime.now(),
              printCount: (row['print_count'] as num?)?.toInt() ?? 0,
              printStatus: row['print_status']?.toString() ?? 'pending',
              isSynced: row['isSynced'] == true,
              isPrepOnly: row['is_prep_only'] == true,
              customerPrinted:
                  row['customer_printed'] == true ||
                  (row['print_status'] == 'completed' ||
                      row['print_status'] == 'partial_failed'),
              kitchenPrinted:
                  row['kitchen_printed'] == true ||
                  (row['print_status'] == 'completed'),
              lastPrintError: row['last_print_error']?.toString(),
            );
            final String cleanDeliv = cleanDate(order.deliveryDate);
            if (cleanDeliv.compareTo(startRangeStr) >= 0 &&
                cleanDeliv.compareTo(endRangeStr) <= 0) {
              allOrders.add(order);
            }
          } catch (e) {
            debugPrint('Error parsing order row: $e');
          }
        }

        // Generate standard 42 monthly grid cells
        DateTime firstOfMonth = DateTime(_currentYear, _currentMonth, 1);
        int firstDayOfWeekOffset =
            firstOfMonth.weekday % 7; // Sunday=0, Monday=1...

        int daysInCurrentMonth = DateTime(
          _currentYear,
          _currentMonth + 1,
          0,
        ).day;
        int daysInPrevMonth = DateTime(_currentYear, _currentMonth, 0).day;

        List<Map<String, dynamic>> cells = [];

        // Previous month padding
        for (int i = firstDayOfWeekOffset - 1; i >= 0; i--) {
          int day = daysInPrevMonth - i;
          int prevMonthVal = _currentMonth == 1 ? 12 : _currentMonth - 1;
          int prevYearVal = _currentMonth == 1
              ? _currentYear - 1
              : _currentYear;
          String dateStr =
              "$prevYearVal-${prevMonthVal.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
          cells.add({
            'day': day,
            'isCurrentMonth': false,
            'dateString': dateStr,
          });
        }

        // Current month days
        for (int d = 1; d <= daysInCurrentMonth; d++) {
          String dateStr =
              "$_currentYear-${_currentMonth.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
          cells.add({'day': d, 'isCurrentMonth': true, 'dateString': dateStr});
        }

        // Next month padding to reach standard 42 cells grid
        int remainingCount = 42 - cells.length;
        for (int d = 1; d <= remainingCount; d++) {
          int nextMonthVal = _currentMonth == 12 ? 1 : _currentMonth + 1;
          int nextYearVal = _currentMonth == 12
              ? _currentYear + 1
              : _currentYear;
          String dateStr =
              "$nextYearVal-${nextMonthVal.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}";
          cells.add({'day': d, 'isCurrentMonth': false, 'dateString': dateStr});
        }

        // Calculate dynamic selectedDayOrders (including tomorrow's morning prep items)
        final selectedDayOrders = _getOrdersForDate(_selectedDate, allOrders);
        final activePrepOrders = selectedDayOrders
            .where((o) => o.id.isNotEmpty && !allDeletedIds.contains(o.id))
            .toList();

        // Grouping sizes tally (grouped ONLY by Size)
        Map<String, Map<String, dynamic>> sizeAggregation = {};
        for (var o in activePrepOrders) {
          final parsedItems = _parseOrderItems(o);
          for (var parsed in parsedItems) {
            String groupKey = parsed.size.trim().isNotEmpty
                ? parsed.size.trim()
                : 'Standard';
            if (!sizeAggregation.containsKey(groupKey)) {
              sizeAggregation[groupKey] = {'count': 0};
            }
            sizeAggregation[groupKey]!['count'] =
                (sizeAggregation[groupKey]!['count'] as int) + parsed.quantity;
          }
        }

        List<String> sortedSizeLabels = sizeAggregation.keys.toList()..sort();

        final screenWidth = MediaQuery.of(context).size.width;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Interactive Order Calendar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D241E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Track collections and delivery due dates mapped across months and days',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C7E6A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.isAdmin) ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade200),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _confirmDeleteMonth(context),
                      icon: const Icon(
                        Icons.delete_sweep,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Clear Month',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Adaptive responsive grid
              if (screenWidth >= 900)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          _buildCalendarCard(cells, allOrders),
                          const SizedBox(height: 16),
                          _buildProductionKitchenCard(
                            activePrepOrders,
                            sortedSizeLabels,
                            sizeAggregation,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: _buildDetailsPanel(selectedDayOrders),
                    ),
                  ],
                )
              else ...[
                _buildCalendarCard(cells, allOrders),
                const SizedBox(height: 16),
                _buildProductionKitchenCard(
                  activePrepOrders,
                  sortedSizeLabels,
                  sizeAggregation,
                ),
                const SizedBox(height: 16),
                _buildDetailsPanel(selectedDayOrders),
              ],
            ],
          ),
        );
    }
  }

  Widget _buildCalendarCard(
    List<Map<String, dynamic>> cells,
    List<Order> allOrders,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        children: [
          // Month Controller Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAE7E2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: Color(0xFFD4A373),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_monthsList[_currentMonth - 1].toUpperCase()} $_currentYear',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2D241E),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: _handlePrevMonth,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: _handleNextMonth,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Days of the Week
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _daysOfWeek.map((day) {
              return Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8C7E6A),
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 12),

          // Grid View of 42 cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              mainAxisExtent: 72,
            ),
            itemBuilder: (context, idx) {
              final cell = cells[idx];
              final int day = cell['day'] as int;
              final bool isCurrentMonth = cell['isCurrentMonth'] as bool;
              final String dateString = cell['dateString'] as String;

              final cellDate = DateTime.tryParse(dateString) ?? DateTime.now();
              final String formattedDate =
                  "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";

              final cellOrders = _getOrdersForDate(formattedDate, allOrders);
              final bool isSelected = _selectedDate == formattedDate;
              final now = DateTime.now();
              final todayStr =
                  "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
              final bool isToday = formattedDate == todayStr;

              return ScaleButton(
                onTap: () {
                  setState(() {
                    _selectedDate = formattedDate;
                    _selectedOrder = null; // show date summaries list first
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFFDF9)
                        : (cellOrders.isNotEmpty
                              ? (cellOrders.every((o) => o.isPrepOnly == true)
                                    ? Colors.green.withValues(alpha: 0.25)
                                    : (isToday
                                          ? Colors.orange.withValues(alpha: 0.2)
                                          : Colors.red.withValues(alpha: 0.15)))
                              : (isCurrentMonth
                                    ? Colors.white
                                    : const Color(0xFFFAF9F6))),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFD4A373)
                          : (isToday
                                ? const Color(0xFFD4A373)
                                : (cellOrders.isNotEmpty
                                      ? (cellOrders.every(
                                              (o) => o.isPrepOnly == true,
                                            )
                                            ? Colors.green.shade300
                                            : Colors.red.shade300)
                                      : const Color(0xFFF3F0EC))),
                      width: isSelected ? 2 : 1.5,
                    ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFFD4A373,
                              ).withValues(alpha: 0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: isToday
                                ? const BoxDecoration(
                                    color: Color(0xFFD4A373),
                                    shape: BoxShape.circle,
                                  )
                                : null,
                            child: Center(
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isToday
                                      ? Colors.white
                                      : (isCurrentMonth
                                            ? const Color(0xFF2D241E)
                                            : const Color(0xFF8C7E6A)),
                                ),
                              ),
                            ),
                          ),
                          if (cellOrders.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D241E),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_getTotalCakesCount(cellOrders)}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (ClosureRepository().getClosureForDate(formattedDate) != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CLOSED',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
    );
  }

  Widget _buildProductionKitchenCard(
    List<Order> selectedDayOrders,
    List<String> sortedSizeLabels,
    Map<String, Map<String, dynamic>> sizeAggregation,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Production Kitchen',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8C7E6A),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.cookie_outlined,
                        color: Color(0xFFD4A373),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Baking Summary: $_selectedDate',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D241E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D241E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getTotalCakesCount(selectedDayOrders)} CAKES DUE',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          if (selectedDayOrders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF9F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAE7E2)),
              ),
              child: const Center(
                child: Text(
                  'No baking schedules or cake sizes to aggregate for this day.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF8C7E6A),
                  ),
                ),
              ),
            )
          else ...[
            const Text(
              'Aggregated production checklist grouped by baking size requirements. Check items off as they are prepared in the kitchen:',
              style: TextStyle(fontSize: 10, color: Color(0xFF8C7E6A)),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width < 500 ? 1 : 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: sortedSizeLabels.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final groupKey = sortedSizeLabels[index];
                final key = "$_selectedDate-$groupKey";
                final isBaked = _bakedSizes[key] ?? false;
                final data = sizeAggregation[groupKey]!;
                final int count = data['count'] as int;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isBaked
                        ? Colors.green.shade50.withValues(alpha: 0.3)
                        : const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isBaked
                          ? Colors.green.shade200
                          : const Color(0xFFEAE7E2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    groupKey,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isBaked
                                          ? Colors.green.shade900
                                          : const Color(0xFF2D241E),
                                      decoration: isBaked
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2D241E,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$count ${count == 1 ? "Bake" : "Bakes"}',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                          ],
                        ),
                      ),
                      ScaleButton(
                        onTap: () {
                          setState(() {
                            _bakedSizes[key] = !isBaked;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isBaked
                                ? Colors.green.shade600
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isBaked
                                  ? Colors.green.shade600
                                  : const Color(0xFFEAE7E2),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: isBaked ? Colors.white : Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showCelebrationDialog(BuildContext context, int completedCount) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Celebration',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return Stack(
              children: [
                const Positioned.fill(child: CelebrationParticles()),
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Container(
                        width: 320,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 32,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            const Text(
                              'Well Done!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D241E),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Today All Orders\nare Finished!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8C7E6A),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00796B,
                                ).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF00796B,
                                  ).withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF00796B),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Completed Orders: $completedCount',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF00796B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                },
                                child: const Text(
                                  'OK',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5.0 * animation.value,
            sigmaY: 5.0 * animation.value,
          ),
          child: child,
        );
      },
    );
  }

  void _showOrderDetailsDialog(Order order) {
    setState(() {
      _selectedOrder = order;
    });
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Order Details',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return _buildOrderDetailsBottomSheet(order, context);
          },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5.0 * animation.value,
            sigmaY: 5.0 * animation.value,
          ),
          child: FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.4),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedOrder = null;
        });
      }
    });
  }

  void _showVoucherPreviewOnly(BuildContext parentSheetContext, Order order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return DigitalVoucherDialog(
          order: order,
          bakeryName: widget.settings?.bakeryName ?? 'ASH Bakery',
          footerNotes:
              widget.settings?.footerNotes ?? 'Thank you for your order!',
          items: widget.items,
          isViewOnly: true,
          onCancel: () {
            Navigator.of(dialogContext).pop();
          },
        );
      },
    );
  }

  Widget _buildOrderDetailsBottomSheet(Order order, BuildContext sheetContext) {
    final double screenWidth = MediaQuery.of(sheetContext).size.width;
    final bool isDesktop = screenWidth > 800;
    final double maxHeight = MediaQuery.of(sheetContext).size.height * 0.85;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            maxWidth: isDesktop ? 700 : screenWidth * 0.90,
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF004D40), // ASH Deep Teal
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long,
                            color: Color(0xFFFF6D00),
                            size: 18,
                          ), // Orange Icon
                          const SizedBox(width: 8),
                          Text(
                            '${order.orderNumber} DETAILS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                // Content Area
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            StatefulBuilder(
                              builder: (context, setPopupState) {
                                final bool isDone = order.isPrepOnly;
                                return ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isDone
                                            ? const Color(0xFF2E7D32)
                                            : const Color(0xFFFAF9F6),
                                    foregroundColor:
                                        isDone
                                            ? Colors.white
                                            : const Color(0xFF2E7D32),
                                    side: BorderSide(
                                      color:
                                          isDone
                                              ? Colors.green.shade800
                                              : const Color(0xFF2E7D32),
                                      width: 1.5,
                                    ),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () async {
                                    final bool nextVal = !isDone;
                                    setPopupState(() {
                                      order.isPrepOnly = nextVal;
                                    });
                                    await _toggleOrderCompletion(
                                      order,
                                      nextVal,
                                    );
                                  },
                                  icon: Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    size: 14,
                                    color:
                                        isDone
                                            ? Colors.white
                                            : const Color(0xFF2E7D32),
                                  ),
                                  label: Text(
                                    isDone ? 'Completed ✓' : 'Mark Done',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            if (widget.isAdmin) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFAF9F6),
                                  foregroundColor: const Color(
                                    0xFF00897B,
                                  ), // Secondary Teal Text
                                  side: const BorderSide(
                                    color: Color(0xFF00897B),
                                  ), // Teal border
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  widget.onEdit(order);
                                },
                                icon: const Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Color(0xFF00897B),
                                ),
                                label: const Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF004D40,
                                ), // Solid Deep Teal fill
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                _showVoucherPreviewOnly(sheetContext, order);
                              },
                              icon: const Icon(
                                Icons.receipt_long,
                                size: 14,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Voucher Preview',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (widget.isAdmin) ...[
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFAF9F6),
                                  foregroundColor: const Color(
                                    0xFFFF6D00,
                                  ), // Orange text
                                  side: const BorderSide(
                                    color: Color(0xFFFF6D00),
                                  ), // Orange border
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  widget.onReprint(order);
                                },
                                icon: const Icon(
                                  Icons.print,
                                  size: 14,
                                  color: Color(0xFFFF6D00),
                                ),
                                label: const Text(
                                  'Reprint',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade50,
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade200),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  _confirmDelete(context, order);
                                },
                                icon: const Icon(
                                  Icons.delete_forever,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (order.lastPrintError != null &&
                            order.lastPrintError!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFEF9A9A),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 14,
                                  color: Color(0xFFC62828),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Print Error: ${order.lastPrintError}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFC62828),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: 24),
                        _buildProductionDetails(order, widget.items),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(List<Order> selectedDayOrders) {
    final visibleOrders = selectedDayOrders
        .where((o) => o.id.isNotEmpty && !_deletedOrderIds.contains(o.id))
        .toList();

    return Column(
      children: [
        // Date Selector Header List
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: const Color(0xFFEAE7E2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DATE SELECTOR',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8C7E6A),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color(0xFFD4A373),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Orders due: $_selectedDate',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D241E),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              if (visibleOrders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No orders due on this date.',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF8C7E6A),
                      ),
                    ),
                  ),
                )
              else ...[
                Builder(
                  builder: (context) {
                    final finishedCount = visibleOrders
                        .where((o) => o.isPrepOnly == true)
                        .length;
                    final remainingCount = visibleOrders.length - finishedCount;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (visibleOrders.isNotEmpty &&
                            remainingCount == 0) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00796B,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF00796B,
                                ).withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF00796B),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Today Production Completed ✅',
                                  style: TextStyle(
                                    color: Color(0xFF00796B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEAE7E2),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Finished',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '$finishedCount orders',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2D241E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                height: 24,
                                width: 1.5,
                                color: const Color(0xFFEAE7E2),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.hourglass_empty_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Remaining',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '$remainingCount orders',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2D241E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleOrders.length,
                  itemBuilder: (context, idx) {
                    final ord = visibleOrders[idx];
                    final isSelected = _selectedOrder?.id == ord.id;
                    final isCompleted = ord.isPrepOnly;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ScaleButton(
                        onTap: () {
                          _showOrderDetailsDialog(ord);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFFE8F5E9)
                                : (cleanDate(ord.deliveryDate) !=
                                          cleanDate(_selectedDate)
                                      ? const Color(
                                          0xFFFFEBEE,
                                        ).withValues(alpha: 0.5)
                                      : (isSelected
                                            ? const Color(0xFFFFFDF9)
                                            : const Color(0xFFFFFFFF))),
                            borderRadius: BorderRadius.circular(12),
                            border: isCompleted
                                ? Border.all(
                                    color: Colors.green.shade300,
                                    width: 1.5,
                                  )
                                : (cleanDate(ord.deliveryDate) !=
                                          cleanDate(_selectedDate)
                                      ? Border.all(
                                          color: const Color(
                                            0xFFFF8A80,
                                          ).withValues(alpha: 0.8),
                                          width: 1.5,
                                        )
                                      : Border.all(
                                          color: isSelected
                                              ? const Color(0xFFD4A373)
                                              : const Color(0xFFEAE7E2),
                                          width: isSelected ? 2 : 1.5,
                                        )),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              if (isCompleted)
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2E7D32),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                )
                              else if (cleanDate(ord.deliveryDate) !=
                                  cleanDate(_selectedDate))
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 5,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF3D00),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: EdgeInsets.only(
                                  left: (isCompleted ||
                                          cleanDate(ord.deliveryDate) !=
                                              cleanDate(_selectedDate))
                                      ? 8.0
                                      : 0.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Checkbox(
                                  value: ord.isPrepOnly,
                                  onChanged: (val) {
                                    _toggleOrderCompletion(
                                      ord,
                                      val ?? false,
                                      visibleOrders,
                                    );
                                  },
                                  activeColor: const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  final bool isPrep =
                                                      cleanDate(
                                                        ord.deliveryDate,
                                                      ) !=
                                                      cleanDate(_selectedDate);
                                                  return Row(
                                                    children: [
                                                      if (!isPrep) ...[
                                                        const Icon(
                                                          Icons.access_time,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF8C7E6A,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          'Due: ${formatTimeTo12Hour(ord.deliveryTime)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                  0xFF2D241E,
                                                                ),
                                                              ),
                                                        ),
                                                      ] else ...[
                                                        const Icon(
                                                          Icons
                                                              .access_time_filled_rounded,
                                                          size: 14,
                                                          color: Color(
                                                            0xFFFF3D00,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          'Due: ${formatTimeTo12Hour(ord.deliveryTime)}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                                color: Color(
                                                                  0xFFD84315,
                                                                ),
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        const Text(
                                                          '(Prep)',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Color(
                                                              0xFFD84315,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      if (ord.isKpay) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 4,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .blue
                                                                .shade50,
                                                            border: Border.all(
                                                              color: Colors
                                                                  .blue
                                                                  .shade200,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: const Text(
                                                            'KPAY',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              color:
                                                                  Colors.blue,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  );
                                                },
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    ord.orderNumber,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                      fontFamily:
                                                          'JetBrains Mono',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              _buildStatusBadges(ord),
                                            ],
                                          ),
                                        ),
                                        if (widget.isAdmin)
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red[300],
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _confirmDelete(context, ord),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEAE7E2),
                                    ),
                                    const SizedBox(height: 12),
                                    // Items List
                                    Builder(
                                      builder: (context) {
                                        final parsedItems = _parseOrderItems(
                                          ord,
                                        );
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: parsedItems.map((pi) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8.0,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${pi.quantity}x',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF2D241E),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          pi.name,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                  0xFF2D241E,
                                                                ),
                                                              ),
                                                        ),
                                                        if (pi
                                                                .size
                                                                .isNotEmpty ||
                                                            pi
                                                                .variant
                                                                .isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  top: 2.0,
                                                                ),
                                                            child: Text(
                                                              [
                                                                if (pi
                                                                    .size
                                                                    .isNotEmpty)
                                                                  pi.size,
                                                                if (pi
                                                                    .variant
                                                                    .isNotEmpty)
                                                                  pi.variant,
                                                              ].join(' • '),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Color(
                                                                      0xFF8C7E6A,
                                                                    ),
                                                                  ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 4),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFEAE7E2),
                                    ),
                                    const SizedBox(height: 12),
                                    // Footer
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Recipient',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                ord.customName.isNotEmpty
                                                    ? ord.customName
                                                    : "Not specified",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF2D241E),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${ord.totalAmount.toLocaleString()} MMK',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'JetBrains Mono',
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isCompleted
                                                    ? Colors.green.shade100
                                                    : (cleanDate(
                                                              ord.deliveryDate,
                                                            ) !=
                                                            cleanDate(
                                                              _selectedDate,
                                                            )
                                                        ? Colors.red.shade50
                                                        : (ord.paymentStatus ==
                                                                'fully_paid'
                                                            ? Colors.green.shade50
                                                            : Colors
                                                                .orange
                                                                .shade50)),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: isCompleted
                                                      ? Colors.green.shade600
                                                      : (cleanDate(
                                                                ord.deliveryDate,
                                                              ) !=
                                                              cleanDate(
                                                                _selectedDate,
                                                              )
                                                          ? Colors.red.shade200
                                                          : (ord.paymentStatus ==
                                                                  'fully_paid'
                                                              ? Colors
                                                                  .green
                                                                  .shade300
                                                              : Colors
                                                                  .orange
                                                                  .shade300)),
                                                ),
                                              ),
                                              child: Text(
                                                isCompleted
                                                    ? 'Done ✓'
                                                    : (cleanDate(
                                                              ord.deliveryDate,
                                                            ) !=
                                                            cleanDate(
                                                              _selectedDate,
                                                            )
                                                        ? 'Prep'
                                                        : (ord.paymentStatus ==
                                                                'fully_paid'
                                                            ? 'Paid'
                                                            : 'Bal Due')),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCompleted
                                                      ? Colors.green.shade900
                                                      : (cleanDate(
                                                                ord.deliveryDate,
                                                              ) !=
                                                              cleanDate(
                                                                _selectedDate,
                                                              )
                                                          ? Colors.red.shade700
                                                          : (ord.paymentStatus ==
                                                                  'fully_paid'
                                                              ? Colors
                                                                  .green
                                                                  .shade700
                                                              : Colors
                                                                  .orange
                                                                  .shade800)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
  }

  Widget _buildProductionDetails(Order order, List<CakeItem> items) {
    final item = items.firstWhere(
      (i) => i.id == order.itemId,
      orElse: () => CakeItem(
        id: '',
        name: 'Custom Cake',
        sizes: [],
        variants: [],
        pricing: {},
      ),
    );

    // Parse designFrom and qty
    String mainDesignFrom = 'N/A';
    String cleanInstructions = order.specialInstructions;
    if (cleanInstructions.contains('[Design From: ')) {
      final startIdx =
          cleanInstructions.indexOf('[Design From: ') + '[Design From: '.length;
      final endIdx = cleanInstructions.indexOf(']', startIdx);
      if (endIdx != -1) {
        mainDesignFrom = cleanInstructions.substring(startIdx, endIdx).trim();
        cleanInstructions = cleanInstructions
            .replaceRange(
              cleanInstructions.indexOf('[Design From: '),
              endIdx + 1,
              '',
            )
            .trim();
      }
    }

    int mainQty = 1;
    if (cleanInstructions.contains('[Qty: ')) {
      final startIdx = cleanInstructions.indexOf('[Qty: ') + '[Qty: '.length;
      final endIdx = cleanInstructions.indexOf(']', startIdx);
      if (endIdx != -1) {
        mainQty =
            int.tryParse(cleanInstructions.substring(startIdx, endIdx)) ?? 1;
        cleanInstructions = cleanInstructions
            .replaceRange(cleanInstructions.indexOf('[Qty: '), endIdx + 1, '')
            .trim();
      }
    }

    final List<Map<String, dynamic>> parsedItems = [
      {
        'name': item.name,
        'sizeShape': '${order.size} - ${order.variant}',
        'qty': mainQty,
        'designCode': order.designCode,
        'designFrom': mainDesignFrom,
        'toysCost': order.toysCost,
        'moneyPullingNote': order.moneyPullingNote,
      },
    ];

    if (cleanInstructions.contains('[Additional Items: ')) {
      final startIdx =
          cleanInstructions.indexOf('[Additional Items: ') +
          '[Additional Items: '.length;
      int bracketCount = 1;
      int endIdx = -1;
      for (int i = startIdx; i < cleanInstructions.length; i++) {
        if (cleanInstructions[i] == '[') {
          bracketCount++;
        } else if (cleanInstructions[i] == ']') {
          bracketCount--;
        }

        if (bracketCount == 0) {
          endIdx = i;
          break;
        }
      }
      if (endIdx != -1) {
        final itemsPart = cleanInstructions.substring(startIdx, endIdx);
        final itemStrings = <String>[];
        int lastSplit = 0;
        int inBrackets = 0;
        for (int i = 0; i < itemsPart.length; i++) {
          if (itemsPart[i] == '[') {
            inBrackets++;
          } else if (itemsPart[i] == ']') {
            inBrackets--;
          } else if (itemsPart.startsWith(', ', i) && inBrackets == 0) {
            itemStrings.add(itemsPart.substring(lastSplit, i));
            lastSplit = i + 2;
            i++;
          }
        }
        if (lastSplit < itemsPart.length) {
          itemStrings.add(itemsPart.substring(lastSplit));
        }
        for (var itemStr in itemStrings) {
          final nameEnd = itemStr.indexOf(' (');
          if (nameEnd != -1) {
            final name = itemStr.substring(0, nameEnd);
            final specsStart = nameEnd + 2;
            final specsEnd = itemStr.indexOf(') x', specsStart);
            if (specsEnd != -1) {
              final specs = itemStr.substring(specsStart, specsEnd);
              final qtyStart = specsEnd + 3;
              final qtyPart = itemStr.substring(qtyStart);
              int qty = 1;
              String designCode = '';
              String designFrom = 'N/A';
              int toysCost = 0;
              String moneyPullingNote = '';

              if (qtyPart.contains(' [')) {
                final tagStart = qtyPart.indexOf(' [') + 2;
                final tagEnd = qtyPart.indexOf(']', tagStart);
                final qtyStr = qtyPart.substring(0, qtyPart.indexOf(' ['));
                qty = int.tryParse(qtyStr) ?? 1;

                if (tagEnd != -1) {
                  final tagsStr = qtyPart.substring(tagStart, tagEnd);
                  final tags = tagsStr.split(', ');
                  for (var tag in tags) {
                    if (tag.startsWith('Design: ')) {
                      designCode = tag.substring('Design: '.length);
                    } else if (tag.startsWith('DesignFrom: ')) {
                      designFrom = tag.substring('DesignFrom: '.length);
                    } else if (tag.startsWith('ToysCost: ')) {
                      toysCost =
                          int.tryParse(tag.substring('ToysCost: '.length)) ?? 0;
                    } else if (tag.startsWith('MoneyPullingNote: ')) {
                      moneyPullingNote = tag.substring(
                        'MoneyPullingNote: '.length,
                      );
                    }
                  }
                }
              } else {
                qty = int.tryParse(qtyPart) ?? 1;
              }

              final specParts = specs.split(' - ');
              final size = specParts[0];
              final variant = specParts.length > 1 ? specParts[1] : '';

              parsedItems.add({
                'name': name,
                'sizeShape': '$size - $variant',
                'qty': qty,
                'designCode': designCode,
                'designFrom': designFrom,
                'toysCost': toysCost,
                'moneyPullingNote': moneyPullingNote,
              });
            }
          }
        }
        cleanInstructions = cleanInstructions
            .replaceRange(
              cleanInstructions.indexOf('[Additional Items: '),
              endIdx + 1,
              '',
            )
            .trim();
      }
    }

    // Final cleanup to prevent stray characters from rendering an empty block
    cleanInstructions = cleanInstructions
        .replaceAll(RegExp(r'^[\]\s,]+|[\]\s,]+$'), '')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Order Information
        _buildSectionCard(
          icon: Icons.calendar_month,
          title: 'Order Information',
          child: Column(
            children: [
              _buildInfoRow(
                'Order No.',
                order.orderNumber,
                isBold: true,
                isMono: true,
              ),
              _buildInfoRow(
                'Due Date',
                formatDateToDDMMYY(order.deliveryDate),
                isBold: true,
                textColor: const Color(0xFFFF6D00), // Orange Accent
              ),
              _buildInfoRow(
                'Due Time',
                formatTimeTo12Hour(order.deliveryTime),
                isBold: true,
                textColor: const Color(0xFFFF6D00), // Orange Accent
              ),
              _buildInfoRow('Channel', order.orderFrom),
              _buildInfoRow('Customer Ph', order.customerPhone),
            ],
          ),
        ),

        // 2. Cake Details (Render one card per item)
        for (int i = 0; i < parsedItems.length; i++)
          _buildSectionCard(
            icon: Icons.cake,
            title: parsedItems.length > 1
                ? 'Cake Details (Item #${i + 1})'
                : 'Cake Details',
            child: Column(
              children: [
                _buildInfoRow(
                  'Item',
                  parsedItems[i]['name'] as String,
                  isBold: true,
                  textColor: const Color(0xFF00897B), // Secondary Teal
                ),
                _buildInfoRow(
                  'Size/Shape',
                  parsedItems[i]['sizeShape'] as String,
                  isBold: true,
                  textColor: const Color(0xFF00897B), // Secondary Teal
                ),
                _buildInfoRow(
                  'Quantity',
                  '${parsedItems[i]['qty']}x',
                  isBold: true,
                  textColor: const Color(0xFFFF6D00), // Orange Accent
                ),
                if ((parsedItems[i]['designCode'] as String).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 85,
                          child: Text(
                            'Design Code',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8C7E6A),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            parsedItems[i]['designCode'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(
                                0xFF004D40,
                              ), // ASH Deep Teal highlight
                              fontFamily: 'JetBrains Mono',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (parsedItems[i]['designFrom'] != 'N/A' &&
                    (parsedItems[i]['designFrom'] as String).isNotEmpty)
                  _buildInfoRow(
                    'Design From',
                    parsedItems[i]['designFrom'] as String,
                    textColor: const Color(0xFF00897B), // Secondary Teal
                  ),
                if ((parsedItems[i]['toysCost'] as int) > 0)
                  _buildInfoRow(
                    'Toy',
                    '✓ Toy Included',
                    isBold: true,
                    textColor: Colors.green.shade700,
                  ),
                if ((parsedItems[i]['moneyPullingNote'] as String).isNotEmpty)
                  _buildInfoRow(
                    'Money Pulling',
                    parsedItems[i]['moneyPullingNote'] as String,
                    isBold: true,
                    textColor: Colors.blue.shade700,
                  ),
              ],
            ),
          ),

        // 3. Customization (Inscriptions & Notes)
        if (order.customName.isNotEmpty ||
            order.customAge.isNotEmpty ||
            order.customDate.isNotEmpty ||
            order.customLettering.isNotEmpty ||
            cleanInstructions.isNotEmpty)
          _buildSectionCard(
            icon: Icons.draw,
            title: 'Customization',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.customName.isNotEmpty)
                  _buildInfoRow('Name', order.customName, isBold: true),
                if (order.customAge.isNotEmpty)
                  _buildInfoRow('Age', order.customAge, isBold: true),
                if (order.customDate.isNotEmpty)
                  _buildInfoRow('Date on Cake', order.customDate, isBold: true),
                if (order.customLettering.isNotEmpty) ...[
                  if (order.customName.isNotEmpty ||
                      order.customAge.isNotEmpty ||
                      order.customDate.isNotEmpty)
                    const SizedBox(height: 6),
                  const Text(
                    'Cake Message:',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8C7E6A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"${order.customLettering}"',
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (cleanInstructions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Text(
                    'Bakery Instructions:',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8C7E6A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cleanInstructions,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.15),
          width: 1.5,
        ), // Teal opacity border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: const Color(0xFFFF6D00),
              ), // Orange Accent Icon
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00897B), // Secondary Teal Title
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    bool isMono = false,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8C7E6A)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor ?? const Color(0xFF2D241E),
                fontFamily: isMono ? 'JetBrains Mono' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Unsubscribe this tab's channel via centralized RealtimeManager
    RealtimeManager().unsubscribe('calendar');
    debugPrint('CalendarTab: Disposed — realtime unsubscribed via RealtimeManager.');
    super.dispose();
  }
}

class _CakeOrderItem {
  final String name;
  final String size;
  final String variant;
  final int quantity;
  _CakeOrderItem({
    required this.name,
    required this.size,
    required this.variant,
    required this.quantity,
  });
}

class CelebrationParticles extends StatefulWidget {
  const CelebrationParticles({super.key});

  @override
  State<CelebrationParticles> createState() => _CelebrationParticlesState();
}

class _CelebrationParticlesState extends State<CelebrationParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  void _initParticles(Size size) {
    final colors = [
      const Color(0xFF00796B),
      const Color(0xFFFF6D00),
      const Color(0xFFD4A373),
      const Color(0xFF00897B),
      const Color(0xFFFFAB40),
    ];

    for (int i = 0; i < 50; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble() * size.width,
          y: size.height + _random.nextDouble() * 100,
          vx: -1.5 + _random.nextDouble() * 3.0,
          vy: -3.0 - _random.nextDouble() * 5.0,
          size: 6.0 + _random.nextDouble() * 6.0,
          color: colors[_random.nextInt(colors.length)],
          isConfetti: true,
          rotation: _random.nextDouble() * 2 * pi,
          rotSpeed: -0.05 + _random.nextDouble() * 0.1,
        ),
      );
    }

    for (int i = 0; i < 25; i++) {
      _particles.add(
        _Particle(
          x: 0,
          y: size.height * 0.7,
          vx: 3.0 + _random.nextDouble() * 7.0,
          vy: -5.0 - _random.nextDouble() * 8.0,
          size: 3.0 + _random.nextDouble() * 4.0,
          color: colors[_random.nextInt(colors.length)],
          isConfetti: false,
          rotation: 0,
          rotSpeed: 0,
        ),
      );
    }

    for (int i = 0; i < 25; i++) {
      _particles.add(
        _Particle(
          x: size.width,
          y: size.height * 0.7,
          vx: -3.0 - _random.nextDouble() * 7.0,
          vy: -5.0 - _random.nextDouble() * 8.0,
          size: 3.0 + _random.nextDouble() * 4.0,
          color: colors[_random.nextInt(colors.length)],
          isConfetti: false,
          rotation: 0,
          rotSpeed: 0,
        ),
      );
    }

    _initialized = true;
  }

  void _updateParticles(Size size) {
    for (final p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      if (p.isConfetti) {
        p.rotation += p.rotSpeed;
        p.vy += 0.02;
        if (p.y < -50) {
          p.y = size.height + 20;
          p.x = _random.nextDouble() * size.width;
          p.vy = -3.0 - _random.nextDouble() * 5.0;
        }
      } else {
        p.vy += 0.15;
        p.vx *= 0.96;
        p.vy *= 0.96;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            onPaint: (size) {
              if (!_initialized) {
                _initParticles(size);
              }
              _updateParticles(size);
            },
          ),
          child: Container(),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  bool isConfetti;
  double rotation;
  double rotSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.isConfetti,
    required this.rotation,
    required this.rotSpeed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final void Function(Size) onPaint;

  _ParticlePainter({required this.particles, required this.onPaint});

  @override
  void paint(Canvas canvas, Size size) {
    onPaint(size);

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      if (p.isConfetti) {
        canvas.rotate(p.rotation);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 1.5,
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
