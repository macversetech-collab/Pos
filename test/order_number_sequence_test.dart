import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

Future<String> generateNextOrderNumberTest(Box box, List<String> remoteOrderNumbers) async {
  final now = DateTime.now();
  final dateStr =
      "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
  final prefix = 'ASH-$dateStr-';

  final Set<String> existingOrderNumbers = {};

  final allCached = box.toMap();
  for (var entry in allCached.entries) {
    if (entry.key == 'DRAFT_ORDER_STATE') continue;
    if (entry.value is Map) {
      final Map data = entry.value as Map;
      final String? numStr = data['order_number'] as String?;
      if (numStr != null && numStr.isNotEmpty) {
        existingOrderNumbers.add(numStr);
      }
    }
  }

  existingOrderNumbers.addAll(remoteOrderNumbers);

  int maxSeq = 0;
  final regExp = RegExp(r'^ASH-' + dateStr + r'-(\d+)$');

  for (var numStr in existingOrderNumbers) {
    if (numStr.startsWith(prefix)) {
      final match = regExp.firstMatch(numStr);
      if (match != null) {
        final seq = int.tryParse(match.group(1)!) ?? 0;
        if (seq > maxSeq) {
          maxSeq = seq;
        }
      }
    }
  }

  int nextSeq = maxSeq + 1;
  String candidate = '$prefix${nextSeq.toString().padLeft(3, '0')}';

  while (existingOrderNumbers.contains(candidate)) {
    nextSeq++;
    candidate = '$prefix${nextSeq.toString().padLeft(3, '0')}';
  }

  return candidate;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_dir_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Test A: Create 3 new orders sequentially', () async {
    final box = await Hive.openBox('orders_cache');
    final now = DateTime.now();
    final dateStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    final num1 = await generateNextOrderNumberTest(box, []);
    expect(num1, equals('ASH-$dateStr-001'));
    await box.put('ord-1', {'id': 'ord-1', 'order_number': num1});

    final num2 = await generateNextOrderNumberTest(box, []);
    expect(num2, equals('ASH-$dateStr-002'));
    await box.put('ord-2', {'id': 'ord-2', 'order_number': num2});

    final num3 = await generateNextOrderNumberTest(box, []);
    expect(num3, equals('ASH-$dateStr-003'));
    await box.put('ord-3', {'id': 'ord-3', 'order_number': num3});
  });

  test('Test B: App restart sequence continuation', () async {
    final box = await Hive.openBox('orders_cache');
    final now = DateTime.now();
    final dateStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    await box.put('ord-10', {'id': 'ord-10', 'order_number': 'ASH-$dateStr-001'});
    await box.put('ord-11', {'id': 'ord-11', 'order_number': 'ASH-$dateStr-002'});
    await box.put('ord-12', {'id': 'ord-12', 'order_number': 'ASH-$dateStr-003'});

    final nextNum = await generateNextOrderNumberTest(box, []);
    expect(nextNum, equals('ASH-$dateStr-004'));
  });

  test('Test C: Backward compatibility with legacy order numbers', () async {
    final box = await Hive.openBox('orders_cache');
    final now = DateTime.now();
    final dateStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    await box.put('ord-old1', {'id': 'ord-old1', 'order_number': 'KB-20260628-01'});
    await box.put('ord-old2', {'id': 'ord-old2', 'order_number': 'ASH-20260725-37'});

    expect((box.get('ord-old1') as Map)['order_number'], equals('KB-20260628-01'));
    expect((box.get('ord-old2') as Map)['order_number'], equals('ASH-20260725-37'));

    final newNum = await generateNextOrderNumberTest(box, []);
    expect(newNum, equals('ASH-$dateStr-001'));
  });

  test('Test D: Collision safety check', () async {
    final box = await Hive.openBox('orders_cache');
    final now = DateTime.now();
    final dateStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    final remoteNumbers = ['ASH-$dateStr-001', 'ASH-$dateStr-002'];

    final nextNum = await generateNextOrderNumberTest(box, remoteNumbers);
    expect(nextNum, equals('ASH-$dateStr-003'));
  });
}
