import re

with open("lib/tabs/order_form_tab.dart", "r") as f:
    content = f.read()

# Replace DropdownButtonFormField<CakeItem>
content = content.replace("DropdownButtonFormField<CakeItem>", "BottomSheetDropdown<CakeItem>")
# Replace DropdownButtonFormField<CakeSize>
content = content.replace("DropdownButtonFormField<CakeSize>", "BottomSheetDropdown<CakeSize>")
# Replace DropdownButtonFormField<String>
content = content.replace("DropdownButtonFormField<String>", "BottomSheetDropdown<String>")
# Remove isExpanded: true,
content = content.replace("isExpanded: true,", "")

with open("lib/tabs/order_form_tab.dart", "w") as f:
    f.write(content)
