import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    original = f.read()

start_idx = original.find("            // FLOATING ACTION PILL")
end_idx = original.find("    );\n  }\n}", start_idx)

if start_idx != -1 and end_idx != -1:
    with open("extracted_pill.dart", "w") as f:
        f.write(original[start_idx:end_idx+6])
    print("Extracted successfully.")
else:
    print("Could not find block.")
