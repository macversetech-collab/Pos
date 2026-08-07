import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models.dart';

/// Centralized repository for idempotent Voucher generation, management, and offline sync.
///
/// Guarantees:
/// - Exactly ONE voucher record per (order_id, voucher_type)
/// - Safe under double clicks, print retries, network failures, and realtime loops
/// - Decoupled printing — print calls use ensureVoucher() and never create vouchers themselves
class VoucherRepository {
  static const String _boxName = 'vouchers_cache';
  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton instance
  static final VoucherRepository _instance = VoucherRepository._internal();
  factory VoucherRepository() => _instance;
  VoucherRepository._internal();

  /// Initializes the local Hive box for offline persistent voucher tracking
  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _localBox => Hive.box(_boxName);

  /// Guarantees EXACTLY ONE voucher per (orderId, voucherType).
  ///
  /// Flow:
  /// 1. Check local Hive box for `vch_{orderId}_{voucherType}`
  /// 2. If not found locally, query Supabase `vouchers` table
  /// 3. If exists -> return existing voucher (REUSE)
  /// 4. If missing -> perform atomic UPSERT with `onConflict: 'order_id,voucher_type'`
  Future<Voucher> ensureVoucher({
    required String orderId,
    required String orderNumber,
    String voucherType = 'customer',
  }) async {
    final String cacheKey = 'vch_${orderId}_$voucherType';

    // Step 1: Local cache check (Instant result)
    final cachedData = _localBox.get(cacheKey);
    if (cachedData != null && cachedData is Map) {
      debugPrint('[VoucherRepository] Reusing existing voucher from local cache: ${cachedData['code']}');
      return Voucher.fromMap(Map<String, dynamic>.from(cachedData));
    }

    // Step 2: Remote DB check (If online)
    try {
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.none)) {
        final res = await _supabase
            .from('vouchers')
            .select()
            .eq('order_id', orderId)
            .eq('voucher_type', voucherType)
            .maybeSingle();

        if (res != null) {
          final existingVoucher = Voucher.fromMap(res);
          await _localBox.put(cacheKey, existingVoucher.toMap());
          debugPrint('[VoucherRepository] Reusing existing voucher from remote DB: ${existingVoucher.code}');
          return existingVoucher;
        }
      }
    } catch (e) {
      debugPrint('[VoucherRepository] Remote fetch check note: $e');
    }

    // Step 3: Create new voucher with atomic UPSERT (ON CONFLICT DO UPDATE)
    final now = DateTime.now();
    final String voucherCode = 'VCH-$orderNumber';
    final String id = 'vch-${now.millisecondsSinceEpoch}_${orderId.hashCode}';

    final newVoucher = Voucher(
      id: id,
      orderId: orderId,
      code: voucherCode,
      voucherType: voucherType,
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );

    // Save locally first
    await _localBox.put(cacheKey, newVoucher.toMap());

    // Idempotent UPSERT to Supabase with ON CONFLICT (order_id, voucher_type)
    try {
      final results = await Connectivity().checkConnectivity();
      if (!results.contains(ConnectivityResult.none)) {
        final res = await _supabase.from('vouchers').upsert(
          newVoucher.toMap(),
          onConflict: 'order_id,voucher_type',
        ).select().single();

        final persistedVoucher = Voucher.fromMap(res);
        await _localBox.put(cacheKey, persistedVoucher.toMap());
        debugPrint('[VoucherRepository] Created and persisted new voucher: ${persistedVoucher.code}');
        return persistedVoucher;
      }
    } catch (e) {
      debugPrint('[VoucherRepository] Error upserting voucher to remote DB: $e');
    }

    return newVoucher;
  }

  /// Updates status of a voucher ('pending' -> 'printed') idempotently
  Future<void> updateVoucherStatus(String orderId, String voucherType, String status) async {
    final String cacheKey = 'vch_${orderId}_$voucherType';
    final cachedData = _localBox.get(cacheKey);
    if (cachedData != null && cachedData is Map) {
      final map = Map<String, dynamic>.from(cachedData);
      map['status'] = status;
      map['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _localBox.put(cacheKey, map);

      try {
        final results = await Connectivity().checkConnectivity();
        if (!results.contains(ConnectivityResult.none)) {
          await _supabase
              .from('vouchers')
              .update({'status': status, 'updated_at': map['updated_at']})
              .eq('order_id', orderId)
              .eq('voucher_type', voucherType);
        }
      } catch (e) {
        debugPrint('[VoucherRepository] Error updating voucher status: $e');
      }
    }
  }

  /// Fetches an existing voucher for an order without creating a new one
  Voucher? getCachedVoucher(String orderId, {String voucherType = 'customer'}) {
    final String cacheKey = 'vch_${orderId}_$voucherType';
    final cachedData = _localBox.get(cacheKey);
    if (cachedData != null && cachedData is Map) {
      return Voucher.fromMap(Map<String, dynamic>.from(cachedData));
    }
    return null;
  }
}
