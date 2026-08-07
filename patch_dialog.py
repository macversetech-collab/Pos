with open("lib/widgets/digital_voucher_dialog.dart", "r") as f:
    content = f.read()

# Remove targetSize to allow intrinsic height
content = content.replace("targetSize: const Size(logicalWidth, 4000.0),", "")

with open("lib/widgets/digital_voucher_dialog.dart", "w") as f:
    f.write(content)
print("Removed fixed targetSize from digital_voucher_dialog.")
