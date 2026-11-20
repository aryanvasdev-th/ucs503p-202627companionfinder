import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/utils/when_format.dart';

void main() {
  test('single-day activities show date and time', () {
    expect(formatWhen(DateTime(2026, 11, 21, 18, 0)), 'Nov 21, 6:00 PM');
    expect(
      formatWhen(DateTime(2026, 11, 21, 9, 5), DateTime(2026, 11, 21, 11)),
      'Nov 21, 9:05 AM',
    );
  });

  test('multi-day events show a date range', () {
    expect(
      formatWhen(DateTime(2026, 11, 21, 10), DateTime(2026, 11, 23, 22)),
      'Nov 21 – 23',
    );
    expect(
      formatWhen(DateTime(2026, 11, 30, 10), DateTime(2026, 12, 2, 22)),
      'Nov 30 – Dec 2',
    );
  });

  test('an event still running has not ended', () {
    final now = DateTime(2026, 11, 22, 12);
    final running = {
      'startsAt': DateTime(2026, 11, 21, 10).toIso8601String(),
      'endsAt': DateTime(2026, 11, 23, 22).toIso8601String(),
    };
    final over = {
      'startsAt': DateTime(2026, 11, 18, 10).toIso8601String(),
      'endsAt': DateTime(2026, 11, 20, 22).toIso8601String(),
    };
    expect(activityHasEnded(running, now), isFalse);
    expect(activityHasEnded(over, now), isTrue);
  });
}
