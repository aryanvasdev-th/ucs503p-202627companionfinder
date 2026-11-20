import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/models/categories.dart';
import 'package:campus_companion/theme/app_theme.dart';
import 'package:campus_companion/widgets/host_choice_sheet.dart';

void main() {
  Widget app() => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showHostChoice(context),
          child: const Text('+'),
        ),
      ),
    ),
  );

  testWidgets('+ offers an activity or an event', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    expect(find.text('What are you hosting?'), findsOneWidget);
    expect(find.text('An activity'), findsOneWidget);
    expect(find.text('An event'), findsOneWidget);
  });

  testWidgets('choosing an event opens the event form without categories', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('An event'));
    await tester.pumpAndSettle();
    expect(find.text('Host Event'), findsOneWidget);
    expect(find.text('EVENT NAME'), findsOneWidget);
    expect(find.text('CATEGORY'), findsNothing);
    expect(find.text('MAXIMUM ATTENDEES'), findsOneWidget);
  });

  testWidgets('choosing an activity opens the activity form', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('An activity'));
    await tester.pumpAndSettle();
    expect(find.text('Host Activity'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
    for (final c in kHostableCategories) {
      expect(find.text(c), findsOneWidget);
    }
    expect(find.text(kEventCategory), findsNothing);
  });

  test('Event is a Discover category but never offered to activities', () {
    expect(kActivityCategories, contains(kEventCategory));
    expect(kHostableCategories, isNot(contains(kEventCategory)));
  });
}
