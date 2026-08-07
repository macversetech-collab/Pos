with open("lib/bluetooth_printer_service.dart", "r") as f:
    content = f.read()

# For printRasterizedReceiptImage
old_init = """      if (settings.initialCommands.isNotEmpty) {
        bytes += _parseHexCommands(settings.initialCommands);
      }
      if (settings.drawerCommands.isNotEmpty) {
        bytes += _parseHexCommands(settings.drawerCommands);
      }"""

new_init = """      String initCmd = settings.initialCommands.replaceAll('0A,0A,56,42,00', '').replaceAll('56,42', '');
      if (initCmd.isNotEmpty) {
        bytes += _parseHexCommands(initCmd);
      }
      String drawCmd = settings.drawerCommands.replaceAll('0A,0A,56,42,00', '').replaceAll('56,42', '');
      if (drawCmd.isNotEmpty) {
        bytes += _parseHexCommands(drawCmd);
      }"""

content = content.replace(old_init, new_init)

with open("lib/bluetooth_printer_service.dart", "w") as f:
    f.write(content)
print("Patched VB from all commands.")
