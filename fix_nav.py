import re

with open("lib/main.dart", "r") as f:
    content = f.read()

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

"""

# Replace ONLY the first occurrence
content = content.replace(helper_method, "", 1)

with open("lib/main.dart", "w") as f:
    f.write(content)
