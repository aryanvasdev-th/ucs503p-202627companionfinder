import 'package:flutter/material.dart';
import 'home_page.dart';

class LoginSuccessPage extends StatelessWidget {
  const LoginSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(
              Icons.check_circle,
              size: 100,
              color: Colors.green,
            ),

            const SizedBox(height: 25),

            const Text(
              'Login Successful!',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              'Welcome to Campus Companion 👋',
              style: TextStyle(
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    ),
                  );
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}