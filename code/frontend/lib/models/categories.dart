/// The activity categories the app knows about.
///
/// This is the single source of truth. The host form offers exactly these when
/// an activity is created, and Discover filters on exactly these, so neither
/// screen can offer a value the other does not understand. Adding a category is
/// a one-line change here and needs no edit to either screen.
///
/// Keep this in step with `ACTIVITY_CATEGORIES` in `backend/categories.js`,
/// which rejects anything outside the set at the API.
const List<String> kActivityCategories = [
  'Hangout',
  'Coffee',
  'Movie',
  'Gym',
  'Walk',
  kEventCategory,
];

/// Category every event (fest and other umbrella with activities inside) is
/// filed under. Set automatically when hosting an event, never picked.
const String kEventCategory = 'Event';

/// What the Host Activity form offers: everything except [kEventCategory].
final List<String> kHostableCategories = kActivityCategories
    .where((c) => c != kEventCategory)
    .toList();

/// Label for Discover's leading chip, which clears the filter rather than
/// selecting a category. It is deliberately not a member of
/// [kActivityCategories]: no activity is ever stored under it.
const String kAllActivitiesLabel = 'All Activities';

/// Discover's chip row: the clear-filter chip followed by every real category.
const List<String> kDiscoverCategories = [
  kAllActivitiesLabel,
  ...kActivityCategories,
];
