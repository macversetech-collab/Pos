import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# 1. Revert gradient
target_gradient = """                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealLight,
                                ],"""
replacement_gradient = """                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealMain,
                                ],"""
content = content.replace(target_gradient, replacement_gradient)

# 2. Revert border
target_border = """                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : AppColors.mintGreen.withValues(alpha: 0.5),"""
replacement_border = """                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : Colors.tealAccent.withValues(alpha: 0.4),"""
content = content.replace(target_border, replacement_border)

# 3. Revert collapsed text row
target_collapsed = """                          : Row(
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

replacement_collapsed = """                          : Row(
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
content = content.replace(target_collapsed, replacement_collapsed)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
