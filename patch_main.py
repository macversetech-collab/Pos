import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# 1. Imports
if "import 'dart:ui';" not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'dart:ui';\nimport 'widgets/fade_indexed_stack.dart';"
    )

# 2. Body
content = content.replace(
    "child: IndexedStack(index: activeIndex, children: tabs)",
    "child: FadeIndexedStack(index: activeIndex, children: tabs)"
)

# 3. BottomNavigationBar container
old_navbar = """        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BottomNavigationBar("""

new_navbar = """        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: BottomNavigationBar("""

content = content.replace(old_navbar, new_navbar)

# 4. AnimatedScale for icons
# We need to wrap each Icon(...) in the items list with AnimatedScale.
# Let's just do a manual replace of the items list since it's short.
old_items = """                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.add_shopping_cart_outlined),
                    activeIcon: Icon(Icons.add_shopping_cart),
                    label: 'Order',
                  ),
                  if (!isCompactScreen)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.analytics_outlined),
                      activeIcon: Icon(Icons.analytics),
                      label: 'Sales',
                    ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_outlined),
                    activeIcon: Icon(Icons.calendar_month),
                    label: 'Calendar',
                  ),
                  if (!isCompactScreen)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.storefront_outlined),
                      activeIcon: Icon(Icons.storefront),
                      label: 'Counter & Showline',
                    ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.print_outlined),
                    activeIcon: Icon(Icons.print),
                    label: 'Printer',
                  ),
                  if (!isCompactScreen)
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.settings_outlined),
                      activeIcon: Icon(Icons.settings),
                      label: 'Configurator',
                    ),
                ],"""

new_items = """                items: [
                  BottomNavigationBarItem(
                    icon: AnimatedScale(
                      scale: activeIndex == 0 ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(activeIndex == 0 ? Icons.add_shopping_cart : Icons.add_shopping_cart_outlined),
                    ),
                    label: 'Order',
                  ),
                  if (!isCompactScreen)
                    BottomNavigationBarItem(
                      icon: AnimatedScale(
                        scale: activeIndex == 1 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(activeIndex == 1 ? Icons.analytics : Icons.analytics_outlined),
                      ),
                      label: 'Sales',
                    ),
                  BottomNavigationBarItem(
                    icon: AnimatedScale(
                      scale: activeIndex == (isCompactScreen ? 1 : 2) ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(activeIndex == (isCompactScreen ? 1 : 2) ? Icons.calendar_month : Icons.calendar_month_outlined),
                    ),
                    label: 'Calendar',
                  ),
                  if (!isCompactScreen)
                    BottomNavigationBarItem(
                      icon: AnimatedScale(
                        scale: activeIndex == 3 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(activeIndex == 3 ? Icons.storefront : Icons.storefront_outlined),
                      ),
                      label: 'Counter & Showline',
                    ),
                  BottomNavigationBarItem(
                    icon: AnimatedScale(
                      scale: activeIndex == (isCompactScreen ? 2 : 4) ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: Icon(activeIndex == (isCompactScreen ? 2 : 4) ? Icons.print : Icons.print_outlined),
                    ),
                    label: 'Printer',
                  ),
                  if (!isCompactScreen)
                    BottomNavigationBarItem(
                      icon: AnimatedScale(
                        scale: activeIndex == 5 ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(activeIndex == 5 ? Icons.settings : Icons.settings_outlined),
                      ),
                      label: 'Configurator',
                    ),
                ],"""

content = content.replace(old_items, new_items)

# Add closing tags for the BackdropFilter and Container around the BottomNavigationBar
old_bottom_end = """                ],
              ),
            ),
          ),
        ),
      ),
    );"""

new_bottom_end = """                ],
              ),
                ),
              ),
            ),
          ),
        ),
      ),
    );"""

content = content.replace(old_bottom_end, new_bottom_end)

with open("lib/main.dart", "w") as f:
    f.write(content)
print("Updated main.dart successfully.")
