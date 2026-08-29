import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import 'activity_detail_page.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  List<Map<String, dynamic>>? _past;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/activities/mine'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        final now = DateTime.now();
        final past = (data['activities'] as List)
            .cast<Map<String, dynamic>>()
            .where((a) => DateTime.parse(a['startsAt']).isBefore(now))
            .toList()
          ..sort(
            (a, b) => DateTime.parse(
              b['startsAt'],
            ).compareTo(DateTime.parse(a['startsAt'])),
          );
        setState(() => _past = past);
      } else {
        setState(() => _error = data['message'] ?? 'Could not load history');
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Check your connection and try again.',
      );
    }
  }

  String _formatWhen(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
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
    if (_past == null) {
      return _centered(child: const CircularProgressIndicator());
    }
    if (_past!.isEmpty) {
      return _centered(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 48, color: extras.text3),
            const SizedBox(height: 16),
            Text(
              'No past activities yet',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              'Activities you\'ve hosted or joined will show up here\nonce they\'ve happened.',
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
      itemCount: _past!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final activity = _past![i];
        final startsAt = DateTime.parse(activity['startsAt']).toLocal();
        final isHost =
            activity['hostUserId'].toString() == AuthSession.userId;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ActivityDetailPage(activityId: activity['id']),
              ),
            );
            _load();
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorForSeed(activity['id']),
                  child: Text(
                    initialsFor(activity['title'] ?? '?'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['title'] ?? 'Untitled',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatWhen(startsAt)} · ${isHost ? 'You hosted' : 'Hosted by ${activity['hostName'] ?? 'Unknown'}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: extras.text2),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: extras.text3),
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
