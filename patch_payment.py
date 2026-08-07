import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# 1. Replace the Payment UI section
old_payment_ui = """                    children: [
                      if (isCompact) ...[
                        AnchoredDropdown<String>(
                          initialValue: _paymentStatus,
                          decoration: AppDecorations.input(
                            labelText: 'Payment Status',
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _paymentStatus = val;
                                if (val == 'fully_paid') {
                                  _depositPaid = liveTotal;
                                }
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: 'deposit',
                              child: Text('စရံပေး'),
                            ),
                            DropdownMenuItem(
                              value: 'fully_paid',
                              child: Text('ရှင်းပြီး'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey(
                            'deposit-paid-$_paymentStatus-$liveTotal-v',
                          ),
                          initialValue: _depositPaid > 0
                              ? _depositPaid.toString()
                              : '',
                          enabled: _paymentStatus == 'deposit',
                          keyboardType: TextInputType.number,
                          decoration: AppDecorations.input(
                            labelText: 'Deposit Amount (စရံငွေပမာဏ)',
                          ),
                          onChanged: (val) {
                            setState(() {
                              _depositPaid = int.tryParse(val) ?? 0;
                            });
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: AnchoredDropdown<String>(
                                initialValue: _paymentStatus,
                                decoration: AppDecorations.input(
                                  labelText: 'Payment Status',
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _paymentStatus = val;
                                      if (val == 'fully_paid') {
                                        _depositPaid = liveTotal;
                                      }
                                    });
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 'deposit',
                                    child: Text('စရံပေး'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'fully_paid',
                                    child: Text('ရှင်းပြီး'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                key: ValueKey(
                                  'deposit-paid-$_paymentStatus-$liveTotal-h',
                                ),
                                initialValue: _depositPaid > 0
                                    ? _depositPaid.toString()
                                    : '',
                                enabled: _paymentStatus == 'deposit',
                                keyboardType: TextInputType.number,
                                decoration: AppDecorations.input(
                                  labelText: 'Deposit Amount (စရံငွေပမာဏ)',
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _depositPaid = int.tryParse(val) ?? 0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      AnchoredDropdown<String>(
                        initialValue: _isKpay ? 'Kpay' : 'Cash',
                        decoration: AppDecorations.input(
                          labelText: 'Payment Method',
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _isKpay = (val == 'Kpay');
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                          DropdownMenuItem(value: 'Kpay', child: Text('Kpay')),
                        ],
                      ),
                    ],"""

new_payment_ui = """                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _paymentStatus == 'deposit' 
                                  ? const Color(0xFF00796B) 
                                  : Colors.white.withOpacity(0.5),
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
                                  : Colors.white.withOpacity(0.5),
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
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.5)),
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
                                '${_depositPaid} MMK',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00796B), fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],"""

if old_payment_ui not in content:
    print("Error: Could not find old payment UI to replace!")
else:
    content = content.replace(old_payment_ui, new_payment_ui)

# 2. Insert helper methods right before `Widget build(BuildContext context)`
helpers = """  void _showDepositBottomSheet(BuildContext context, int liveTotal) {
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
  Widget build(BuildContext context) {"""

content = content.replace("  @override\n  Widget build(BuildContext context) {", helpers)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
print("Patch applied.")
