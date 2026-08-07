import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

target = """            // STATIC BOTTOM ACTION BANNER (Responsive & Safe layout)
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + (MediaQuery.of(context).viewInsets.bottom > 0
                    ? 0.0
                    : (MediaQuery.of(context).padding.bottom + 84.0)),
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24.0),
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: isCompact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL:',
                              style: TextStyle(
                                color: AppColors.tealDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '${liveTotal.toLocaleString()} MMK',
                              style: const TextStyle(
                                color: AppColors.tealDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _paymentStatus == 'fully_paid'
                              ? 'STATUS: ရှင်းပြီး'
                              : 'STATUS: စရံပေး (DUE: ${liveRemaining.toLocaleString()} MMK)',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: _paymentStatus == 'fully_paid'
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.initialOrder != null) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _resetForm();
                                  });
                                  widget.onCancel();
                                },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.tealMain,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: _submitForm,
                                child: Text(
                                  widget.initialOrder != null
                                      ? 'Apply & Reprint'
                                      : 'Confirm & Print',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL: ${liveTotal.toLocaleString()} MMK',
                                style: const TextStyle(
                                  color: AppColors.tealDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _paymentStatus == 'fully_paid'
                                    ? 'STATUS: ရှင်းပြီး'
                                    : 'STATUS: စရံပေး (DUE: ${liveRemaining.toLocaleString()} MMK)',
                                style: TextStyle(
                                  color: _paymentStatus == 'fully_paid'
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.initialOrder != null) ...[
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _resetForm();
                              });
                              widget.onCancel();
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.tealMain,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _submitForm,
                          child: Text(
                            widget.initialOrder != null
                                ? 'Apply & Reprint'
                                : 'Confirm & Print (2 Copies)',
                          ),
                        ),
                      ],
                    ),
            ),"""

replacement = """            // FLOATING ACTION PILL
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16.0 : 84.0, 
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
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(_isTotalExpanded ? 24.0 : 32.0),
                        border: Border.all(
                          color: AppColors.tealMain.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: _isTotalExpanded
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'TOTAL:',
                                      style: TextStyle(
                                        color: AppColors.tealDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${liveTotal.toLocaleString()} MMK',
                                      style: const TextStyle(
                                        color: AppColors.tealDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _paymentStatus == 'fully_paid'
                                      ? 'STATUS: ရှင်းပြီး'
                                      : 'STATUS: စရံပေး (DUE: ${liveRemaining.toLocaleString()} MMK)',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _paymentStatus == 'fully_paid'
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontSize: 10,
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
                                          widget.onCancel();
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.tealMain,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        onPressed: _submitForm,
                                        child: Text(
                                          widget.initialOrder != null
                                              ? 'Apply & Reprint'
                                              : 'Confirm & Print',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined, color: AppColors.tealMain, size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        color: AppColors.tealDark,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${liveTotal.toLocaleString()} MMK',
                                      style: const TextStyle(
                                        color: AppColors.tealDark,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.keyboard_arrow_up, color: AppColors.tealMain, size: 20),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),"""

content = content.replace(target, replacement)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)

