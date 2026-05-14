import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _userKey = 'novachat_current_user';
  static const _authKey = 'novachat_auth_state';
  static const _fcmKey = 'novachat_fcm_token';
  static const _themeKey = 'novachat_theme_mode';
  static const _notificationKey = 'novachat_notifications_enabled';

  // ─── Auth State ────────────────────────────────────────────
  Future<void> saveAuthState(String uid, bool isNewUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authKey, jsonEncode({
      'uid': uid,
      'isNewUser': isNewUser,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  Future<Map<String, dynamic>?> getAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_authKey);
    if (data == null) return null;
    // Check if session is stale (older than 7 days)
    final decoded = jsonDecode(data) as Map<String, dynamic>;
    final timestamp = decoded['timestamp'] as int? ?? 0;
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    if (age > 7 * 24 * 60 * 60 * 1000) {
      await clearAuthState();
      return null;
    }
    return decoded;
  }

  Future<void> clearAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    await prefs.remove(_userKey);
  }

  // ─── User Cache ────────────────────────────────────────────
  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(profile));
  }

  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userKey);
    if (data == null) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  // ─── FCM Token ──────────────────────────────────────────────
  Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmKey, token);
  }

  Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmKey);
  }

  // ─── Theme ──────────────────────────────────────────────────
  Future<void> saveThemeMode(int mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode);
  }

  Future<int> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeKey) ?? 0;
  }

  // ─── Notifications Toggle ───────────────────────────────────
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationKey, enabled);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationKey) ?? true;
  }
}