import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuration stored per channel key so reconnectAll() can re-create channels
/// with the same table and callback after a token refresh.
class _ChannelConfig {
  final String table;
  final String schema;
  final void Function(PostgresChangePayload payload) onChange;

  _ChannelConfig({
    required this.table,
    required this.onChange,
    this.schema = 'public',
  });
}

/// Centralized singleton manager for ALL Supabase realtime channels.
///
/// Guarantees:
/// - One channel per unique key (no duplicates)
/// - Race-condition-safe reconnection via async mutex
/// - Automatic reconnect on JWT token refresh
/// - Channel-isolated cleanup (never removeAllChannels)
/// - Debug logging only — no UI errors exposed
///
/// Usage:
/// ```dart
/// // Subscribe
/// await RealtimeManager().subscribe(
///   key: 'calendar',
///   table: 'orders',
///   onChange: (payload) => _refreshOrders(),
/// );
///
/// // Unsubscribe
/// await RealtimeManager().unsubscribe('calendar');
/// ```
class RealtimeManager {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------
  static final RealtimeManager _instance = RealtimeManager._internal();
  factory RealtimeManager() => _instance;

  RealtimeManager._internal() {
    _setupAuthListener();
  }

  // ---------------------------------------------------------------------------
  // Core state
  // ---------------------------------------------------------------------------
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Active channels keyed by caller-provided unique key.
  final Map<String, RealtimeChannel> _channels = {};

  /// Stored configs so we can re-subscribe after reconnect.
  final Map<String, _ChannelConfig> _configs = {};

  /// Prevents overlapping reconnect cycles.
  bool _isReconnecting = false;

  /// Auth state listener subscription.
  StreamSubscription<AuthState>? _authSub;

  // ---------------------------------------------------------------------------
  // Auth state listener — triggers reconnect on token refresh
  // ---------------------------------------------------------------------------
  void _setupAuthListener() {
    _authSub?.cancel();
    _authSub = _supabase.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        debugPrint('[RealtimeManager] Auth event: $event');

        if (event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('[RealtimeManager] Token refreshed → reconnecting all channels…');
          reconnectAll();
        }
      },
      onError: (e) {
        debugPrint('[RealtimeManager] Auth listener error: $e');
      },
    );
    debugPrint('[RealtimeManager] Auth state listener initialized.');
  }

  // ---------------------------------------------------------------------------
  // Subscribe — creates (or replaces) a single channel for the given key
  // ---------------------------------------------------------------------------

  /// Subscribes to Postgres changes on [table] under the unique [key].
  ///
  /// If a channel with the same [key] already exists it is unsubscribed first,
  /// guaranteeing at most one channel per key.
  Future<void> subscribe({
    required String key,
    required String table,
    required void Function(PostgresChangePayload payload) onChange,
    String schema = 'public',
  }) async {
    // Store config for reconnect
    _configs[key] = _ChannelConfig(
      table: table,
      onChange: onChange,
      schema: schema,
    );

    // Remove existing channel for this key (safe no-op if absent)
    await _removeChannel(key);

    // Create new channel
    final channelName = 'realtime:$key';
    debugPrint('[RealtimeManager] Creating channel "$channelName" for table "$table"');

    final channel = _supabase.channel(channelName);

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: schema,
      table: table,
      callback: (payload) {
        debugPrint('[RealtimeManager] [$key] Change event: ${payload.eventType}');
        onChange(payload);
      },
    );

    channel.subscribe((status, error) {
      debugPrint('[RealtimeManager] [$key] Status: $status${error != null ? ' Error: $error' : ''}');

      if (status == RealtimeSubscribeStatus.channelError) {
        _handleChannelError(key);
      }
    });

    _channels[key] = channel;
    debugPrint('[RealtimeManager] [$key] Subscribed successfully.');
  }

  // ---------------------------------------------------------------------------
  // Unsubscribe — safely removes a single channel by key
  // ---------------------------------------------------------------------------

  /// Unsubscribes and removes the channel associated with [key].
  /// Also removes its stored config so it won't be re-created on reconnect.
  Future<void> unsubscribe(String key) async {
    await _removeChannel(key);
    _configs.remove(key);
    debugPrint('[RealtimeManager] [$key] Unsubscribed and config removed.');
  }

  // ---------------------------------------------------------------------------
  // Reconnect all — tear down every channel, then re-subscribe using configs
  // ---------------------------------------------------------------------------

  /// Disconnects all channels and re-subscribes them using stored configs.
  /// Protected by [_isReconnecting] mutex to prevent overlapping reconnects.
  Future<void> reconnectAll() async {
    if (_isReconnecting) {
      debugPrint('[RealtimeManager] Reconnect already in progress — skipping.');
      return;
    }
    _isReconnecting = true;

    try {
      debugPrint('[RealtimeManager] Reconnecting ${_channels.length} channel(s)…');

      // 1. Unsubscribe all active channels
      final keys = List<String>.from(_channels.keys);
      for (final key in keys) {
        await _removeChannel(key);
      }

      // 2. Small delay for token propagation
      await Future.delayed(const Duration(milliseconds: 300));

      // 3. Re-subscribe using stored configs
      final configEntries = Map<String, _ChannelConfig>.from(_configs);
      for (final entry in configEntries.entries) {
        await subscribe(
          key: entry.key,
          table: entry.value.table,
          onChange: entry.value.onChange,
          schema: entry.value.schema,
        );
      }

      debugPrint('[RealtimeManager] All channels reconnected.');
    } catch (e) {
      debugPrint('[RealtimeManager] Reconnect error (silent): $e');
    } finally {
      _isReconnecting = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Removes a channel by key without clearing its config (used during reconnect).
  Future<void> _removeChannel(String key) async {
    final channel = _channels.remove(key);
    if (channel == null) return;

    try {
      await _supabase.removeChannel(channel);
      debugPrint('[RealtimeManager] [$key] Channel removed.');
    } catch (e) {
      debugPrint('[RealtimeManager] [$key] Error removing channel: $e');
    }
  }

  /// Handles channel errors by scheduling a reconnect for the specific key.
  void _handleChannelError(String key) {
    debugPrint('[RealtimeManager] [$key] Channel error — scheduling reconnect…');

    // Delay briefly to avoid tight retry loops
    Future.delayed(const Duration(seconds: 2), () {
      reconnectAll();
    });
  }

  // ---------------------------------------------------------------------------
  // Cleanup (for app lifecycle if needed)
  // ---------------------------------------------------------------------------

  /// Tears down all channels and the auth listener.
  /// Call this only on full app shutdown — NOT on individual screen disposal.
  Future<void> disposeAll() async {
    _authSub?.cancel();
    _authSub = null;

    final keys = List<String>.from(_channels.keys);
    for (final key in keys) {
      await _removeChannel(key);
    }
    _configs.clear();

    debugPrint('[RealtimeManager] Fully disposed — all channels and listeners cleaned up.');
  }
}
