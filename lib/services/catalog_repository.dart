import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';

class CatalogSnapshot {
  final List<CakeSize> sizes;
  final List<CakeItem> items;

  const CatalogSnapshot({required this.sizes, required this.items});
}

class CatalogRepository {
  static const String _boxName = 'catalog_cache';
  static const String _sizesKey = 'cake_sizes';
  static const String _itemsKey = 'cake_items';
  static const String _variantsKey = 'variants';
  static const String _refreshedAtKey = 'refreshed_at';

  static final CatalogRepository _instance = CatalogRepository._internal();
  factory CatalogRepository() => _instance;
  CatalogRepository._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  Future<CatalogSnapshot?>? _refreshInProgress;

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _box => Hive.box(_boxName);

  CatalogSnapshot getCachedCatalog() {
    return CatalogSnapshot(
      sizes: _readSizes(_box.get(_sizesKey)),
      items: _readItems(_box.get(_itemsKey)),
    );
  }

  List<Map<String, dynamic>> getCachedVariants(String itemId, String size) {
    final stored = _box.get(_variantsKey);
    if (stored is! List) return [];

    return stored
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where(
          (row) =>
              row['item_id']?.toString() == itemId &&
              row['size']?.toString() == size,
        )
        .toList();
  }

  Future<CatalogSnapshot?> refreshFromRemote() {
    final activeRefresh = _refreshInProgress;
    if (activeRefresh != null) return activeRefresh;

    final refresh = _performRemoteRefresh();
    _refreshInProgress = refresh;
    refresh.whenComplete(() {
      if (identical(_refreshInProgress, refresh)) {
        _refreshInProgress = null;
      }
    });
    return refresh;
  }

  Future<CatalogSnapshot?> _performRemoteRefresh() async {
    try {
      // Fetch the required catalog tables before changing the snapshot.
      final sizesResponse = await _supabase.from('cake_sizes').select();
      final itemsResponse = await _supabase.from('cake_items').select();

      final sizes = List<Map<String, dynamic>>.from(sizesResponse as List);
      final items = List<Map<String, dynamic>>.from(itemsResponse as List);

      // Sizes and items are required for a usable Sale catalog. Never replace
      // a valid snapshot with an empty or incomplete network response.
      if (sizes.isEmpty || items.isEmpty) {
        debugPrint(
          'CatalogRepository: Ignoring empty/incomplete remote catalog.',
        );
        return null;
      }

      final cachedVariants = _box.get(_variantsKey);
      dynamic variantsToStore = cachedVariants ?? <Map<String, dynamic>>[];
      try {
        final variantsResponse = await _supabase.from('variants').select();
        variantsToStore = List<Map<String, dynamic>>.from(
          variantsResponse as List,
        );
      } catch (e) {
        debugPrint(
          'CatalogRepository: Optional variants refresh failed; preserving cache: $e',
        );
      }

      await _box.putAll({
        _sizesKey: sizes,
        _itemsKey: items,
        _variantsKey: variantsToStore,
        _refreshedAtKey: DateTime.now().toUtc().toIso8601String(),
      });

      return CatalogSnapshot(
        sizes: _readSizes(sizes),
        items: _readItems(items),
      );
    } catch (e) {
      debugPrint('CatalogRepository: Remote refresh failed: $e');
      return null;
    }
  }

  List<CakeSize> _readSizes(dynamic stored) {
    if (stored is! List) return [];
    try {
      return stored.whereType<Map>().map((row) {
        final data = Map<String, dynamic>.from(row);
        return CakeSize(
          id: data['id'] as String,
          name: data['name'] as String,
          basePrice: (data['base_price'] as num).toInt(),
        );
      }).toList();
    } catch (e) {
      debugPrint('CatalogRepository: Invalid cached cake sizes: $e');
      return [];
    }
  }

  List<CakeItem> _readItems(dynamic stored) {
    if (stored is! List) return [];
    try {
      return stored.whereType<Map>().map((row) {
        final data = Map<String, dynamic>.from(row);
        final pricing = Map<dynamic, dynamic>.from(data['pricing'] as Map);
        return CakeItem(
          id: data['id'] as String,
          name: data['name'] as String,
          sizes: List<String>.from(data['sizes'] as List),
          variants: List<String>.from(data['variants'] as List),
          pricing: pricing.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          ),
        );
      }).toList();
    } catch (e) {
      debugPrint('CatalogRepository: Invalid cached cake items: $e');
      return [];
    }
  }
}
