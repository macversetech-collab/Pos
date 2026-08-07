// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import '../widgets/anchored_dropdown.dart';
import '../app_theme.dart';

class CounterItem {
  final String id;
  final String itemName;
  final int unitPrice;
  final String category;

  CounterItem({
    required this.id,
    required this.itemName,
    required this.unitPrice,
    required this.category,
  });
}

class CounterRevenueEntry {
  final String id;
  final String itemId;
  final String itemName;
  final int qty;
  final int totalAmount;
  final DateTime createdAt;

  CounterRevenueEntry({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.totalAmount,
    required this.createdAt,
  });
}

class ShowlineEntry {
  final DateTime date;
  final int amount;
  ShowlineEntry({required this.date, required this.amount});
}

class CounterShowlineDashboard extends StatefulWidget {
  final bool isActive;
  final List<CakeItem> items;
  final List<CakeSize> sizes;

  const CounterShowlineDashboard({
    super.key,
    required this.isActive,
    required this.items,
    required this.sizes,
  });

  @override
  State<CounterShowlineDashboard> createState() =>
      _CounterShowlineDashboardState();
}

class _CounterShowlineDashboardState extends State<CounterShowlineDashboard> {
  int _dashboardSubTab = 0; // 0: Entry, 1: Configurator, 2: Maintenance
  bool _isLoading = true;

  // Counter & Showline Data
  List<CounterItem> _counterItems = [];
  String? _selectedCounterItemId;
  List<CounterRevenueEntry> _counterRevenueEntries = [];
  List<ShowlineEntry> _dbShowlineEntries = [];
  final List<Map<String, dynamic>> _localCounterItems = [];
  DateTime _counterDate = DateTime.now();

  // Controllers
  final TextEditingController _showlineController = TextEditingController();
  DateTime _showlineDate = DateTime.now();
  final TextEditingController _counterQtyController =
      TextEditingController(text: '1');

  final TextEditingController _configNameController = TextEditingController();
  final TextEditingController _configPriceController = TextEditingController();
  String _configCategory = 'Slice Cake';

  // Clear Month Maintenance Selection
  String _selectedPurgeMonthOption = '';

  @override
  void initState() {
    super.initState();
    _initPurgeOptions();
    fetchCounterAndShowlineData();
  }

  @override
  void didUpdateWidget(CounterShowlineDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      fetchCounterAndShowlineData();
    }
  }

  @override
  void dispose() {
    _showlineController.dispose();
    _counterQtyController.dispose();
    _configNameController.dispose();
    _configPriceController.dispose();
    super.dispose();
  }

  void _initPurgeOptions() {
    final now = DateTime.now();
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevMonthName = _getMonthName(prevMonthDate.month);

    _selectedPurgeMonthOption =
        '$prevMonthName ${prevMonthDate.year}'.toUpperCase();
  }

  String _getMonthName(int m) {
    const list = [
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
      'December'
    ];
    return list[m - 1];
  }

  Future<void> fetchCounterAndShowlineData() async {
    setState(() => _isLoading = true);
    List<CounterItem> counterItems = [];
    List<CounterRevenueEntry> counterEntries = [];
    List<ShowlineEntry> showlines = [];

    // 1. Fetch Counter configuration
    try {
      final res = await Supabase.instance.client
          .from('counter_items_config')
          .select()
          .order('item_name');
      counterItems = (res as List).map((row) {
        return CounterItem(
          id: row['id'] as String,
          itemName: row['item_name'] as String,
          unitPrice: row['unit_price'] as int,
          category: row['category'] as String? ?? 'Slice Cake',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching counter items config: $e');
    }

    // 2. Fetch Showline Entries
    try {
      final now = DateTime.now();
      final startOfMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}-01T00:00:00";
      final res =
          await Supabase.instance.client.from('showline_entries').select().gte('date', startOfMonth);
      showlines = (res as List).map((row) {
        return ShowlineEntry(
          date: DateTime.parse(row['date'] as String),
          amount: row['amount'] as int,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching showlines: $e');
      // Fallback mocks
      showlines = [
        ShowlineEntry(date: DateTime(2026, 6, 30), amount: 15000),
        ShowlineEntry(date: DateTime(2026, 6, 28), amount: 25000),
      ];
    }

    // 3. Fetch Counter Revenue Entries
    try {
      final now = DateTime.now();
      final startOfMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}-01T00:00:00";
      final res = await Supabase.instance.client
          .from('counter_cake_revenue_entries')
          .select()
          .gte('created_at', startOfMonth);
      counterEntries = (res as List).map((row) {
        return CounterRevenueEntry(
          id: row['id'] as String,
          itemId: row['item_id'] as String,
          itemName: row['item_name'] as String,
          qty: row['qty'] as int,
          totalAmount: row['total_amount'] as int,
          createdAt: DateTime.parse(row['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching counter cake entries: $e');
    }

    setState(() {
      _counterItems = counterItems;
      _dbShowlineEntries = showlines;
      _counterRevenueEntries = counterEntries;
      _isLoading = false;
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  // Segmented Tab Selector Builder
  Widget _buildSubTabSelector() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabSelectorItem(0, 'Revenue Entries', Icons.receipt_long_outlined),
            _buildTabSelectorItem(1, 'Product Config', Icons.restaurant_menu_outlined),
            _buildTabSelectorItem(2, 'Maintenance', Icons.cleaning_services_outlined),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelectorItem(int index, String label, IconData icon) {
    final bool isSelected = _dashboardSubTab == index;
    return GestureDetector(
      onTap: () => setState(() => _dashboardSubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF2D241E) : const Color(0xFF8C7E6A),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF2D241E) : const Color(0xFF8C7E6A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dashboard Main Body
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubTabSelector(),
              const SizedBox(height: 16),
              if (_dashboardSubTab == 0)
                _buildEntryView()
              else if (_dashboardSubTab == 1)
                _buildConfiguratorView()
              else
                _buildDataMaintenanceView(),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 0: Entry Form & Revenue Tables View
  Widget _buildEntryView() {
    final now = DateTime.now();

    // 1. Showline filtering & accumulation
    List<ShowlineEntry> todayShowlines = _dbShowlineEntries.where((e) {
      return e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day;
    }).toList();

    List<ShowlineEntry> monthShowlines = _dbShowlineEntries.where((e) {
      return e.date.year == now.year && e.date.month == now.month;
    }).toList();

    int showlineTodaySum = todayShowlines.fold(0, (sum, e) => sum + e.amount);
    int showlineMonthSum = monthShowlines.fold(0, (sum, e) => sum + e.amount);

    // 2. Counter Cake filtering & accumulation
    List<CounterRevenueEntry> todayCounter = _counterRevenueEntries.where((e) {
      final local = e.createdAt.toLocal();
      return local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
    }).toList();

    List<CounterRevenueEntry> monthCounter = _counterRevenueEntries.where((e) {
      final local = e.createdAt.toLocal();
      return local.year == now.year && local.month == now.month;
    }).toList();

    int counterTodaySum = todayCounter.fold(0, (sum, e) => sum + e.totalAmount);
    int counterMonthSum = monthCounter.fold(0, (sum, e) => sum + e.totalAmount);

    final showlineForm = Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Showline Revenue Entry',
            style: TextStyle(
              color: Color(0xFF2D241E),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _showlineController,
            keyboardType: TextInputType.number,
            decoration: AppDecorations.input(
              labelText: 'Showline Input Amount',
              hintText: 'e.g. 5000',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEAE7E2), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8C7E6A)),
                  label: Text(
                    'Date: ${_formatDate(_showlineDate)}',
                    style: const TextStyle(
                      color: Color(0xFF2D241E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _showlineDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2028),
                    );
                    if (picked != null) {
                      setState(() => _showlineDate = picked);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D241E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final val = _showlineController.text;
                  final amt = int.tryParse(val) ?? 0;
                  if (amt > 0) {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await Supabase.instance.client.from('showline_entries').insert({
                        'date': _showlineDate.toIso8601String(),
                        'amount': amt,
                      });
                      _showlineController.clear();
                      setState(() {
                        _showlineDate = DateTime.now();
                      });
                      fetchCounterAndShowlineData();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Showline entry added successfully!')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Database error: $e')),
                      );
                    }
                  }
                },
                child: const Text(
                  'Add Entry',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final counterForm = Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Counter Cake Revenue Entry (EOD Summary)',
            style: TextStyle(
              color: Color(0xFF2D241E),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AnchoredDropdown<String>(
                  value: _selectedCounterItemId,
                  hint: const Text('Select Product'),
                  decoration: AppDecorations.input(),
                  onChanged: (val) => setState(() => _selectedCounterItemId = val),
                  items: _counterItems.map((opt) {
                    return DropdownMenuItem(
                      value: opt.id,
                      child: Text(opt.itemName),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _counterQtyController,
                  keyboardType: TextInputType.number,
                  decoration: AppDecorations.input(labelText: 'Qty'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D241E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final itemId = _selectedCounterItemId;
                  final qty = int.tryParse(_counterQtyController.text) ?? 0;

                  if (itemId == null || qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a product and enter quantity.')),
                    );
                    return;
                  }

                  final product = _counterItems.firstWhere((i) => i.id == itemId);
                  final total = product.unitPrice * qty;

                  setState(() {
                    final existingIdx = _localCounterItems.indexWhere((item) => item['id'] == itemId);
                    if (existingIdx != -1) {
                      _localCounterItems[existingIdx]['qty'] += qty;
                      _localCounterItems[existingIdx]['total'] = _localCounterItems[existingIdx]['qty'] * product.unitPrice;
                    } else {
                      _localCounterItems.add({
                        'id': product.id,
                        'name': product.itemName,
                        'unitPrice': product.unitPrice,
                        'qty': qty,
                        'total': total,
                      });
                    }
                    _selectedCounterItemId = null;
                    _counterQtyController.text = '1';
                  });
                },
                child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (_localCounterItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Accumulated Daily Session Items:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8C7E6A),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localCounterItems.length,
              itemBuilder: (context, index) {
                final item = _localCounterItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item['name']} x${item['qty']} (${(item['unitPrice'] as int).toLocaleString()} MMK)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF2D241E)),
                        ),
                      ),
                      Text(
                        '${(item['total'] as int).toLocaleString()} MMK',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D241E),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 16),
                        onPressed: () {
                          setState(() {
                            _localCounterItems.removeAt(index);
                          });
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Session Grand Total:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D241E)),
                ),
                Text(
                  '${_localCounterItems.fold<int>(0, (sum, item) => sum + (item['total'] as int)).toLocaleString()} MMK',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2D241E)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFEAE7E2), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.calendar_today, size: 14, color: Color(0xFF8C7E6A)),
                    label: Text(
                      'Session Date: ${_formatDate(_counterDate)}',
                      style: const TextStyle(
                        color: Color(0xFF2D241E),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _counterDate,
                        firstDate: DateTime(2025),
                        lastDate: DateTime(2028),
                      );
                      if (picked != null) {
                        setState(() => _counterDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final int combinedQty = _localCounterItems.fold(0, (sum, item) => sum + (item['qty'] as int));
                    final int combinedTotal = _localCounterItems.fold(0, (sum, item) => sum + (item['total'] as int));

                    try {
                      await Supabase.instance.client
                          .from('counter_cake_revenue_entries')
                          .insert({
                            'id': 'cre-${DateTime.now().millisecondsSinceEpoch}',
                            'item_id': _localCounterItems.first['id'],
                            'item_name': 'Daily Counter Bulk Total',
                            'qty': combinedQty,
                            'total_amount': combinedTotal,
                            'created_at': _counterDate.toUtc().toIso8601String(),
                          });

                      setState(() {
                        _localCounterItems.clear();
                        _counterDate = DateTime.now();
                      });
                      fetchCounterAndShowlineData();

                      messenger.showSnackBar(
                        const SnackBar(content: Text('Daily counter bulk total saved successfully!')),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Database error: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'Counter Cake Revenue Entry (EOD Summary)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 800;

        return Column(
          children: [
            // Revenue Cards Row (Monthly Totals only)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'MONTHLY SHOWLINE REVENUE TOTAL',
                    value: '${showlineMonthSum.toLocaleString()} MMK',
                    subtext: 'From the 1st of this month',
                    icon: Icons.trending_up,
                    color: const Color(0xFF2D241E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'MONTHLY COUNTER CAKE SALES TOTAL',
                    value: '${counterMonthSum.toLocaleString()} MMK',
                    subtext: 'From the 1st of this month',
                    icon: Icons.storefront,
                    color: const Color(0xFFD4A373),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: showlineForm),
                  const SizedBox(width: 16),
                  Expanded(child: counterForm),
                ],
              )
            else ...[
              showlineForm,
              const SizedBox(height: 16),
              counterForm,
            ],
            const SizedBox(height: 16),
            
            // Bottom Section: Today's Detailed Record Lists
            LayoutBuilder(
              builder: (context, auditConstraints) {
                final bool isAuditWide = auditConstraints.maxWidth > 700;

                final Widget showlineAuditList = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.container(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Showline Log",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D241E),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D241E).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Total: ${showlineTodaySum.toLocaleString()} MMK',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D241E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      if (todayShowlines.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No showline entries logged today.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todayShowlines.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final entry = todayShowlines[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Showline Entry',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D241E),
                                    ),
                                  ),
                                  Text(
                                    '${entry.amount.toLocaleString()} MMK',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D241E),
                                      fontFamily: 'JetBrains Mono',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );

                final Widget counterAuditList = Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.container(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Counter Cake Log",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D241E),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4A373).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Total: ${counterTodaySum.toLocaleString()} MMK',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4A373),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      if (todayCounter.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No counter cake entries logged today.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todayCounter.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final entry = todayCounter[index];
                            final localTime = entry.createdAt.toLocal();
                            final formattedTime =
                                '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.itemName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D241E),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${entry.totalAmount.toLocaleString()} MMK',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D241E),
                                          fontFamily: 'JetBrains Mono',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '($formattedTime)',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.grey,
                                          fontFamily: 'JetBrains Mono',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );

                if (isAuditWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: showlineAuditList),
                      const SizedBox(width: 16),
                      Expanded(child: counterAuditList),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      showlineAuditList,
                      const SizedBox(height: 16),
                      counterAuditList,
                    ],
                  );
                }
              },
            ),
          ],
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.shade900.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.shade300, width: 1),
            ),
            child: Icon(icon, color: Colors.amber.shade900, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade900.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.amber.shade800.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // TAB 1: Product Configurator View
  Widget _buildConfiguratorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Boutique Counter Products Configurator',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2D241E)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Define boutique cake products sold over the counter and set standard end-of-day unit prices',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // Config fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _configNameController,
                  decoration: AppDecorations.input(labelText: 'Item Name *', hintText: 'e.g. Cheese Lava Slice'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _configPriceController,
                  keyboardType: TextInputType.number,
                  decoration: AppDecorations.input(labelText: 'Unit Price *', hintText: 'e.g. 8000'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: AnchoredDropdown<String>(
                  value: _configCategory,
                  decoration: AppDecorations.input(labelText: 'Category'),
                  onChanged: (val) => setState(() => _configCategory = val ?? 'Slice Cake'),
                  items: ['Slice Cake', 'Whole Cake', 'Boutique Bread', 'Cookies'].map((opt) {
                    return DropdownMenuItem(value: opt, child: Text(opt));
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D241E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = _configNameController.text.trim();
                  final price = int.tryParse(_configPriceController.text) ?? 0;

                  if (name.isEmpty || price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid product name and price.')),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await Supabase.instance.client.from('counter_items_config').insert({
                      'id': 'cic-${DateTime.now().millisecondsSinceEpoch}',
                      'item_name': name,
                      'unit_price': price,
                      'category': _configCategory,
                    });
                    _configNameController.clear();
                    _configPriceController.clear();
                    fetchCounterAndShowlineData();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Boutique product added successfully!')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Database error: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),

          // Config list
          if (_counterItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text(
                  'No boutique products configured yet. Add products above.',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _counterItems.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final prod = _counterItems[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    prod.itemName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2D241E)),
                  ),
                  subtitle: Text(
                    'Category: ${prod.category}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${prod.unitPrice.toLocaleString()} MMK',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D241E),
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await Supabase.instance.client
                                .from('counter_items_config')
                                .delete()
                                .eq('id', prod.id);
                            fetchCounterAndShowlineData();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Boutique product deleted successfully!')),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Database error: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // TAB 2: Clear Month View
  Widget _buildDataMaintenanceView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Boutique Sales Maintenance',
            style: TextStyle(
              color: Color(0xFF2D241E),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Purge Counter Cake and Showline records month-by-month for archive maintenance.',
            style: TextStyle(color: Color(0xFF8C7E6A), fontSize: 11),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AnchoredDropdown<String>(
                  value: _selectedPurgeMonthOption,
                  decoration: AppDecorations.input(
                    labelText: 'Select Month to Purge',
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPurgeMonthOption = val);
                    }
                  },
                  items: (() {
                    final now = DateTime.now();
                    final currentLabel =
                        '${_getMonthName(now.month)} ${now.year}'.toUpperCase();
                    final prevDate = DateTime(now.year, now.month - 1, 1);
                    final prevLabel =
                        '${_getMonthName(prevDate.month)} ${prevDate.year}'
                            .toUpperCase();
                    return [currentLabel, prevLabel].map((opt) {
                      return DropdownMenuItem(value: opt, child: Text(opt));
                    }).toList();
                  })(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _confirmPurgeMonth(context),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text(
                  'Purge Selected Month',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPurgeMonth(BuildContext context) async {
    final String monthString = _selectedPurgeMonthOption;
    final parts = monthString.split(' ');
    if (parts.length != 2) return;

    final String monthName = parts[0];
    final int targetYear = int.tryParse(parts[1]) ?? DateTime.now().year;
    
    const monthNamesList = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    final int targetMonth = monthNamesList.indexOf(monthName) + 1;
    if (targetMonth == 0) return;

    final confirmTextController = TextEditingController();

    final bool? deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final String inputVal = confirmTextController.text.trim();
            final bool isValid = inputVal == monthString;

            return AlertDialog(
              backgroundColor: const Color(0xFFFFFDF9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Double Confirmation Lock',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        'WARNING: This will permanently delete ALL data for $monthString across Counter Cake and Showline tables. Vouchers are completely untouched. This action cannot be undone.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please type "$monthString" in UPPERCASE to unlock deletion:',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF2D241E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: confirmTextController,
                      autofocus: true,
                      decoration: AppDecorations.input(
                        hintText: monthString,
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF8C7E6A),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? Colors.red : Colors.grey.shade300,
                    foregroundColor: isValid ? Colors.white : Colors.grey.shade600,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onPressed: isValid ? () => Navigator.of(context).pop(true) : null,
                  child: const Text(
                    'Confirm Delete',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (deleted == true && context.mounted) {
      final DateTime startLocal = DateTime(targetYear, targetMonth, 1, 0, 0, 0);
      final DateTime endLocal = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59, 999);

      final String startUtcStr = startLocal.toUtc().toIso8601String();
      final String endUtcStr = endLocal.toUtc().toIso8601String();

      final String startLocalStr = startLocal.toIso8601String();
      final String endLocalStr = endLocal.toIso8601String();

      final messenger = ScaffoldMessenger.of(context);

      try {
        // Delete from counter_cake_revenue_entries
        final counterRes = await Supabase.instance.client
            .from('counter_cake_revenue_entries')
            .delete()
            .gte('created_at', startUtcStr)
            .lte('created_at', endUtcStr)
            .select();
            
        // Delete from showline_entries
        final showlineRes = await Supabase.instance.client
            .from('showline_entries')
            .delete()
            .gte('date', startLocalStr)
            .lte('date', endLocalStr)
            .select();

        final int deletedCounter = (counterRes as List).length;
        final int deletedShowline = (showlineRes as List).length;
        final int totalDeleted = deletedCounter + deletedShowline;

        // Refresh UI immediately
        await fetchCounterAndShowlineData();

        if (totalDeleted > 0) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Purged $totalDeleted boutique records for $monthString successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('No records were deleted. If data is still showing, please verify that DELETE policies are enabled in your Supabase SQL editor.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 7),
            ),
          );
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error purging boutique data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
