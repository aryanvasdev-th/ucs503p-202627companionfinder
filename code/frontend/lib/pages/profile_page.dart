import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';

/// Placeholder — no reference design or backend for profile data yet.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: const AppTopBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Text('A', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 14),
                  Text('Your Name', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text('you@thapar.edu', style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5, color: extras.text2)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _MenuTile(icon: Icons.event_available_outlined, label: 'My Activities'),
            _MenuTile(icon: Icons.notifications_outlined, label: 'Notifications'),
            _MenuTile(icon: Icons.settings_outlined, label: 'Settings'),
            _MenuTile(icon: Icons.logout_rounded, label: 'Log Out'),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: extras.text2),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.5, fontWeight: FontWeight.w600))),
          Icon(Icons.chevron_right_rounded, color: extras.text3),
        ],
      ),
    );
  }
}
