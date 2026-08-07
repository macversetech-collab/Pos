import re

with open("lib/tabs/calendar_tab.dart", "r") as f:
    content = f.read()

# Replace unused endLocal block that failed to match earlier due to targetMonth + 1, 0,
content = re.sub(r'      final DateTime endLocal = DateTime\(\s*targetYear,\s*targetMonth \+ 1,\s*0,\s*23,\s*59,\s*59,\s*999,\s*\);\s*', '', content)

with open("lib/tabs/calendar_tab.dart", "w") as f:
    f.write(content)
