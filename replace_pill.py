import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

target = """                      decoration: BoxDecoration(
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
                      ),"""

replacement = """                      decoration: BoxDecoration(
                        gradient: _isTotalExpanded
                            ? null
                            : const LinearGradient(
                                colors: [
                                  AppColors.tealDark,
                                  AppColors.tealMain,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isTotalExpanded ? Colors.white.withValues(alpha: 0.95) : null,
                        borderRadius: BorderRadius.circular(_isTotalExpanded ? 24.0 : 32.0),
                        border: Border.all(
                          color: _isTotalExpanded 
                              ? AppColors.tealMain.withValues(alpha: 0.2)
                              : Colors.tealAccent.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isTotalExpanded 
                                ? Colors.black.withValues(alpha: 0.1)
                                : AppColors.tealDark.withValues(alpha: 0.4),
                            blurRadius: _isTotalExpanded ? 15 : 12,
                            spreadRadius: _isTotalExpanded ? 0 : 2,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),"""

target_bottom = """                          : Row(
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
                            ),"""

replacement_bottom = """                          : Row(
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

content = content.replace(target, replacement)
content = content.replace(target_bottom, replacement_bottom)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)

