import re

with open("lib/tabs/calendar_tab.dart", "r") as f:
    content = f.read()

# 1. unused endLocal
target_end_local = """      final DateTime endLocal = DateTime(
        targetYear,
        targetMonth,
        daysInMonth,
        23,
        59,
        59,
        999,
      );"""
content = content.replace(target_end_local, "")

# 2. unused nextMonthDate
content = content.replace("final DateTime nextMonthDate = DateTime(targetYear, targetMonth + 1, 1);\n", "")

# 3. unused endM and endY
content = content.replace("int endM = nextM == 12 ? 1 : nextM + 1;\n    int endY = nextM == 12 ? nextY + 1 : nextY;\n", "")

with open("lib/tabs/calendar_tab.dart", "w") as f:
    f.write(content)
