import 'package:flutter/material.dart';

import '../pages/discover_page.dart';
import '../home_page.dart';
import '../pages/messages_page.dart';
import '../pages/profile_page.dart';
import '../services/notifications_state.dart';
import '../services/realtime_service.dart';
import '../theme/app_theme.dart';
import 'host_choice_sheet.dart';

/// Owns the 5-item bottom nav (Home / Discover / Host / Messages / Profile).
/// Host is the same size as the tabs but opens the host chooser as its own
/// flow instead of becoming a screen you idle on.
class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 1});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    NotificationsState.refresh();
    RealtimeService.connect();
  }

  List<Widget> get _tabs => [
    const HomePage(),
    DiscoverPage(isActive: _index == 1),
    const MessagesPage(),
    const ProfilePage(),
  ];

  void _openHost() => showHostChoice(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onSelect: (i) => setState(() => _index = i),
        onHostTap: _openHost,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onHostTap;

  const _BottomNav({
    required this.index,
    required this.onSelect,
    required this.onHostTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 88 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.of(context).padding.bottom * 0.4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: index == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              icon: Icons.explore_rounded,
              label: 'Discover',
              selected: index == 1,
              onTap: () => onSelect(1),
            ),
            // Same size as the other tabs: the old raised red button got
            // pressed by accident. It opens the host chooser rather than
            // becoming the selected tab; the red icon keeps it findable.
            _NavItem(
              icon: Icons.add_circle_outline_rounded,
              label: 'Host',
              selected: false,
              accent: true,
              onTap: onHostTap,
            ),
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Messages',
              selected: index == 2,
              onTap: () => onSelect(2),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              selected: index == 3,
              onTap: () => onSelect(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Brand-red icon for the Host action when it isn't selected.
  final bool accent;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: selected
            ? const EdgeInsets.fromLTRB(16, 9, 16, 7)
            : const EdgeInsets.symmetric(horizontal: 4),
        transform: selected
            ? (Matrix4.identity()..translateByDouble(0.0, -10.0, 0.0, 1.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? Colors.white
                  : accent
                  ? theme.colorScheme.primary
                  : extras.text3,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : accent
                    ? theme.colorScheme.primary
                    : extras.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
