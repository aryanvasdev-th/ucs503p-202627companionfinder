import 'package:flutter/material.dart';

import '../login_page.dart';
import '../services/auth_session.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/verified_badge.dart';
import 'activity_history_page.dart';
import 'edit_profile_page.dart';
import 'emergency_contact_page.dart';
import 'notifications_page.dart';
import 'verify_id_page.dart';

/// Everything about your account that other people don't see: verification,
/// safety contact, history, notifications, appearance and logging out.
class SettingsPage extends StatelessWidget {
  final Map<String, dynamic> user;
  const SettingsPage({super.key, required this.user});

  bool get _isIdVerified => user['id_verification_status'] == 'verified';

  void _logOut(BuildContext context) {
    RealtimeService.disconnect();
    // Forget the saved login too, so the next launch shows the login page.
    AuthSession.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _Section('ACCOUNT'),
            _MenuTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              onTap: () => _push(context, EditProfilePage(user: user)),
            ),
            _MenuTile(
              icon: Icons.verified_outlined,
              label: _isIdVerified ? 'ID Verified' : 'Verify Thapar ID',
              trailing: _isIdVerified ? const VerifiedBadge(size: 18) : null,
              onTap: () =>
                  _push(context, VerifyIdPage(alreadyVerified: _isIdVerified)),
            ),
            _MenuTile(
              icon: Icons.shield_outlined,
              label: 'Emergency Contact',
              onTap: () => _push(context, EmergencyContactPage(user: user)),
            ),
            const _Section('ACTIVITY'),
            _MenuTile(
              icon: Icons.history_rounded,
              label: 'History',
              onTap: () => _push(context, const ActivityHistoryPage()),
            ),
            _MenuTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => _push(context, const NotificationsPage()),
            ),
            const _Section('APPEARANCE'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, _) => _MenuTile(
                icon: Icons.dark_mode_outlined,
                label: 'Dark mode',
                trailing: Switch(
                  value: theme.brightness == Brightness.dark,
                  onChanged: (dark) => ThemeController.mode.value = dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              onTap: () => _logOut(context),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: context.extras.text3,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final color = destructive ? theme.colorScheme.error : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: trailing is Switch ? 6 : 16,
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color ?? extras.text2),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                ?trailing,
                if (onTap != null && trailing is! Switch) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: extras.text3),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
