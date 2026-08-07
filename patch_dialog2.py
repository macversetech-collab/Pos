with open("lib/widgets/digital_voucher_dialog.dart", "r") as f:
    content = f.read()

import_line = "import 'package:flutter/foundation.dart';\nimport '../utils/download_helper.dart';"
if "import '../utils/download_helper.dart';" not in content:
    content = content.replace("import 'package:flutter/foundation.dart';", import_line)

# Replace the save logic
old_save = """      await Gal.putImageBytes(
        pngBytes,
        name: "Customer_Voucher_${widget.order.orderNumber}",
      );"""

new_save = """      if (kIsWeb) {
        await downloadImageWeb(pngBytes, "Customer_Voucher_${widget.order.orderNumber}");
      } else {
        await Gal.putImageBytes(
          pngBytes,
          name: "Customer_Voucher_${widget.order.orderNumber}",
        );
      }"""

if old_save in content:
    content = content.replace(old_save, new_save)
    with open("lib/widgets/digital_voucher_dialog.dart", "w") as f:
        f.write(content)
    print("Patched digital_voucher_dialog.dart with web download support.")
else:
    print("Could not find the Gal.putImageBytes block.")
