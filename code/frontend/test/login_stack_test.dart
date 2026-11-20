import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/login_success_page.dart';
import 'package:campus_companion/theme/app_theme.dart';

void main() {
  testWidgets('after login nothing is left to swipe back to', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.dark,
        home: const Scaffold(body: Text('login form')),
      ),
    );
    // Same call login_page.dart makes on a successful login.
    navKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginSuccessPage()),
      (route) => false,
    );
    await tester.pumpAndSettle();
    expect(find.text('login form'), findsNothing);
    expect(navKey.currentState!.canPop(), isFalse);
  });
}
