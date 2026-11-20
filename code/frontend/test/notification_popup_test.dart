import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/services/notifications_state.dart';
import 'package:campus_companion/services/realtime_service.dart';
import 'package:campus_companion/theme/app_theme.dart';
import 'package:campus_companion/widgets/notification_popup.dart';

void main() {
  Widget app() => MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => NotificationPopupHost(child: child!),
    home: const Scaffold(body: Text('home')),
  );

  testWidgets('a pushed notification slides in as a banner, then hides', (
    tester,
  ) async {
    NotificationsState.unreadCount.value = 0;
    await tester.pumpWidget(app());
    expect(find.text('Request accepted'), findsNothing);

    RealtimeService.debugDeliver({
      'type': 'request_accepted',
      'title': 'Request accepted',
      'body': 'You\'re in! Your request to join "Football" was accepted.',
      'activityId': null,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Request accepted'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(NotificationsState.unreadCount.value, 1);

    // Auto-dismisses after a few seconds.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Request accepted'), findsNothing);
  });

  testWidgets('notifications that arrive together are shown one at a time', (
    tester,
  ) async {
    await tester.pumpWidget(app());

    RealtimeService.debugDeliver({
      'type': 'join_request',
      'title': 'New join request',
      'body': 'Riya wants to join "Chess"',
    });
    RealtimeService.debugDeliver({
      'type': 'request_declined',
      'title': 'Request declined',
      'body': 'Your request to join "Trek" was declined.',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('New join request'), findsOneWidget);
    expect(find.text('Request declined'), findsNothing);

    // Swiping up dismisses the first and brings in the next.
    await tester.fling(
      find.text('New join request'),
      const Offset(0, -200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('New join request'), findsNothing);
    expect(find.text('Request declined'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
