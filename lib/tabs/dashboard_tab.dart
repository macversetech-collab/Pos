// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/scale_button.dart';
import '../services/order_repository.dart';

class SalesDashboardTab extends StatefulWidget {
  final List<CakeItem> items;
  final List<CakeSize> sizes;
  final void Function(Order) onSelectOrder;
  final void Function(int) setActiveTab;
  final bool isActive;

  const SalesDashboardTab({
    super.key,
    required this.items,
    required this.sizes,
    required this.onSelectOrder,
    required this.setActiveTab,
    this.isActive = false,
  });

  @override
  State<SalesDashboardTab> createState() => _SalesDashboardTabState();
}

class _SalesDashboardTabState extends State<SalesDashboardTab> {
  String _activeFilter = 'Today'; // 'Today', 'Month', 'Custom'
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  List<Order> _dbOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }


  @override
  void didUpdateWidget(covariant SalesDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _fetchDashboardData();
    }
  }

  void _showVoucherDialog(Order order) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _buildVoucherModal(order, dialogContext);
      },
    );
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    List<Order> orders = [];

    // 1. Fetch Orders
    try {
      final now = DateTime.now();
      var query = Supabase.instance.client.from('orders').select();

      if (_activeFilter == 'Today') {
        final startStr = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
        final endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
        query = query.gte('created_at', startStr).lte('created_at', endStr);
      } else if (_activeFilter == 'Month') {
        final startStr = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
        final endStr = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
        query = query.gte('created_at', startStr).lte('created_at', endStr);
      } else {
        final startStr = DateTime(_startDate.year, _startDate.month, _startDate.day).toUtc().toIso8601String();
        final endStr = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toUtc().toIso8601String();
        query = query.gte('created_at', startStr).lte('created_at', endStr);
      }

      final res = await query;
      final Set<String> deletedIds = OrderRepository().getDeletedOrderIds();

      orders = (res as List)
          .where((row) => row['id'] != null && !deletedIds.contains(row['id'] as String))
          .map((row) {
        return Order(
          id: row['id'] as String,
          orderNumber: row['order_number'] as String,
          deliveryDate: row['delivery_date'] as String,
          deliveryTime: row['delivery_time'] as String,
          itemId: row['item_id'] as String,
          size: row['size'] as String,
          variant: row['variant'] as String,
          designCode: row['design_code'] as String,
          customName: row['custom_name'] as String,
          customAge: row['custom_age'] as String,
          customDate: row['custom_date'] as String,
          customLettering: row['custom_lettering'] as String,
          specialInstructions: row['special_instructions'] as String,
          customerPhone: row['customer_phone'] as String,
          paymentStatus: row['payment_status'] as String,
          depositPaid: row['deposit_paid'] as int,
          remainingBalance: row['remaining_balance'] as int,
          isKpay: row['is_kpay'] as bool,
          totalAmount: row['total_amount'] as int,
          toysCost: row['toys_cost'] as int,
          moneyPullingCost: row['money_pulling_cost'] as int,
          moneyPullingNote: row['money_pulling_note'] as String,
          deliveryCost: row['delivery_cost'] as int,
          orderFrom: row['order_from'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          printCount: row['print_count'] as int? ?? 0,
          printStatus: row['print_status'] as String? ?? 'pending',
          isPrepOnly: row['is_prep_only'] as bool? ?? false,
          customerPrinted: row['customer_printed'] as bool? ?? (row['print_status'] == 'completed' || row['print_status'] == 'partial_failed'),
          kitchenPrinted: row['kitchen_printed'] as bool? ?? (row['print_status'] == 'completed'),
          lastPrintError: row['last_print_error'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      orders = [];
    }

    setState(() {
      _dbOrders = orders;
      _isLoading = false;
    });
  }

  // Parse total cakes quantity
  int _getTotalCakesCount(List<Order> orders) {
    int total = 0;
    for (var o in orders) {
      int firstQty = 1;
      String instructions = o.specialInstructions;
      if (instructions.contains('[Qty: ')) {
        final startIdx = instructions.indexOf('[Qty: ') + '[Qty: '.length;
        final endIdx = instructions.indexOf(']', startIdx);
        if (endIdx != -1) {
          firstQty = int.tryParse(instructions.substring(startIdx, endIdx)) ?? 1;
          instructions = instructions
              .replaceRange(
                instructions.indexOf('[Qty: '),
                endIdx + 1,
                '',
              )
              .trim();
        }
      }
      total += firstQty;

      if (instructions.contains('[Additional Items: ')) {
        final startIdx =
            instructions.indexOf('[Additional Items: ') +
            '[Additional Items: '.length;
        int bracketCount = 1;
        int endIdx = -1;
        for (int i = startIdx; i < instructions.length; i++) {
          if (instructions[i] == '[') {
            bracketCount++;
          } else if (instructions[i] == ']') {
            bracketCount--;
          }
          
          if (bracketCount == 0) {
            endIdx = i;
            break;
          }
        }
        if (endIdx != -1) {
          final itemsPart = instructions.substring(startIdx, endIdx);
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
              final specsEnd = itemStr.indexOf(') x', nameEnd + 2);
              if (specsEnd != -1) {
                final qtyStart = specsEnd + 3;
                final qtyPart = itemStr.substring(qtyStart);
                int qty = 1;
                if (qtyPart.contains(' [')) {
                  final qtyStr = qtyPart.substring(0, qtyPart.indexOf(' ['));
                  qty = int.tryParse(qtyStr) ?? 1;
                } else {
                  qty = int.tryParse(qtyPart) ?? 1;
                }
                total += qty;
              }
            }
          }
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Filter orders based on active selection
    List<Order> filteredOrders = _dbOrders.where((o) {
      try {
        final status = o.paymentStatus.toLowerCase();
        if (status == 'cancelled' || status == 'refunded' || status == 'void') {
          return false;
        }

        DateTime orderDate = o.createdAt;
        if (_activeFilter == 'Today') {
          final now = DateTime.now();
          final startClean = DateTime(now.year, now.month, now.day);
          final endClean = DateTime(now.year, now.month, now.day, 23, 59, 59);
          return orderDate.isAfter(startClean.subtract(const Duration(seconds: 1))) &&
                 orderDate.isBefore(endClean.add(const Duration(seconds: 1)));
        } else if (_activeFilter == 'Month') {
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, 1);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
          return orderDate.isAfter(start.subtract(const Duration(seconds: 1))) &&
                 orderDate.isBefore(end.add(const Duration(seconds: 1)));
        } else {
          // Custom Range
          DateTime startClean = DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
          );
          DateTime endClean = DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            23,
            59,
            59,
          );
          return orderDate.isAfter(
                startClean.subtract(const Duration(seconds: 1)),
              ) &&
              orderDate.isBefore(endClean.add(const Duration(seconds: 1)));
        }
      } catch (e) {
        return false;
      }
    }).toList();

    // Financial aggregates
    int totalOrdersCount = _getTotalCakesCount(filteredOrders);
    int revenueCollected = filteredOrders.fold(
      0,
      (sum, o) => sum + o.depositPaid,
    );
    int outstandingReceivable = filteredOrders.fold(
      0,
      (sum, o) => sum + o.remainingBalance,
    );
    int totalNetValue = filteredOrders.fold(0, (sum, o) => sum + o.totalAmount);

    // Split by Payment Method (K-Pay vs Cash)
    int kpayCollected = filteredOrders
        .where((o) => o.isKpay)
        .fold(0, (sum, o) => sum + o.depositPaid);
    int cashCollected = filteredOrders
        .where((o) => !o.isKpay)
        .fold(0, (sum, o) => sum + o.depositPaid);

    // Channel breakdown aggregates
    int countPage = filteredOrders
        .where((o) => o.orderFrom == 'Page' || o.orderFrom.isEmpty)
        .length;
    int countPhone = filteredOrders.where((o) => o.orderFrom == 'Phone').length;
    int countViber = filteredOrders.where((o) => o.orderFrom == 'Viber').length;
    int countTelegram = filteredOrders
        .where((o) => o.orderFrom == 'Telegram')
        .length;
    int countWeChat = filteredOrders
        .where((o) => o.orderFrom == 'WeChat')
        .length;

    // Popularity tallies
    Map<String, int> sizeCounts = {};
    for (var o in filteredOrders) {
      String sizeName = o.size.isNotEmpty ? o.size : 'Other';
      sizeCounts[sizeName] = (sizeCounts[sizeName] ?? 0) + 1;
    }
    var sortedSizes = sizeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Map<String, int> flavorCounts = {};
    for (var o in filteredOrders) {
      final item = widget.items.isEmpty
          ? null
          : widget.items.firstWhere(
              (i) => i.id == o.itemId,
              orElse: () => CakeItem(
                id: '',
                name: 'Custom Cake',
                sizes: [],
                variants: [],
                pricing: {},
              ),
            );
      if (item != null) {
        flavorCounts[item.name] = (flavorCounts[item.name] ?? 0) + 1;
      }
    }
    var sortedFlavors = flavorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filters control banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppDecorations.container(borderWidth: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Sales & Analytics Dashboard',
                      style: TextStyle(
                        color: Color(0xFF2D241E),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track collections, payments split totals, receivables, and product popularity indexes',
                      style: TextStyle(
                        color: Color(0xFF8C7E6A),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 6,
                          children: [
                            _buildFilterChip('Today'),
                            _buildFilterChip('Month'),
                            _buildFilterChip('Custom'),
                          ],
                        ),
                      ],
                    ),
                    if (_activeFilter == 'Custom') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePickerButton(
                              label:
                                  'From: ${_startDate.day}-${_startDate.month}-${_startDate.year}',
                              onPressed: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2028),
                                );
                                if (picked != null) {
                                  setState(() => _startDate = picked);
                                  _fetchDashboardData();
                                }
                              },
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: Color(0xFF8C7E6A),
                            ),
                          ),
                          Expanded(
                            child: _buildDatePickerButton(
                              label:
                                  'To: ${_endDate.day}-${_endDate.month}-${_endDate.year}',
                              onPressed: () async {
                                DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2028),
                                );
                                if (picked != null) {
                                  setState(() => _endDate = picked);
                                  _fetchDashboardData();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // KPI Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final double childWidth = constraints.maxWidth > 700
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2;

                  final wrapWidgets = [
                    SizedBox(
                      width: childWidth,
                      child: _buildMetricCard(
                        title: 'BAKERY ORDERS COUNT',
                        value: '$totalOrdersCount cakes',
                        subtext: 'Filtered due active sum',
                        icon: Icons.cake,
                        color: const Color(0xFFD4A373),
                      ),
                    ),
                    SizedBox(
                      width: childWidth,
                      child: _buildMetricCard(
                        title: 'TOTAL NET VALUES',
                        value: '${totalNetValue.toLocaleString()} MMK',
                        subtext: 'Raw total amount due',
                        icon: Icons.monetization_on,
                        color: const Color(0xFF1E88E5),
                      ),
                    ),
                    SizedBox(
                      width: childWidth,
                      child: _buildMetricCard(
                        title: 'REVENUE COLLECTED (DEPOSIT)',
                        value: '${revenueCollected.toLocaleString()} MMK',
                        subtext: 'Cash & K-Pay splits combined',
                        icon: Icons.account_balance_wallet,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: childWidth,
                      child: _buildMetricCard(
                        title: 'OUTSTANDING RECEIVABLE',
                        value: '${outstandingReceivable.toLocaleString()} MMK',
                        subtext: 'To be collected on delivery',
                        icon: Icons.hourglass_top,
                        color: Colors.red,
                      ),
                    ),
                  ];

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: wrapWidgets,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Main grid layout: Left side splits & channels, Right side popular & activity
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool isWide = constraints.maxWidth > 800;

                  Widget leftSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPaymentSplitsCard(kpayCollected, cashCollected),
                      const SizedBox(height: 16),
                      _buildChannelBreakdownCard(
                        countPage: countPage,
                        countPhone: countPhone,
                        countViber: countViber,
                        countTelegram: countTelegram,
                        countWeChat: countWeChat,
                      ),
                    ],
                  );

                  Widget rightSection = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProductPopularityCatalog(sortedSizes, sortedFlavors),
                      const SizedBox(height: 16),
                      _buildRecentActivityFeed(filteredOrders),
                    ],
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: leftSection),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: rightSection),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        leftSection,
                        const SizedBox(height: 16),
                        rightSection,
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(borderWidth: 2),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D241E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFEAE7E2), width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      icon: const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8C7E6A)),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2D241E),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildFilterChip(String label) {
    final bool isSelected = _activeFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeFilter = label;
          });
          _fetchDashboardData();
        }
      },
      selectedColor: const Color(0xFFD4A373),
      backgroundColor: const Color(0xFFF8F9FA),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF2D241E),
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
    );
  }

  Widget _buildPaymentSplitsCard(int kpaySum, int cashSum) {
    int total = kpaySum + cashSum;
    double kpayPct = total > 0 ? (kpaySum / total) * 100 : 0;
    double cashPct = total > 0 ? (cashSum / total) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEPOSITS REVENUE COLLECTED SPLIT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C7E6A),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Payment Methods Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D241E),
            ),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  'No transactions logged in this range',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8C7E6A),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  flex: kpaySum,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E88E5), // K-Pay Blue
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: cashSum,
                  child: Container(
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4A373), // Cash Orange
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.credit_card, color: Color(0xFF1E88E5), size: 16),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobile Banking / K-Pay',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D241E),
                          ),
                        ),
                        Text(
                          '${kpayPct.toStringAsFixed(1)}% share',
                          style: const TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${kpaySum.toLocaleString()} MMK',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D241E),
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.money_outlined, color: Color(0xFFD4A373), size: 16),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Physical Cash',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D241E),
                          ),
                        ),
                        Text(
                          '${cashPct.toStringAsFixed(1)}% share',
                          style: const TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${cashSum.toLocaleString()} MMK',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D241E),
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildChannelBreakdownCard({
    required int countPage,
    required int countPhone,
    required int countViber,
    required int countTelegram,
    required int countWeChat,
  }) {
    int total = countPage + countPhone + countViber + countTelegram + countWeChat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BOOKING CHANNELS PERFORMANCE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C7E6A),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Order Intake Inflow Sources',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D241E),
            ),
          ),
          const SizedBox(height: 16),
          _buildChannelItem('Facebook Page / Shop', countPage, total, Colors.blue),
          const Divider(height: 16),
          _buildChannelItem('Telephone Call', countPhone, total, Colors.orange),
          const Divider(height: 16),
          _buildChannelItem('Viber Chats', countViber, total, Colors.purple),
          const Divider(height: 16),
          _buildChannelItem('Telegram Channels', countTelegram, total, Colors.lightBlue),
          const Divider(height: 16),
          _buildChannelItem('WeChat Inflows', countWeChat, total, Colors.green),
        ],
      ),
    );
  }

  Widget _buildChannelItem(String name, int val, int total, Color barColor) {
    double pct = total > 0 ? (val / total) : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D241E),
              ),
            ),
            Text(
              '$val bookings (${(pct * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8C7E6A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF3F0EC),
            color: barColor,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildProductPopularityCatalog(
    List<MapEntry<String, int>> sortedSizes,
    List<MapEntry<String, int>> sortedFlavors,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'POPULAR PRODUCTS INDEX',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C7E6A),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Baking Size & Flavor Popularity Tally',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D241E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Baking Sizes (Ordered by popularity)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D241E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sortedSizes.isEmpty)
                      const Text(
                        'No size data available',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedSizes.length > 5 ? 5 : sortedSizes.length,
                        itemBuilder: (context, idx) {
                          final item = sortedSizes[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${idx + 1}. Size "${item.key}"', style: const TextStyle(fontSize: 10)),
                                Text('${item.value} sold', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cake Flavors (Ordered by popularity)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D241E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (sortedFlavors.isEmpty)
                      const Text(
                        'No flavor data available',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: sortedFlavors.length > 5 ? 5 : sortedFlavors.length,
                        itemBuilder: (context, idx) {
                          final item = sortedFlavors[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${idx + 1}. ${item.key}',
                                    style: const TextStyle(fontSize: 10),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${item.value} sold', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityFeed(List<Order> orders) {
    final reversedOrders = orders.reversed.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECENT ACTIVITY FEED',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8C7E6A),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Latest Active Bookings',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2D241E),
            ),
          ),
          const SizedBox(height: 12),
          if (reversedOrders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                  'No orders found inside this interval',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8C7E6A),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reversedOrders.length > 5 ? 5 : reversedOrders.length,
              itemBuilder: (context, idx) {
                final ord = reversedOrders[idx];
                final item = widget.items.firstWhere(
                  (i) => i.id == ord.itemId,
                  orElse: () => CakeItem(
                    id: '',
                    name: 'Custom Cake',
                    sizes: [],
                    variants: [],
                    pricing: {},
                  ),
                );
                return ScaleButton(
                  onTap: () => _showVoucherDialog(ord),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAE7E2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ord.orderNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Booked: ${formatDateToDDMMYY(ord.createdAt.toLocal().toString().split(' ')[0])}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF2D241E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Pickup: ${formatDateToDDMMYY(ord.deliveryDate)} @ ${formatTimeTo12Hour(ord.deliveryTime)}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Color(0xFF8C7E6A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${ord.customName.isEmpty ? 'N/A' : ord.customName} · ${item.name} (${ord.size} - ${ord.variant})',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF8C7E6A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        ScaleButton(
                          onTap: () => _showVoucherDialog(ord),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFEAE7E2),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 12,
                                  color: Color(0xFFD4A373),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Voucher',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD4A373),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D241E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                widget.setActiveTab(0); // Jump to Order Form tab
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'LOG A NEW BAKERY TICKET',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherModal(Order order, BuildContext dialogContext) {
    final item = widget.items.firstWhere(
      (i) => i.id == order.itemId,
      orElse: () => CakeItem(
        id: '',
        name: 'Custom Cake',
        sizes: [],
        variants: [],
        pricing: {},
      ),
    );

    return GestureDetector(
      onTap: () => Navigator.of(dialogContext).pop(),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // Prevent tap from bubbling up
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2D241E),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              color: Color(0xFFD4A373),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Bakery Voucher Ticket',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    ),
                  ),

              // Voucher simulated receipt
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF9F6),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: const Color(0xFFEAE7E2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header info
                        const Center(
                          child: Column(
                            children: [
                              Text(
                                'SWEET BLOOM ARTISAN BAKERY',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: Color(0xFF2D241E),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Baking Prep & Printing Ticket',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF8C7E6A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReceiptRow('Voucher No:', order.orderNumber, isMono: true),
                        _buildReceiptRow('Order Channel:', order.orderFrom),
                        _buildReceiptRow(
                          'Intake Time:',
                          '${_formatDate(order.createdAt)} - ${_formatTime(order.createdAt)}',
                        ),
                        _buildReceiptRow(
                          'Delivery Due:',
                          '${formatDateToDDMMYY(order.deliveryDate)} @ ${formatTimeTo12Hour(order.deliveryTime)}',
                        ),
                        const Divider(height: 20),
                        const Text(
                          'BAKERY ITEMS TALLY:',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8C7E6A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Main item quantity parsing
                        (() {
                          int firstQty = 1;
                          String cleanInstructions = order.specialInstructions;
                          if (cleanInstructions.contains('[Qty: ')) {
                            final startIdx = cleanInstructions.indexOf('[Qty: ') + '[Qty: '.length;
                            final endIdx = cleanInstructions.indexOf(']', startIdx);
                            if (endIdx != -1) {
                              firstQty = int.tryParse(cleanInstructions.substring(startIdx, endIdx)) ?? 1;
                              cleanInstructions = cleanInstructions
                                  .replaceRange(cleanInstructions.indexOf('[Qty: '), endIdx + 1, '')
                                  .trim();
                            }
                          }
                          return Text(
                            '• ${item.name} (${order.size} - ${order.variant}) x$firstQty',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D241E),
                            ),
                          );
                        })(),

                        // Additional items parsing
                        (() {
                          String cleanInstructions = order.specialInstructions;
                          if (cleanInstructions.contains('[Additional Items: ')) {
                            final startIdx = cleanInstructions.indexOf('[Additional Items: ') +
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
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: itemStrings.map((i) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '• $i',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D241E),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }
                          }
                          return const SizedBox.shrink();
                        })(),
                        const Divider(height: 20),
                        _buildReceiptRow(
                          'Toys Addon Cost:',
                          '${order.toysCost.toLocaleString()} MMK',
                        ),
                        _buildReceiptRow(
                          'Money Pulling:',
                          '${order.moneyPullingCost.toLocaleString()} MMK ${order.moneyPullingNote.isNotEmpty ? "(${order.moneyPullingNote})" : ""}',
                        ),
                        _buildReceiptRow(
                          'Delivery Charges:',
                          '${order.deliveryCost.toLocaleString()} MMK',
                        ),
                        _buildDashedLine(),
                        _buildReceiptRow(
                          'GRAND TOTAL:',
                          '${order.totalAmount.toLocaleString()} MMK',
                          isBold: true,
                        ),
                        _buildReceiptRow(
                          'DEPOSIT (CASH/KP):',
                          '${order.depositPaid.toLocaleString()} MMK',
                          isBold: true,
                          valueColor: Colors.green,
                        ),
                        _buildReceiptRow(
                          'REMAINING OUTSTANDING:',
                          '${order.remainingBalance.toLocaleString()} MMK',
                          isBold: true,
                          valueColor: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Reprint/Action footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFEAE7E2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Close Preview',
                        style: TextStyle(
                          color: Color(0xFF8C7E6A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  Widget _buildDashedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: List.generate(
          20,
          (i) => Expanded(
            child: Container(
              color: i % 2 == 0 ? Colors.transparent : const Color(0xFFEAE7E2),
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    bool isMono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8C7E6A)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: valueColor ?? const Color(0xFF2D241E),
              fontFamily: isMono ? 'JetBrains Mono' : null,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
