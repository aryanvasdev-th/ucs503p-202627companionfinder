// categories.js
// The activity categories the API accepts.
//
// This mirrors kActivityCategories in frontend/lib/models/categories.dart and
// the two must be edited together. The server check exists because `category`
// is a plain VARCHAR with no enum constraint: without it, any client can write
// a value that Discover has no chip for, and the activity becomes reachable
// only under "All Activities".
// 'Event' is used for events (fests and other umbrellas with activities
// inside); the host form sets it automatically rather than offering it.
const ACTIVITY_CATEGORIES = ['Hangout', 'Coffee', 'Movie', 'Gym', 'Walk', 'Event'];

// Categories from earlier versions of the app and what existing activities
// filed under them become. migrate.js applies this on startup.
const RENAMED_CATEGORIES = {
  Hiking: 'Walk',
  Gaming: 'Hangout',
  Sports: 'Gym',
};

module.exports = { ACTIVITY_CATEGORIES, RENAMED_CATEGORIES };
