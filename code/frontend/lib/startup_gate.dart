import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'login_page.dart';
import 'services/auth_session.dart';
import 'widgets/main_scaffold.dart';

/// First screen on launch: if a login was saved on this phone, check it's
/// still valid and go straight into the app; otherwise show the login page.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    var loggedIn = await AuthSession.restore();
    if (loggedIn) {
      try {
        final response = await http
            .get(
              Uri.parse('${ApiConfig.apiRoot}/api/users/me'),
              headers: AuthSession.authHeaders,
            )
            .timeout(const Duration(seconds: 8));
        // Expired token, deleted or banned account: back to the login page.
        if (response.statusCode == 401 || response.statusCode == 403) {
          await AuthSession.clear();
          loggedIn = false;
        }
      } catch (_) {
        // Server unreachable (laptop off, no signal): stay logged in; the
        // screens show their own network errors and recover on retry.
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        pageBuilder: (_, _, _) =>
            loggedIn ? const MainScaffold(initialIndex: 1) : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/brand/app_icon.png',
            width: 72,
            height: 72,
          ),
        ),
      ),
    );
  }
}
