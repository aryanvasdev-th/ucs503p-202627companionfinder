import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_top_bar.dart';
import 'edit_profile_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';
import 'user_profile_page.dart';

/// Profile tab: your profile exactly as other students see it — rating,
/// review insights, verified tick, what you're hosting — with Edit profile
/// and Settings under your name. Account settings live in [SettingsPage].
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _user;
  String? _error;

  // Bumped after an edit so the embedded public profile reloads.
  int _version = 0;

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
        setState(() {
          _user = data['user'];
          _error = null;
          _version++;
        });
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

  Future<void> _editProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfilePage(user: _user!)),
    );
    if (changed == true) _load();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SettingsPage(user: _user!)));
    // Verification or profile details may have changed in there.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;

    return Scaffold(
      appBar: AppTopBar(
        onBellTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NotificationsPage())),
      ),
      body: SafeArea(
        top: false,
        child: _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: extras.text2)),
              )
            : _user == null
            ? const Center(child: CircularProgressIndicator())
            : UserProfilePage(
                key: ValueKey(_version),
                userId: _user!['id'] as int,
                embedded: true,
                ownActions: [
                  FilledButton.tonalIcon(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit profile'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined, size: 18),
                    label: const Text('Settings'),
                  ),
                ],
              ),
      ),
    );
  }
}
