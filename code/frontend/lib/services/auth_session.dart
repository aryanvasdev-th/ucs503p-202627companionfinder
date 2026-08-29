/// Holds the JWT for the current app run, set on successful login.
/// In-memory only for now — closing the app requires logging in again.
class AuthSession {
  AuthSession._();

  static String? token;
  static String? userId;

  static Map<String, String> get authHeaders =>
      token == null ? {} : {'Authorization': 'Bearer $token'};
}
