import re

with open("lib/tabs/calendar_tab.dart", "r") as f:
    content = f.read()

# Replace unused endLocal block that failed to match earlier due to spacing
content = re.sub(r'      final DateTime endLocal = DateTime\(\s*targetYear,\s*targetMonth,\s*daysInMonth,\s*23,\s*59,\s*59,\s*999,\s*\);\s*', '', content)

content = content.replace("    int nextM = _currentMonth == 12 ? 1 : _currentMonth + 1;\n    int nextY = _currentMonth == 12 ? _currentYear + 1 : _currentYear;\n", "")

with open("lib/tabs/calendar_tab.dart", "w") as f:
    f.write(content)
