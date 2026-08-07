import os

files = [
    "lib/tabs/calendar_tab.dart",
    "lib/tabs/counter_showline_tab.dart",
    "lib/tabs/order_form_tab.dart",
    "lib/tabs/settings_tab.dart"
]

for file_path in files:
    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            content = f.read()

        # Add import if replacing
        if "DropdownButtonFormField" in content:
            if "import '../widgets/anchored_dropdown.dart';" not in content:
                if "import '../models.dart';" in content:
                    content = content.replace("import '../models.dart';", "import '../models.dart';\nimport '../widgets/anchored_dropdown.dart';")
                else:
                    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../widgets/anchored_dropdown.dart';")

            content = content.replace("DropdownButtonFormField", "AnchoredDropdown")

        with open(file_path, "w") as f:
            f.write(content)

print("Replaced DropdownButtonFormField with AnchoredDropdown in all tabs.")
