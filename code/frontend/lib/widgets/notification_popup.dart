import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/activity_detail_page.dart';
import '../services/app_navigator.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';

/// Wraps the logged-in part of the app and slides a banner down from the top
/// whenever a notification is pushed — so a host sees "Riya wants to join"
/// and a requester sees "You're in!" the moment it happens, on any tab.
/// Tapping the banner opens the activity; swiping it up dismisses it.
class NotificationPopupHost extends StatefulWidget {
  final Widget child;
  const NotificationPopupHost({super.key, required this.child});

  @override
  State<NotificationPopupHost> createState() => _NotificationPopupHostState();
}

class _NotificationPopupHostState extends State<NotificationPopupHost>
    with SingleTickerProviderStateMixin {
  static const _visibleFor = Duration(seconds: 5);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));

  StreamSubscription<Map<String, dynamic>>? _sub;
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? _current;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _sub = RealtimeService.notifications.listen((n) {
      _queue.add(n);
      if (_current == null) _showNext();
    });
  }

  void _showNext() {
    if (_queue.isEmpty || !mounted) return;
    setState(() => _current = _queue.removeAt(0));
    _anim.forward(from: 0);
    _hideTimer?.cancel();
    _hideTimer = Timer(_visibleFor, _hide);
  }

  Future<void> _hide() async {
    _hideTimer?.cancel();
    if (!mounted || _current == null) return;
    await _anim.reverse();
    if (!mounted) return;
    setState(() => _current = null);
    _showNext();
  }

  void _open() {
    final activityId = _current?['activityId'];
    _hide();
    if (activityId is int) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ActivityDetailPage(activityId: activityId),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hideTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            left: 12,
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: SlideTransition(
              position: _slide,
              child: GestureDetector(
                onTap: _open,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < 0) _hide();
                },
                child: _Banner(notification: _current!),
              ),
            ),
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final Map<String, dynamic> notification;
  const _Banner({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;
    final style = styleForNotificationType(
      notification['type'] as String?,
      theme,
      extras,
    );

    return Material(
      color: theme.colorScheme.surface,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: style.color, width: 4)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, color: style.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification['title'] ?? 'Notification',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if ((notification['body'] as String?)?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        notification['body'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: extras.text2),
                      ),
                    ),
                ],
              ),
            ),
            if (notification['activityId'] is int)
              Icon(Icons.chevron_right_rounded, color: extras.text3),
          ],
        ),
      ),
    );
  }
}

class NotificationStyle {
  final IconData icon;
  final Color color;
  const NotificationStyle(this.icon, this.color);
}

/// Shared with the notifications list so both use the same icon/colour per
/// type: green for good news, red for declines/cancellations.
NotificationStyle styleForNotificationType(
  String? type,
  ThemeData theme,
  AppExtras extras,
) {
  switch (type) {
    case 'join_request':
      return NotificationStyle(Icons.person_add_alt_1_rounded, extras.indigo);
    case 'request_accepted':
      return NotificationStyle(Icons.check_circle_rounded, extras.green);
    case 'request_declined':
      return NotificationStyle(Icons.cancel_rounded, theme.colorScheme.error);
    case 'activity_cancelled':
    case 'team_deleted':
      return NotificationStyle(
        Icons.event_busy_rounded,
        theme.colorScheme.error,
      );
    case 'team_joined':
      return NotificationStyle(Icons.groups_rounded, extras.indigo);
    case 'rating_received':
      return const NotificationStyle(Icons.star_rounded, Color(0xFFF0A93B));
    default:
      return NotificationStyle(
        Icons.notifications_rounded,
        theme.colorScheme.primary,
      );
  }
}
