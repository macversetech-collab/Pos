import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models.dart';

class OrderRepository {
  static const String _boxName = 'orders_cache';
  static const String _tombstoneBoxName = 'deleted_orders_tombstone';
  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton instance
  static final OrderRepository _instance = OrderRepository._internal();
  factory OrderRepository() => _instance;
  OrderRepository._internal();

  /// Initializes local Hive Database Boxes and sanitizes stuck printing states
  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    await Hive.openBox(_tombstoneBoxName);
    await _sanitizeStalePrintingStatus();
  }

  Box get _localBox => Hive.box(_boxName);
  Box get _tombstoneBox => Hive.box(_tombstoneBoxName);

  /// Marks an order ID as permanently deleted in local persistent tombstone storage
  Future<void> markAsDeleted(String id) async {
    try {
      await _tombstoneBox.put(id, true);
      debugPrint('Marked order ID as persistent tombstone deleted: $id');
    } catch (e) {
      debugPrint('Error marking order $id as tombstone deleted: $e');
    }
  }

  /// Returns all permanently deleted order IDs from persistent tombstone storage
  Set<String> getDeletedOrderIds() {
    try {
      return _tombstoneBox.keys.cast<String>().toSet();
    } catch (e) {
      debugPrint('Error fetching tombstone deleted order IDs: $e');
      return {};
    }
  }

  /// Sanitizes any order left in 'printing' status from an interrupted session
  Future<void> _sanitizeStalePrintingStatus() async {
    try {
      final allCached = _localBox.toMap();
      for (var entry in allCached.entries) {
        if (entry.key == 'DRAFT_ORDER_STATE') continue;
        if (entry.value is Map) {
          final Map data = entry.value as Map;
          if (data['print_status'] == 'printing') {
            final String id = entry.key as String;
            final updated = Map<String, dynamic>.from(data);
            updated['print_status'] = 'failed';
            updated['last_print_error'] = 'Print session interrupted (app closed or restarted).';
            updated['isSynced'] = false;
            await _localBox.put(id, updated);
            debugPrint('Sanitized stale printing status for order ID: $id -> set to failed');
          }
        }
      }
    } catch (e) {
      debugPrint('Error sanitizing stale printing status: $e');
    }
  }

  /// Generates a safe, non-colliding daily sequential order number (e.g. ASH-YYYYMMDD-001)
  /// Checks local Hive cache and remote Supabase database to guarantee uniqueness.
  Future<String> generateNextOrderNumber() async {
    final now = DateTime.now();
    final dateStr =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";
    final prefix = 'ASH-$dateStr-';

    final Set<String> existingOrderNumbers = {};

    // 1. Scan local Hive cache for existing order numbers
    try {
      final allCached = _localBox.toMap();
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
    } catch (e) {
      debugPrint('Error reading local cache for order number sequence: $e');
    }

    // 2. Fetch remote order numbers from Supabase if connected
    try {
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.none)) {
        final String todayStart =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final List res = await _supabase
            .from('orders')
            .select('order_number')
            .gte('delivery_date', todayStart)
            .timeout(const Duration(seconds: 5));
        for (var row in res) {
          final String? remoteNum = row['order_number'] as String?;
          if (remoteNum != null && remoteNum.isNotEmpty) {
            existingOrderNumbers.add(remoteNum);
          }
        }
      }
    } catch (e) {
      debugPrint('Note: Could not query remote orders for order number sequence: $e');
    }

    // 3. Find highest sequence number for today's date prefix
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

    // 4. Generate candidate sequence and verify collision safety
    int nextSeq = maxSeq + 1;
    String candidate = '$prefix${nextSeq.toString().padLeft(3, '0')}';

    while (existingOrderNumbers.contains(candidate)) {
      nextSeq++;
      candidate = '$prefix${nextSeq.toString().padLeft(3, '0')}';
    }

    return candidate;
  }

  /// Saves an order locally first (with isSynced = false), then attempts an online push if connected.
  Future<bool> saveOrder(Map<String, dynamic> orderData) async {
    debugPrint('DEBUG: saveOrder - size: "${orderData['size']}", phone: "${orderData['customer_phone']}", lettering: "${orderData['custom_lettering']}"');
    try {
      final String id = orderData['id'] as String;

      // Add local sync metadata
      final localData = Map<String, dynamic>.from(orderData);
      localData['isSynced'] = false;

      // Store in local Hive Box
      await _localBox.put(id, localData);
      debugPrint('Order saved locally. ID: $id');

      // Attempt immediate remote sync
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.none)) {
        await _pushOrderToRemote(id, orderData);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving order: $e');
      return false;
    }
  }

  /// Updates only the completion status (is_prep_only) of an existing order
  Future<void> updateOrderStatus(String id, bool isPrepOnly) async {
    try {
      final existingData = _localBox.get(id) as Map?;
      if (existingData != null) {
        final data = Map<String, dynamic>.from(existingData);
        data['is_prep_only'] = isPrepOnly;
        data['isSynced'] = false;
        await _localBox.put(id, data);
        
        final results = await Connectivity().checkConnectivity();
        if (!results.contains(ConnectivityResult.none)) {
          await _pushOrderToRemote(id, data);
        }
      } else {
        // Fallback for orders not currently cached in localBox
        final results = await Connectivity().checkConnectivity();
        if (!results.contains(ConnectivityResult.none)) {
          await _supabase
              .from('orders')
              .update({'is_prep_only': isPrepOnly})
              .eq('id', id);
        }
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  /// Updates print status and count for an existing order locally and attempts remote sync
  Future<void> updatePrintStatus(
    String id,
    String printStatus, {
    int? printCount,
    bool? customerPrinted,
    bool? kitchenPrinted,
    String? lastPrintError,
  }) async {
    try {
      final existingData = _localBox.get(id) as Map?;
      if (existingData != null) {
        final data = Map<String, dynamic>.from(existingData);
        data['print_status'] = printStatus;
        if (printCount != null) {
          data['print_count'] = printCount;
        }
        if (customerPrinted != null) {
          data['customer_printed'] = customerPrinted;
        }
        if (kitchenPrinted != null) {
          data['kitchen_printed'] = kitchenPrinted;
        }
        if (lastPrintError != null) {
          data['last_print_error'] = lastPrintError;
        }
        data['isSynced'] = false;
        await _localBox.put(id, data);

        final results = await Connectivity().checkConnectivity();
        if (!results.contains(ConnectivityResult.none)) {
          await _pushOrderToRemote(id, data);
        }
      } else {
        final results = await Connectivity().checkConnectivity();
        if (!results.contains(ConnectivityResult.none)) {
          final Map<String, dynamic> updatePayload = {
            'print_status': printStatus,
          };
          if (printCount != null) {
            updatePayload['print_count'] = printCount;
          }
          if (customerPrinted != null) {
            updatePayload['customer_printed'] = customerPrinted;
          }
          if (kitchenPrinted != null) {
            updatePayload['kitchen_printed'] = kitchenPrinted;
          }
          if (lastPrintError != null) {
            updatePayload['last_print_error'] = lastPrintError;
          }
          await _supabase.from('orders').update(updatePayload).eq('id', id);
        }
      }
    } catch (e) {
      debugPrint('Error updating print status: $e');
    }
  }

  /// Permanently deletes a single order from local Hive storage, tombstone, and Supabase DB.
  /// Returns `true` if remote deletion returned 1+ affected rows or local Hive record was cleared.
  Future<bool> deleteOrder(String id) async {
    debugPrint('=== deleteOrder: target ID "$id" ===');

    bool remoteDeleted = false;

    // 1. Delete from Supabase DB and chain .select() to verify deleted rows representation
    try {
      debugPrint('Executing Supabase DELETE with .select() for order ID: "$id"...');
      final List<dynamic> deleted = await _supabase
          .from('orders')
          .delete()
          .eq('id', id)
          .select();

      debugPrint('Deleted Supabase rows count: ${deleted.length}');

      if (deleted.isNotEmpty) {
        remoteDeleted = true;
        debugPrint('Successfully deleted order from Supabase: $id (Order Number: ${deleted.first['order_number']})');
      } else {
        debugPrint('Warning: 0 rows deleted from Supabase for order $id (RLS policy block or ID mismatch)');
      }
    } catch (e, stackTrace) {
      debugPrint('Error deleting order $id from Supabase: $e');
      debugPrint('Stacktrace: $stackTrace');
    }

    // 2. Delete local Hive record (if present) & mark persistent tombstone
    try {
      final bool inHive = _localBox.containsKey(id);
      await _localBox.delete(id);
      await markAsDeleted(id);
      debugPrint('Local Hive order record deleted and tombstoned: $id');
      if (remoteDeleted || inHive) {
        return true;
      }
    } catch (e) {
      debugPrint('Error clearing local Hive order $id: $e');
    }

    return remoteDeleted;
  }

  /// Permanently deletes all orders for a specific month from local Hive storage, tombstone, and Supabase DB
  Future<void> deleteOrdersForMonth(int year, int month) async {
    try {
      final String monthStr = month.toString().padLeft(2, '0');
      final String startStr = "$year-$monthStr-01";
      final int lastDay = DateTime(year, month + 1, 0).day;
      final String endStr = "$year-$monthStr-${lastDay.toString().padLeft(2, '0')}";

      final int nextMonthYear = month == 12 ? year + 1 : year;
      final int nextMonth = month == 12 ? 1 : month + 1;
      final String nextMonthStartStr = "$nextMonthYear-${nextMonth.toString().padLeft(2, '0')}-01";

      final keysToRemove = <dynamic>[];
      final allCached = _localBox.toMap();
      for (var entry in allCached.entries) {
        if (entry.key == 'DRAFT_ORDER_STATE') continue;

        String? delDate;
        if (entry.value is Map) {
          final Map data = entry.value as Map;
          delDate = data['delivery_date'] as String?;
        } else if (entry.value is Order) {
          delDate = (entry.value as Order).deliveryDate;
        }

        if (delDate != null && delDate.compareTo(startStr) >= 0 && delDate.compareTo(endStr) <= 0) {
          keysToRemove.add(entry.key);
        }
      }
      for (var k in keysToRemove) {
        await _localBox.delete(k);
        if (k is String) {
          await markAsDeleted(k);
        }
      }
      debugPrint('Cleared ${keysToRemove.length} month orders from Hive for $year-$monthStr');

      try {
        await _supabase
            .from('orders')
            .delete()
            .gte('delivery_date', startStr)
            .lt('delivery_date', nextMonthStartStr);
        debugPrint('Bulk month delete executed on Supabase orders table for $year-$monthStr');
      } catch (e) {
        debugPrint('Error deleting month orders from Supabase for $year-$monthStr: $e');
      }
    } catch (e) {
      debugPrint('Error in deleteOrdersForMonth ($year-$month): $e');
      rethrow;
    }
  }

  /// Returns all cached orders from Hive where isSynced == false
  List<Map<String, dynamic>> getUnsyncedOrders() {
    try {
      final allCached = _localBox.toMap();
      final deletedIds = getDeletedOrderIds();
      final List<Map<String, dynamic>> unsynced = [];
      for (var entry in allCached.entries) {
        if (entry.key == 'DRAFT_ORDER_STATE') continue;
        if (deletedIds.contains(entry.key)) continue;

        if (entry.value is Map) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(entry.value as Map);
          final String? id = data['id'] as String?;
          if (id != null && deletedIds.contains(id)) continue;

          if (data['isSynced'] == false) {
            unsynced.add(data);
          }
        }
      }
      return unsynced;
    } catch (e) {
      debugPrint('Error getting unsynced orders: $e');
      return [];
    }
  }

  /// Pushes a specific order to Supabase and updates local sync flag
  Future<void> _pushOrderToRemote(
    String id,
    Map<String, dynamic> orderData,
  ) async {
    try {
      // Remove any local metadata flags before sending to Supabase
      final remoteData = Map<String, dynamic>.from(orderData);
      remoteData.remove('isSynced');

      // Use onConflict to ensure idempotent insert — prevents duplicate
      // order_number rows even if called with different IDs.
      await _supabase.from('orders').upsert(
        remoteData,
        onConflict: 'order_number',
      ).timeout(const Duration(seconds: 5));

      // Update local storage flag to true
      final localData = Map<String, dynamic>.from(orderData);
      localData['isSynced'] = true;
      await _localBox.put(id, localData);
      debugPrint('Order synced successfully to database. ID: $id');
    } catch (e) {
      debugPrint(
        'Failed to push order $id to remote database: $e. Kept in offline queue.',
      );
    }
  }

  /// Iterates through local unsynced records and pushes them to Supabase
  Future<void> syncPendingOrders() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.none)) {
        debugPrint('Connectivity checked: Offline. Skipping sync.');
        return;
      }

      final allCached = _localBox.toMap();
      if (allCached.isEmpty) return;

      int syncCount = 0;
      for (var entry in allCached.entries) {
        final String id = entry.key as String;
        if (id == 'DRAFT_ORDER_STATE') continue;
        
        final Map<dynamic, dynamic> data = entry.value as Map;
        final bool isSynced = data['isSynced'] as bool? ?? false;

        if (!isSynced) {
          final cleanData = Map<String, dynamic>.from(data);
          await _pushOrderToRemote(id, cleanData);
          syncCount++;
        }
      }

      if (syncCount > 0) {
        debugPrint(
          'Sync cycle complete. Synchronized $syncCount pending orders.',
        );
      }
    } catch (e) {
      debugPrint('Error in sync cycle: $e');
    }
  }

  // --- Draft Order Persistence ---

  Future<void> saveDraft(Map<String, dynamic> draftData) async {
    try {
      await _localBox.put('DRAFT_ORDER_STATE', draftData);
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  Map<String, dynamic>? getDraft() {
    try {
      final data = _localBox.get('DRAFT_ORDER_STATE');
      if (data != null) {
        return Map<String, dynamic>.from(data as Map);
      }
    } catch (e) {
      debugPrint('Error getting draft: $e');
    }
    return null;
  }

  Future<void> clearDraft() async {
    try {
      await _localBox.delete('DRAFT_ORDER_STATE');
    } catch (e) {
      debugPrint('Error clearing draft: $e');
    }
  }
}
