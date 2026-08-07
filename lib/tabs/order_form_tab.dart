import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';
import '../services/order_repository.dart';
import '../models.dart';
import '../widgets/scale_button.dart';
import '../widgets/anchored_dropdown.dart';

class OrderEntryFormTab extends StatefulWidget {
  final List<CakeItem> items;
  final List<CakeSize> sizes;
  final Order? initialOrder;
  final Future<void> Function(Order) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onReset;

  const OrderEntryFormTab({
    super.key,
    required this.items,
    required this.sizes,
    this.initialOrder,
    required this.onSubmit,
    required this.onCancel,
    this.onReset,
  });

  @override
  State<OrderEntryFormTab> createState() => _OrderEntryFormTabState();
}

class _OrderEntryFormTabState extends State<OrderEntryFormTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isTotalExpanded = false;
  bool _isSubmitting = false;

  Timer? _draftDebounce;

  void _scheduleDraftSave() {
    if (_draftDebounce?.isActive ?? false) _draftDebounce!.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveDraft();
    });
  }

  void _saveDraft() {
    // Only save draft if it's a new order (not editing)
    if (widget.initialOrder != null) return;
    
    final draftData = {
      '_id': _id,
      '_orderNumber': _orderNumber,
      '_deliveryDate': _deliveryDate,
      '_deliveryTime': _deliveryTime,
      '_itemId': _itemId,
      '_selectedSize': _selectedSize,
      '_selectedVariant': _selectedVariant,
      '_designCode': _designCode,
      '_customName': _customName,
      '_customAge': _customAge,
      '_customDate': _customDate,
      '_customLettering': _customLettering,
      '_specialInstructions': _specialInstructions,
      '_customerPhone': _customerPhone,
      '_paymentStatus': _paymentStatus,
      '_depositPaid': _depositPaid,
      '_isKpay': _isKpay,
      '_orderFrom': _orderFrom,
      '_designFrom': _designFrom,
      '_deliveryCost': _deliveryCost,
      '_orderedItems': _orderedItems.map((item) => item.toMap()).toList(),
    };
    OrderRepository().saveDraft(draftData);
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    super.dispose();
  }


  late String _id;
  late String _orderNumber;
  late String _deliveryDate;
  late String _deliveryTime;
  late String _itemId;
  late String _selectedSize;
  late String _selectedVariant;
  late String _designCode;
  late String _customName;
  late String _customAge;
  late String _customDate;
  late String _customLettering;
  late String _specialInstructions;
  late String _customerPhone;
  late String _paymentStatus;
  late int _depositPaid;
  late bool _isKpay;
  late String _orderFrom;
  String? _designFrom;
  List<FormOrderItem> _orderedItems = [];

  // Global delivery configuration
  late int _deliveryCost;

  bool _isOptionalExpanded = false;

  // Cache for variants fetched from the dedicated 'variants' table
  // Key: "itemId:size" -> List of variant records {name, price, ...}
  final Map<String, List<Map<String, dynamic>>> _variantCache = {};

  @override
  void initState() {
    super.initState();
    _resetForm();
    _prefetchVariants();
  }

  /// Pre-fetches variants for any pre-populated ordered items (edit mode).
  void _prefetchVariants() {
    for (var orderedItem in _orderedItems) {
      if (orderedItem.itemId.isNotEmpty && orderedItem.size.isNotEmpty) {
        _fetchVariants(orderedItem.itemId, orderedItem.size);
      }
    }
    calculateTotalPrice();
  }

  /// Fetches variants from the dedicated 'variants' table,
  /// filtered by item_id and size. Results are cached.
  Future<List<Map<String, dynamic>>> _fetchVariants(
    String itemId,
    String size,
  ) async {
    final cacheKey = '$itemId:$size';
    if (_variantCache.containsKey(cacheKey)) {
      return _variantCache[cacheKey]!;
    }
    try {
      final res = await Supabase.instance.client
          .from('variants')
          .select()
          .eq('item_id', itemId)
          .eq('size', size);
      final results = List<Map<String, dynamic>>.from(res as List);
      setState(() {
        _variantCache[cacheKey] = results;
      });
      return results;
    } catch (e) {
      debugPrint('Error fetching variants for $itemId/$size: $e');
      return [];
    }
  }

  @override
  void didUpdateWidget(OrderEntryFormTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOrder != oldWidget.initialOrder) {
      _resetForm();
    }
  }

  int _itemBasePrice = 0;

  void _syncMainFieldsFromOrderedItems() {
    if (_orderedItems.isNotEmpty) {
      _selectedSize = _orderedItems[0].size;
      _itemId = _orderedItems[0].itemId;
      _selectedVariant = _orderedItems[0].variant;
      _designCode = _orderedItems[0].designCode;
      _designFrom = _orderedItems[0].designFrom;
      _orderFrom = _orderedItems[0].orderFrom;
    } else {
      _selectedSize = '';
      _itemId = '';
      _selectedVariant = '';
      _designCode = '';
      _designFrom = null;
      _orderFrom = 'Walk-In';
    }
  }

  void calculateTotalPrice() {
    _scheduleDraftSave();
    int totalBasePrice = 0;
    for (var orderedItem in _orderedItems) {
      if (orderedItem.size.isNotEmpty && orderedItem.itemId.isNotEmpty) {
        final selectedItem = widget.items.firstWhere(
          (i) => i.id == orderedItem.itemId,
          orElse: () =>
              CakeItem(id: '', name: '', sizes: [], variants: [], pricing: {}),
        );

        int foundPrice = 0;

        // 1) Check variant-table price first
        final variantCacheKey = '${orderedItem.itemId}:${orderedItem.size}';
        final cachedVariants = _variantCache[variantCacheKey] ?? [];
        final matchedVariant = cachedVariants
            .where((v) => v['name'] == orderedItem.variant)
            .toList();
        if (matchedVariant.isNotEmpty &&
            matchedVariant.first['price'] != null) {
          foundPrice = matchedVariant.first['price'] as int;
        } else {
          // 2) Fallback to cake_items.pricing map
          final key = '${orderedItem.size}:${orderedItem.variant}';
          if (selectedItem.pricing.containsKey(key)) {
            foundPrice = selectedItem.pricing[key] ?? 0;
          } else {
            // 3) Last resort: first key matching the size
            final fallbackKey = selectedItem.pricing.keys.firstWhere(
              (k) => k.startsWith('${orderedItem.size}:'),
              orElse: () => '',
            );
            if (fallbackKey.isNotEmpty) {
              foundPrice = selectedItem.pricing[fallbackKey] ?? 0;
            }
          }
        }
        totalBasePrice += foundPrice * orderedItem.quantity;
      }
    }
    setState(() {
      _itemBasePrice = totalBasePrice;
    });
    _syncMainFieldsFromOrderedItems();
  }

  void _resetForm() {
    if (widget.initialOrder != null) {
      final o = widget.initialOrder!;
      _id = o.id;
      _orderNumber = o.orderNumber;
      _deliveryDate = o.deliveryDate;
      _deliveryTime = o.deliveryTime;
      _itemId = o.itemId;
      _selectedSize = o.size;
      _selectedVariant = o.variant;
      _designCode = o.designCode;
      _customName = o.customName;
      _customAge = o.customAge;
      _customDate = o.customDate;
      _customLettering = o.customLettering;
      _specialInstructions = o.specialInstructions;

      int firstQty = 1;
      if (_specialInstructions.contains('[Qty: ')) {
        final startIdx =
            _specialInstructions.indexOf('[Qty: ') + '[Qty: '.length;
        final endIdx = _specialInstructions.indexOf(']', startIdx);
        if (endIdx != -1) {
          firstQty =
              int.tryParse(_specialInstructions.substring(startIdx, endIdx)) ??
              1;
          _specialInstructions = _specialInstructions
              .replaceRange(
                _specialInstructions.indexOf('[Qty: '),
                endIdx + 1,
                '',
              )
              .trim();
        }
      }

      _orderedItems = [
        FormOrderItem(
          size: o.size,
          itemId: o.itemId,
          variant: o.variant,
          quantity: firstQty,
        ),
      ];

      if (_specialInstructions.contains('[Additional Items: ')) {
        final startIdx =
            _specialInstructions.indexOf('[Additional Items: ') +
            '[Additional Items: '.length;
        int bracketCount = 1;
        int endIdx = -1;
        for (int i = startIdx; i < _specialInstructions.length; i++) {
          if (_specialInstructions[i] == '[') {
            bracketCount++;
          } else if (_specialInstructions[i] == ']') {
            bracketCount--;
          }

          if (bracketCount == 0) {
            endIdx = i;
            break;
          }
        }
        if (endIdx != -1) {
          final itemsPart = _specialInstructions.substring(startIdx, endIdx);
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
                String designCode = '';
                String? designFrom;
                String orderFrom = 'Walk-In';
                int itemToysCost = 0;
                int itemMoneyPullingCost = 0;
                String itemMoneyPullingNote = '';
                String itemMoneyPullingSelection = 'None';

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
                      } else if (tag.startsWith('Channel: ')) {
                        orderFrom = tag.substring('Channel: '.length);
                      } else if (tag.startsWith('ToysCost: ')) {
                        itemToysCost =
                            int.tryParse(tag.substring('ToysCost: '.length)) ??
                            0;
                      } else if (tag.startsWith('MoneyPullingCost: ')) {
                        itemMoneyPullingCost =
                            int.tryParse(
                              tag.substring('MoneyPullingCost: '.length),
                            ) ??
                            0;
                      } else if (tag.startsWith('MoneyPullingNote: ')) {
                        itemMoneyPullingNote = tag.substring(
                          'MoneyPullingNote: '.length,
                        );
                      }
                    }
                  }
                } else {
                  qty = int.tryParse(qtyPart) ?? 1;
                }

                if (itemMoneyPullingCost == 0) {
                  itemMoneyPullingSelection = 'None';
                } else if (itemMoneyPullingCost == 5000) {
                  itemMoneyPullingSelection = '5,000 MMK';
                } else if (itemMoneyPullingCost == 10000) {
                  itemMoneyPullingSelection = '10,000 MMK';
                } else if (itemMoneyPullingCost == 20000) {
                  itemMoneyPullingSelection = '20,000 MMK';
                } else {
                  itemMoneyPullingSelection = 'Other';
                }

                final specParts = specs.split(' - ');
                final size = specParts[0];
                final variant = specParts.length > 1 ? specParts[1] : '';

                final matchedCake = widget.items.firstWhere(
                  (i) => i.name.trim().toLowerCase() == name.toLowerCase(),
                  orElse: () => CakeItem(
                    id: '',
                    name: '',
                    sizes: [],
                    variants: [],
                    pricing: {},
                  ),
                );

                _orderedItems.add(
                  FormOrderItem(
                    size: size,
                    itemId: matchedCake.id,
                    variant: variant,
                    quantity: qty,
                    designCode: designCode,
                    designFrom: designFrom,
                    orderFrom: orderFrom,
                    toysCost: itemToysCost,
                    moneyPullingCost: itemMoneyPullingCost,
                    moneyPullingSelection: itemMoneyPullingSelection,
                    moneyPullingNote: itemMoneyPullingNote,
                  ),
                );
              }
            }
          }
          _specialInstructions = _specialInstructions
              .replaceRange(
                _specialInstructions.indexOf('[Additional Items: '),
                endIdx + 1,
                '',
              )
              .trim();
        }
      }

      if (_specialInstructions.contains('[Design From: ')) {
        final startIdx =
            _specialInstructions.indexOf('[Design From: ') +
            '[Design From: '.length;
        final endIdx = _specialInstructions.indexOf(']', startIdx);
        if (endIdx != -1) {
          _designFrom = _specialInstructions.substring(startIdx, endIdx);
          _specialInstructions = _specialInstructions
              .replaceRange(
                _specialInstructions.indexOf('[Design From: '),
                endIdx + 1,
                '',
              )
              .trim();
        } else {
          _designFrom = null;
        }
      } else {
        _designFrom = null;
      }
      if (_orderedItems.isNotEmpty) {
        _orderedItems[0].designCode = o.designCode;
        _orderedItems[0].designFrom = _designFrom;
        _orderedItems[0].orderFrom = o.orderFrom;
        _orderedItems[0].toysCost = o.toysCost;
        _orderedItems[0].moneyPullingCost = o.moneyPullingCost;
        _orderedItems[0].moneyPullingNote = o.moneyPullingNote;

        String selection = 'None';
        if (o.moneyPullingCost == 5000) {
          selection = '5,000 MMK';
        } else if (o.moneyPullingCost == 10000) {
          selection = '10,000 MMK';
        } else if (o.moneyPullingCost == 20000) {
          selection = '20,000 MMK';
        } else if (o.moneyPullingCost > 0) {
          selection = 'Other';
        }
        _orderedItems[0].moneyPullingSelection = selection;
      }
      _customerPhone = o.customerPhone;
      _paymentStatus = o.paymentStatus;
      _depositPaid = o.depositPaid;
      _isKpay = o.isKpay;
      _orderFrom = o.orderFrom;
      _deliveryCost = o.deliveryCost;

      debugPrint('DEBUG OrderForm _resetForm mapped: size="${o.size}", phone="${o.customerPhone}", lettering="${o.customLettering}", instructions="${o.specialInstructions}"');
      debugPrint('DEBUG OrderForm State after _resetForm: size="$_selectedSize", phone="$_customerPhone", lettering="$_customLettering", instructions="$_specialInstructions"');
    } else {
      final draftData = OrderRepository().getDraft();
      if (draftData != null) {
        _id = draftData['_id'] ?? '';
        _orderNumber = draftData['_orderNumber'] ?? '';
        _deliveryDate = draftData['_deliveryDate'] ?? '';
        _deliveryTime = draftData['_deliveryTime'] ?? '';
        _itemId = draftData['_itemId'] ?? '';
        _selectedSize = draftData['_selectedSize'] ?? '';
        _selectedVariant = draftData['_selectedVariant'] ?? '';
        _designCode = draftData['_designCode'] ?? '';
        _customName = draftData['_customName'] ?? '';
        _customAge = draftData['_customAge'] ?? '';
        _customDate = draftData['_customDate'] ?? '';
        _customLettering = draftData['_customLettering'] ?? '';
        _specialInstructions = draftData['_specialInstructions'] ?? '';
        _customerPhone = draftData['_customerPhone'] ?? '';
        _paymentStatus = draftData['_paymentStatus'] ?? 'unpaid';
        _depositPaid = draftData['_depositPaid'] ?? 0;
        _isKpay = draftData['_isKpay'] ?? false;
        _orderFrom = draftData['_orderFrom'] ?? 'Walk-In';
        _designFrom = draftData['_designFrom'];
        _deliveryCost = draftData['_deliveryCost'] ?? 0;
        
        final itemsList = draftData['_orderedItems'] as List<dynamic>?;
        if (itemsList != null) {
          _orderedItems = itemsList.map((m) => FormOrderItem.fromMap(Map<String, dynamic>.from(m as Map))).toList();
        }
      } else {
        final now = DateTime.now();
        _id = 'ord-${now.millisecondsSinceEpoch}';
      _orderNumber = '';
      _deliveryDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final hour = now.hour;
      final minute = now.minute;
      final roundedMinute = minute < 15 ? 0 : (minute < 45 ? 30 : 0);
      final finalHour = minute >= 45 ? (hour + 1) % 24 : hour;
      _deliveryTime =
          "${finalHour.toString().padLeft(2, '0')}:${roundedMinute.toString().padLeft(2, '0')}";
      _itemId = '';
      _selectedSize = '';
      _selectedVariant = '';
      _orderedItems = [
        FormOrderItem(
          size: '',
          itemId: '',
          variant: '',
          quantity: 1,
          designCode: '',
          designFrom: null,
          orderFrom: 'Walk-In',
        ),
      ];
      _designCode = '';
      _designFrom = null;
      _customName = '';
      _customAge = '';
      _customDate = '';
      _customLettering = '';
      _specialInstructions = '';
      _customerPhone = '';
      _paymentStatus = 'deposit';
      _depositPaid = 0;
      _isKpay = false;
      _orderFrom = 'Walk-In';
      _deliveryCost = 0;
      }
    }
    calculateTotalPrice();
  }

  int _calculateLiveTotal() {
    int total = _itemBasePrice;
    for (var item in _orderedItems) {
      total += item.toysCost;
      total += (item.moneyPullingSelection == 'None'
          ? 0
          : item.moneyPullingCost);
    }
    total += _deliveryCost;
    return total;
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 12,
              left: 12,
              right: 12,
              bottom: 4,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.tealMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: AppColors.tealMain.withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.tealMain, size: 18),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: AppDecorations.container(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 12,
              left: 12,
              right: 12,
              bottom: 4,
            ),
            child: ScaleButton(
              onTap: () {
                setState(() {
                  _isOptionalExpanded = !_isOptionalExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tealMain.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(
                    color: AppColors.tealMain.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.tealMain, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            title.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.tealDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.tealMain,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _isOptionalExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.tealMain,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
            crossFadeState: _isOptionalExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String text, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF8C7E6A),
              letterSpacing: 0.5,
            ),
          ),
          if (suffix != null)
            Text(
              suffix,
              style: const TextStyle(
                fontSize: 9.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF8C7E6A),
              ),
            ),
        ],
      ),
    );
  }

  void _showDepositBottomSheet(BuildContext context, int liveTotal) {
    int tempDeposit = _depositPaid;
    bool tempIsKpay = _isKpay;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF7F5F2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter Deposit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D241E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: $liveTotal MMK',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF78909C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: tempDeposit > 0 ? tempDeposit.toString() : '',
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: AppDecorations.input(
                        labelText: 'Deposit Amount (MMK)',
                      ),
                      onChanged: (val) {
                        tempDeposit = int.tryParse(val) ?? 0;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => tempIsKpay = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !tempIsKpay ? const Color(0xFF00796B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00796B)),
                              ),
                              child: Text(
                                'Cash',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !tempIsKpay ? Colors.white : const Color(0xFF00796B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setModalState(() => tempIsKpay = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: tempIsKpay ? const Color(0xFF00796B) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00796B)),
                              ),
                              child: Text(
                                'Kpay',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: tempIsKpay ? Colors.white : const Color(0xFF00796B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D241E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _depositPaid = tempDeposit;
                          _paymentStatus = 'deposit';
                          _isKpay = tempIsKpay;
                        });
                        calculateTotalPrice();
                        _scheduleDraftSave();
                        Navigator.pop(sheetContext);
                      },
                      child: const Text(
                        'Save Deposit',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFullyPaidDialog(BuildContext context, int liveTotal) {
    bool tempIsKpay = _isKpay;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFFF7F5F2),
              title: const Text(
                'Fully Paid',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D241E)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Mark order as fully paid? Total is $liveTotal MMK.',
                    style: const TextStyle(color: Color(0xFF2D241E)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => tempIsKpay = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !tempIsKpay ? const Color(0xFF00796B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00796B)),
                            ),
                            child: Text(
                              'Cash',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !tempIsKpay ? Colors.white : const Color(0xFF00796B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => tempIsKpay = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: tempIsKpay ? const Color(0xFF00796B) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF00796B)),
                            ),
                            child: Text(
                              'Kpay',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: tempIsKpay ? Colors.white : const Color(0xFF00796B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF78909C))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D241E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    setState(() {
                      _paymentStatus = 'fully_paid';
                      _depositPaid = liveTotal;
                      _isKpay = tempIsKpay;
                    });
                    calculateTotalPrice();
                    _scheduleDraftSave();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 380;

    int liveTotal = _calculateLiveTotal();
    if (_paymentStatus == 'fully_paid') {
      _depositPaid = liveTotal;
    }
    int liveRemaining = liveTotal - _depositPaid;

    // Adaptive Input rows
    Widget collectionDateWidget = InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.parse(_deliveryDate),
          firstDate: DateTime(2025),
          lastDate: DateTime(2028),
        );
        if (picked != null) {
          setState(() {
            _deliveryDate =
                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
          });
        }
      },
      child: InputDecorator(
        decoration: AppDecorations.input(labelText: 'Collection Date *'),
        child: Text(formatDateToDDMMYY(_deliveryDate)),
      ),
    );

    Widget collectionTimeWidget = InkWell(
      onTap: () async {
        List<String> parts = _deliveryTime.split(':');
        TimeOfDay initial = parts.length == 2
            ? TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]))
            : const TimeOfDay(hour: 12, minute: 0);
        TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) {
          setState(() {
            _deliveryTime =
                "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
          });
        }
      },
      child: InputDecorator(
        decoration: AppDecorations.input(labelText: 'Collection Time *'),
        child: Text(formatTimeTo12Hour(_deliveryTime)),
      ),
    );

    return KeyedSubtree(
      key: ValueKey(_id),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        onChanged: _scheduleDraftSave,
        child: Stack(
          children: [
            // Scrollable form content
            Listener(
              onPointerDown: (_) {
                if (_isTotalExpanded) {
                  setState(() => _isTotalExpanded = false);
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 160.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App title indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.initialOrder != null
                              ? 'Edit Cake Order'
                              : 'New Cake Order',
                          style: const TextStyle(
                            color: Color(0xFF2D241E),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _orderNumber,
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8C7E6A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CARD 1: ESSENTIAL SPECS
                  _buildCard(
                    title: '1. Essential Specs',
                    icon: Icons.assignment_outlined,
                    children: [
                      if (isCompact) ...[
                        collectionDateWidget,
                        const SizedBox(height: 12),
                        collectionTimeWidget,
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: collectionDateWidget),
                            const SizedBox(width: 12),
                            Expanded(child: collectionTimeWidget),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Column(
                        children: List.generate(_orderedItems.length, (index) {
                          final item = _orderedItems[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              border: Border.all(
                                color: const Color(0xFFEAE7E2),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Item #${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: Color(0xFF2D241E),
                                      ),
                                    ),
                                    if (index > 0)
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _orderedItems.removeAt(index);
                                          });
                                          calculateTotalPrice();
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                AnchoredDropdown<String>(
                                  initialValue: item.size.isNotEmpty
                                      ? item.size
                                      : null,
                                  decoration: AppDecorations.input(
                                    labelText: 'Size *',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Size is required';
                                    }
                                    return null;
                                  },
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        item.size = val;
                                      });
                                      if (item.itemId.isNotEmpty) {
                                        _fetchVariants(item.itemId, val).then((fetched) {
                                          if (mounted) {
                                            setState(() {
                                              bool variantExists = fetched.any((v) => v['variant_name'] == item.variant);
                                              if (!variantExists) {
                                                item.variant = '';
                                              }
                                              calculateTotalPrice();
                                            });
                                          }
                                        });
                                      } else {
                                        setState(() {
                                          calculateTotalPrice();
                                        });
                                      }
                                    }
                                  },
                                  items: widget.sizes.map((s) {
                                    return DropdownMenuItem(
                                      value: s.name,
                                      child: Text(s.name),
                                    );
                                  }).toList(),
                                ),
                                if (item.size.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  AnchoredDropdown<String>(
                                    initialValue: item.itemId.isNotEmpty
                                        ? item.itemId
                                        : null,
                                    decoration: AppDecorations.input(
                                      labelText: 'Cake Item Choice *',
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Cake Item Choice is required';
                                      }
                                      return null;
                                    },
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          item.itemId = val;
                                          item.variant = '';
                                        });
                                        // Fetch variants from the dedicated table
                                        _fetchVariants(val, item.size).then((
                                          results,
                                        ) {
                                          setState(() {
                                            _variantCache['$val:${item.size}'] =
                                                results;
                                          });
                                          calculateTotalPrice();
                                        });
                                      }
                                    },
                                    items: widget.items
                                        .where(
                                          (cake) =>
                                              cake.sizes.contains(item.size) || cake.id == item.itemId,
                                        )
                                        .map((i) {
                                          return DropdownMenuItem(
                                            value: i.id,
                                            child: Text(i.name),
                                          );
                                        })
                                        .toList(),
                                  ),
                                  if (item.itemId.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: AnchoredDropdown<String>(
                                            initialValue:
                                                item.variant.isNotEmpty
                                                ? item.variant
                                                : null,
                                            decoration: AppDecorations.input(
                                              labelText: 'Variant / Shape',
                                            ),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(
                                                  () => item.variant = val,
                                                );
                                                calculateTotalPrice();
                                              }
                                            },
                                            items: (() {
                                              // Use variants from the dedicated table (cached)
                                              final cacheKey =
                                                  '${item.itemId}:${item.size}';
                                              final cachedVariants =
                                                  _variantCache[cacheKey] ?? [];
                                              if (cachedVariants.isNotEmpty) {
                                                return cachedVariants.map((v) {
                                                  return DropdownMenuItem(
                                                    value: v['name'] as String,
                                                    child: Text(
                                                      v['name'] as String,
                                                    ),
                                                  );
                                                }).toList();
                                              }
                                              // Fallback to embedded variants on cake_items
                                              final cake = widget.items
                                                  .firstWhere(
                                                    (c) => c.id == item.itemId,
                                                    orElse: () => CakeItem(
                                                      id: '',
                                                      name: '',
                                                      sizes: [],
                                                      variants: [],
                                                      pricing: {},
                                                    ),
                                                  );
                                              return cake.variants.map((v) {
                                                return DropdownMenuItem(
                                                  value: v,
                                                  child: Text(v),
                                                );
                                              }).toList();
                                            })(),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 1,
                                          child: AnchoredDropdown<int>(
                                            initialValue: item.quantity,
                                            decoration: AppDecorations.input(
                                              labelText: 'Qty',
                                            ),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(
                                                  () => item.quantity = val,
                                                );
                                                calculateTotalPrice();
                                              }
                                            },
                                            items:
                                                List.generate(
                                                  10,
                                                  (i) => i + 1,
                                                ).map((qty) {
                                                  return DropdownMenuItem<int>(
                                                    value: qty,
                                                    child: Text('$qty'),
                                                  );
                                                }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Design Code & Source Row
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            key: ValueKey('designCode_$index'),
                                            initialValue: item.designCode,
                                            decoration: AppDecorations.input(
                                              labelText:
                                                  (item.designFrom == null ||
                                                      item.designFrom!.isEmpty)
                                                  ? 'Design Code *'
                                                  : 'Design Code',
                                              hintText:
                                                  'e.g. ASH-005 (English only)',
                                            ),
                                            onChanged: (val) {
                                              item.designCode = val.trim();
                                              calculateTotalPrice();
                                            },
                                            validator: (val) {
                                              if ((val == null ||
                                                      val.trim().isEmpty) &&
                                                  (item.designFrom == null ||
                                                      item
                                                          .designFrom!
                                                          .isEmpty)) {
                                                return 'Design Code or Design From is required';
                                              }
                                              if (val != null &&
                                                  val.isNotEmpty &&
                                                  hasBurmeseCharacters(val)) {
                                                return 'Burmese characters are forbidden';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child:
                                              AnchoredDropdown<String?>(
                                                initialValue: item.designFrom,
                                                decoration:
                                                    AppDecorations.input(
                                                      labelText: 'Design from',
                                                    ),
                                                onChanged: (val) {
                                                  setState(() {
                                                    item.designFrom = val;
                                                  });
                                                  calculateTotalPrice();
                                                },
                                                items: [
                                                  const DropdownMenuItem<
                                                    String?
                                                  >(
                                                    value: null,
                                                    child: Text('None (Clear)'),
                                                  ),
                                                  ...[
                                                    'Viber',
                                                    'Telegram',
                                                    'Page',
                                                    'WeChat',
                                                  ].map((opt) {
                                                    return DropdownMenuItem<
                                                      String?
                                                    >(
                                                      value: opt,
                                                      child: Text(opt),
                                                    );
                                                  }),
                                                ],
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    AnchoredDropdown<String>(
                                      initialValue: item.orderFrom,
                                      decoration: AppDecorations.input(
                                        labelText:
                                            'Order From Channel (Optional)',
                                      ),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => item.orderFrom = val);
                                          calculateTotalPrice();
                                        }
                                      },
                                      items:
                                          [
                                            'Page',
                                            'Phone',
                                            'Viber',
                                            'Telegram',
                                            'WeChat',
                                            'Walk-In',
                                          ].map((ch) {
                                            return DropdownMenuItem(
                                              value: ch,
                                              child: Text(ch),
                                            );
                                          }).toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            key: ValueKey('toysCost_$index'),
                                            initialValue: item.toysCost > 0
                                                ? item.toysCost.toString()
                                                : '',
                                            keyboardType: TextInputType.number,
                                            decoration: AppDecorations.input(
                                              labelText: 'Toys Cost (Optional)',
                                              hintText: 'e.g. 5000',
                                            ),
                                            onChanged: (val) {
                                              setState(() {
                                                item.toysCost =
                                                    int.tryParse(val) ?? 0;
                                              });
                                              calculateTotalPrice();
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: AnchoredDropdown<String>(
                                            initialValue:
                                                item.moneyPullingSelection,
                                            decoration: AppDecorations.input(
                                              labelText: 'Money Pulling Cost',
                                            ),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  item.moneyPullingSelection =
                                                      val;
                                                  if (val == 'None') {
                                                    item.moneyPullingCost = 0;
                                                  } else if (val ==
                                                      '5,000 MMK') {
                                                    item.moneyPullingCost =
                                                        5000;
                                                  } else if (val ==
                                                      '10,000 MMK') {
                                                    item.moneyPullingCost =
                                                        10000;
                                                  } else if (val ==
                                                      '20,000 MMK') {
                                                    item.moneyPullingCost =
                                                        20000;
                                                  }
                                                });
                                                calculateTotalPrice();
                                              }
                                            },
                                            items:
                                                [
                                                  'None',
                                                  '5,000 MMK',
                                                  '10,000 MMK',
                                                  '20,000 MMK',
                                                  'Other',
                                                ].map((type) {
                                                  return DropdownMenuItem(
                                                    value: type,
                                                    child: Text(type),
                                                  );
                                                }).toList(),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (item.moneyPullingSelection ==
                                        'Other') ...[
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        key: ValueKey('customPulling_$index'),
                                        initialValue: item.moneyPullingCost > 0
                                            ? item.moneyPullingCost.toString()
                                            : '',
                                        keyboardType: TextInputType.number,
                                        decoration: AppDecorations.input(
                                          labelText:
                                              'Custom Pulling Cost (MMK)',
                                          hintText: 'e.g. 15000',
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            item.moneyPullingCost =
                                                int.tryParse(val) ?? 0;
                                          });
                                          calculateTotalPrice();
                                        },
                                      ),
                                    ],
                                    if (item.moneyPullingSelection !=
                                        'None') ...[
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        key: ValueKey('pullingNote_$index'),
                                        initialValue: item.moneyPullingNote,
                                        decoration: AppDecorations.input(
                                          labelText:
                                              'Money Pulling Note (Optional)',
                                          hintText:
                                              'e.g., 1000 Kyats x 30 sheets',
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            item.moneyPullingNote = val.trim();
                                          });
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ],
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFD4A373),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            'Add More Item',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _orderedItems.add(
                                FormOrderItem(
                                  size: '',
                                  itemId: '',
                                  variant: '',
                                  quantity: 1,
                                ),
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _customerPhone,
                        keyboardType: TextInputType.phone,
                        decoration: AppDecorations.input(
                          labelText: 'Customer Phone Number *',
                          hintText: 'e.g. 09775432109',
                        ),
                        onChanged: (val) => _customerPhone = val.trim(),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Customer phone is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),

                  // CARD 2: CAKE CUSTOMIZATION
                  _buildCard(
                    title: '2. Styling & Customization',
                    icon: Icons.cake_outlined,
                    children: [
                      TextFormField(
                        initialValue: _customLettering,
                        decoration: AppDecorations.input(
                          labelText: 'Custom Lettering Message *',
                          hintText: 'e.g. Happy Birthday / မွေးနေ့ဂုဏ်ပြုလွှာ',
                        ),
                        onChanged: (val) => _customLettering = val.trim(),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Lettering Message is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _specialInstructions,
                        maxLines: 2,
                        decoration: AppDecorations.input(
                          labelText: 'Special Bakery Instructions',
                        ),
                        onChanged: (val) => _specialInstructions = val.trim(),
                      ),
                    ],
                  ),

                  // CARD 3: DELIVERY COST (Collapsible/Expandable matching screenshot)
                  _buildExpandableCard(
                    title: 'Delivery Cost',
                    subtitle: '(ပို့ဆောင်ခ)',
                    icon: Icons.delivery_dining_outlined,
                    children: [
                      _buildInputLabel('Delivery Cost (Optional)'),
                      TextFormField(
                        initialValue: _deliveryCost > 0
                            ? _deliveryCost.toString()
                            : '',
                        keyboardType: TextInputType.number,
                        decoration: AppDecorations.input(
                          hintText: 'e.g. 3000',
                          filled: true,
                          fillColor: const Color(0xFFFAF9F6),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _deliveryCost = int.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ],
                  ),

                  // CARD 4: DEPOSIT & PAYMENT LEDGER
                  _buildCard(
                    title: '4. Deposit & Payment Ledger',
                    icon: Icons.payments_outlined,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _paymentStatus == 'deposit' 
                                  ? const Color(0xFF00796B) 
                                  : Colors.white.withValues(alpha: 0.5),
                                foregroundColor: _paymentStatus == 'deposit'
                                  ? Colors.white 
                                  : const Color(0xFF2D241E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                              ),
                              onPressed: () => _showDepositBottomSheet(context, liveTotal),
                              icon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                              label: const Text('Deposit', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _paymentStatus == 'fully_paid'
                                  ? const Color(0xFF00796B)
                                  : Colors.white.withValues(alpha: 0.5),
                                foregroundColor: _paymentStatus == 'fully_paid'
                                  ? Colors.white
                                  : const Color(0xFF2D241E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 0,
                              ),
                              onPressed: () => _showFullyPaidDialog(context, liveTotal),
                              icon: const Icon(Icons.check_circle_outline, size: 20),
                              label: const Text('Fully Paid', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      if (_paymentStatus.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _paymentStatus == 'fully_paid' 
                                      ? 'Fully Paid'
                                      : 'Deposit Paid',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D241E), fontSize: 14),
                                  ),
                                  Text(
                                    'via ${_isKpay ? "Kpay" : "Cash"}',
                                    style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                                  ),
                                ],
                              ),
                              Text(
                                '$_depositPaid MMK',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00796B), fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // FLOATING ACTION PILL
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0
                        ? 16.0
                        : 84.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isTotalExpanded = !_isTotalExpanded;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.fastOutSlowIn,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _isTotalExpanded ? 24.0 : 32.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: _isTotalExpanded ? 20 : 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          _isTotalExpanded ? 24.0 : 32.0,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.fastOutSlowIn,
                            width: _isTotalExpanded ? MediaQuery.of(context).size.width - 32 : null,
                            padding: EdgeInsets.symmetric(
                              horizontal: _isTotalExpanded ? 24 : 20,
                              vertical: _isTotalExpanded ? 20 : 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tealDark.withValues(alpha: 0.75),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.fastOutSlowIn,
                              alignment: Alignment.topCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Persistent Top Row
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.shopping_bag_outlined,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'TOTAL',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (!_isTotalExpanded) const SizedBox(width: 24),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${liveTotal.toLocaleString()} MMK',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          AnimatedRotation(
                                            turns: _isTotalExpanded ? 0.5 : 0.0,
                                            duration: const Duration(milliseconds: 350),
                                            curve: Curves.fastOutSlowIn,
                                            child: const Icon(
                                              Icons.keyboard_arrow_up,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  // Expandable Content
                                  if (_isTotalExpanded) ...[
                                    const SizedBox(height: 12),
                                    Divider(color: Colors.white.withValues(alpha: 0.2)),
                                    const SizedBox(height: 8),
                                    Text(
                                      _paymentStatus == 'fully_paid'
                                          ? 'STATUS: ရှင်းပြီး'
                                          : 'STATUS: စရံပေး (DUE: ${liveRemaining.toLocaleString()} MMK)',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: _paymentStatus == 'fully_paid'
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (widget.initialOrder != null) ...[
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _resetForm();
                                              });
                                              if (widget.initialOrder == null) {
                                                OrderRepository().clearDraft();
                                              }
                                              widget.onCancel();
                                            },
                                            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                                          ),
                                          const SizedBox(width: 8),
                                        ] else if (widget.onReset != null) ...[
                                          TextButton(
                                            onPressed: () {
                                              OrderRepository().clearDraft();
                                              widget.onReset!();
                                            },
                                            child: const Text('Clear', style: TextStyle(color: Colors.white70)),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Expanded(
                                          child: ScaleButton(
                                            onTap: _isSubmitting ? null : _submitForm,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              decoration: BoxDecoration(
                                                color: _isSubmitting ? Colors.white70 : Colors.white,
                                                borderRadius: BorderRadius.circular(12.0),
                                              ),
                                              child: Center(
                                                child: _isSubmitting
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppColors.tealDark,
                                                        ),
                                                      )
                                                    : Text(
                                                  widget.initialOrder != null
                                                      ? 'Apply & Reprint'
                                                      : 'Confirm & Print',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: AppColors.tealDark,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitForm() async {
    // Prevent double-submission (race condition guard)
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
    if (_formKey.currentState!.validate()) {
      if (widget.initialOrder == null) {
        final now = DateTime.now();
        _orderNumber = await OrderRepository().generateNextOrderNumber();
        _id = 'ord-${now.millisecondsSinceEpoch}';
      }
      int finalTotal = _calculateLiveTotal();
      int finalRemaining = _paymentStatus == 'fully_paid'
          ? 0
          : (finalTotal - _depositPaid);

      _syncMainFieldsFromOrderedItems();

      String finalInstructions = _specialInstructions;
      if (_orderedItems.length > 1) {
        final additionalItemsText = _orderedItems
            .skip(1)
            .map((item) {
              final dbItem = widget.items.firstWhere(
                (i) => i.id == item.itemId,
                orElse: () => CakeItem(
                  id: '',
                  name: 'Cake',
                  sizes: [],
                  variants: [],
                  pricing: {},
                ),
              );
              String details =
                  "${dbItem.name} (${item.size} - ${item.variant}) x${item.quantity}";
              List<String> tags = [];
              if (item.designCode.isNotEmpty) {
                tags.add("Design: ${item.designCode}");
              }
              if (item.designFrom != null && item.designFrom!.isNotEmpty) {
                tags.add("DesignFrom: ${item.designFrom}");
              }
              if (item.orderFrom != 'Walk-In') {
                tags.add("Channel: ${item.orderFrom}");
              }
              if (item.toysCost > 0) {
                tags.add("ToysCost: ${item.toysCost}");
              }
              if (item.moneyPullingCost > 0) {
                tags.add("MoneyPullingCost: ${item.moneyPullingCost}");
              }
              if (item.moneyPullingNote.isNotEmpty) {
                tags.add("MoneyPullingNote: ${item.moneyPullingNote}");
              }
              if (tags.isNotEmpty) {
                details += " [${tags.join(', ')}]";
              }
              return details;
            })
            .join(", ");
        finalInstructions =
            "$finalInstructions [Additional Items: $additionalItemsText]"
                .trim();
      }
      if (_designFrom != null && _designFrom!.isNotEmpty) {
        finalInstructions = "$finalInstructions [Design From: $_designFrom]"
            .trim();
      }
      final firstItem = _orderedItems.first;
      if (firstItem.quantity > 1) {
        finalInstructions = "$finalInstructions [Qty: ${firstItem.quantity}]"
            .trim();
      }

      // Fallback for Edit Mode if state variables were lost
      debugPrint('DEBUG OrderForm _submitForm UI State: size="$_selectedSize", phone="$_customerPhone", lettering="$_customLettering", instructions="$_specialInstructions"');
      
      if (widget.initialOrder != null) {
        if (_selectedSize.isEmpty) _selectedSize = widget.initialOrder!.size;
        if (_customerPhone.isEmpty) _customerPhone = widget.initialOrder!.customerPhone;
        if (_customLettering.isEmpty) _customLettering = widget.initialOrder!.customLettering;
      }
      
      debugPrint('DEBUG: _submitForm (after fallback) - _selectedSize: "$_selectedSize", _customerPhone: "$_customerPhone", _customLettering: "$_customLettering"');

      final outOrder = Order(
        id: _id,
        orderNumber: _orderNumber,
        deliveryDate: _deliveryDate,
        deliveryTime: _deliveryTime,
        itemId: _itemId,
        size: _selectedSize,
        variant: _selectedVariant,
        designCode: _designCode,
        customName: _customName,
        customAge: _customAge,
        customDate: _customDate,
        customLettering: _customLettering,
        specialInstructions: finalInstructions,
        customerPhone: _customerPhone,
        paymentStatus: _paymentStatus,
        depositPaid: _paymentStatus == 'fully_paid' ? finalTotal : _depositPaid,
        remainingBalance: finalRemaining,
        isKpay: _isKpay,
        totalAmount: finalTotal,
        toysCost: firstItem.toysCost,
        moneyPullingCost: firstItem.moneyPullingSelection == 'None'
            ? 0
            : firstItem.moneyPullingCost,
        moneyPullingNote: firstItem.moneyPullingSelection == 'None'
            ? ''
            : firstItem.moneyPullingNote,
        deliveryCost: _deliveryCost,
        orderFrom: _orderFrom,
        createdAt: widget.initialOrder?.createdAt ?? DateTime.now(),
        printCount: widget.initialOrder?.printCount ?? 0,
        isPrepOnly: widget.initialOrder?.isPrepOnly ?? false,
      );

      if (kDebugMode && widget.initialOrder != null) {
        final orig = widget.initialOrder!;
        if (outOrder.id != orig.id) {
          debugPrint(
            'WARNING: Order ID mismatch! Orig: ${orig.id}, New: ${outOrder.id}',
          );
        }
        if (outOrder.orderNumber != orig.orderNumber) {
          debugPrint(
            'WARNING: Order Number mismatch! Orig: ${orig.orderNumber}, New: ${outOrder.orderNumber}',
          );
        }
        if (outOrder.createdAt != orig.createdAt) {
          debugPrint(
            'WARNING: Order CreatedAt mismatch! Orig: ${orig.createdAt}, New: ${outOrder.createdAt}',
          );
        }
        if (outOrder.printCount != orig.printCount) {
          debugPrint(
            'WARNING: Order PrintCount mismatch! Orig: ${orig.printCount}, New: ${outOrder.printCount}',
          );
        }
        if (outOrder.isPrepOnly != orig.isPrepOnly) {
          debugPrint(
            'WARNING: Order IsPrepOnly mismatch! Orig: ${orig.isPrepOnly}, New: ${outOrder.isPrepOnly}',
          );
        }
      }

      // We don't call _resetForm() here anymore.
      if (widget.initialOrder == null) {
        OrderRepository().clearDraft();
      }
      // The parent widget (main.dart) will handle resetting the form
      // by changing the ValueKey of OrderEntryFormTab upon successful submission.
      await widget.onSubmit(outOrder);
    }
    } finally {
      // Re-enable after submission completes (success or failure)
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class FormOrderItem {
  String size;
  String itemId;
  String variant;
  int quantity;
  String designCode;
  String? designFrom;
  String orderFrom;
  int toysCost;
  int moneyPullingCost;
  String moneyPullingSelection;
  String moneyPullingNote;

  FormOrderItem({
    required this.size,
    required this.itemId,
    required this.variant,
    this.quantity = 1,
    this.designCode = '',
    this.designFrom,
    this.orderFrom = 'Walk-In',
    this.toysCost = 0,
    this.moneyPullingCost = 0,
    this.moneyPullingSelection = 'None',
    this.moneyPullingNote = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'itemId': itemId,
      'variant': variant,
      'quantity': quantity,
      'designCode': designCode,
      'designFrom': designFrom,
      'orderFrom': orderFrom,
      'toysCost': toysCost,
      'moneyPullingCost': moneyPullingCost,
      'moneyPullingSelection': moneyPullingSelection,
      'moneyPullingNote': moneyPullingNote,
    };
  }

  factory FormOrderItem.fromMap(Map<String, dynamic> map) {
    return FormOrderItem(
      size: map['size'] ?? '',
      itemId: map['itemId'] ?? '',
      variant: map['variant'] ?? '',
      quantity: map['quantity'] ?? 1,
      designCode: map['designCode'] ?? '',
      designFrom: map['designFrom'],
      orderFrom: map['orderFrom'] ?? 'Walk-In',
      toysCost: map['toysCost'] ?? 0,
      moneyPullingCost: map['moneyPullingCost'] ?? 0,
      moneyPullingSelection: map['moneyPullingSelection'] ?? 'None',
      moneyPullingNote: map['moneyPullingNote'] ?? '',
    );
  }
}
