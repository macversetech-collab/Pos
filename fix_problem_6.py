import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# 1. Fix the gradient colors to match "dark teal -> lighter mint teal" (tealDark -> tealLight)
target_gradient = """                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealMain,
                                ],"""

replacement_gradient = """                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealLight,
                                ],"""

content = content.replace(target_gradient, replacement_gradient)

# 2. Fix the subtle mint border highlight
target_border = """                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : Colors.tealAccent.withValues(alpha: 0.4),"""

replacement_border = """                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : AppColors.mintGreen.withValues(alpha: 0.5),"""

content = content.replace(target_border, replacement_border)

# 3. Replace the collapsed text with exact string "TOTAL: XXX MMK"
target_collapsed = """                          : Row(
                              key: const ValueKey('collapsed'),
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
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
                                const SizedBox(width: 24),
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
                                    const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                                  ],
                                ),
                              ],
                            ),"""

replacement_collapsed = """                          : Row(
                              key: const ValueKey('collapsed'),
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'TOTAL: ${liveTotal.toLocaleString()} MMK',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                              ],
                            ),"""

content = content.replace(target_collapsed, replacement_collapsed)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
