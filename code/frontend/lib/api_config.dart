// api_config.dart
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// The laptop running the backend, passed in at build time so nobody has
  /// to edit this file when its IP changes (it's handed out by the campus
  /// wifi and moves around):
  ///
  ///   flutter run --dart-define=API_HOST=$(ipconfig getifaddr en0)
  ///   flutter build apk --dart-define=API_HOST=172.16.x.x
  ///
  /// When set, every platform uses it — phones, simulators and emulators.
  static const String _hostOverride = String.fromEnvironment('API_HOST');

  /// Full server address instead of a LAN host, e.g. a tunnel or hosted
  /// backend: --dart-define=API_URL=https://example.trycloudflare.com
  /// Needed off-LAN: campus wifi isolates devices from each other, so
  /// phones can't reach the laptop's LAN IP directly. Takes priority.
  static const String _urlOverride = String.fromEnvironment('API_URL');

  /// Fallback when no API_HOST is given. Update this if you'd rather not
  /// pass --dart-define (check with `ipconfig getifaddr en0`).
  static const String _lanHost = '172.16.212.95';

  static const int _port = 5001;

  /// Without an override:
  /// - Web -> runs on the laptop, so localhost reaches it directly.
  /// - Android emulator (debug) -> 10.0.2.2 is its alias for the host machine.
  ///   A physical Android phone in debug mode needs API_HOST instead.
  /// - Everything else (iOS Simulator, iPhone, release Android) -> _lanHost.
  static String get apiRoot {
    if (_urlOverride.isNotEmpty) {
      return _urlOverride.endsWith('/')
          ? _urlOverride.substring(0, _urlOverride.length - 1)
          : _urlOverride;
    }
    if (_hostOverride.isNotEmpty) return 'http://$_hostOverride:$_port';
    if (kIsWeb) return 'http://localhost:$_port';
    if (!kReleaseMode && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_port';
    }
    return 'http://$_lanHost:$_port';
  }

  static String get baseUrl => '$apiRoot/api/auth';
}
