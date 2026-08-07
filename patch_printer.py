import re

with open("lib/bluetooth_printer_service.dart", "r") as f:
    content = f.read()

# Sanitize cutter commands to fix the "VB" bug
sanitize = """      String cutterCmd = settings.cutterCommands;
      if (cutterCmd == '0A,0A,56,42,00' || cutterCmd.contains('56,42')) {
        cutterCmd = '1D,56,42,00';
      }

      if (cutterCmd.isNotEmpty) {
        bytes += _parseHexCommands(cutterCmd);"""

old_cutter = """      if (settings.cutterCommands.isNotEmpty) {
        bytes += _parseHexCommands(settings.cutterCommands);"""

if old_cutter in content:
    content = content.replace(old_cutter, sanitize)
    with open("lib/bluetooth_printer_service.dart", "w") as f:
        f.write(content)
    print("Patched BluetoothPrinterService cutterCommands.")
else:
    print("Could not find cutterCommands in bluetooth_printer_service.dart")

# Also fix models.dart default
with open("lib/models.dart", "r") as f:
    models_content = f.read()
models_content = models_content.replace("'0A,0A,56,42,00'", "'1D,56,42,00'")
with open("lib/models.dart", "w") as f:
    f.write(models_content)
