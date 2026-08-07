import re

with open("lib/main.dart", "r") as f:
    content = f.read()

# I will replace the BottomNavigationBar with the new icon styling.
old_nav_search = """                items: [
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

new_nav_builder = """                items: [
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(Icons.shopping_cart_rounded, Icons.shopping_cart_outlined, activeIndex == 0),
                    label: 'Order',
                  ),
                  if (!isCompactScreen)
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.bar_chart_rounded, Icons.bar_chart_outlined, activeIndex == 1),
                      label: 'Sales',
                    ),
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(Icons.calendar_month_rounded, Icons.calendar_month_outlined, activeIndex == (isCompactScreen ? 1 : 2)),
                    label: 'Calendar',
                  ),
                  if (!isCompactScreen)
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.storefront_rounded, Icons.storefront_outlined, activeIndex == 3),
                      label: 'Counter & Showline',
                    ),
                  BottomNavigationBarItem(
                    icon: _buildNavIcon(Icons.print_rounded, Icons.print_outlined, activeIndex == (isCompactScreen ? 2 : 4)),
                    label: 'Printer',
                  ),
                  if (!isCompactScreen)
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.settings_rounded, Icons.settings_outlined, activeIndex == 5),
                      label: 'Configurator',
                    ),
                ],"""

helper_method = """  Widget _buildNavIcon(IconData activeIcon, IconData inactiveIcon, bool isActive) {
    return AnimatedScale(
      scale: isActive ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF00796B).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          isActive ? activeIcon : inactiveIcon,
          color: isActive ? const Color(0xFF00796B) : const Color(0xFF78909C).withOpacity(0.7),
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {"""

if old_nav_search in content:
    content = content.replace(old_nav_search, new_nav_builder)
    
    # insert helper method
    content = content.replace("  @override\n  Widget build(BuildContext context) {", helper_method)
    
    # fix unselected label style (since the icon color is handled manually, we want label to match)
    nav_setup = """                currentIndex: activeIndex,
                selectedItemColor: const Color(0xFF00796B),
                unselectedItemColor: const Color(0xFF78909C),
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,"""
    new_nav_setup = """                currentIndex: activeIndex,
                selectedItemColor: const Color(0xFF00796B),
                unselectedItemColor: const Color(0xFF78909C).withOpacity(0.8),
                selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                backgroundColor: Colors.transparent,
                showUnselectedLabels: true,
                elevation: 0,
                type: BottomNavigationBarType.fixed,"""
    content = content.replace(nav_setup, new_nav_setup)
    
    with open("lib/main.dart", "w") as f:
        f.write(content)
    print("Nav bar patched successfully.")
else:
    print("Could not find old nav search text")

