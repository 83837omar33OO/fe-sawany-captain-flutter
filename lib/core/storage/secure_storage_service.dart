import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const String _keyToken = "captain_auth_token";
  static const String _keyRiderId = "captain_rider_id";
  static const String _keyRiderName = "captain_rider_name";
  static const String _keyRiderPhone = "captain_rider_phone";
  static const String _keyRiderZone = "captain_rider_zone";

  static Future<void> saveSession({
    required String token,
    required String id,
    required String name,
    required String phone,
    String? zone,
  }) async {
    try {
      await _storage.write(key: _keyToken, value: token);
      await _storage.write(key: _keyRiderId, value: id);
      await _storage.write(key: _keyRiderName, value: name);
      await _storage.write(key: _keyRiderPhone, value: phone);
      if (zone != null) await _storage.write(key: _keyRiderZone, value: zone);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      await prefs.setString(_keyRiderId, id);
      await prefs.setString(_keyRiderName, name);
      await prefs.setString(_keyRiderPhone, phone);
      if (zone != null) await prefs.setString(_keyRiderZone, zone);
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    }
  }

  static Future<Map<String, String?>> getRiderProfile() async {
    try {
      return {
        "id": await _storage.read(key: _keyRiderId),
        "name": await _storage.read(key: _keyRiderName),
        "phone": await _storage.read(key: _keyRiderPhone),
        "zone": await _storage.read(key: _keyRiderZone),
      };
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return {
        "id": prefs.getString(_keyRiderId),
        "name": prefs.getString(_keyRiderName),
        "phone": prefs.getString(_keyRiderPhone),
        "zone": prefs.getString(_keyRiderZone),
      };
    }
  }

  static Future<void> clearSession() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
