import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/activity.dart';
import '../services/auth_session.dart';
import '../theme/app_theme.dart';
import '../utils/avatar.dart';
import '../widgets/activity_card.dart';
import '../widgets/app_top_bar.dart';
import 'activity_detail_page.dart';
import 'notifications_page.dart';

const kDiscoverCategories = [
  'All Activities',
  'Hiking',
  'Coffee',
  'Gaming',
  'Sports',
];

/// Default landing tab: search and browse activities.
class DiscoverPage extends StatefulWidget {
  /// Whether this tab is the one currently visible in the bottom nav's
  /// IndexedStack. The page stays mounted while hidden, so this is how it
  /// knows to refetch on becoming active again instead of showing stale data.
  final bool isActive;

  const DiscoverPage({super.key, this.isActive = false});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  String _activeCategory = kDiscoverCategories.first;
  List<ActivityListing>? _listings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiscoverPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse('${ApiConfig.apiRoot}/api/activities')
          .replace(queryParameters: {'upcoming': 'true'});
      final response = await http.get(uri, headers: AuthSession.authHeaders);
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        setState(
          () => _listings = (data['activities'] as List)
              .map((a) => _toListing(a))
              .toList(),
        );
      } else {
        setState(() => _error = data['message'] ?? 'Could not load activities');
      }
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = 'Network error. Check your connection and try again.',
      );
    }
  }

  ActivityListing _toListing(Map<String, dynamic> a) {
    final startsAt = DateTime.parse(a['startsAt']).toLocal();
    return ActivityListing(
      id: a['id'],
      title: a['title'],
      category: a['category'],
      rating: a['hostRating'] == null
          ? null
          : (a['hostRating'] as num).toDouble(),
      timeLabel: _formatWhen(startsAt),
      peopleJoined: a['peopleJoined'],
      peopleCapacity: a['maxPeople'],
      hostName: a['hostName'] ?? 'Unknown',
      hostInitials: initialsFor(a['hostName'] ?? '?'),
      hostColor: colorForSeed(a['hostUserId']),
      imageGradient: gradientForSeed(a['id']),
      bannerUrl: a['bannerUrl'],
      joinedByMe: a['joinedByMe'] == true,
      requestPending: a['requestPending'] == true,
      requestDeclined: a['requestDeclined'] == true,
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

  Future<void> _requestJoin(int activityId) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.apiRoot}/api/activities/$activityId/request-join',
        ),
        headers: AuthSession.authHeaders,
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (data['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request sent!')));
        _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Could not send request')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Check your connection and try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    final listings = _listings == null
        ? const <ActivityListing>[]
        : _activeCategory == kDiscoverCategories.first
        ? _listings!
        : _listings!.where((l) => l.category == _activeCategory).toList();

    return Scaffold(
      appBar: AppTopBar(
        onBellTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsPage()),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: extras.field,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: extras.text3,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Find activities, groups, or places...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14.5,
                              color: extras.text3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kDiscoverCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final category = kDiscoverCategories[i];
                        final active = category == _activeCategory;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _activeCategory = category),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: active
                                  ? theme.colorScheme.primary
                                  : extras.field,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: active ? Colors.white : extras.text2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: extras.text2),
                      ),
                    )
                  : _listings == null
                  ? const Center(child: CircularProgressIndicator())
                  : listings.isEmpty
                  ? Center(
                      child: Text(
                        'No activities here yet.',
                        style: TextStyle(color: extras.text2),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                        itemCount: listings.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 18),
                        itemBuilder: (context, i) => ActivityCard(
                          listing: listings[i],
                          onJoin: () => _requestJoin(listings[i].id),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ActivityDetailPage(
                                  activityId: listings[i].id,
                                ),
                              ),
                            );
                            _load();
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
