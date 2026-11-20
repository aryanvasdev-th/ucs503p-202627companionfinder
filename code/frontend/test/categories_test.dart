import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/models/categories.dart';

/// These guard the invariant that the host form and Discover agree about what a
/// category is. They exist because they did not always: the host form used to
/// offer a "More..." chip that Discover had no filter for, so an activity filed
/// under it was reachable only from "All Activities".
void main() {
  group('activity categories', () {
    test('every category the host form can post has a Discover chip', () {
      for (final category in kActivityCategories) {
        expect(
          kDiscoverCategories,
          contains(category),
          reason:
              '"$category" can be hosted but has no Discover chip, so an '
              'activity filed under it would only ever show up under '
              '"$kAllActivitiesLabel".',
        );
      }
    });

    test('the clear-filter label is not itself a postable category', () {
      expect(kActivityCategories, isNot(contains(kAllActivitiesLabel)));
    });

    test('Discover offers the clear-filter chip first and nothing extra', () {
      expect(kDiscoverCategories.first, kAllActivitiesLabel);
      expect(kDiscoverCategories.skip(1).toList(), kActivityCategories);
    });

    test('categories are unique and non-empty', () {
      expect(kActivityCategories, isNotEmpty);
      expect(
        kActivityCategories.toSet().length,
        kActivityCategories.length,
        reason: 'a duplicate chip would filter to the same activities twice',
      );
      for (final category in kActivityCategories) {
        expect(category.trim(), isNotEmpty);
      }
    });
  });
}
