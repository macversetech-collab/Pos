with open("lib/widgets/digital_voucher_dialog.dart", "r") as f:
    content = f.read()

import_lines = "import 'package:flutter/foundation.dart';\nimport '../utils/download_helper.dart';\n"
content = import_lines + content

with open("lib/widgets/digital_voucher_dialog.dart", "w") as f:
    f.write(content)
print("Added imports")
