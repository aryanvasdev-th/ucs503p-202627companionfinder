import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'models/activity.dart';
import 'pages/activity_detail_page.dart';
import 'pages/host_activity_page.dart';
import 'pages/notifications_page.dart';
import 'services/auth_session.dart';
import 'theme/app_theme.dart';
import 'utils/avatar.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/event_card.dart';

/// Home tab: your upcoming activities, plus a way to host your own.
/// Discover (not this page) is the default landing tab for finding activities.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<UpcomingEvent>? _events;
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
        final activities =
            (data['activities'] as List).cast<Map<String, dynamic>>()..sort(
              (a, b) =>
                  DateTime.parse(a['startsAt'])
                      .compareTo(DateTime.parse(b['startsAt'])),
            );
        setState(
          () => _events = activities.map((a) => _toUpcomingEvent(a)).toList(),
        );
      } else {
        setState(
          () => _error = data['message'] ?? 'Could not load your activities',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Check your connection and try again.',
      );
    }
  }

  UpcomingEvent _toUpcomingEvent(Map<String, dynamic> a) {
    final startsAt = DateTime.parse(a['startsAt']).toLocal();
    final isHost = a['hostUserId'].toString() == AuthSession.userId;
    final rating = a['hostRating'] == null
        ? null
        : (a['hostRating'] as num).toDouble();
    return UpcomingEvent(
      id: a['id'],
      title: a['title'],
      timeLabel: _formatWhen(startsAt),
      rsvp: isHost ? EventRsvp.confirmed : EventRsvp.going,
      hostName: a['hostName'] ?? 'Unknown',
      hostInitials: initialsFor(a['hostName'] ?? '?'),
      hostColor: colorForSeed(a['hostUserId']),
      rating: rating,
      peopleJoined: a['peopleJoined'],
      peopleCapacity: a['maxPeople'],
      imageGradient: gradientForSeed(a['id']),
      bannerUrl: a['bannerUrl'],
    );
  }

  String _formatWhen(DateTime dt) {
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

  void _openDetail(int activityId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ActivityDetailPage(activityId: activityId),
          ),
        )
        .then((_) => _load());
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
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              _HostCard(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HostActivityPage()),
                  );
                  _load();
                },
              ),
              const SizedBox(height: 26),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(_error!, style: TextStyle(color: extras.text2)),
                )
              else if (_events == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_events!.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No upcoming activities yet — join or host one from Discover.',
                    style: TextStyle(color: extras.text2),
                  ),
                )
              else ...[
                Text(
                  'Next Up',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 12),
                EventCard(
                  event: _events!.first,
                  onViewDetails: () => _openDetail(_events!.first.id),
                ),
                if (_events!.length > 1) ...[
                  const SizedBox(height: 26),
                  Text(
                    'Your Upcoming Events',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
                  ),
                  const SizedBox(height: 12),
                  ..._events!
                      .skip(1)
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: EventCard(
                            event: event,
                            onViewDetails: () => _openDetail(event.id),
                          ),
                        ),
                      ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HostCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: extras.brandTint,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add_rounded,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Host an Activity',
            style: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Share your passion and meet new people\nby hosting your own event.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: extras.text2,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            ),
            child: const Text('Create Activity'),
          ),
        ],
      ),
    );
  }
}
