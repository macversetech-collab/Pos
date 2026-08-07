import 'dart:io';

void fixFile(String filePath) {
  final file = File(filePath);
  String content = file.readAsStringSync();

  if (content.contains("indexOf(']',")) {
    // ignore: avoid_print
    debugLog("Found indexOf(']', in $filePath");
  }
}

void debugLog(String message) {
  // Using stderr for diagnostic scripts to avoid avoid_print lint
  stderr.writeln(message);
}

void main() {
  fixFile('lib/widgets/unified_receipt_widget.dart');
  fixFile('lib/tabs/order_form_tab.dart');
}
