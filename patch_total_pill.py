import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# We need to find the entire SafeArea that builds the total pill.
# It starts with '              alignment: Alignment.bottomCenter,'
# and ends right before the closing brace of the Stack.
# We'll use regex to isolate it safely.

pattern = r"(?<=              alignment: Alignment.bottomCenter,\n              child: SafeArea\().*?(?=\n            \),\n          \],\n        \),\n      \),\n    \);\n  \})"

match = re.search(pattern, content, flags=re.DOTALL)
if match:
    old_block = match.group(0)
    
    new_block = """
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
                                        ],
                                        Expanded(
                                          child: ScaleButton(
                                            onTap: _submitForm,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12.0),
                                              ),
                                              child: Center(
                                                child: Text(
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
                )"""

    content = content[:match.start()] + new_block + content[match.end():]
    with open("lib/tabs/order_form_tab.dart", "w") as f:
        f.write(content)
    print("Replaced Total Pill implementation.")
else:
    print("Failed to find Total Pill block.")

