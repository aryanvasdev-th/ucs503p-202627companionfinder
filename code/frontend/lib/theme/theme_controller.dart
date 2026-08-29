import 'package:flutter/material.dart';

/// App-wide theme mode, switchable from the top bar toggle.
/// Starts following the system setting; toggling pins it explicitly.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static void toggle(Brightness currentBrightness) {
    mode.value = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}
