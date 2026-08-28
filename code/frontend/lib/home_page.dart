import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'pages/host_activity_page.dart';
import 'theme/app_theme.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/event_card.dart';

/// Home tab: your upcoming activities, plus a way to host your own.
/// Discover (not this page) is the default landing tab for finding activities.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppTopBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            _HostCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HostActivityPage()),
              ),
            ),
            const SizedBox(height: 26),
            Text('Your Upcoming Events', style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
            const SizedBox(height: 12),
            ...kUpcomingEvents.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: EventCard(
                  event: event,
                  onViewDetails: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event details aren\'t wired up yet — design preview only.')),
                    );
                  },
                ),
              ),
            ),
          ],
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
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35), width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: theme.colorScheme.surface, shape: BoxShape.circle),
            child: Icon(Icons.add_rounded, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(height: 10),
          Text('Host an Activity', style: theme.textTheme.titleMedium?.copyWith(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            'Share your passion and meet new people\nby hosting your own event.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, color: extras.text2),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12)),
            child: const Text('Create Activity'),
          ),
        ],
      ),
    );
  }
}
