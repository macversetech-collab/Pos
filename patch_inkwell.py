import os

files = [
    "lib/tabs/calendar_tab.dart",
    "lib/tabs/printer_connect_tab.dart",
    "lib/tabs/counter_showline_tab.dart"
]

for file_path in files:
    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            content = f.read()

        # Add import
        if "import '../widgets/scale_button.dart';" not in content:
            if "import '../models.dart';" in content:
                content = content.replace("import '../models.dart';", "import '../models.dart';\nimport '../widgets/scale_button.dart';")
            else:
                content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../widgets/scale_button.dart';")

        # Replace InkWell( with ScaleButton(
        content = content.replace("InkWell(", "ScaleButton(")

        with open(file_path, "w") as f:
            f.write(content)

print("Replaced InkWell with ScaleButton in all tabs.")
