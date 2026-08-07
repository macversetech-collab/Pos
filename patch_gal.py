import re

with open("lib/widgets/digital_voucher_dialog.dart", "r") as f:
    content = f.read()

content = content.replace("import 'package:image_gallery_saver/image_gallery_saver.dart';", "import 'package:gal/gal.dart';")

old_gal = """      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "Customer_Voucher_${widget.order.orderNumber}",
      );

      if (mounted) {
        if (result != null && result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voucher saved to gallery successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save voucher: $result')),
          );
        }
      }"""

new_gal = """      await Gal.putImageBytes(
        pngBytes,
        name: "Customer_Voucher_${widget.order.orderNumber}",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voucher saved to gallery successfully!')),
        );
      }"""

content = content.replace(old_gal, new_gal)

with open("lib/widgets/digital_voucher_dialog.dart", "w") as f:
    f.write(content)
