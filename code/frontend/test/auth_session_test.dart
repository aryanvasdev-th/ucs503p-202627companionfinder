import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_companion/services/auth_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a login survives an app restart until logout', () async {
    FlutterSecureStorage.setMockInitialValues({});
    AuthSession.token = 'jwt-123';
    AuthSession.userId = '42';
    AuthSession.isAdmin = false;
    await AuthSession.persist();

    // Simulate the app being closed and reopened.
    AuthSession.token = null;
    AuthSession.userId = null;
    expect(await AuthSession.restore(), isTrue);
    expect(AuthSession.token, 'jwt-123');
    expect(AuthSession.userId, '42');

    await AuthSession.clear();
    expect(AuthSession.token, isNull);
    expect(await AuthSession.restore(), isFalse);
  });
}
