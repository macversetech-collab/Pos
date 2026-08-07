import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    original = f.read()

with open("extracted.dart", "r") as f:
    replacement = f.read()

start_idx = -1
end_idx = -1
lines = original.splitlines(True)
for i, line in enumerate(lines):
    if "// FLOATING ACTION PILL" in line:
        start_idx = i
    if start_idx != -1 and "    );\n" == line and "  }\n" == lines[i+1]:
        end_idx = i
        break

new_lines = lines[:start_idx] + [replacement] + lines[end_idx+1:]
new_content = "".join(new_lines)

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(new_content)
