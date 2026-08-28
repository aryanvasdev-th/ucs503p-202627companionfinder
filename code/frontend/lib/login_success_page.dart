import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/main_scaffold.dart';

class LoginSuccessPage extends StatelessWidget {
  const LoginSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.extras;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(color: extras.greenTint, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 44, color: extras.green),
            ),

            const SizedBox(height: 24),

            Text('Login Successful!', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 24)),

            const SizedBox(height: 10),

            Text(
              'Welcome to Companion',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, color: extras.text2),
            ),

            const SizedBox(height: 36),

            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MainScaffold(initialIndex: 1),
                    ),
                  );
                },
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
