import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# 1. Update the SingleChildScrollView with a Listener
# It starts around: child: SingleChildScrollView(
# We want to wrap it in a Listener.
old_scroll_view = """            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 160.0),"""
new_scroll_view = """            Listener(
              onPointerDown: (_) {
                if (_isTotalExpanded) {
                  setState(() => _isTotalExpanded = false);
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 160.0),"""

content = content.replace(old_scroll_view, new_scroll_view)

# 2. Update Size onChanged
old_size_on_changed = """                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        item.size = val;
                                        item.itemId = '';
                                        item.variant = '';
                                      });
                                      calculateTotalPrice();
                                    }
                                  },"""

new_size_on_changed = """                                  onChanged: (val) {
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
                                  },"""

content = content.replace(old_size_on_changed, new_size_on_changed)

# 3. Update Cake Item Choice items filter
old_cake_filter = """                                    items: widget.items
                                        .where(
                                          (cake) =>
                                              cake.sizes.contains(item.size),
                                        )"""

new_cake_filter = """                                    items: widget.items
                                        .where(
                                          (cake) =>
                                              cake.sizes.contains(item.size) || cake.id == item.itemId,
                                        )"""

content = content.replace(old_cake_filter, new_cake_filter)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
print("Patch applied.")
