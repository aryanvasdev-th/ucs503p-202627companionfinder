import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../services/notifications_state.dart';
import '../theme/app_theme.dart';
import 'activity_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/notifications'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(
          () => _notifications =
              (data['notifications'] as List).cast<Map<String, dynamic>>(),
        );
        NotificationsState.unreadCount.value =
            _notifications!.where((n) => n['read'] != true).length;
      } else {
        setState(
          () => _error = data['message'] ?? 'Could not load notifications',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Check your connection and try again.',
      );
    }
  }

  Future<void> _markAllRead() async {
    if (_notifications == null || _notifications!.every((n) => n['read'] == true)) {
      return;
    }
    setState(() {
      for (final n in _notifications!) {
        n['read'] = true;
      }
    });
    NotificationsState.unreadCount.value = 0;
    try {
      await http.post(
        Uri.parse('${ApiConfig.apiRoot}/api/notifications/read-all'),
        headers: AuthSession.authHeaders,
      );
    } catch (e) {
      // Best-effort — a stale badge briefly is fine; next load reconciles it.
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    if (notification['read'] != true) {
      setState(() => notification['read'] = true);
      NotificationsState.unreadCount.value =
          (_notifications ?? []).where((n) => n['read'] != true).length;
      try {
        await http.patch(
          Uri.parse(
            '${ApiConfig.apiRoot}/api/notifications/${notification['id']}/read',
          ),
          headers: AuthSession.authHeaders,
        );
      } catch (e) {
        // Best-effort.
      }
    }

    final activityId = notification['activityId'];
    if (activityId != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActivityDetailPage(activityId: activityId),
        ),
      );
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'activity_joined':
        return Icons.person_add_alt_1_rounded;
      case 'activity_cancelled':
        return Icons.event_busy_rounded;
      case 'rating_received':
        return Icons.star_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(theme, extras),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, AppExtras extras) {
    if (_error != null) {
      return _centered(
        child: Text(_error!, style: TextStyle(color: extras.text2)),
      );
    }
    if (_notifications == null) {
      return _centered(child: const CircularProgressIndicator());
    }
    if (_notifications!.isEmpty) {
      return _centered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 48, color: extras.text3),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll see updates here when someone joins your\nactivities or rates you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13.5,
                color: extras.text2,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: _notifications!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final n = _notifications![i];
        final isRead = n['read'] == true;
        final createdAt = DateTime.parse(n['createdAt']).toLocal();
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openNotification(n),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: isRead
                  ? null
                  : Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isRead ? extras.field : extras.brandTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconFor(n['type'] ?? ''),
                    size: 18,
                    color: isRead ? extras.text2 : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n['title'] ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if ((n['body'] as String?)?.isNotEmpty == true)
                        Text(
                          n['body'],
                          style: TextStyle(fontSize: 13, color: extras.text2),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(createdAt),
                        style: TextStyle(fontSize: 11.5, color: extras.text3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _centered({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: Padding(padding: const EdgeInsets.all(32), child: child)),
        ),
      ),
    );
  }
}
