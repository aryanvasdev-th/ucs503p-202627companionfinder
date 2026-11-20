import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The logged-in user's token, kept in memory for requests and saved in the
/// phone's secure storage (iOS Keychain / Android encrypted storage) so the
/// app stays logged in after it's closed — until the token expires (7 days)
/// or the user logs out.
class AuthSession {
  AuthSession._();

  static String? token;
  static String? userId;

  /// The app's maker (set server-side via ADMIN_EMAILS). Only decides which
  /// buttons show; every admin action is checked again by the server.
  static bool isAdmin = false;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _adminKey = 'auth_is_admin';

  static Map<String, String> get authHeaders =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

  /// Remembers the current login. Best-effort: if secure storage fails, the
  /// user is still logged in for this run.
  static Future<void> persist() async {
    if (token == null) return;
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userIdKey, value: userId);
      await _storage.write(key: _adminKey, value: isAdmin ? '1' : '0');
    } catch (_) {}
  }

  /// Loads a saved login into memory. Returns true if there was one.
  static Future<bool> restore() async {
    try {
      token = await _storage.read(key: _tokenKey);
      userId = await _storage.read(key: _userIdKey);
      isAdmin = (await _storage.read(key: _adminKey)) == '1';
    } catch (_) {
      token = null;
    }
    return token != null && userId != null;
  }

  /// Logs out: forgets the login in memory and on the device.
  static Future<void> clear() async {
    token = null;
    userId = null;
    isAdmin = false;
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
