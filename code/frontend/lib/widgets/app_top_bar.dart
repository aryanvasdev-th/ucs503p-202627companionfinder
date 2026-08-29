import 'package:flutter/material.dart';

import '../services/notifications_state.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Shared top bar: "Companion" wordmark on the left, theme toggle, bell, SOS.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onBellTap;

  const AppTopBar({super.key, this.onBellTap});

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
            ValueListenableBuilder<int>(
              valueListenable: NotificationsState.unreadCount,
              builder: (context, count, _) => Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onBellTap,
                    icon: const Icon(Icons.notifications_outlined),
                    color: theme.colorScheme.onSurface,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const _SosPill(),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

/// Disabled until the emergency-contact + Twilio SMS flow is wired up —
/// styled as muted/inactive rather than the live brand color so it doesn't
/// read as a working safety feature before it actually is one.
class _SosPill extends StatelessWidget {
  const _SosPill();

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS isn\'t set up yet — coming soon')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: extras.field,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, size: 13, color: extras.text2),
            const SizedBox(width: 4),
            Text(
              'SOS',
              style: TextStyle(
                color: extras.text2,
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
