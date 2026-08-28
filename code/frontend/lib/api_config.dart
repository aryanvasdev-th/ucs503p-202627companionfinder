// api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Your Mac's LAN IP — required for a physical phone on the same wifi
  /// (localhost on-device means the phone itself, not your Mac). Update this
  /// if your Mac's IP changes (check with `ipconfig getifaddr en0`).
  static const String _lanHost = '192.168.31.18';

  /// Picks the right host per platform automatically:
  /// - Web -> runs on your Mac, so localhost reaches it directly.
  /// - Android emulator -> 10.0.2.2 is its special alias for the host machine.
  /// - iOS Simulator / physical iPhone -> your Mac's LAN IP (works for both,
  ///   since the simulator shares the host's network too).
  /// Once deployed, swap for your hosted URL.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5001/api/auth';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001/api/auth';
    }
    return 'http://$_lanHost:5001/api/auth';
  }
}
