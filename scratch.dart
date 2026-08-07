// ignore_for_file: avoid_print
void main() {
  var now = DateTime.now();
  var utcNow = now.toUtc();
  var parsed = DateTime.parse(utcNow.toIso8601String());
  
  var startClean = DateTime(now.year, now.month, now.day);
  var endClean = DateTime(now.year, now.month, now.day, 23, 59, 59);
  
  print('Now Local: $now');
  print('Now UTC: $utcNow');
  print('Parsed: $parsed');
  print('Start Clean: $startClean');
  print('End Clean: $endClean');
  print('Is After Start: ${parsed.isAfter(startClean.subtract(const Duration(seconds: 1)))}');
  print('Is Before End: ${parsed.isBefore(endClean.add(const Duration(seconds: 1)))}');
}
