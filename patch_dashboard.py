with open("lib/tabs/dashboard_tab.dart", "r") as f:
    content = f.read()

if "import '../widgets/scale_button.dart';" not in content:
    content = content.replace(
        "import '../models.dart';",
        "import '../models.dart';\nimport '../widgets/scale_button.dart';"
    )

old_inkwell_1 = """                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVoucherOrder = ord;
                    });
                  },
                  child: Container("""

new_inkwell_1 = """                return ScaleButton(
                  onTap: () {
                    setState(() {
                      _selectedVoucherOrder = ord;
                    });
                  },
                  child: Container("""

content = content.replace(old_inkwell_1, new_inkwell_1)

old_inkwell_2 = """                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedVoucherOrder = ord;
                            });
                          },
                          child: Container("""

new_inkwell_2 = """                        ScaleButton(
                          onTap: () {
                            setState(() {
                              _selectedVoucherOrder = ord;
                            });
                          },
                          child: Container("""

content = content.replace(old_inkwell_2, new_inkwell_2)

old_elevated = """            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D241E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                widget.setActiveTab(0); // Jump to Order Form tab
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'New Order',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),"""

new_elevated = """            child: ScaleButton(
              onTap: () {
                widget.setActiveTab(0); // Jump to Order Form tab
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D241E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'New Order',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),"""

content = content.replace(old_elevated, new_elevated)

with open("lib/tabs/dashboard_tab.dart", "w") as f:
    f.write(content)
print("dashboard updated")
