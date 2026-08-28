import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Shared top bar: "Companion" wordmark on the left, theme toggle, bell, SOS.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBellTap;
  final VoidCallback? onSosTap;

  const AppTopBar({super.key, this.onBellTap, this.onSosTap});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text(
              'Companion',
              style: theme.textTheme.titleLarge?.copyWith(
                color: extras.brandInk,
                fontSize: 20,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => ThemeController.toggle(theme.brightness),
              icon: Icon(
                theme.brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              color: theme.colorScheme.onSurface,
            ),
            IconButton(
              onPressed: onBellTap,
              icon: const Icon(Icons.notifications_outlined),
              color: theme.colorScheme.onSurface,
            ),
            _SosPill(onTap: onSosTap),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

class _SosPill extends StatelessWidget {
  final VoidCallback? onTap;
  const _SosPill({this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.shield_outlined, size: 13, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
