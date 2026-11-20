import 'package:flutter/material.dart';

import '../pages/host_activity_page.dart';
import '../theme/app_theme.dart';

/// What the + button opens: host a single activity, or an event (a fest or
/// any umbrella) that has several activities inside it.
Future<void> showHostChoice(BuildContext context) async {
  final isEvent = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _HostChoiceSheet(),
  );
  if (isEvent == null || !context.mounted) return;
  // Completes when the host screen closes, so callers can refresh.
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => HostActivityPage(isEvent: isEvent)));
}

class _HostChoiceSheet extends StatelessWidget {
  const _HostChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What are you hosting?', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _ChoiceTile(
              icon: Icons.local_cafe_outlined,
              color: theme.colorScheme.primary,
              tint: extras.brandTint,
              title: 'An activity',
              subtitle: 'One meetup: chai, a movie, a gym session, a walk.',
              onTap: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: 12),
            // Solid brand red so the bigger option stands out, without
            // bringing in the indigo accent the rest of the app avoids here.
            _ChoiceTile(
              icon: Icons.celebration_rounded,
              color: Colors.white,
              tint: theme.colorScheme.primary,
              title: 'An event',
              subtitle: 'Something bigger, like a fest, with several activities inside it that people sign up for.',
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    // Same look as the activity cards: filled surface, soft shadow, no
    // outline.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.35 : 0.06,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: extras.text2),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: extras.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
