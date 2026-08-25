import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'otp_verification_page.dart';

// Change this if the college domain is different
const String kAllowedEmailDomain = '@thapar.edu';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Please enter your college email';
    }
    if (!email.toLowerCase().endsWith(kAllowedEmailDomain)) {
      return 'Email must end with $kAllowedEmailDomain';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> signup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    final email = emailController.text.trim();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': passwordController.text,
          'name': nameController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (data['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(email: email),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Signup failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network error. Check your connection and try again.')),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New User Setup'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  const Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 70,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Create Your Account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Sign up with your college email ($kAllowedEmailDomain)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 35),

                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateName,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'College Email',
                      hintText: 'you$kAllowedEmailDomain',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: _validateEmail,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: _validatePassword,
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                    ),
                    validator: _validateConfirmPassword,
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : signup,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontSize: 17),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
