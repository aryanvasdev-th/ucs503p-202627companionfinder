// reviewTags.js
// Fixed set of quick tags a reviewer can attach alongside the star score.
// Kept to a fixed list (rather than free text) so profiles can show counts
// like "Punctual x4" — the "review insights" on a public profile.
const REVIEW_TAGS = [
  'Friendly',
  'Punctual',
  'Great host',
  'Good communicator',
  'Reliable',
  'Respectful',
  'Fun to be around',
];

const REVIEW_TEXT_MAX = 500;

module.exports = { REVIEW_TAGS, REVIEW_TEXT_MAX };
