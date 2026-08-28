import 'package:flutter/material.dart';
import '../pages/discover_page.dart';
import '../home_page.dart';
import '../pages/host_activity_page.dart';
import '../pages/messages_page.dart';
import '../pages/profile_page.dart';
import '../theme/app_theme.dart';

/// Owns the 5-tab bottom nav (Home / Discover / Host / Messages / Profile).
/// Host is a raised center button that pushes HostActivityPage rather than
/// a persistent tab, matching the design (it opens as its own flow, not a
/// screen you idle on).
class MainScaffold extends StatefulWidget {
  final int initialIndex;
  const MainScaffold({super.key, this.initialIndex = 1});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _index = widget.initialIndex;

  static const _tabs = [
    HomePage(),
    DiscoverPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  void _openHost() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HostActivityPage()),
    );
  }

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

  const _BottomNav({required this.index, required this.onSelect, required this.onHostTap});

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
        padding: EdgeInsets.only(bottom: 16 + MediaQuery.of(context).padding.bottom * 0.4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _NavItem(icon: Icons.home_rounded, label: 'Home', selected: index == 0, onTap: () => onSelect(0)),
            _NavItem(icon: Icons.explore_rounded, label: 'Discover', selected: index == 1, onTap: () => onSelect(1)),
            _HostButton(onTap: onHostTap),
            _NavItem(icon: Icons.chat_bubble_rounded, label: 'Messages', selected: index == 2, onTap: () => onSelect(2)),
            _NavItem(icon: Icons.person_rounded, label: 'Profile', selected: index == 3, onTap: () => onSelect(3)),
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

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: selected ? const EdgeInsets.fromLTRB(16, 9, 16, 7) : const EdgeInsets.symmetric(horizontal: 4),
        transform: selected ? (Matrix4.identity()..translateByDouble(0.0, -10.0, 0.0, 1.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: selected ? Colors.white : extras.text3),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : extras.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HostButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: const Offset(0, -20),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
