import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# 1. Expandable card header
old_expandable = """            child: InkWell(
              onTap: () {
                setState(() {
                  _isOptionalExpanded = !_isOptionalExpanded;
                });
              },
              borderRadius: BorderRadius.circular(14.0),
              child: Container("""

new_expandable = """            child: ScaleButton(
              onTap: () {
                setState(() {
                  _isOptionalExpanded = !_isOptionalExpanded;
                });
              },
              child: Container("""

content = content.replace(old_expandable, new_expandable)

# 2. Confirm button in floating pill
# Elevated button
old_button = """                                          Expanded(
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.tealMain,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        12.0,
                                                      ),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                              ),
                                              onPressed: _submitForm,
                                              child: Text(
                                                widget.initialOrder != null
                                                    ? 'Apply & Reprint'
                                                    : 'Confirm & Print',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),"""

new_button = """                                          Expanded(
                                            child: ScaleButton(
                                              onTap: _submitForm,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.tealMain,
                                                  borderRadius: BorderRadius.circular(12.0),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    widget.initialOrder != null
                                                        ? 'Apply & Reprint'
                                                        : 'Confirm & Print',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),"""

content = content.replace(old_button, new_button)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
print("Updated order form with ScaleButton.")
