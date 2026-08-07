import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _boxName = 'auth_cache';
  final SupabaseClient _supabase = Supabase.instance.client;

  // Singleton instance
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Initializes the local Hive Box for caching auth details
  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Box get _localBox => Hive.box(_boxName);

  /// Performs user sign in via Supabase, fetches their profile, and caches the details locally.
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        // Fetch user profile from public.profiles table
        final profileData = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null) {
          final String role = profileData['role']?.toString() ?? 'staff';
          final String? shopId = profileData['shop_id']?.toString();
          final String name = profileData['name']?.toString() ?? email;

          // Cache auth profile details locally
          await _localBox.put('role', role);
          await _localBox.put('shop_id', shopId);
          await _localBox.put('email', email);
          await _localBox.put('name', name);

          // Cache last logged-in user details (persists after logout)
          await _localBox.put('last_role', role);
          await _localBox.put('last_shop_id', shopId);
          await _localBox.put('last_email', email);
          await _localBox.put('last_name', name);
          await _localBox.put('last_login_timestamp', DateTime.now().toIso8601String());

          return {
            'role': role,
            'shop_id': shopId,
            'email': email,
            'name': name,
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('AuthService: Login error: $e');
      rethrow;
    }
  }

  /// Logs out the user from Supabase and clears local cache details.
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('AuthService: Supabase signOut error: $e');
    } finally {
      await _localBox.delete('role');
      await _localBox.delete('shop_id');
      await _localBox.delete('email');
      await _localBox.delete('name');
    }
  }

  /// Check current auth state: returns role if authenticated
  Future<String?> checkCurrentRole() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        // Unauthenticated, clear session details just in case
        await _localBox.delete('role');
        await _localBox.delete('shop_id');
        await _localBox.delete('email');
        await _localBox.delete('name');
        return null;
      }

      // Check if we already have the role cached locally (fast path / offline path)
      final cachedRole = _localBox.get('role') as String?;
      if (cachedRole != null) {
        return cachedRole;
      }

      // Fallback: If session exists but role is not cached (e.g. first boot or cache cleared)
      final user = session.user;
      final profileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null) {
        final String role = profileData['role']?.toString() ?? 'staff';
        final String? shopId = profileData['shop_id']?.toString();
        final String name = profileData['name']?.toString() ?? user.email ?? '';

        await _localBox.put('role', role);
        await _localBox.put('shop_id', shopId);
        await _localBox.put('email', user.email);
        await _localBox.put('name', name);

        return role;
      }
    } catch (e) {
      debugPrint('AuthService: Check auth error: $e');
      // If error occurs (e.g. offline and profile fetch fails), fallback to cached role if available
      final cachedRole = _localBox.get('role') as String?;
      if (cachedRole != null) {
        return cachedRole;
      }
    }
    return null;
  }

  /// Get locally cached user details
  String? getCachedRole() => _localBox.get('role') as String?;
  String? getCachedShopId() => _localBox.get('shop_id') as String?;
  String? getCachedEmail() => _localBox.get('email') as String?;
  String? getCachedName() => _localBox.get('name') as String?;

  /// Get last logged-in user details
  String? getLastEmail() => _localBox.get('last_email') as String?;
  String? getLastName() => _localBox.get('last_name') as String?;
  String? getLastRole() => _localBox.get('last_role') as String?;
  String? getLastShopId() => _localBox.get('last_shop_id') as String?;
  String? getLastLoginTimestamp() => _localBox.get('last_login_timestamp') as String?;
}
