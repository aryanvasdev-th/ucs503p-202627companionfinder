import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import 'chat_page.dart';

class ActivityDetailPage extends StatefulWidget {
  final int activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  Map<String, dynamic>? _activity;
  List<Map<String, dynamic>>? _joinRequests;
  bool _isLoading = true;
  String? _error;
  bool _isActionInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.apiRoot}/api/activities/${widget.activityId}'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() {
          _activity = data['activity'];
          _isLoading = false;
        });
        final isHost =
            _activity!['hostUserId'].toString() == AuthSession.userId;
        if (isHost) _loadJoinRequests();
      } else {
        setState(() {
          _isLoading = false;
          _error = data['message'] ?? 'Could not load activity';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Network error. Check your connection and try again.';
      });
    }
  }

  Future<void> _loadJoinRequests() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/${widget.activityId}/requests',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(
          () => _joinRequests =
              (data['requests'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      // Non-critical — the rest of the page still works without this.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestJoin() async {
    setState(() => _isActionInFlight = true);
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/${widget.activityId}/request-join',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      if (data['success'] == true) {
        _showMessage('Request sent!');
        _load();
      } else {
        _showMessage(data['message'] ?? 'Could not send request');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> _cancelRequest() async {
    setState(() => _isActionInFlight = true);
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/${widget.activityId}/request-join',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      if (data['success'] == true) {
        _load();
      } else {
        _showMessage(data['message'] ?? 'Could not cancel request');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> _leaveActivity() async {
    setState(() => _isActionInFlight = true);
    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/${widget.activityId}/join',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      if (data['success'] == true) {
        _load();
      } else {
        _showMessage(data['message'] ?? 'Could not leave activity');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> _respondToRequest(int requestId, bool accept) async {
    setState(() => _isActionInFlight = true);
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/${widget.activityId}/requests/$requestId/${accept ? 'accept' : 'decline'}',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      if (data['success'] == true) {
        _load();
      } else {
        _showMessage(data['message'] ?? 'Could not update request');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> _messageParticipant(int userId, String name) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.apiRoot}/api/conversations/dm'),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({'otherUserId': userId}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ChatPage(conversationId: data['conversationId'], title: name),
          ),
        );
      } else {
        _showMessage(data['message'] ?? 'Could not start conversation');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> _deleteActivity() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this activity?'),
        content: const Text(
          'This removes it for everyone, along with its group chat. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isActionInFlight = true);
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.apiRoot}/api/activities/${widget.activityId}'),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isActionInFlight = false);
        _showMessage(data['message'] ?? 'Could not delete activity');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActionInFlight = false);
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  Future<void> _rateParticipant(int userId, String name) async {
    final score = await showDialog<double>(
      context: context,
      builder: (context) => _RatingDialog(name: name),
    );
    if (score == null) return;

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/${widget.activityId}/rate',
        ),
        headers: {
          'Content-Type': 'application/json',
          ...AuthSession.authHeaders,
        },
        body: jsonEncode({'ratedUserId': userId, 'score': score}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        _showMessage('Rating saved');
        _load();
      } else {
        _showMessage(data['message'] ?? 'Could not save rating');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Network error. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Details')),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: TextStyle(color: extras.text2)),
              )
            : _buildContent(theme, extras),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, AppExtras extras) {
    final activity = _activity!;
    final participants = (activity['participants'] as List)
        .cast<Map<String, dynamic>>();
    final isHost = activity['hostUserId'].toString() == AuthSession.userId;
    final isJoined = activity['joinedByMe'] == true;
    final requestPending = activity['requestPending'] == true;
    final requestDeclined = activity['requestDeclined'] == true;
    final startsAt = DateTime.parse(activity['startsAt']).toLocal();
    final durationMinutes = activity['durationMinutes'] as int?;
    final endsAt = startsAt.add(Duration(minutes: durationMinutes ?? 0));
    final isOver = DateTime.now().isAfter(endsAt);

    final bannerUrl = activity['bannerUrl'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (bannerUrl != null && bannerUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              '${ApiConfig.apiRoot}$bannerUrl',
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          activity['title'],
          style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(
              icon: Icons.category_outlined,
              label: activity['category'],
            ),
            _InfoChip(
              icon: Icons.event_outlined,
              label: _formatDateTime(startsAt),
            ),
            if ((activity['landmark'] as String?)?.isNotEmpty == true)
              _InfoChip(
                icon: Icons.place_outlined,
                label: activity['landmark'],
              ),
            _InfoChip(
              icon: Icons.groups_outlined,
              label:
                  '${activity['peopleJoined']}/${activity['maxPeople']} people',
            ),
          ],
        ),
        if ((activity['description'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          Text(
            activity['description'],
            style: theme.textTheme.bodyMedium?.copyWith(color: extras.text2),
          ),
        ],
        if (isHost) ...[
          const SizedBox(height: 26),
          Text(
            'Join Requests',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 12),
          if (_joinRequests == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_joinRequests!.isEmpty)
            Text(
              'No pending requests.',
              style: TextStyle(fontSize: 13.5, color: extras.text2),
            )
          else
            ..._joinRequests!.map((r) => _buildRequestCard(theme, extras, r)),
        ],
        const SizedBox(height: 26),
        Text(
          'Who\'s In',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        if (!isOver) ...[
          const SizedBox(height: 4),
          Text(
            'Ratings open once this activity is over.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: extras.text2,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...participants.map((p) {
          final userId = p['id'] as int;
          final isMe = userId.toString() == AuthSession.userId;
          final avgRating = p['avgRating'] as num?;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorForSeed(userId),
                  child: Text(
                    initialsFor(p['name'] ?? '?'),
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
                        p['name'] ?? 'Unknown',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        children: [
                          if (avgRating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Color(0xFFF0A93B),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              avgRating.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: extras.text2,
                              ),
                            ),
                          ] else
                            Text(
                              'New',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: extras.text3,
                              ),
                            ),
                          if (userId == activity['hostUserId']) ...[
                            const SizedBox(width: 8),
                            Text(
                              '· Host',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: extras.text3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isMe) ...[
                  IconButton(
                    onPressed: isOver
                        ? () => _rateParticipant(
                            userId,
                            p['name'] ?? 'this person',
                          )
                        : null,
                    icon: const Icon(Icons.star_outline_rounded),
                    tooltip: isOver
                        ? 'Rate'
                        : 'You can rate once this activity is over',
                  ),
                  IconButton(
                    onPressed: () =>
                        _messageParticipant(userId, p['name'] ?? 'Chat'),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    tooltip: 'Message',
                  ),
                ],
              ],
            ),
          );
        }),
        if (!isHost) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isActionInFlight || requestDeclined
                  ? null
                  : isJoined
                  ? _leaveActivity
                  : requestPending
                  ? _cancelRequest
                  : _requestJoin,
              style: (isJoined || requestPending || requestDeclined)
                  ? ElevatedButton.styleFrom(
                      backgroundColor: extras.field,
                      foregroundColor: extras.text2,
                    )
                  : null,
              child: Text(
                isJoined
                    ? 'Leave Activity'
                    : requestPending
                    ? 'Cancel Request'
                    : requestDeclined
                    ? 'Request Declined'
                    : 'Request to Join',
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _isActionInFlight ? null : _deleteActivity,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              child: const Text('Delete Activity'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequestCard(
    ThemeData theme,
    AppExtras extras,
    Map<String, dynamic> request,
  ) {
    final avgRating = request['avgRating'] as num?;
    final gender = request['gender'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorForSeed(request['userId']),
                child: Text(
                  initialsFor(request['name'] ?? '?'),
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
                      request['name'] ?? 'Unknown',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        if (avgRating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Color(0xFFF0A93B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: extras.text2,
                            ),
                          ),
                        ] else
                          Text(
                            'New',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: extras.text3,
                            ),
                          ),
                        if (gender != null && gender.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '· $gender',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: extras.text3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isActionInFlight
                      ? null
                      : () => _respondToRequest(request['id'], false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isActionInFlight
                      ? null
                      : () => _respondToRequest(request['id'], true),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
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
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, $hour:$minute $period';
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final extras = context.extras;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: extras.field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: extras.text2),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: extras.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingDialog extends StatefulWidget {
  final String name;
  const _RatingDialog({required this.name});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  double _score = 5;
  static const _starSize = 36.0;

  void _setFromTap(int starIndex, double dx) {
    final half = dx < _starSize / 2;
    setState(() => _score = starIndex + (half ? 0.5 : 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate ${widget.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final IconData icon;
              if (_score >= i + 1) {
                icon = Icons.star_rounded;
              } else if (_score >= i + 0.5) {
                icon = Icons.star_half_rounded;
              } else {
                icon = Icons.star_outline_rounded;
              }
              return GestureDetector(
                onTapDown: (details) =>
                    _setFromTap(i, details.localPosition.dx),
                child: SizedBox(
                  width: _starSize,
                  height: _starSize,
                  child: Icon(
                    icon,
                    color: const Color(0xFFF0A93B),
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            _score.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _score),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
