import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/activity_card.dart';
import '../widgets/app_top_bar.dart';

/// Default landing tab: search and browse activities.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  String _activeCategory = kCategories.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    final listings = _activeCategory == kCategories.first
        ? kDiscoverListings
        : kDiscoverListings.where((l) => l.category == _activeCategory).toList();

    return Scaffold(
      appBar: const AppTopBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(color: extras.field, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: extras.text3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Find activities, groups, or places...',
                            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.5, color: extras.text3),
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
                      itemCount: kCategories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final category = kCategories[i];
                        final active = category == _activeCategory;
                        return GestureDetector(
                          onTap: () => setState(() => _activeCategory = category),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            decoration: BoxDecoration(
                              color: active ? theme.colorScheme.primary : extras.field,
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
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
                itemCount: listings.length,
                separatorBuilder: (_, _) => const SizedBox(height: 18),
                itemBuilder: (context, i) => ActivityCard(
                  listing: listings[i],
                  onJoin: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Joining isn\'t wired up yet — design preview only.')),
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
