import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# 1. Imports
if "import 'dart:async';" not in content:
    content = content.replace("import 'dart:ui';", "import 'dart:ui';\nimport 'dart:async';")
if "import '../services/order_repository.dart';" not in content:
    content = content.replace("import '../app_theme.dart';", "import '../app_theme.dart';\nimport '../services/order_repository.dart';")

# 2. Add Timer and _scheduleDraftSave
draft_methods = """
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
"""
content = content.replace("  bool _isTotalExpanded = false;", "  bool _isTotalExpanded = false;\n" + draft_methods)

# 3. Restore draft in _resetForm
# Find the 'else {' block in _resetForm which initializes a new order.
# We will inject checking for draft there.

old_new_order_init = """    } else {
      final now = DateTime.now();
      _id = 'ord-${now.millisecondsSinceEpoch}';"""

new_new_order_init = """    } else {
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
        _id = 'ord-${now.millisecondsSinceEpoch}';"""

content = content.replace(old_new_order_init, new_new_order_init)

# We must close the added else block after the original new order initialization
old_new_order_end = """      _deliveryCost = 0;
    }"""
new_new_order_end = """      _deliveryCost = 0;
      }
    }"""
content = content.replace(old_new_order_end, new_new_order_end, 1)

# 4. Add clearDraft in _submitForm
old_submit = """      // The parent widget (main.dart) will handle resetting the form
      // by changing the ValueKey of OrderEntryFormTab upon successful submission.
      widget.onSubmit(outOrder);"""

new_submit = """      if (widget.initialOrder == null) {
        OrderRepository().clearDraft();
      }
      // The parent widget (main.dart) will handle resetting the form
      // by changing the ValueKey of OrderEntryFormTab upon successful submission.
      widget.onSubmit(outOrder);"""

content = content.replace(old_submit, new_submit)

# 5. Wrap Form with onChanged
old_form = """        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Stack("""
        
new_form = """        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        onChanged: _scheduleDraftSave,
        child: Stack("""

content = content.replace(old_form, new_form)

# 6. Also add _scheduleDraftSave to setState blocks for custom fields
# Find setState blocks that update state and don't trigger form onChanged (like date pickers, item adding)
# I will just replace all `setState(() {` with `setState(() { _scheduleDraftSave();` inside this file?
# No, some setStates are for UI (like _isTotalExpanded). We just want data.
# But it's easier and harmless to schedule draft save on any setState in OrderEntryFormTab, since it's debounced and checks if it's a new order.
# Actually, let's explicitly inject it in a few key places: date picker, time picker, calculateTotalPrice
content = content.replace("void calculateTotalPrice() {", "void calculateTotalPrice() {\n    _scheduleDraftSave();")

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)

print("order_form_tab updated")
