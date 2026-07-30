import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A signed-in staff member. The staff token is scoped to a single restaurant,
/// so the name and slug travel with it rather than being fetched separately -
/// `/api/staff/login` already returns both.
class StaffSession {
  const StaffSession({required this.token, required this.restaurantName, required this.restaurantSlug});

  factory StaffSession.fromJson(Map<String, dynamic> json) => StaffSession(
    token: json['token'] as String,
    restaurantName: json['restaurantName'] as String,
    restaurantSlug: json['restaurantSlug'] as String,
  );

  final String token;
  final String restaurantName;
  final String restaurantSlug;

  Map<String, dynamic> toJson() => {'token': token, 'restaurantName': restaurantName, 'restaurantSlug': restaurantSlug};
}

/// Keeps the staff token in the platform keystore/keychain rather than plain
/// shared preferences. Kitchen/Waiter mode is deliberately *not* stored: every
/// session picks a mode fresh.
class AuthStore {
  static const _key = 'snapodr_staff_session';
  static const _storage = FlutterSecureStorage();

  static Future<StaffSession?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return StaffSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A token written by an older build; drop it and make the user sign in.
      await clear();
      return null;
    }
  }

  static Future<void> save(StaffSession session) => _storage.write(key: _key, value: jsonEncode(session.toJson()));

  static Future<void> clear() => _storage.delete(key: _key);
}
