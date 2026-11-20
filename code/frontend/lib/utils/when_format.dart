/// How an activity's time is written across the app.
///
/// Single-day: "Nov 21, 6:00 PM". Multi-day events (a 3-day fest) show the
/// date range instead: "Nov 21 – 23", or "Nov 30 – Dec 2" across months.
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatTime(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String formatDay(DateTime d) => '${_months[d.month - 1]} ${d.day}';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatWhen(DateTime start, [DateTime? end]) {
  if (end == null || _sameDay(start, end)) {
    return '${formatDay(start)}, ${formatTime(start)}';
  }
  final endPart = start.month == end.month && start.year == end.year
      ? '${end.day}'
      : formatDay(end);
  return '${formatDay(start)} – $endPart';
}

/// Parses `startsAt` / `endsAt` from an activity JSON map, local time.
(DateTime, DateTime?) activityWindow(Map<String, dynamic> a) {
  final start = DateTime.parse(a['startsAt']).toLocal();
  final end = a['endsAt'] == null
      ? null
      : DateTime.parse(a['endsAt']).toLocal();
  return (start, end);
}

/// Has the activity finished? Uses its end when it has one, else its start.
bool activityHasEnded(Map<String, dynamic> a, [DateTime? now]) {
  final (start, end) = activityWindow(a);
  return (end ?? start).isBefore(now ?? DateTime.now());
}
