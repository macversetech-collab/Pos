import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class ClosureRepository {
  static const String _boxName = 'closures_cache';
  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton instance
  static final ClosureRepository _instance = ClosureRepository._internal();
  factory ClosureRepository() => _instance;
  ClosureRepository._internal();

  /// Initializes local Hive Database Box and pulls from Supabase
  Future<void> init() async {
    await Hive.openBox(_boxName);
    // Do not block app startup on network sync
    syncDown();
  }

  Box get _localBox => Hive.box(_boxName);

  /// Synchronously get a closure for a specific date from local cache
  /// Returns a Map containing start_time, end_time, reason, etc., or null if none
  Map<dynamic, dynamic>? getClosureForDate(String date) {
    return _localBox.get(date) as Map<dynamic, dynamic>?;
  }

  /// Get all cached closures synchronously
  List<Map<dynamic, dynamic>> getAllCachedClosures() {
    final all = _localBox.toMap();
    final List<Map<dynamic, dynamic>> result = [];
    for (var entry in all.entries) {
      if (entry.value is Map) {
        final Map data = entry.value as Map;
        // Keep the date as part of the map
        final mapWithDate = Map<dynamic, dynamic>.from(data);
        mapWithDate['date'] = entry.key;
        result.add(mapWithDate);
      }
    }
    // Sort by date descending
    result.sort((a, b) {
      final String dateA = a['date'] ?? '';
      final String dateB = b['date'] ?? '';
      return dateB.compareTo(dateA);
    });
    return result;
  }

  /// Pulls all active closures from Supabase and overwrites local cache
  Future<void> syncDown() async {
    try {
      final res = await _supabase.from('shop_closures').select();
      
      // Clear existing local cache and refill
      await _localBox.clear();
      for (var row in res) {
        final date = row['date'] as String;
        // The value map holds all other details
        await _localBox.put(date, {
          'id': row['id'],
          'start_time': row['start_time'],
          'end_time': row['end_time'],
          'reason': row['reason'],
        });
      }
      debugPrint('Closures synced down from Supabase: ${res.length} items');
    } catch (e) {
      debugPrint('Failed to sync closures from Supabase: $e');
    }
  }

  Future<String?> addClosure({
    required String date,
    required String startTime,
    required String endTime,
    String reason = '',
  }) async {
    try {
      final random = Random();
      String hex(int length) => List.generate(length, (_) => random.nextInt(16).toRadixString(16)).join();
      final localId = '${hex(8)}-${hex(4)}-4${hex(3)}-a${hex(3)}-${hex(12)}';

      final insertData = {
        'id': localId,
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'reason': reason,
      };

      final res = await _supabase.from('shop_closures').insert(insertData).select().single();
      
      // Update local cache
      await _localBox.put(date, {
        'id': res['id'],
        'start_time': res['start_time'],
        'end_time': res['end_time'],
        'reason': res['reason'],
      });
      return null;
    } catch (e) {
      debugPrint('Error adding closure: $e');
      return e.toString();
    }
  }

  /// Deletes a closure from Supabase and removes it from local cache
  Future<bool> deleteClosure(String id, String date) async {
    try {
      await _supabase.from('shop_closures').delete().eq('id', id);
      await _localBox.delete(date);
      return true;
    } catch (e) {
      debugPrint('Error deleting closure: $e');
      return false;
    }
  }
}
