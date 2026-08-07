import 'package:flutter/material.dart';
import '../models.dart';

/// 80mm thermal print renderer.
///
/// Rendering math:
///   Logical width  : 384 px
///   Pixel ratio    : 1.5  (set in captureFromWidget inside digital_voucher_dialog.dart)
///   Physical output: 576 px → 80mm @ 203dpi
///
/// Font sizes are LOGICAL pixels (×1.5 on paper):
///   16px logical title   → 24 physical dots → ~3.0mm  ✓
///   11px logical section → 16.5 dots        → ~2.0mm  ✓
///   10px logical body    → 15 dots          → ~1.9mm  ✓
///    9px logical footer  → 13.5 dots        → ~1.7mm  ✓
///
/// All colors: explicit Colors.black (thermal printers are monochrome).
enum ReceiptType { customer, kitchen }

class ThermalReceiptWidget extends StatelessWidget {
  final Order order;
  final List<CakeItem> activeItems;
  final double? width;
  final ReceiptType type;

  const ThermalReceiptWidget({
    super.key,
    required this.order,
    required this.activeItems,
    this.width,
    this.type = ReceiptType.customer,
  });

  // ─── date / time helpers ─────────────────────────────────────────────────

  String _fmtDate(DateTime dt) =>
      '${_p(dt.day)}-${_p(dt.month)}-${dt.year.toString().substring(2)}';

  String _p(int n) => n.toString().padLeft(2, '0');

  String _fmtDueDate(String dateStr, String timeStr) {
    if (dateStr.isEmpty) return '-';
    final parts = dateStr.split('-');
    String d = dateStr;
    if (parts.length == 3) {
      final y = parts[0].length >= 2
          ? parts[0].substring(parts[0].length - 2)
          : parts[0];
      d = '${parts[2]}-${parts[1]}-$y';
    }
    final t = _fmtTime(timeStr);
    return t.isEmpty ? d : '$d @ $t';
  }

  String _fmtTime(String t) {
    if (t.isEmpty) return '';
    try {
      final p = t.split(':');
      int h = int.parse(p[0]);
      final m = p.length > 1 ? p[1] : '00';
      final suf = h >= 12 ? 'PM' : 'AM';
      if (h == 0) {
        h = 12;
      } else if (h > 12) {
        h -= 12;
      }
      return '${_p(h)}:$m $suf';
    } catch (_) {
      return t;
    }
  }

  String _fmtNum(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  String _paymentLabel() {
    final status =
        order.paymentStatus == 'fully_paid' ? 'ရှင်းပြီး' : 'စရံပေး';
    final method = order.isKpay ? 'KPAY' : 'CASH';
    return '$status ($method)';
  }

  // ─── item parsing (same logic as UnifiedReceiptWidget) ───────────────────

  List<_TItem> _parseItems() {
    final items = <_TItem>[];
    final mainCake = activeItems.firstWhere(
      (c) => c.id == order.itemId,
      orElse: () =>
          CakeItem(id: '', name: 'Special Cake', sizes: [], variants: [], pricing: {}),
    );

    String raw = order.specialInstructions;
    String? mainDesignFrom;

    if (raw.contains('[Design From: ')) {
      final s = raw.indexOf('[Design From: ') + '[Design From: '.length;
      final e = raw.indexOf(']', s);
      if (e != -1) {
        mainDesignFrom = raw.substring(s, e).trim();
        raw = raw.replaceRange(raw.indexOf('[Design From: '), e + 1, '').trim();
      }
    }

    int firstQty = 1;
    if (raw.contains('[Qty: ')) {
      final s = raw.indexOf('[Qty: ') + '[Qty: '.length;
      final e = raw.indexOf(']', s);
      if (e != -1) {
        firstQty = int.tryParse(raw.substring(s, e)) ?? 1;
        raw = raw.replaceRange(raw.indexOf('[Qty: '), e + 1, '').trim();
      }
    }

    items.add(_TItem(
      name: mainCake.name,
      size: order.size,
      variant: order.variant,
      qty: firstQty,
      designCode: order.designCode,
      designFrom: mainDesignFrom,
      toysCost: order.toysCost,
      moneyPullingCost: order.moneyPullingCost,
      moneyPullingNote: order.moneyPullingNote,
      itemId: order.itemId,
    ));

    if (raw.contains('[Additional Items: ')) {
      final start =
          raw.indexOf('[Additional Items: ') + '[Additional Items: '.length;
      int depth = 1, endIdx = -1;
      for (int i = start; i < raw.length; i++) {
        if (raw[i] == '[') {
          depth++;
        } else if (raw[i] == ']') {
          depth--;
          if (depth == 0) { endIdx = i; break; }
        }
      }
      if (endIdx != -1) {
        final part = raw.substring(start, endIdx);
        final splits = <String>[];
        int last = 0, inB = 0;
        for (int i = 0; i < part.length; i++) {
          if (part[i] == '[') {
            inB++;
          } else if (part[i] == ']') {
            inB--;
          } else if (part.startsWith(', ', i) && inB == 0) {
            splits.add(part.substring(last, i));
            last = i + 2; i++;
          }
        }
        if (last < part.length) splits.add(part.substring(last));

        for (final s in splits) {
          final ne = s.indexOf(' (');
          if (ne == -1) continue;
          final name = s.substring(0, ne);
          final ss = ne + 2, se = s.indexOf(') x', ss);
          if (se == -1) continue;
          final specs = s.substring(ss, se);
          final qp = s.substring(se + 3);
          int qty = 1, toys = 0, money = 0;
          String design = '', moneyNote = '';
          String? designFrom;

          if (qp.contains(' [')) {
            final ts = qp.indexOf(' [') + 2;
            final te = qp.indexOf(']', ts);
            qty = int.tryParse(qp.substring(0, qp.indexOf(' ['))) ?? 1;
            if (te != -1) {
              for (final tag in qp.substring(ts, te).split(', ')) {
                if (tag.startsWith('Design: ')) {
                  design = tag.substring(8);
                } else if (tag.startsWith('DesignFrom: ')) {
                  designFrom = tag.substring(12);
                } else if (tag.startsWith('ToysCost: ')) {
                  toys = int.tryParse(tag.substring(10)) ?? 0;
                } else if (tag.startsWith('MoneyPullingCost: ')) {
                  money = int.tryParse(tag.substring(18)) ?? 0;
                } else if (tag.startsWith('MoneyPullingNote: ')) {
                  moneyNote = tag.substring(18);
                }
              }
            }
          } else {
            qty = int.tryParse(qp) ?? 1;
          }

          final sp = specs.split(' - ');
          final matched = activeItems.firstWhere(
            (c) => c.name == name,
            orElse: () => CakeItem(id: '', name: '', sizes: [], variants: [], pricing: {}),
          );
          items.add(_TItem(
            name: name,
            size: sp[0],
            variant: sp.length > 1 ? sp[1] : '',
            qty: qty,
            designCode: design,
            designFrom: designFrom,
            toysCost: toys,
            moneyPullingCost: money,
            moneyPullingNote: moneyNote,
            itemId: matched.id,
          ));
        }
      }
    }
    return items;
  }

  // ─── price calculation (same as UnifiedReceiptWidget) ────────────────────

  List<int> _calcPrices(List<_TItem> items) {
    int addTotal = 0;
    final extra = <int>[];
    for (int i = 1; i < items.length; i++) {
      final item = items[i];
      final cake = activeItems.firstWhere(
        (c) => c.id == item.itemId || c.name == item.name,
        orElse: () => CakeItem(id: '', name: '', sizes: [], variants: [], pricing: {}),
      );
      int up = 0;
      if (cake.id.isNotEmpty) {
        final key = '${item.size}:${item.variant}';
        if (cake.pricing.containsKey(key)) {
          up = cake.pricing[key]!;
        } else {
          final fb = cake.pricing.keys.firstWhere(
            (k) => k.startsWith('${item.size}:'), orElse: () => '');
          if (fb.isNotEmpty) up = cake.pricing[fb]!;
        }
      }
      extra.add(up);
      addTotal += up * item.qty;
    }
    final totalToys = items.fold(0, (s, i) => s + i.toysCost);
    final totalMoney = items.fold(0, (s, i) => s + i.moneyPullingCost);
    final firstPrice =
        order.totalAmount - totalToys - totalMoney - addTotal - order.deliveryCost;
    return [firstPrice, ...extra];
  }

  // ─── text styles ──────────────────────────────────────────────────────────
  // All Colors.black — thermal printers are monochrome.
  // Sizes are LOGICAL pixels; physical = logical × 1.5.

  static const _c = Colors.black;

  // Header
  static const _sTitle    = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _c);
  static const _sAddress  = TextStyle(fontSize: 14, color: _c);


  // Label / value rows
  static const _sLabel    = TextStyle(fontSize: 15, color: _c);
  static const _sValue    = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _c);

  // Item card
  static const _sItemHdr  = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _c);
  static const _sBody     = TextStyle(fontSize: 15, color: _c);
  static const _sBold     = TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _c);

  // Prices (monospace for right-alignment)
  static const _sMono     = TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                                      color: _c, fontFamily: 'JetBrains Mono');

  // Prominent TOTAL styles (+2 levels larger than body/mono)
  static const _sTotalLabel = TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _c);
  static const _sTotalMono  = TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                                        color: _c, fontFamily: 'JetBrains Mono');

  // Footer
  static const _sFoot     = TextStyle(fontSize: 14, color: _c);

  // ─── layout helpers ───────────────────────────────────────────────────────

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Divider(height: 1, thickness: 0.8, color: Colors.black),
  );

  Widget _thinDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 3),
    child: Divider(height: 1, thickness: 0.4, color: Colors.black54),
  );

  /// Label-value row with fixed 135px label column to prevent wrapping.
  Widget _row(String label, String value, {bool boldValue = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 135, child: Text(label, style: _sLabel)),
            const Text(': ', style: _sLabel),
            Expanded(
              child: Text(value, style: boldValue ? _sValue : _sLabel),
            ),
          ],
        ),
      );

  /// Price row — label left, amount right.
  Widget _priceRow(String label, int amount, {bool isTotal = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: isTotal ? _sTotalLabel : _sBody),
        Text('${_fmtNum(amount)} MMK', style: isTotal ? _sTotalMono : _sMono),
      ],
    ),
  );

  // ─── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final items    = _parseItems();
    final prices   = _calcPrices(items);
    final lettering     = order.customLettering.trim();
    String instructions = order.specialInstructions;

    // Strip metadata tags from instructions
    for (final tag in ['[Design From: ', '[Qty: ', '[Additional Items: ']) {
      while (instructions.contains(tag)) {
        final open = instructions.indexOf('[', instructions.indexOf(tag));
        if (open == -1) {
          break;
        }
        int depth = 0, end = -1;
        for (int i = open; i < instructions.length; i++) {
          if (instructions[i] == '[') {
            depth++;
          } else if (instructions[i] == ']') { depth--; if (depth == 0) { end = i; break; } }
        }
        if (end == -1) break;
        instructions = instructions.replaceRange(open, end + 1, '').trim();
      }
    }
    instructions = instructions.replaceAll(RegExp(r'^[\]\s,]+|[\]\s,]+$'), '').trim();

    return Container(
      width: width ?? 384,
      color: Colors.white,
      // Horizontal: tight margin (6px each side = 12px total, 360px content area).
      // Bottom: 20px to guarantee footer + blank feed lines are fully captured.
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 20),
      child: DefaultTextStyle(
        style: _sBody,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [

            // ── LOGO ──────────────────────────────────────────────────────
            Center(
              child: SizedBox(
                height: 120,
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── HEADER ────────────────────────────────────────────────────
            if (type == ReceiptType.customer) ...[
              const Text('ASH Bakery',
                  textAlign: TextAlign.center, style: _sTitle),
              const SizedBox(height: 3),
              const Text(
                  'အောင်စည်ဟိန်း_မုန့်တိုက်၊ စျေးရပ်၊ သီပေါမြို့။',
                  textAlign: TextAlign.center, style: _sAddress),
              const Text('ဖုန်း - 09798942010, 09794003671',
                  textAlign: TextAlign.center, style: _sAddress),
              _divider(),
            ],

            // ── ORDER INFORMATION ─────────────────────────────────────────
            _row('Order No',
                order.orderNumber, boldValue: true),
            _row('Order Date',    _fmtDate(order.createdAt)),
            _row('Due Date/Time',
                _fmtDueDate(order.deliveryDate, order.deliveryTime),
                boldValue: true),
            if (type == ReceiptType.customer) ...[
              _row('Customer Tel',  order.customerPhone),
              _row('Order From',
                  order.orderFrom.isEmpty ? 'Walk-In' : order.orderFrom),
            ],
            _divider(),

            // ── CUSTOMIZATIONS (only when present) ────────────────────────
            if (lettering.isNotEmpty || instructions.isNotEmpty) ...[
              if (lettering.isNotEmpty)
                _row('Message', '"$lettering"', boldValue: true),
              if (instructions.isNotEmpty)
                _row('Instructions', instructions),
              _divider(),
            ],

            // ── ITEM DETAILS ──────────────────────────────────────────────
            for (int i = 0; i < items.length; i++) ...[
              _buildItem(items[i], i, prices[i], type),
              if (i < items.length - 1) _thinDivider(),
            ],

            _divider(),

            // ── PAYMENT ───────────────────────────────────────────────────
            if (type == ReceiptType.customer) ...[
              _priceRow('TOTAL:', order.totalAmount, isTotal: true),
              const SizedBox(height: 2),
              _row('Payment', _paymentLabel()),
              const SizedBox(height: 2),
              _priceRow('Deposit:', order.depositPaid),
              _priceRow('Balance Due:', order.totalAmount - order.depositPaid),
              _divider(),
            ],

            if (type == ReceiptType.kitchen) ...[
              const SizedBox(height: 4),
              const Text('Payment:', style: _sItemHdr),
              const SizedBox(height: 4),
              _row('Total', '${_fmtNum(order.totalAmount)} MMK'),
              _row('Deposit', '${_fmtNum(order.depositPaid)} MMK'),
              _row('Balance', '${_fmtNum(order.totalAmount - order.depositPaid)} MMK'),
              _row('Status', order.paymentStatus == 'fully_paid' ? 'Paid' : 'Deposit'),
              _divider(),
            ],

            // ── FOOTER ────────────────────────────────────────────────────
            if (type == ReceiptType.customer) ...[
              const SizedBox(height: 4),
              const Text('ဘာကြောင့်လိုလို ကိတ်နဲ့ပတ်သက်ရင်',
                  textAlign: TextAlign.center, style: _sFoot),
              const Text('ASH_Bakery ကို သတိရပေးနော်...',
                  textAlign: TextAlign.center, style: _sFoot),
              const Text('အားပေးမှုကို ကျေးဇူးအထူးပါ။',
                  textAlign: TextAlign.center, style: _sFoot),
            ],
            // Blank feed area — ensures easy tear + no footer clipping.
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_TItem item, int index, int unitPrice, ReceiptType type) {
    final lineTotal = unitPrice * item.qty;
    final designParts = <String>[];
    if (item.designCode.isNotEmpty) {
      designParts.add(item.designCode);
    }
    if (item.designFrom != null && item.designFrom!.isNotEmpty) {
      designParts.add(item.designFrom!);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Text('ITEM #${index + 1}', style: _sItemHdr),
          const SizedBox(height: 3),

          // Item details
          _row('Cake',   item.name),
          _row('Size',   '${item.size} x${item.qty}'),
          if (designParts.isNotEmpty)
            _row('Design', designParts.join(' | ')),

          // Extras — only shown when present
          if (item.toysCost > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('  \u2713 Toy Included', style: _sBold),
            ),
          if (item.moneyPullingNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _row('Money Pulling', item.moneyPullingNote),
            ),

          if (type == ReceiptType.customer) ...[
            // Price breakdown
            const SizedBox(height: 4),
            _priceRow('  Cake Price', lineTotal),
            if (item.toysCost > 0)
              _priceRow('  + Toy Cost', item.toysCost),
            if (item.moneyPullingCost > 0)
              _priceRow('  + Money Pulling', item.moneyPullingCost),
          ],
        ],
      ),
    );
  }
}

class _TItem {
  final String name, size, variant, designCode, moneyPullingNote, itemId;
  final String? designFrom;
  final int qty, toysCost, moneyPullingCost;

  _TItem({
    required this.name,
    required this.size,
    required this.variant,
    required this.qty,
    required this.designCode,
    required this.designFrom,
    required this.toysCost,
    required this.moneyPullingCost,
    required this.moneyPullingNote,
    required this.itemId,
  });
}
