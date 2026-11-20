import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/verified_badge.dart';
import 'activity_detail_page.dart';
import 'chat_page.dart';

const _starColor = Color(0xFFF0A93B);

/// Someone's profile: who they are, how others rated them, and what they're
/// hosting next. Opened by tapping a name anywhere in the app, and also used
/// (embedded) as your own Profile tab so you see yourself as others do.
class UserProfilePage extends StatefulWidget {
  final int userId;
  final String? initialName;

  /// Render without its own Scaffold/AppBar, inside the Profile tab.
  final bool embedded;

  /// Buttons shown under the name on your own profile (Edit, Settings).
  final List<Widget>? ownActions;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.initialName,
    this.embedded = false,
    this.ownActions,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _profile;
  String? _error;

  bool get _isMe => widget.userId.toString() == AuthSession.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/users/${widget.userId}'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _profile = data['profile'];
          _error = null;
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

  Future<void> _message() async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiRoot}/api/conversations/dm'),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({'otherUserId': widget.userId}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: data['conversationId'],
              title: _profile?['name'] ?? 'Chat',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Could not start chat')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Try again.')),
      );
    }
  }

  Future<void> _admin(String method, String path, [Object? body]) async {
    try {
      final uri = Uri.parse('${ApiConfig.apiRoot}/api/admin$path');
      final headers = {
        'Content-Type': 'application/json',
        ...AuthSession.authHeaders,
      };
      final response = method == 'DELETE'
          ? await http.delete(uri, headers: headers)
          : await http.post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? {}),
            );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(data['message'] ?? 'Done')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Try again.')),
      );
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _ban() async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ban ${_profile?['name'] ?? 'this user'}?'),
        content: TextField(
          controller: reason,
          maxLength: 255,
          decoration: const InputDecoration(
            hintText: 'Reason (shown to them), e.g. Spam events',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ban'),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (ok == true) {
      await _admin('POST', '/users/${widget.userId}/ban', {'reason': text});
    }
  }

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    if (await _confirm(
      'Remove this review?',
      'It disappears for everyone and the reviewer is told it broke the guidelines.',
    )) {
      await _admin('DELETE', '/reviews/${review['id']}');
    }
  }

  /// Moderation tools, shown only to the app's maker on other profiles.
  Widget _adminPanel(ThemeData theme, Map<String, dynamic> p) {
    final extras = context.extras;
    final banned = p['isBanned'] == true;
    final verified = p['verified'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: extras.brandTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: extras.brandInk,
              ),
              const SizedBox(width: 6),
              Text(
                'Admin',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: extras.brandInk,
                ),
              ),
              const Spacer(),
              if (banned)
                Text(
                  'Banned',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          if (banned && (p['banReason'] as String?)?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Reason: ${p['banReason']}',
                style: TextStyle(fontSize: 12.5, color: extras.text2),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              banned
                  ? FilledButton.tonal(
                      onPressed: () =>
                          _admin('POST', '/users/${widget.userId}/unban'),
                      child: const Text('Unban'),
                    )
                  : OutlinedButton(
                      onPressed: _ban,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                      child: const Text('Ban'),
                    ),
              OutlinedButton.icon(
                onPressed: () => _admin(
                  'POST',
                  '/users/${widget.userId}/verification',
                  {'verified': !verified},
                ),
                icon: Icon(
                  verified ? Icons.remove_moderator_outlined : Icons.verified,
                  size: 18,
                ),
                label: Text(verified ? 'Remove tick' : 'Give red tick'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    final content = _error != null
        ? Center(
            child: Text(_error!, style: TextStyle(color: extras.text2)),
          )
        : _profile == null
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(onRefresh: _load, child: _buildBody());
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(widget.initialName ?? 'Profile')),
      body: SafeArea(top: false, child: content),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final extras = context.extras;
    final p = _profile!;
    final stats = p['stats'] as Map<String, dynamic>;
    final avg = stats['avgRating'] as num?;
    final ratingCount = stats['ratingCount'] as int;
    final reviews = (p['reviews'] as List).cast<Map<String, dynamic>>();
    final topTags = (p['topTags'] as List).cast<Map<String, dynamic>>();
    final upcoming = (p['upcomingHosted'] as List).cast<Map<String, dynamic>>();
    final bio = p['bio'] as String?;
    final name = (p['name'] as String?)?.isNotEmpty == true
        ? p['name'] as String
        : 'Unnamed student';
    final memberSince = DateTime.parse(p['memberSince']).toLocal();

    return ListView(
      // Extra bottom room when embedded so the tab bar doesn't cover it.
      padding: EdgeInsets.fromLTRB(20, 20, 20, widget.embedded ? 110 : 32),
      children: [
        Center(
          child: Column(
            children: [
              _avatar(theme, p, name),
              const SizedBox(height: 12),
              NameWithBadge(
                name: name,
                verified: p['verified'] == true,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 21),
                badgeSize: 20,
              ),
              if (p['isAdmin'] == true) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Team Companion',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                [
                  if ((p['gender'] as String?)?.isNotEmpty == true) p['gender'],
                  'Joined ${_monthYear(memberSince)}',
                ].join(' · '),
                style: TextStyle(fontSize: 13, color: extras.text2),
              ),
              if (bio != null && bio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: extras.text2,
                  ),
                ),
              ],
              if (!_isMe) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _message,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Message'),
                ),
              ],
              if (widget.ownActions != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: widget.ownActions!,
                ),
              ],
            ],
          ),
        ),
        if (AuthSession.isAdmin && !_isMe) ...[
          const SizedBox(height: 18),
          _adminPanel(theme, p),
        ],
        const SizedBox(height: 22),
        Row(
          children: [
            _StatTile(
              value: avg == null ? '–' : avg.toStringAsFixed(1),
              label: ratingCount == 1 ? '1 rating' : '$ratingCount ratings',
              icon: Icons.star_rounded,
              iconColor: _starColor,
            ),
            const SizedBox(width: 10),
            _StatTile(value: '${stats['hosted']}', label: 'Hosted'),
            const SizedBox(width: 10),
            _StatTile(value: '${stats['joined']}', label: 'Joined'),
          ],
        ),
        const SizedBox(height: 26),
        _sectionTitle(theme, 'Review insights'),
        const SizedBox(height: 12),
        if (ratingCount == 0)
          Text(
            'No ratings yet. They show up here after shared activities end.',
            style: TextStyle(fontSize: 13.5, color: extras.text2),
          )
        else ...[
          _RatingHistogram(
            distribution: Map<String, dynamic>.from(p['ratingDistribution']),
            total: ratingCount,
          ),
          if (topTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'What people say',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: extras.text2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topTags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: extras.brandTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${t['tag']}  ×${t['count']}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: extras.brandInk,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 26),
          _sectionTitle(theme, 'Reviews'),
          const SizedBox(height: 12),
          ...reviews.map(
            (r) => _ReviewCard(
              review: r,
              onDelete: AuthSession.isAdmin ? () => _deleteReview(r) : null,
            ),
          ),
        ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 26),
          _sectionTitle(theme, 'Hosting soon'),
          const SizedBox(height: 12),
          ...upcoming.map(
            (a) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: Text(a['title']),
                subtitle: Text(
                  '${a['category']} · ${_shortDate(DateTime.parse(a['startsAt']).toLocal())}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ActivityDetailPage(activityId: a['id']),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatar(ThemeData theme, Map<String, dynamic> p, String name) {
    final url = p['avatarUrl'] as String?;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundImage: CachedNetworkImageProvider('${ApiConfig.apiRoot}$url'),
      );
    }
    return CircleAvatar(
      radius: 44,
      backgroundColor: colorForSeed(widget.userId),
      child: Text(
        initialsFor(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) =>
      Text(text, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18));
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  const _StatTile({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 3),
                ],
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: extras.text2)),
          ],
        ),
      ),
    );
  }
}

class _RatingHistogram extends StatelessWidget {
  final Map<String, dynamic> distribution;
  final int total;

  const _RatingHistogram({required this.distribution, required this.total});

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    return Column(
      children: [5, 4, 3, 2, 1].map((stars) {
        final count = (distribution['$stars'] as num?)?.toInt() ?? 0;
        final fraction = total == 0 ? 0.0 : count / total;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '$stars★',
                  style: TextStyle(fontSize: 12.5, color: extras.text2),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: extras.field,
                    valueColor: const AlwaysStoppedAnimation(_starColor),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 12.5, color: extras.text2),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  /// Admins only: remove an abusive or fake review.
  final VoidCallback? onDelete;
  const _ReviewCard({required this.review, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final score = (review['score'] as num).toDouble();
    final text = review['text'] as String?;
    final tags = (review['tags'] as List).cast<String>();
    final date = DateTime.parse(review['createdAt']).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ...List.generate(5, (i) {
                final IconData icon = score >= i + 1
                    ? Icons.star_rounded
                    : score >= i + 0.5
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded;
                return Icon(icon, size: 16, color: _starColor);
              }),
              const Spacer(),
              Text(
                _shortDate(date),
                style: TextStyle(fontSize: 12, color: extras.text3),
              ),
              if (onDelete != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove review (admin)',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${review['reviewerName'] ?? 'Someone'} · ${review['asHost'] == true ? 'hosted' : 'joined'} "${review['activityTitle']}"',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: extras.text2,
            ),
          ),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: extras.field,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(fontSize: 11.5, color: extras.text2),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String _shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
