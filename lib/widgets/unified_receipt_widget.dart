import 'dart:ui';
import 'package:flutter/material.dart';
import '../models.dart';

class UnifiedReceiptWidget extends StatelessWidget {
  final Order order;
  final List<CakeItem> activeItems;
  final String bakeryName;
  final String footerNotes;
  final double? width;

  const UnifiedReceiptWidget({
    super.key,
    required this.order,
    required this.activeItems,
    required this.bakeryName,
    required this.footerNotes,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    const double scale = 1.0;
    const double fontSizeBody = 12.0 * scale;
    const double fontSizeBodyBold = 13.0 * scale;
    const double fontSizeCaption = 10.0 * scale;

    // Resolve main cake item name
    final mainCake = activeItems.firstWhere(
      (item) => item.id == order.itemId,
      orElse: () => CakeItem(
        id: '',
        name: 'Special Cake',
        sizes: [],
        variants: [],
        pricing: {},
      ),
    );

    final List<_ReceiptItem> printItems = [];

    // Parse the first item (main order columns)
    String? mainDesignFrom;
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

    int firstQty = 1;
    if (cleanInstructions.contains('[Qty: ')) {
      final startIdx =
          cleanInstructions.indexOf('[Qty: ') + '[Qty: '.length;
      final endIdx = cleanInstructions.indexOf(']', startIdx);
      if (endIdx != -1) {
        firstQty =
            int.tryParse(cleanInstructions.substring(startIdx, endIdx)) ?? 1;
        cleanInstructions = cleanInstructions
            .replaceRange(
              cleanInstructions.indexOf('[Qty: '),
              endIdx + 1,
              '',
            )
            .trim();
      }
    }

    printItems.add(
      _ReceiptItem(
        name: mainCake.name,
        size: order.size,
        variant: order.variant,
        quantity: firstQty,
        designCode: order.designCode,
        designFrom: mainDesignFrom,
        orderFrom: order.orderFrom,
        toysCost: order.toysCost,
        moneyPullingCost: order.moneyPullingCost,
        moneyPullingNote: order.moneyPullingNote,
        itemId: order.itemId,
      ),
    );

    // Parse additional items from instructions
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
              String? designFrom;
              String orderFrom = 'Walk-In';
              int toysCost = 0;
              int moneyPullingCost = 0;
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
                    } else if (tag.startsWith('Channel: ')) {
                      orderFrom = tag.substring('Channel: '.length);
                    } else if (tag.startsWith('ToysCost: ')) {
                      toysCost =
                          int.tryParse(tag.substring('ToysCost: '.length)) ?? 0;
                    } else if (tag.startsWith('MoneyPullingCost: ')) {
                      moneyPullingCost =
                          int.tryParse(
                            tag.substring('MoneyPullingCost: '.length),
                          ) ??
                          0;
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

              final matchedCake = activeItems.firstWhere(
                (c) => c.name == name,
                orElse: () => CakeItem(
                  id: '',
                  name: '',
                  sizes: [],
                  variants: [],
                  pricing: {},
                ),
              );

              printItems.add(
                _ReceiptItem(
                  name: name,
                  size: size,
                  variant: variant,
                  quantity: qty,
                  designCode: designCode,
                  designFrom: designFrom,
                  orderFrom: orderFrom,
                  toysCost: toysCost,
                  moneyPullingCost: moneyPullingCost,
                  moneyPullingNote: moneyPullingNote,
                  itemId: matchedCake.id,
                ),
              );
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

    String localFormatDueDate(String dateStr, String timeStr) {
      if (dateStr.isEmpty) return '';
      List<String> parts = dateStr.split('-');
      String formattedDate = dateStr;
      if (parts.length == 3) {
        String year = parts[0];
        String month = parts[1];
        String day = parts[2];
        String shortYear = year.length >= 2
            ? year.substring(year.length - 2)
            : year;
        formattedDate = "$day-$month-$shortYear";
      }
      return "$formattedDate @ ${_formatTimeTo12Hour(timeStr)}";
    }

    String localGetPaymentTypeString(Order order) {
      final status = order.paymentStatus == 'fully_paid'
          ? 'ရှင်းပြီး'
          : 'စရံပေး';
      final method = order.isKpay ? 'KPAY' : 'CASH';
      return '$status ($method)';
    }

    return Container(
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top brown decorative stripe
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFD4A373), // Gold/Brown
                  Color(0xFF2D241E), // Dark Brown/Black
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8.0)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branding
                Text(
                  bakeryName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D241E),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'အောင်စည်ဟိန်း_မုန့်တိုက်၊ စျေးရပ်၊ သီပေါမြို့။',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8C7E6A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  'ဖုန်း - 09798942010, 09794003671',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Color(0xFF8C7E6A), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(
                  'Date: ${_formatDate(order.createdAt)} | Cashier: HUB-01',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
                const SizedBox(height: 10),
                _buildReceiptDivider(),
                const SizedBox(height: 10),

                // Details table
                _buildReceiptRow(
                  'ORDER NUMBER:',
                  order.orderNumber,
                  fontSizeBody,
                  isBold: true,
                ),
                _buildReceiptRow(
                  'ORDER DATE:',
                  _formatDate(order.createdAt),
                  fontSizeBody,
                ),
                _buildReceiptRow(
                  'DUE DATE/TIME:',
                  localFormatDueDate(order.deliveryDate, order.deliveryTime),
                  fontSizeBody,
                  isBold: true,
                  underline: true,
                ),
                _buildReceiptRow(
                  'CUSTOMER TEL:',
                  order.customerPhone,
                  fontSizeBody,
                  isBold: true,
                ),
                _buildReceiptRow(
                  'ORDER CHANNEL:',
                  order.orderFrom.isEmpty ? 'Walk-In' : order.orderFrom,
                  fontSizeBody,
                  valueColor: const Color(0xFFD4A373),
                  labelColor: const Color(0xFFD4A373),
                ),
                const SizedBox(height: 10),
                _buildReceiptDivider(),
                const SizedBox(height: 10),

                // Customizations Box
                Align(
                  alignment: Alignment.centerLeft,
                  child: DashedContainer(
                    color: const Color(0xFFD0D7DE),
                    borderRadius: 8.0,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CAKE CUSTOMIZATIONS:',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4A373),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildInnerDottedDivider(),
                          const SizedBox(height: 8),
                          const Text(
                            'LETTERING MESSAGE:',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '"${order.customLettering}"',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF2D241E),
                            ),
                          ),
                          if (cleanInstructions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildInnerDottedDivider(),
                            const SizedBox(height: 8),
                            const Text(
                              'SPECIAL BAKERY INSTRUCTIONS:',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cleanInstructions,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D241E),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildReceiptDivider(),
                const SizedBox(height: 10),

                // Specs table
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ITEM / SPECS',
                      style: TextStyle(
                        fontSize: fontSizeCaption,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'AMOUNT',
                      style: TextStyle(
                        fontSize: fontSizeCaption,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...() {
                  // Calculate individual item prices using activeItems database
                  final List<int> itemPrices = [];
                  int additionalTotal = 0;
                  for (int i = 1; i < printItems.length; i++) {
                    final item = printItems[i];
                    final matchedCake = activeItems.firstWhere(
                      (c) => c.id == item.itemId || c.name == item.name,
                      orElse: () => CakeItem(
                        id: '',
                        name: '',
                        sizes: [],
                        variants: [],
                        pricing: {},
                      ),
                    );
                    int unitPrice = 0;
                    if (matchedCake.id.isNotEmpty) {
                      final key = '${item.size}:${item.variant}';
                      if (matchedCake.pricing.containsKey(key)) {
                        unitPrice = matchedCake.pricing[key] ?? 0;
                      } else {
                        final fallbackKey = matchedCake.pricing.keys.firstWhere(
                          (k) => k.startsWith('${item.size}:'),
                          orElse: () => '',
                        );
                        if (fallbackKey.isNotEmpty) {
                          unitPrice = matchedCake.pricing[fallbackKey] ?? 0;
                        }
                      }
                    }
                    itemPrices.add(unitPrice);
                    additionalTotal += unitPrice * item.quantity;
                  }

                  final int totalToysCost = printItems.fold(
                    0,
                    (sum, item) => sum + item.toysCost,
                  );
                  final int totalMoneyPullingCost = printItems.fold(
                    0,
                    (sum, item) => sum + item.moneyPullingCost,
                  );
                  final int firstItemUnitPrice =
                      order.totalAmount -
                      totalToysCost -
                      totalMoneyPullingCost -
                      additionalTotal -
                      order.deliveryCost;

                  return List.generate(printItems.length, (index) {
                    final item = printItems[index];
                    final int unitPrice = index == 0
                        ? firstItemUnitPrice
                        : itemPrices[index - 1];
                    final int lineTotal = unitPrice * item.quantity;
                    final String displayName =
                        '${item.name} (${item.size} - ${item.variant}) x${item.quantity}';

                    final List<String> designParts = [];
                    if (item.designCode.isNotEmpty) designParts.add(item.designCode);
                    if (item.designFrom != null && item.designFrom!.isNotEmpty) designParts.add(item.designFrom!);
                    final String designText = designParts.join(' | ');

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ITEM #${index + 1}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD4A373)),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D241E),
                                      ),
                                    ),
                                    if (designText.isNotEmpty)
                                      Text(
                                        'Design: $designText',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                                      ),
                                    if (item.toysCost > 0)
                                      const Text(
                                        '✓ Toy Included',
                                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    if (item.moneyPullingNote.isNotEmpty)
                                      Text(
                                        'Money Pulling Note: ${item.moneyPullingNote}',
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                '${lineTotal.toLocaleString()} MMK',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'JetBrains Mono',
                                  color: Color(0xFF2D241E),
                                ),
                              ),
                            ],
                          ),
                          if (item.toysCost > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '  + Toys Cost',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF8C7E6A)),
                                  ),
                                  Text(
                                    '${item.toysCost.toLocaleString()} MMK',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF8C7E6A), fontFamily: 'JetBrains Mono'),
                                  ),
                                ],
                              ),
                            ),
                          if (item.moneyPullingCost > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '  + Money Pulling Cost',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF8C7E6A)),
                                  ),
                                  Text(
                                    '${item.moneyPullingCost.toLocaleString()} MMK',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF8C7E6A), fontFamily: 'JetBrains Mono'),
                                  ),
                                ],
                              ),
                            ),

                        ],
                      ),
                    );
                  });
                }(),
                if (order.deliveryCost > 0) ...[
                  const SizedBox(height: 6.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Delivery Cost',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${order.deliveryCost.toLocaleString()} MMK',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _buildReceiptDivider(),
                const SizedBox(height: 10),

                // Net total & dynamic calculations rows
                _buildReceiptRow(
                  'NET TOTAL:',
                  '${order.totalAmount.toLocaleString()} MMK',
                  fontSizeBodyBold + 1,
                  isBold: true,
                  isMono: true,
                ),
                const SizedBox(height: 4),
                _buildReceiptRow(
                  'PAYMENT TYPE:',
                  localGetPaymentTypeString(order),
                  fontSizeCaption,
                  isBold: true,
                  valueColor: Colors.grey.shade700,
                  labelColor: Colors.grey.shade600,
                ),
                const SizedBox(height: 4),
                _buildReceiptRow(
                  'ရှင်းငွေ:',
                  '${order.depositPaid.toLocaleString()} MMK',
                  fontSizeBodyBold + 1,
                  isBold: true,
                  valueColor: const Color(0xFF1E7E34),
                  labelColor: const Color(0xFF1E7E34),
                  isMono: true,
                ),
                const SizedBox(height: 4),
                _buildReceiptRow(
                  'ကျန်ငွေ:',
                  '${(order.totalAmount - order.depositPaid).toLocaleString()} MMK',
                  fontSizeBodyBold + 1,
                  isBold: true,
                  valueColor: (order.totalAmount - order.depositPaid) > 0
                      ? const Color(0xFFDC3545)
                      : const Color(0xFF1E7E34),
                  labelColor: (order.totalAmount - order.depositPaid) > 0
                      ? const Color(0xFFDC3545)
                      : const Color(0xFF1E7E34),
                  isMono: true,
                ),
                const SizedBox(height: 10),
                _buildReceiptDivider(),
                const SizedBox(height: 12),

                // Footer note
                const Text(
                  'ဘာကြောင့်လိုလို ကိတ်နဲ့ပတ်သက်ရင်',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                const Text(
                  'ASH_Bakery ကို သတိရပေးနော်...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                const Text(
                  'အားပေးမှုကို ကျေးဇူးအထူးပါ။',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptDivider() {
    return Row(
      children: List.generate(
        45,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.grey.shade300 : Colors.transparent,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInnerDottedDivider() {
    return Row(
      children: List.generate(
        40,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.grey.shade300 : Colors.transparent,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value,
    double fontSize, {
    bool isBold = false,
    bool underline = false,
    Color? valueColor,
    Color? labelColor,
    bool useBadge = false,
    bool isMono = false,
  }) {
    Widget valueWidget;
    if (useBadge) {
      valueWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF9F6),
          border: Border.all(color: const Color(0xFFD0D7DE), width: 1.0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'JetBrains Mono',
            color: const Color(0xFF2D241E),
          ),
        ),
      );
    } else {
      valueWidget = Text(
        value,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: isMono ? 'JetBrains Mono' : null,
          decoration: underline ? TextDecoration.underline : null,
          color: valueColor ?? const Color(0xFF2D241E),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: labelColor ?? Colors.black87,
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatTimeTo12Hour(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      List<String> parts = timeStr.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        String ampm = hour >= 12 ? 'PM' : 'AM';
        int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        String minStr = minute.toString().padLeft(2, '0');
        return '$displayHour:$minStr $ampm';
      }
    } catch (_) {}
    return timeStr;
  }
}

class DashedContainer extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  const DashedContainer({
    super.key,
    required this.child,
    this.color = const Color(0xFFD0D7DE),
    this.strokeWidth = 1.0,
    this.gap = 3.0,
    this.dash = 5.0,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(
        color: color,
        strokeWidth: strokeWidth,
        gap: gap,
        dash: dash,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.dash,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);

    final Path dashedPath = Path();
    double distance = 0.0;
    for (final PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashedPath.addPath(
          measurePath.extractPath(distance, distance + dash),
          Offset.zero,
        );
        distance += dash + gap;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class _ReceiptItem {
  final String name;
  final String size;
  final String variant;
  final int quantity;
  final String designCode;
  final String? designFrom;
  final String orderFrom;
  final int toysCost;
  final int moneyPullingCost;
  final String moneyPullingNote;
  final String itemId;

  _ReceiptItem({
    required this.name,
    required this.size,
    required this.variant,
    required this.quantity,
    required this.designCode,
    required this.designFrom,
    required this.orderFrom,
    required this.toysCost,
    required this.moneyPullingCost,
    required this.moneyPullingNote,
    required this.itemId,
  });
}
