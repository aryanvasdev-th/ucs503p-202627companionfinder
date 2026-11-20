import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/main.dart';

void main() {
  testWidgets('with no saved login the app boots to the login screen', (
    WidgetTester tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const CampusCompanion());
    await tester.pumpAndSettle();

    expect(find.text('Companion'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });
}
