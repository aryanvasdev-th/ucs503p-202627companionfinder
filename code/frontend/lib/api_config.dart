// api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Your Mac's LAN IP — required for a physical phone on the same wifi
  /// (localhost on-device means the phone itself, not your Mac). Update this
  /// if your Mac's IP changes (check with `ipconfig getifaddr en0`).
  static const String _lanHost = '172.16.212.56';

  /// Picks the right host per platform automatically:
  /// - Web -> runs on your Mac, so localhost reaches it directly.
  /// - Android emulator -> 10.0.2.2 is its special alias for the host machine.
  ///   (Only used in debug mode — a release build is always a real device,
  ///   e.g. a tester's phone, which needs the LAN IP like iOS does below.)
  /// - Everything else (iOS Simulator, physical iPhone, physical Android) ->
  ///   your Mac's LAN IP, since they're real network clients on the same wifi.
  /// Once deployed, swap for your hosted URL.
  static String get apiRoot {
    if (kIsWeb) return 'http://localhost:5001';
    if (!kReleaseMode && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5001';
    }
    return 'http://$_lanHost:5001';
  }

  static String get baseUrl => '$apiRoot/api/auth';
}
