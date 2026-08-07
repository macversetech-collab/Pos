import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

start_index = content.find("            // FLOATING ACTION PILL")
end_index = content.find("          ],", start_index)
end_index = content.find("        ),", end_index)
end_index = content.find("      ),", end_index)
end_index = content.find("    );", end_index)

print(content[start_index:end_index+6])
