import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../login_page.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/app_top_bar.dart';
import 'activity_history_page.dart';
import 'edit_profile_page.dart';
import 'emergency_contact_page.dart';
import 'notifications_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/users/me'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() => _user = data['user']);
      } else {
        setState(() => _error = data['message'] ?? 'Could not load profile');
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Check your connection and try again.',
      );
    }
  }

  void _logOut() {
    AuthSession.token = null;
    AuthSession.userId = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppTopBar(
        onBellTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: extras.text2)),
              )
            : _user == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          _buildAvatar(theme),
                          const SizedBox(height: 14),
                          Text(
                            (_user!['name'] as String?)?.isNotEmpty == true
                                ? _user!['name']
                                : 'Add your name',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _user!['email'] ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 13.5,
                              color: extras.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    _MenuTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Edit Profile',
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => EditProfilePage(user: _user!),
                          ),
                        );
                        if (changed == true) _load();
                      },
                    ),
                    _MenuTile(
                      icon: Icons.shield_outlined,
                      label: 'Emergency Contact',
                      onTap: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => EmergencyContactPage(user: _user!),
                          ),
                        );
                        if (changed == true) _load();
                      },
                    ),
                    _MenuTile(
                      icon: Icons.history_rounded,
                      label: 'History',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ActivityHistoryPage(),
                        ),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      ),
                    ),
                    _MenuTile(icon: Icons.settings_outlined, label: 'Settings'),
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      label: 'Log Out',
                      onTap: _logOut,
                      destructive: true,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final avatarUrl = _user!['avatar_url'] as String?;
    final name = (_user!['name'] as String?) ?? '';
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage('${ApiConfig.apiRoot}$avatarUrl'),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        initialsFor(name.isEmpty ? '?' : name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
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

  const _MenuTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final color = destructive ? theme.colorScheme.error : null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
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
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, color: extras.text3),
          ],
        ),
      ),
    );
  }
}
