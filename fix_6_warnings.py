import re

with open("lib/tabs/calendar_tab.dart", "r") as f:
    content = f.read()

# 1. unused endTimestampUtc
content = content.replace("final String endTimestampUtc = endLocal.toUtc().toIso8601String();\n", "")

# 2. unused nextMonthStr
content = content.replace("final String nextMonthStr =\n          \"${nextMonthDate.year}-${nextMonthDate.month.toString().padLeft(2, '0')}-01\";\n", "")

# 3. unused endFilterStr
content = content.replace("final String endFilterStr = \"${endY}-${endM.toString().padLeft(2, '0')}-01\";\n", "")

# 4. & 5. unnecessary braces
content = content.replace('"${prevY}-${prevM.toString().padLeft(2, \'0\')}-01"', '"$prevY-${prevM.toString().padLeft(2, \'0\')}-01"')
content = content.replace('"${endY}-${endM.toString().padLeft(2, \'0\')}-01"', '"$endY-${endM.toString().padLeft(2, \'0\')}-01"')

with open("lib/tabs/calendar_tab.dart", "w") as f:
    f.write(content)

with open("lib/tabs/dashboard_tab.dart", "r") as f:
    content = f.read()

# 6. unnecessary braces
content = content.replace('final endStr = "${nextYear}-${nextMonth.toString().padLeft(2, \'0\')}-01T00:00:00";', 'final endStr = "$nextYear-${nextMonth.toString().padLeft(2, \'0\')}-01T00:00:00";')

with open("lib/tabs/dashboard_tab.dart", "w") as f:
    f.write(content)
