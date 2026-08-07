with open("lib/bluetooth_printer_service.dart", "r") as f:
    content = f.read()

# Remove targetSize to allow intrinsic height
content = content.replace("targetSize: Size(width, 2000.0),", "")
content = content.replace("targetSize: const Size(logicalWidth, 2000.0),", "")

with open("lib/bluetooth_printer_service.dart", "w") as f:
    f.write(content)
print("Removed fixed targetSize from BluetoothPrinterService.")
