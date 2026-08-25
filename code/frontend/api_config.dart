// api_config.dart
class ApiConfig {
  // Android emulator -> 10.0.2.2 maps to your computer's localhost
  // iOS simulator -> localhost works directly
  // Physical phone on same wifi -> use your computer's local IP, e.g. 192.168.1.5
  // Once deployed -> swap this for your Render URL, e.g.:
  // 'https://campus-companion-backend.onrender.com/api/auth'
  static const String baseUrl = 'http://172.16.211.131:5001/api/auth';
}
