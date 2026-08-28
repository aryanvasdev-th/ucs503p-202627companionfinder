import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/main.dart';

void main() {
  testWidgets('App boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusCompanion());

    expect(find.text('Companion'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
