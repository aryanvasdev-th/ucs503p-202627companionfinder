import 'package:flutter/material.dart';

import 'startup_gate.dart';
import 'services/app_navigator.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/notification_popup.dart';

void main() {
  runApp(const CampusCompanion());
}

class CampusCompanion extends StatelessWidget {
  const CampusCompanion({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          builder: (context, child) =>
              NotificationPopupHost(child: child ?? const SizedBox.shrink()),
          title: 'Companion',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const StartupGate(),
        );
      },
    );
  }
}
