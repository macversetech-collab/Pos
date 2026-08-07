// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';

Future<void> downloadImageWeb(Uint8List bytes, String filename) async {
  final base64Data = base64Encode(bytes);
  final uri = 'data:image/png;base64,$base64Data';
  html.AnchorElement(href: uri)
    ..setAttribute('download', '$filename.png')
    ..click();
}
