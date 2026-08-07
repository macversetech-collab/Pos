def replace_in_file(filepath, old_str, new_str, count=1):
    with open(filepath, "r") as f:
        content = f.read()
    if old_str in content:
        content = content.replace(old_str, new_str, count)
        with open(filepath, "w") as f:
            f.write(content)
        print(f"Updated {filepath}")
    else:
        print(f"String not found in {filepath}")

# 1. dashboard_tab.dart
# Main scroll
replace_in_file(
    "lib/tabs/dashboard_tab.dart",
    "        SingleChildScrollView(\n          padding: const EdgeInsets.all(16.0),",
    "        SingleChildScrollView(\n          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),"
)
# Voucher scroll
replace_in_file(
    "lib/tabs/dashboard_tab.dart",
    "                child: SingleChildScrollView(\n                  padding: const EdgeInsets.all(16.0),",
    "                child: SingleChildScrollView(\n                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),"
)

# 2. calendar_tab.dart
replace_in_file(
    "lib/tabs/calendar_tab.dart",
    "        return SingleChildScrollView(\n          padding: const EdgeInsets.all(16.0),",
    "        return SingleChildScrollView(\n          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),"
)

# 3. order_form_tab.dart
replace_in_file(
    "lib/tabs/order_form_tab.dart",
    "            SingleChildScrollView(\n              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),",
    "            SingleChildScrollView(\n              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 160.0),"
)

# 4. counter_showline_tab.dart
replace_in_file(
    "lib/tabs/counter_showline_tab.dart",
    "        child: SingleChildScrollView(\n          padding: const EdgeInsets.all(16.0),",
    "        child: SingleChildScrollView(\n          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),"
)

# 5. printer_connect_tab.dart
# Has two scaffolds depending on state:
replace_in_file(
    "lib/tabs/printer_connect_tab.dart",
    "      body: SingleChildScrollView(\n        padding: const EdgeInsets.all(16.0),",
    "      body: SingleChildScrollView(\n        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),",
    count=2
)

# 6. settings_tab.dart
replace_in_file(
    "lib/tabs/settings_tab.dart",
    "    return SingleChildScrollView(\n      padding: const EdgeInsets.all(16.0),",
    "    return SingleChildScrollView(\n      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),"
)
